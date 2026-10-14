import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:movetraq/core/networking/production_api.dart';
import 'package:movetraq/core/storage/session_store.dart';
import 'package:movetraq/features/auth/models/production_session.dart';
import 'package:movetraq/features/auth/repositories/production_auth_repository.dart';
import 'package:movetraq/features/auth/providers/production_auth_controller.dart';
import 'package:movetraq/features/addresses/models/production_address.dart';
import 'package:movetraq/features/addresses/repositories/production_address_repository.dart';

class MemoryStore implements SessionStore {
  ProductionSession? session;
  @override
  Future<ProductionSession?> read() async => session;
  @override
  Future<void> write(ProductionSession value) async {
    session = value;
  }

  @override
  Future<void> clear() async {
    session = null;
  }
}

class Adapter implements HttpClientAdapter {
  Adapter(this.respond);
  final Future<ResponseBody> Function(RequestOptions) respond;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? stream,
      Future<void>? cancelFuture) {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody ok(Map<String, dynamic> data) =>
    ResponseBody.fromString(jsonEncode({'success': true, 'data': data}), 200,
        headers: {
          Headers.contentTypeHeader: ['application/json']
        });
ResponseBody denied(String code, {int status = 401}) => ResponseBody.fromString(
        jsonEncode({
          'success': false,
          'error': {'code': code, 'message': 'Denied.'}
        }),
        status,
        headers: {
          Headers.contentTypeHeader: ['application/json']
        });
final account = {
  'uid': 'user',
  'name': 'User',
  'email': 'user@example.test',
  'roles': ['sender'],
  'wallet': {'balanceMinor': 12345, 'currency': 'NGN'}
};
Map<String, dynamic> auth(String token, {int expiresAt = 2000000000}) => {
      'user': account,
      'session': {
        'accessToken': token,
        'refreshToken': '$token-refresh',
        'expiresAt': expiresAt
      }
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MemoryStore store;
  late Adapter adapter;
  late ProductionApi api;
  late ProductionAuthRepository repository;
  void setup(Future<ResponseBody> Function(RequestOptions) respond) {
    store = MemoryStore();
    adapter = Adapter(respond);
    final dio = Dio()..httpClientAdapter = adapter;
    api = ProductionApi(baseUrl: 'https://api.example.test/api/v1', dio: dio);
    repository = ProductionAuthRepository(
        api: api,
        store: store,
        clock: () => DateTime.fromMillisecondsSinceEpoch(1000000000000));
    addTearDown(api.dispose);
  }

  test('Controller keeps confirmation signup signed out until verification',
      () async {
    setup((request) async => request.path.endsWith('/auth/signup')
        ? ok({'requiresEmailConfirmation': true})
        : ok(auth('verified')));
    final controller = ProductionAuthController(repository);
    addTearDown(controller.dispose);
    expect(
        await controller.signUp(
            name: 'User',
            email: ' user@example.test ',
            password: 'long-test-password'),
        isTrue);
    expect(controller.status, ProductionAuthStatus.emailConfirmationRequired);
    expect(controller.account, isNull);
    expect(store.session, isNull);
    expect(controller.pendingEmail, 'user@example.test');
    expect(await controller.verifyCode('123456'), isTrue);
    expect(controller.status, ProductionAuthStatus.signedIn);
    expect(controller.pendingEmail, isNull);
  });

  test('Controller recovery requires verified code before password update',
      () async {
    setup((request) async => request.path.endsWith('/auth/verify')
        ? ok(auth('recovered'))
        : ok({'updated': true}));
    final controller = ProductionAuthController(repository);
    addTearDown(controller.dispose);
    expect(await controller.changeRecoveredPassword('new-password'), isFalse);
    expect(adapter.requests, isEmpty);
    expect(await controller.requestRecovery('user@example.test'), isTrue);
    expect(controller.status, ProductionAuthStatus.recoveryCodeRequired);
    expect(await controller.verifyCode('123456'), isTrue);
    expect(adapter.requests.last.data['type'], 'recovery');
    expect(controller.status, ProductionAuthStatus.passwordChangeRequired);
    expect(await controller.changeRecoveredPassword('new-password'), isTrue);
    expect(controller.status, ProductionAuthStatus.signedIn);
  });

  test('Controller logout clears account on failed remote revocation',
      () async {
    setup((request) async => request.path.endsWith('/auth/logout')
        ? denied('UNAVAILABLE', status: 503)
        : ok(auth('login')));
    final controller = ProductionAuthController(repository);
    addTearDown(controller.dispose);
    await controller.signIn('user@example.test', 'password');
    expect(await controller.signOut(), isFalse);
    expect(controller.status, ProductionAuthStatus.signedOut);
    expect(controller.account, isNull);
    expect(store.session, isNull);
    expect(controller.errorMessage, 'Denied.');
  });

  test(
      'Controller suppresses duplicate actions and notifications after disposal',
      () async {
    final response = Completer<ResponseBody>();
    setup((_) => response.future);
    final controller = ProductionAuthController(repository);
    final login = controller.signIn('user@example.test', 'password');
    expect(controller.isBusy, isTrue);
    expect(await controller.signIn('user@example.test', 'password'), isFalse);
    controller.dispose();
    response.complete(ok(auth('login')));
    expect(await login, isTrue);
    expect(adapter.requests, hasLength(1));
  });

  test(
      'Production accounts preserve simultaneous sender and deliverer capabilities',
      () {
    final profile = ProductionAccount.fromJson({
      ...account,
      'roles': ['sender', 'deliverer'],
      'activeRole': 'deliverer',
      'verificationStatus': 'approved',
      'delivererVerificationStatus': 'suspended'
    });
    expect(profile.canSend, isTrue);
    expect(profile.canDeliver, isTrue);
    expect(profile.activeRole, 'deliverer');
    expect(profile.delivererVerificationStatus, 'suspended');
  });

  test(
      'Production address CRUD and selection use authenticated server contracts',
      () async {
    const id = '10000000-0000-4000-8000-000000000099';
    final row = {
      'id': id,
      'user_id': 'user',
      'label': 'Home',
      'address': 'Ikeja Lagos',
      'latitude': 6.6,
      'longitude': 3.3,
      'place_id': 'place',
      'city': 'Lagos',
      'state': 'Lagos',
      'country': 'NG',
      'is_default': false,
      'created_at': '2026-10-12T10:00:00Z',
      'updated_at': '2026-10-12T10:00:00Z'
    };
    setup((request) async {
      if (request.path == '/auth/signin') return ok(auth('first'));
      if (request.method == 'DELETE') return ok({'deleted': true});
      if (request.path.endsWith('/select')) {
        return ok({'selected_address_id': id});
      }
      if (request.method == 'GET') {
        return ok({
          'addresses': [row]
        });
      }
      return ok({
        'address': {...row, 'is_default': request.path.endsWith('/default')}
      });
    });
    await repository.signIn('user@example.test', 'secret');
    final addresses = ProductionAddressRepository(repository);
    const input = AddressInput(
        label: 'Home',
        address: 'Ikeja Lagos',
        latitude: 6.6,
        longitude: 3.3,
        city: 'Lagos');
    expect((await addresses.add(input)).id, id);
    expect((adapter.requests.last.data as Map).containsKey('user_id'), isFalse);
    expect((await addresses.list()).single.city, 'Lagos');
    await addresses.edit(id, input);
    expect(adapter.requests.last.method, 'PUT');
    expect((await addresses.markDefault(id)).isDefault, isTrue);
    expect(adapter.requests.last.data, isNull);
    await addresses.select(id);
    await addresses.delete(id);
    for (final request in adapter.requests.skip(1)) {
      expect(request.headers['Authorization'], 'Bearer first');
    }
  });

  test(
      'Address operations never fabricate success on missing session or server failure',
      () async {
    setup((request) async => request.path == '/auth/signin'
        ? ok(auth('first'))
        : denied('NOT_FOUND', status: 404));
    final addresses = ProductionAddressRepository(repository);
    await expectLater(addresses.list(), throwsA(isA<ProductionApiError>()));
    expect(adapter.requests, isEmpty);
    await repository.signIn('user@example.test', 'secret');
    await expectLater(
        addresses.delete('10000000-0000-4000-8000-000000000099'),
        throwsA(
            isA<ProductionApiError>().having((e) => e.status, 'status', 404)));
    final count = adapter.requests.length;
    await expectLater(addresses.select('../other-user'), throwsArgumentError);
    expect(adapter.requests.length, count);
  });

  test('Secure session storage round-trips credentials and clears corrupt data',
      () async {
    FlutterSecureStorage.setMockInitialValues({});
    const secure = SecureSessionStore();
    const session = ProductionSession(
        accessToken: 'test-access',
        refreshToken: 'test-refresh',
        expiresAt: 2000000000);
    await secure.write(session);
    expect((await secure.read())!.refreshToken, 'test-refresh');
    await secure.clear();
    expect(await secure.read(), isNull);
    FlutterSecureStorage.setMockInitialValues(
        {'movetraq.production.session.v1': '{broken-json'});
    expect(await secure.read(), isNull);
    expect(await const FlutterSecureStorage().readAll(), isEmpty);
  });

  test('Signin stores rotated credentials and preserves integer money',
      () async {
    setup((_) async => ok(auth('first')));
    final result = await repository.signIn(' user@example.test ', 'secret');
    expect(result.balanceMinor, 12345);
    expect(store.session!.accessToken, 'first');
    expect(adapter.requests.single.uri.toString(),
        'https://api.example.test/api/v1/auth/signin');
    expect(
        adapter.requests.single.headers.containsKey('Authorization'), isFalse);
  });

  test('Signup confirmation never fabricates an authenticated account',
      () async {
    setup((_) async => ok({'requiresEmailConfirmation': true}));
    final result = await repository.signUp(
        name: 'User', email: 'user@example.test', password: 'secret');
    expect(result, isNull);
    expect(store.session, isNull);
  });

  test('Expired restored credentials refresh once before loading profile',
      () async {
    setup((options) async => options.path == '/auth/refresh'
        ? ok(auth('rotated'))
        : ok({'user': account}));
    store.session = const ProductionSession(
        accessToken: 'expired', refreshToken: 'old-refresh', expiresAt: 1);
    expect((await repository.restore())!.id, 'user');
    expect(adapter.requests.map((request) => request.path),
        ['/auth/refresh', '/users/me']);
    expect(adapter.requests.last.headers['Authorization'], 'Bearer rotated');
    expect(store.session!.refreshToken, 'rotated-refresh');
  });

  test('Invalid refresh clears credentials and restores signed-out state',
      () async {
    setup((_) async => denied('INVALID_SESSION'));
    store.session = const ProductionSession(
        accessToken: 'expired', refreshToken: 'revoked', expiresAt: 1);
    expect(await repository.restore(), isNull);
    expect(store.session, isNull);
    expect(adapter.requests.length, 1);
  });

  test(
      'Concurrent restores use the rotated credentials without duplicate refresh',
      () async {
    setup((options) async => options.path == '/auth/refresh'
        ? ok(auth('rotated'))
        : ok({'user': account}));
    store.session = const ProductionSession(
        accessToken: 'expired', refreshToken: 'old-refresh', expiresAt: 1);
    await Future.wait([repository.restore(), repository.restore()]);
    expect(
        adapter.requests
            .where((request) => request.path == '/auth/refresh')
            .length,
        1);
  });

  test('Logout cannot be undone by a late signin response', () async {
    final pending = Completer<ResponseBody>();
    setup((options) async => options.path == '/auth/signin'
        ? await pending.future
        : ok({'message': 'Signed out'}));
    final login = repository.signIn('user@example.test', 'secret');
    await Future<void>.delayed(Duration.zero);
    final logout = repository.signOut();
    pending.complete(ok(auth('first')));
    await login;
    await logout;
    expect(store.session, isNull);
    expect(adapter.requests.last.path, '/auth/logout');
    expect(adapter.requests.last.headers['Authorization'], 'Bearer first');
  });

  test('Offline restore retains secure credentials without inventing a profile',
      () async {
    setup((options) async => throw DioException(
        requestOptions: options, type: DioExceptionType.connectionError));
    store.session = const ProductionSession(
        accessToken: 'first', refreshToken: 'refresh', expiresAt: 2000000000);
    await expectLater(
        repository.restore(),
        throwsA(isA<ProductionApiError>()
            .having((error) => error.code, 'code', 'NETWORK_UNAVAILABLE')));
    expect(store.session, isNotNull);
    expect(adapter.requests.length, 1);
  });

  test('401 retries once after refresh; a second denial clears the session',
      () async {
    setup((options) async => options.path == '/auth/refresh'
        ? ok(auth('rotated'))
        : denied('UNAUTHORIZED'));
    store.session = const ProductionSession(
        accessToken: 'first', refreshToken: 'refresh', expiresAt: 2000000000);
    expect(await repository.restore(), isNull);
    expect(store.session, isNull);
    expect(adapter.requests.length, 3);
  });

  test('Server role denial is not refreshed or converted into success',
      () async {
    setup((_) async => denied('ACCOUNT_DISABLED', status: 403));
    store.session = const ProductionSession(
        accessToken: 'first', refreshToken: 'refresh', expiresAt: 2000000000);
    await expectLater(
        repository.restore(),
        throwsA(isA<ProductionApiError>()
            .having((error) => error.code, 'code', 'ACCOUNT_DISABLED')));
    expect(adapter.requests.length, 1);
  });

  test('Credential-bearing API requests cannot target another host', () async {
    setup((_) async => ok({}));
    for (final path in ['https://other.test/auth', '//other.test/auth']) {
      await expectLater(
          api.request('GET', path, token: 'secret'), throwsArgumentError);
    }
    expect(adapter.requests, isEmpty);
    expect(() => ProductionApi(baseUrl: 'http://public.example.test'),
        throwsArgumentError);
  });

  test('Recovery and verification use the real backend contracts', () async {
    setup((options) async => options.path == '/auth/recover'
        ? ok({'message': 'Check email'})
        : ok(auth('recovered')));
    await repository.recover('user@example.test');
    await repository.verify('user@example.test', '123456', recovery: true);
    await repository.changePassword('new-long-password');
    expect(adapter.requests.map((request) => request.path),
        ['/auth/recover', '/auth/verify', '/auth/password']);
    expect((adapter.requests[1].data as Map)['type'], 'recovery');
    expect(adapter.requests.last.headers['Authorization'], 'Bearer recovered');
  });
}
