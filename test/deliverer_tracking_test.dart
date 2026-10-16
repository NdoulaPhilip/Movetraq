import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:movetraq/models/app_user.dart';
import 'package:movetraq/models/parcel_order.dart';
import 'package:movetraq/providers/deliverer_tracking_provider.dart';
import 'package:movetraq/services/local_data_service.dart';
import 'package:movetraq/services/location_service.dart';

Position sample() => Position(
    latitude: 6.5,
    longitude: 3.4,
    timestamp: DateTime.now(),
    accuracy: 10,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0);

class _Location extends LocationService {
  Completer<Position>? pending;
  bool denied = false;
  int requests = 0;
  final positions = StreamController<Position>.broadcast();
  @override
  Future<Position> getCurrentPosition() {
    requests++;
    if (denied) return Future.error(StateError('Location permission denied'));
    return pending?.future ?? Future.value(sample());
  }

  @override
  Stream<Position> watchPosition() => positions.stream;
}

class _Data extends LocalDataService {
  _Data() {
    currentUser = AppUser(
        uid: 'user_driver',
        name: 'Driver',
        email: 'driver@example.test',
        phone: '',
        activeRole: UserRole.deliverer,
        canDeliver: true,
        verified: true,
        delivererVerificationStatus: 'approved');
  }
  final auth = StreamController<AppUser?>.broadcast();
  String assigned = 'user_driver';
  int writes = 0;
  @override
  Stream<AppUser?> get authStateChanges => auth.stream;
  @override
  Future<ParcelOrder> trackingOrder(String id) async => ParcelOrder(
      id: id,
      code: 'MT-TEST',
      senderId: 'user_sender',
      senderName: 'Sender',
      delivererId: assigned,
      title: 'Fixture',
      category: 'parcel',
      pickupAddress: 'Pickup',
      dropoffAddress: 'Destination',
      price: 0,
      payout: 0,
      status: OrderStatus.accepted,
      createdAt: DateTime.now());
  @override
  Future<void> updateCurrentUserLocation(double lat, double lng) async {}
  @override
  Future<void> updateCourierLocation(String orderId, double lat, double lng,
      {required double accuracy, required DateTime capturedAt}) async {
    writes++;
  }
}

void main() {
  late _Data data;
  late _Location location;
  late DelivererTrackingProvider tracker;
  setUp(() {
    data = _Data();
    location = _Location();
    tracker = DelivererTrackingProvider(data: data, locationService: location);
  });
  tearDown(() async {
    tracker.dispose();
    await location.positions.close();
    await data.auth.close();
    data.dispose();
  });
  test('checks active assignment before requesting GPS', () async {
    data.assigned = 'user_other';
    await tracker.startTracking('order_fixture');
    expect(location.requests, 0);
    expect(data.writes, 0);
    expect(tracker.isTracking, isFalse);
  });
  test('stopping while permission or GPS is pending prevents later writes',
      () async {
    location.pending = Completer<Position>();
    final started = tracker.startTracking('order_fixture');
    await Future<void>.delayed(Duration.zero);
    expect(location.requests, 1);
    await tracker.stopTracking();
    location.pending!.complete(sample());
    await started;
    expect(data.writes, 0);
    expect(location.positions.hasListener, isFalse);
  });
  test('throttles samples and stops publishing after sign-out', () async {
    await tracker.startTracking('order_fixture');
    expect(data.writes, 1);
    expect(tracker.isTracking, isTrue);
    location.positions.add(sample());
    location.positions.add(sample());
    await Future<void>.delayed(Duration.zero);
    expect(data.writes, 1);
    data.currentUser = null;
    data.auth.add(null);
    await Future<void>.delayed(Duration.zero);
    expect(location.positions.hasListener, isFalse);
    expect(tracker.isTracking, isFalse);
    location.positions.add(sample());
    await Future<void>.delayed(Duration.zero);
    expect(data.writes, 1);
  });
  test('denied permission leaves sharing off with a retryable error', () async {
    location.denied = true;
    await tracker.startTracking('order_fixture');
    expect(tracker.isTracking, isFalse);
    expect(tracker.isLoading, isFalse);
    expect(tracker.errorMessage, contains('permission denied'));
    expect(data.writes, 0);
  });
}
