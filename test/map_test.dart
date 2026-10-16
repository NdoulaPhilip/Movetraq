import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' as geo;
import 'package:movetraq/models/parcel_order.dart';
import 'package:movetraq/widgets/live_delivery_map.dart';
import 'package:movetraq/widgets/map_geometry.dart';
import 'package:movetraq/widgets/mini_map.dart';
import 'package:movetraq/widgets/street_map.dart';
import 'support/map_tiles.dart';

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
        createdAt: DateTime(2026));

void main() {
  Future<void> mount(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(MapTileSource(
        create: TestMapTiles.new,
        child: MaterialApp(
            home: Scaffold(body: SizedBox(height: 340, child: child)))));
    await tester.pumpAndSettle();
  }

  StreetMap map(WidgetTester tester) =>
      tester.widget<StreetMap>(find.byType(StreetMap));
  bool courier(WidgetTester tester) => map(tester)
      .markers
      .any((marker) => marker.key == const ValueKey('courier'));
  test('Coordinates reject nonfinite and out-of-range values', () {
    for (final point in [
      const LatLng(91, 3),
      const LatLng(6, 181),
      const LatLng(double.nan, 3),
      const LatLng(6, double.infinity)
    ]) {
      expect(mapPoint(point), isNull);
    }
    expect(mapPoint(const LatLng(0, 0)), const geo.LatLng(0, 0));
  });
  test('Bounds frame single points and the short path across the date line',
      () {
    final single = mapBounds([const geo.LatLng(90, 180)]);
    expect(single.north, greaterThan(single.south));
    expect(single.longitudeWidth, greaterThan(0));
    final bounds =
        mapBounds([const geo.LatLng(6, 179.9), const geo.LatLng(7, -179.9)]);
    expect(bounds.longitudeWidth, closeTo(.2, .001));
    expect(bounds.simpleCenter.longitude.abs(), closeTo(180, .001));
    expect(() => mapBounds([]), throwsArgumentError);
  });
  testWidgets('Map renders without a Google key and keeps attribution visible',
      (tester) async {
    await mount(tester, const MiniMap(courierLocation: LatLng(6.5, 3.4)));
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
    final tiles = tester.widget<TileLayer>(find.byType(TileLayer));
    expect(tiles.urlTemplate, 'https://tile.openstreetmap.org/{z}/{x}/{y}.png');
    expect(tiles.tileProvider.headers['User-Agent'],
        contains('com.example.movetraq'));
    expect(tester.takeException(), isNull);
  });
  testWidgets('Live map clears missing, simulated and invalid courier pins',
      (tester) async {
    await mount(
        tester, LiveDeliveryMap(order: order(courier: const LatLng(6.5, 3.4))));
    expect(courier(tester), isTrue);
    await mount(tester, LiveDeliveryMap(order: order()));
    expect(courier(tester), isFalse);
    await mount(
        tester,
        LiveDeliveryMap(
            order: order(courier: const LatLng(6.5, 3.4), simulated: true)));
    expect(courier(tester), isFalse);
    expect(map(tester).polylines, isEmpty);
    await mount(
        tester, LiveDeliveryMap(order: order(courier: const LatLng(91, 3))));
    expect(courier(tester), isFalse);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'Sheet padding leaves attribution visible and hides crowded controls',
      (tester) async {
    await mount(tester,
        LiveDeliveryMap(order: order(), topPadding: 70, bottomPadding: 160));
    expect(map(tester).padding, const EdgeInsets.only(top: 70, bottom: 160));
    expect(find.byTooltip('Zoom in'), findsNothing);
  });
  testWidgets('Missing route geometry draws no invented connector',
      (tester) async {
    await mount(
        tester,
        const MiniMap(
            pickupLocation: LatLng(6.6, 3.3),
            dropoffLocation: LatLng(6.4, 3.5)));
    expect(map(tester).polylines, isEmpty);
    expect(map(tester).markers, hasLength(2));
    expect(find.text('Route unavailable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
