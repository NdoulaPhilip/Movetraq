import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movetraq/core/config/environment.dart';
import 'package:movetraq/core/networking/api.dart';
import 'package:movetraq/core/networking/production_api.dart';
import 'package:movetraq/core/networking/uploads.dart';
import 'package:movetraq/core/notifications/push_service.dart';
import 'package:movetraq/core/routing/router.dart';
import 'package:movetraq/core/routing/workspace_switch.dart';
import 'package:movetraq/core/storage/cache.dart';
import 'package:movetraq/core/storage/secure_session.dart';
import 'package:movetraq/core/theme/preferences.dart';
import 'package:movetraq/core/widgets/components.dart' as ui;
import 'package:movetraq/core/widgets/resource_view.dart';
import 'package:movetraq/features/auth/repositories/production_auth_repository.dart';
import 'production_auth_test.dart' as fixtures;

class _PushTransport implements PushTransport {
  final changes = StreamController<String>.broadcast();
  bool permitted = true;
  String? currentToken = 'device-token';
  Completer<void>? initializePending;
  int starts = 0, deletions = 0;
  @override
  Future<void> initialize() async {
    starts++;
    await initializePending?.future;
  }

  @override
  Future<bool> requestPermission() async => permitted;
  @override
  Future<String?> token() async => currentToken;
  @override
  Stream<String> get tokenChanges => changes.stream;
  @override
  Future<void> deleteToken() async {
    deletions++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
      'Environment normalizes only current backend origins and rejects insecure URLs',
      () {
    expect(
        const AppEnvironment(apiUrl: 'https://api.example.test/')
            .apiBaseUri
            .toString(),
        'https://api.example.test/api/v1');
    expect(
        const AppEnvironment(apiUrl: 'http://127.0.0.1:3001/api/v1')
            .apiBaseUri
            .port,
        3001);
    for (final value in [
      'http://public.example.test',
      'https://user:secret@example.test',
      'https://api.example.test/v1',
      'https://api.example.test?key=secret'
    ]) {
      expect(
          () => AppEnvironment(apiUrl: value).apiBaseUri, throwsArgumentError);
    }
    expect(const AppEnvironment(apiUrl: '').configured, isFalse);
    expect(
        () => const AppEnvironment(
                apiUrl: 'https://api.example.test',
                supabaseUrl: 'https://storage.example.test/path')
            .storageOrigin,
        throwsArgumentError);
  });

  test(
      'Secure cache isolates users, excludes finance, and preserves credentials on clear',
      () async {
    final cache = ReadCache();
    const pkce = SecurePkceStorage();
    await pkce.setItem(key: 'verifier', value: 'secret-verifier');
    await cache.write('user', '/users/me/preferences', {'reduce_motion': true});
    expect(await cache.read('other-user', '/users/me/preferences'), isNull);
    expect(await cache.read('user', '/users/me/preferences'),
        {'reduce_motion': true});
    for (final path in [
      '/wallet',
      '/orders',
      '/users/me',
      '/payments',
      '/deliverer/jobs'
    ]) {
      await cache.write('user', path, {'balanceMinor': 100});
      expect(await cache.read('user', path), isNull);
    }
    await cache.clearUser('user');
    expect(await cache.read('user', '/users/me/preferences'), isNull);
    expect(await pkce.getItem(key: 'verifier'), 'secret-verifier');
    await pkce.removeItem(key: 'verifier');
    expect(await pkce.getItem(key: 'verifier'), isNull);
  });

  test('Cache expires, deletes corrupt records and rejects future timestamps',
      () async {
    var now = DateTime.utc(2026, 10, 14);
    final cache = ReadCache(clock: () => now);
    const storage = FlutterSecureStorage();
    await cache.write('user', '/users/me/addresses', {'addresses': []});
    now = now.add(const Duration(days: 2));
    expect(await cache.read('user', '/users/me/addresses'), isNull);
    final key = cache.key('user', '/users/me/preferences');
    await storage.write(key: key, value: '{bad-json');
    expect(await cache.read('user', '/users/me/preferences'), isNull);
    expect(await storage.read(key: key), isNull);
    await storage.write(
        key: key,
        value: jsonEncode({
          'saved_at': now.add(const Duration(days: 1)).toIso8601String(),
          'data': {}
        }));
    expect(await cache.read('user', '/users/me/preferences'), isNull);
  });

  test('Cache clear is serialized after pending writes', () async {
    final cache = ReadCache();
    final write = cache.write('user', '/users/me/preferences', {'value': true});
    final clear = cache.clearUser('user');
    await Future.wait([write, clear]);
    expect(await cache.read('user', '/users/me/preferences'), isNull);
  });

  test('API carries idempotency keys and only serves approved reads offline',
      () async {
    var offline = false;
    final adapter = fixtures.Adapter((options) async {
      if (options.path.endsWith('/auth/signin')) {
        return fixtures.ok(fixtures.auth('token'));
      }
      if (options.path.endsWith('/auth/logout')) return fixtures.ok({});
      if (offline) {
        throw DioException(
            requestOptions: options, type: DioExceptionType.connectionError);
      }
      return fixtures.ok({
        'display_preferences': {'reduce_motion': true}
      });
    });
    final transport = ProductionApi(
        baseUrl: 'https://api.example.test/api/v1',
        dio: Dio()..httpClientAdapter = adapter);
    addTearDown(transport.dispose);
    final auth = ProductionAuthRepository(
        api: transport,
        store: fixtures.MemoryStore(),
        clock: () => DateTime.fromMillisecondsSinceEpoch(1000000000000));
    await auth.signIn('user@example.test', 'password');
    final api = ApiClient(auth);
    addTearDown(api.dispose);
    await api.request('/users/me/preferences',
        method: 'PATCH', data: {}, key: '12345678-1234-1234-1234-123456789012');
    expect(adapter.requests.last.headers['Idempotency-Key'],
        '12345678-1234-1234-1234-123456789012');
    await api.request('/users/me/preferences');
    offline = true;
    expect((await api.request('/users/me/preferences'))['display_preferences'],
        {'reduce_motion': true});
    expect(api.offline.value, isTrue);
    await expectLater(
        api.request('/wallet'), throwsA(isA<ProductionApiError>()));
    await expectLater(
        api.request('/users/me/preferences', method: 'PATCH', data: {}),
        throwsA(isA<ProductionApiError>()));
    await expectLater(
        api.request('//foreign.example.test'), throwsArgumentError);
    offline = false;
    await api.signOut();
    expect(auth.userId, isNull);
    expect(await api.cache.read('user', '/users/me/preferences'), isNull);
  });

  test(
      'Private uploads validate format and size before allocating a reservation',
      () {
    expect(
        () => UploadService.validateBytes(
            Uint8List(0), 'image/jpeg', UploadPurpose.evidence),
        throwsArgumentError);
    expect(
        () => UploadService.validateBytes(
            Uint8List(UploadService.evidenceMaximum + 1),
            'image/jpeg',
            UploadPurpose.evidence),
        throwsArgumentError);
    expect(
        () => UploadService.validateBytes(
            Uint8List.fromList([1, 2, 3]), 'image/png', UploadPurpose.evidence),
        throwsArgumentError);
    expect(
        () =>
            UploadService.mimeType('picture.webp', UploadPurpose.verification),
        throwsArgumentError);
    expect(UploadService.mimeType('identity.PDF', UploadPurpose.verification),
        'application/pdf');
  });

  test(
      'Upload confirms only after private Storage succeeds and never sends API credentials',
      () async {
    const id = '10000000-0000-4000-8000-000000000001';
    final events = <String>[];
    final adapter = fixtures.Adapter((options) async {
      events.add('upload');
      expect(options.followRedirects, isFalse);
      expect(options.headers['Authorization'], isNull);
      expect(options.headers['Cookie'], isNull);
      return ResponseBody.fromString('', 200);
    });
    final service = UploadService(
        storageOrigin: Uri.parse('https://project.supabase.co'),
        transport: Dio()..httpClientAdapter = adapter,
        request: (method, path, body) async {
          events.add(path.endsWith('/confirm') ? 'confirm' : 'reserve');
          return {
            'uploadId': id,
            'signedUrl':
                'https://project.supabase.co/storage/v1/object/upload/sign/evidence/file?token=private'
          };
        });
    addTearDown(service.dispose);
    expect(
        await service.uploadBytes(Uint8List.fromList([255, 216, 255]),
            mime: 'image/jpeg', entityId: id, purpose: UploadPurpose.evidence),
        id);
    expect(events, ['reserve', 'upload', 'confirm']);
  });

  test(
      'Upload rejects unrelated origins and failed transfers without confirmation',
      () async {
    const id = '10000000-0000-4000-8000-000000000001';
    var host = 'foreign.example.test';
    final paths = <String>[];
    final service = UploadService(
        storageOrigin: Uri.parse('https://project.supabase.co'),
        transport: Dio()
          ..httpClientAdapter =
              fixtures.Adapter((_) async => ResponseBody.fromString('', 500)),
        request: (_, path, __) async {
          paths.add(path);
          return {
            'uploadId': id,
            'signedUrl':
                'https://$host/storage/v1/object/upload/sign/evidence/file?token=private'
          };
        });
    addTearDown(service.dispose);
    Future<String> send() =>
        service.uploadBytes(Uint8List.fromList([255, 216, 255]),
            mime: 'image/jpeg', entityId: id, purpose: UploadPurpose.evidence);
    await expectLater(send(), throwsStateError);
    host = 'project.supabase.co';
    await expectLater(send(), throwsA(isA<DioException>()));
    expect(paths.any((path) => path.endsWith('/confirm')), isFalse);
  });

  test('Push stays disabled or unconfigured without initializing Firebase',
      () async {
    final transport = _PushTransport();
    addTearDown(transport.changes.close);
    final disabled =
        PushService(enabled: false, userId: () => 'user', transport: transport);
    final unconfigured =
        PushService(enabled: true, userId: () => 'user', transport: transport);
    addTearDown(disabled.dispose);
    addTearDown(unconfigured.dispose);
    expect(await disabled.start(), PushStatus.disabled);
    expect(await unconfigured.start(), PushStatus.notConfigured);
    expect(transport.starts, 0);
  });

  test('Push permission, rotation and unregister use actual provider results',
      () async {
    final transport = _PushTransport();
    addTearDown(transport.changes.close);
    final registrations = <String>[];
    final service = PushService(
        enabled: true,
        userId: () => 'user',
        transport: transport,
        registerDevice: (user, token) async =>
            registrations.add('$user:$token'),
        unregisterDevice: (user, token) async =>
            registrations.add('remove:$user:$token'));
    addTearDown(service.dispose);
    transport.permitted = false;
    expect(await service.start(), PushStatus.permissionDenied);
    expect(registrations, isEmpty);
    transport.permitted = true;
    transport.currentToken = null;
    expect(await service.start(), PushStatus.apnsPending);
    transport.currentToken = 'token-1';
    expect(await service.start(), PushStatus.active);
    transport.changes.add('token-2');
    await Future<void>.delayed(Duration.zero);
    expect(registrations, ['user:token-1', 'user:token-2']);
    await service.unregister();
    expect(registrations.last, 'remove:user:token-2');
    expect(transport.deletions, 1);
  });

  test('Push cannot subscribe or register after disposal during initialization',
      () async {
    final transport = _PushTransport()..initializePending = Completer<void>();
    addTearDown(transport.changes.close);
    final registered = <String>[];
    final service = PushService(
        enabled: true,
        userId: () => 'user',
        transport: transport,
        registerDevice: (_, token) async => registered.add(token),
        unregisterDevice: (_, __) async {});
    final first = service.start();
    final second = service.start();
    expect(identical(first, second), isTrue);
    service.dispose();
    transport.initializePending!.complete();
    await first;
    transport.changes.add('later-token');
    await Future<void>.delayed(Duration.zero);
    expect(registered, isEmpty);
    expect(transport.starts, 1);
  });

  test('Accessibility settings respect system text and isolate users', () {
    final settings = DisplayPreferences();
    addTearDown(settings.dispose);
    settings.resetForUser('user');
    settings.applyServer('other-user', {
      'display_preferences': {'reduce_motion': true}
    });
    expect(settings.reduceMotion, isFalse);
    settings.applyServer('user', {
      'display_preferences': {'reduce_motion': true, 'larger_text': true}
    });
    final media = settings
        .mediaQuery(const MediaQueryData(textScaler: TextScaler.linear(2)));
    expect(media.textScaler.scale(14), 28);
    expect(media.disableAnimations, isTrue);
    settings.resetForUser('other-user');
    expect(settings.largerText, isFalse);
  });

  test(
      'Money display preserves integer precision and rejects malformed amounts',
      () {
    expect(ui.money(350025), '\u20a63,500.25');
    expect(ui.money('-100'), '\u20a6-1');
    expect(ui.money('900719925474099301'), '\u20a69,007,199,254,740,993.01');
    expect(() => ui.money('not-money'), throwsArgumentError);
  });

  test('Every shared icon has an actual bundled asset', () async {
    for (final name in ui.BrandIcon.names.values.toSet()) {
      expect((await rootBundle.load('assets/icons/$name.svg')).lengthInBytes,
          greaterThan(0));
    }
  });

  testWidgets(
      'Resource view retries, sanitizes errors and ignores old resource results',
      (tester) async {
    var fails = true;
    Future<String> load() async {
      if (fails) throw StateError('secret backend details');
      return 'Loaded';
    }

    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ResourceView<String>(
                load: load, builder: Text.new, resourceKey: 'user-1'))));
    await tester.pumpAndSettle();
    expect(find.text('secret backend details'), findsNothing);
    fails = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Loaded'), findsOneWidget);
    final old = Completer<String>();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ResourceView<String>(
                load: () => old.future,
                builder: Text.new,
                resourceKey: 'user-2'))));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ResourceView<String>(
                load: () async => 'New user',
                builder: Text.new,
                resourceKey: 'user-3'))));
    old.complete('Old user');
    await tester.pumpAndSettle();
    expect(find.text('New user'), findsOneWidget);
    expect(find.text('Old user'), findsNothing);
  });

  testWidgets('Unknown routes display an unavailable page', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(),
        initialRoute: '/does-not-exist',
        onGenerateRoute: AppRouter.onGenerateRoute));
    await tester.pumpAndSettle();
    expect(find.text('Page unavailable'), findsOneWidget);
  });

  testWidgets(
      'Workspace overlay waits for the actual role change and never invents progress',
      (tester) async {
    final result = Completer<bool>();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () => WorkspaceSwitch.open(context,
                        deliverer: true, changeRole: () => result.future),
                    child: const Text('Switch'))))));
    await tester.tap(find.text('Switch'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Getting you ready to deliver'), findsOneWidget);
    result.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('Getting you ready to deliver'), findsNothing);
  });
}
