import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as maps;
import 'package:movetraq/models/parcel_order.dart';
import 'package:movetraq/widgets/google_map_status.dart';
import 'package:movetraq/widgets/live_google_map.dart';
import 'package:movetraq/widgets/map_geometry.dart';
import 'package:movetraq/widgets/mini_map.dart';

ParcelOrder order(
        {LatLng? courier, bool simulated = false, String id = 'map'}) =>
    ParcelOrder(
      id: id,
      code: 'MT-MAP',
      senderId: 'sender',
      senderName: 'Sender',
      title: 'Parcel',
      category: 'parcel',
      pickupAddress: 'Ikeja',
      dropoffAddress: 'Lekki',
      pickupLocation: const LatLng(6.6, 3.3),
      dropoffLocation: const LatLng(6.4, 3.5),
      courierLocation: courier,
      courierLocationIsSimulated: simulated,
      courierLocationTrail: const [LatLng(6.5, 3.4), LatLng(6.45, 3.45)],
      price: 3500,
      payout: 3000,
      createdAt: DateTime(2026),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('movetraq/map_config');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() {
    ConfiguredGoogleMap.resetConfigurationCache();
    messenger.setMockMethodCallHandler(channel, (_) async => false);
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  Future<void> mount(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: SizedBox(height: 340, child: child))));
    await tester.pumpAndSettle();
  }

  maps.GoogleMap map(WidgetTester tester) =>
      tester.widget<ConfiguredGoogleMap>(find.byType(ConfiguredGoogleMap)).map;
  bool hasCourier(WidgetTester tester) =>
      map(tester).markers.any((marker) => marker.markerId.value == 'courier');

  test('Coordinates reject nonfinite and out-of-range values', () {
    for (final point in [
      const LatLng(91, 3),
      const LatLng(6, 181),
      const LatLng(double.nan, 3),
      const LatLng(6, double.infinity)
    ]) {
      expect(mapPoint(point), isNull);
    }
    expect(mapPoint(const LatLng(0, 0)), const maps.LatLng(0, 0));
  });

  test('Bounds fit single points, coincident pins, and the date line', () {
    for (final points in [
      [const maps.LatLng(6, 3)],
      [const maps.LatLng(6, 3), const maps.LatLng(6, 3)],
      [const maps.LatLng(6, 179.9), const maps.LatLng(7, -179.9)],
      [const maps.LatLng(90, 180)],
    ]) {
      final bounds = mapBounds(points);
      expect(bounds.southwest.latitude, lessThan(bounds.northeast.latitude));
      for (final point in points) {
        expect(bounds.contains(point), isTrue);
      }
    }
    final bounds =
        mapBounds([const maps.LatLng(6, 179.9), const maps.LatLng(7, -179.9)]);
    expect(bounds.southwest.longitude, greaterThan(bounds.northeast.longitude));
    expect(() => mapBounds([]), throwsArgumentError);
  });

  testWidgets('Live map clears stale pins even during courier animation',
      (tester) async {
    await mount(
        tester, LiveGoogleMap(order: order(courier: const LatLng(6.5, 3.4))));
    expect(hasCourier(tester), isTrue);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(
                height: 340,
                child: LiveGoogleMap(
                    order: order(courier: const LatLng(6.45, 3.45)))))));
    await tester.pump(const Duration(milliseconds: 100));
    await mount(tester, LiveGoogleMap(order: order()));
    expect(hasCourier(tester), isFalse);
    expect(tester.takeException(), isNull);
    await mount(
        tester,
        LiveGoogleMap(
            order: order(courier: const LatLng(6.5, 3.4), id: 'new')));
    expect(hasCourier(tester), isTrue);
  });

  testWidgets('Simulated or invalid locations never appear as live pins',
      (tester) async {
    await mount(
        tester,
        LiveGoogleMap(
            order: order(courier: const LatLng(6.5, 3.4), simulated: true)));
    expect(hasCourier(tester), isFalse);
    expect(
        map(tester)
            .polylines
            .any((line) => line.polylineId.value == 'courier-gps-trail'),
        isFalse);
    await mount(
        tester, LiveGoogleMap(order: order(courier: const LatLng(91, 3))));
    expect(hasCourier(tester), isFalse);
  });

  testWidgets(
      'Embedded maps reserve no sheet space and disable unavailable controls',
      (tester) async {
    await mount(tester, LiveGoogleMap(order: order()));
    expect(map(tester).padding, EdgeInsets.zero);
    for (final button
        in tester.widgetList<IconButton>(find.byType(IconButton))) {
      expect(button.onPressed, isNull);
    }
    await mount(tester,
        LiveGoogleMap(order: order(), topPadding: 70, bottomPadding: 160));
    expect(map(tester).padding, const EdgeInsets.only(top: 70, bottom: 160));
  });

  testWidgets('Location connectors are dashed while GPS history stays solid',
      (tester) async {
    await mount(
        tester, LiveGoogleMap(order: order(courier: const LatLng(6.45, 3.45))));
    for (final line in map(tester).polylines) {
      expect(
          line.patterns.isEmpty, line.polylineId.value == 'courier-gps-trail');
    }
    await mount(
        tester,
        const MiniMap(
            pickupLocation: LatLng(6, 179.9),
            dropoffLocation: LatLng(7, -179.9)));
    expect(map(tester).initialCameraPosition.target.longitude.abs(),
        closeTo(180, .001));
    expect(map(tester).markers.length, 2);
  });

  testWidgets(
      'Missing configuration and bridge errors fail closed and allow retry',
      (tester) async {
    var calls = 0;
    messenger.setMockMethodCallHandler(channel, (_) async {
      calls++;
      throw PlatformException(code: 'NOT_CONFIGURED');
    });
    await mount(
        tester,
        const ConfiguredGoogleMap(
            map: maps.GoogleMap(
                initialCameraPosition:
                    maps.CameraPosition(target: maps.LatLng(6, 3)))));
    expect(find.text('Map unavailable'), findsOneWidget);
    expect(find.byType(maps.GoogleMap), findsNothing);
    expect(calls, 1);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(tester.takeException(), isNull);
  });
}
