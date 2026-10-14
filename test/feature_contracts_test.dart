import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:movetraq/core/networking/api.dart';
import 'package:movetraq/core/networking/production_api.dart';
import 'package:movetraq/features/auth/repositories/production_auth_repository.dart';
import 'package:movetraq/features/orders/order_repository.dart';
import 'package:movetraq/features/payments/checkout_request.dart';
import 'package:movetraq/features/payments/payment_checkout.dart';
import 'package:movetraq/features/tracking/tracking_service.dart';
import 'package:movetraq/features/wallet/deposit_amount.dart';
import 'package:movetraq/services/location_service.dart';
import 'production_auth_test.dart' as fixtures;

class _Location extends LocationService {
  final positions = StreamController<Position>.broadcast();
  int permissions = 0;
  @override
  Future<void> ensurePermission() async {
    permissions++;
  }

  @override
  Stream<Position> watchPosition() => positions.stream;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  const id = '10000000-0000-4000-8000-000000000001';
  late fixtures.Adapter adapter;
  Future<ApiClient> setup(
      Future<ResponseBody> Function(RequestOptions) respond) async {
    adapter = fixtures.Adapter((options) =>
        options.path.endsWith('/auth/signin')
            ? Future.value(fixtures.ok(fixtures.auth('token')))
            : respond(options));
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
    return api;
  }

  test(
      'Order creation uses server quotes and commands, not client totals or status transitions',
      () async {
    final api = await setup(
        (options) async => fixtures.ok(options.path.endsWith('/quotes')
            ? {
                'quote': {'id': id, 'total_amount_minor': 350000}
              }
            : {
                'order': {'id': id}
              }));
    final orders = OrderRepository(api);
    expect((await orders.quote({'serviceType': 'p2p'}))['id'], id);
    await orders.create(id, '12345678-1234-1234-1234-123456789012');
    expect(adapter.requests.last.data, {'quoteId': id});
    expect(adapter.requests.last.headers['Idempotency-Key'], isNotNull);
    await orders.command(id, 'picked_up');
    expect(adapter.requests.last.path, '/orders/$id/commands');
    expect(adapter.requests.last.data, {'command': 'picked_up'});
    await expectLater(
        orders.command(id, 'made-up-status'), throwsArgumentError);
    await expectLater(
        orders.command(id, 'accept', input: {'status': 'completed'}),
        throwsArgumentError);
    await expectLater(
        orders.create('../wallet', '12345678-1234-1234-1234-123456789012'),
        throwsArgumentError);
  });

  test('Wallet deposits use integer kobo and current idempotent topup endpoint',
      () async {
    final api = await setup((_) async => fixtures.ok({'reference': 'test'}));
    await PaymentCheckout(api)
        .initializeTopup(10025, '12345678-1234-1234-1234-123456789012');
    expect(adapter.requests.last.path, '/payments/topups');
    expect(adapter.requests.last.data, {'amountMinor': 10025});
    expect(depositMinorUnits('100.25'), 10025);
    expect(depositMinorUnits('99.99'), isNull);
    expect(depositMinorUnits('1000000.01'), isNull);
    expect(depositMinorUnits('100.001'), isNull);
    expect(() => PaymentCheckout(api).initializeTopup(9999, 'key'),
        throwsArgumentError);
  });

  test(
      'Checkout URLs and callbacks never assert payment success or accept spoofed hosts',
      () {
    final reference = 'mt-${List.filled(64, 'a').join()}';
    Map<String, dynamic> details(String url) => {
          'checkoutUrl': url,
          'reference': reference,
          'callbackUrl': 'https://movetraq.example.test/payment/callback'
        };
    final request = CheckoutRequest.fromJson(
        details('https://checkout.paystack.com/session'));
    expect(
        request.isCallback(Uri.parse(
            'https://movetraq.example.test/payment/callback?reference=$reference')),
        isTrue);
    expect(
        request.isCallback(Uri.parse(
            'https://movetraq.example.test/payment/callback?reference=wrong')),
        isFalse);
    for (final url in [
      'http://checkout.paystack.com/session',
      'https://checkout.paystack.com.evil.test/session',
      'https://user:secret@checkout.paystack.com/session',
      'https://checkout.paystack.com:444/session'
    ]) {
      expect(
          () => CheckoutRequest.fromJson(details(url)), throwsFormatException);
    }
    expect(request.allowsNavigation(Uri.parse('javascript:alert(1)')), isFalse);
    expect(
        request.isAuthenticationClose(
            Uri.parse('https://standard.paystack.co/close')),
        isTrue);
  });

  test('Foreground tracking validates active assignment before requesting GPS',
      () async {
    var status = 'completed';
    final api = await setup((_) async => fixtures.ok({
          'order': {'deliverer_id': 'user', 'status': status}
        }));
    final location = _Location();
    addTearDown(location.positions.close);
    final tracker = TrackingService(api, location: location);
    addTearDown(tracker.stop);
    await expectLater(tracker.start(id, (_) {}), throwsStateError);
    expect(location.permissions, 0);
    status = 'picked_up';
    await tracker.start(id, (_) {});
    expect(location.permissions, 1);
    await tracker.stop();
    expect(location.positions.hasListener, isFalse);
  });

  test(
      'Tracking throttles, uses current location fields, and stops sending after opt-out',
      () async {
    var now = DateTime.utc(2026, 10, 14, 12);
    final api =
        await setup((options) async => fixtures.ok(options.method == 'GET'
            ? {
                'order': {'deliverer_id': 'user', 'status': 'picked_up'}
              }
            : {}));
    final location = _Location();
    addTearDown(location.positions.close);
    final tracker = TrackingService(api, location: location, clock: () => now);
    addTearDown(tracker.stop);
    Position position() => Position(
        latitude: 6.5,
        longitude: 3.4,
        timestamp: now,
        accuracy: 10,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0);
    await tracker.start(id, (_) {});
    location.positions.add(position());
    await Future<void>.delayed(const Duration(milliseconds: 25));
    final sent =
        adapter.requests.where((r) => r.path.endsWith('/location')).toList();
    expect(sent.length, 1);
    expect((sent.single.data as Map).keys,
        containsAll(['accuracyMeters', 'capturedAt']));
    location.positions.add(position());
    await Future<void>.delayed(const Duration(milliseconds: 25));
    expect(
        adapter.requests.where((r) => r.path.endsWith('/location')).length, 1);
    now = now.add(const Duration(seconds: 11));
    location.positions.add(position());
    await Future<void>.delayed(const Duration(milliseconds: 25));
    expect(
        adapter.requests.where((r) => r.path.endsWith('/location')).length, 2);
    await tracker.stop();
    location.positions.add(position());
    await Future<void>.delayed(const Duration(milliseconds: 25));
    expect(
        adapter.requests.where((r) => r.path.endsWith('/location')).length, 2);
  });
}
