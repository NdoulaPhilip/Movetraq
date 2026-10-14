import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../../core/networking/api.dart';
import '../../services/location_service.dart';

class TrackingService {
  TrackingService(this.api,
      {LocationService location = const LocationService(),
      DateTime Function()? clock})
      : _location = location,
        _clock = clock ?? DateTime.now;
  final ApiClient api;
  final LocationService _location;
  final DateTime Function() _clock;
  StreamSubscription<Position>? _subscription;
  DateTime? _last;
  int _generation = 0;
  bool _sending = false;
  Future<void> start(String orderId, void Function(String) onError) async {
    final generation = _generation + 1;
    await stop();
    if (generation != _generation) return;
    if (!RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(orderId)) {
      throw ArgumentError('A valid active delivery is required.');
    }
    final owner = api.auth.userId;
    bool current() => generation == _generation && api.auth.userId == owner;
    final response = await api.request('/orders/$orderId');
    final order = response['order'];
    if (order is! Map ||
        owner == null ||
        order['deliverer_id'] != owner ||
        !const [
          'accepted',
          'heading_to_pickup',
          'arrived_pickup',
          'picked_up',
          'heading_to_dropoff',
          'arrived_dropoff'
        ].contains(order['status'])) {
      throw StateError(
          'Location sharing is limited to your assigned active delivery.');
    }
    await _location.ensurePermission();
    if (!current()) return;
    _subscription = _location.watchPosition().listen((position) async {
      if (!current()) {
        await stop();
        return;
      }
      final now = _clock();
      final age = now.difference(position.timestamp);
      if (_sending ||
          age > const Duration(minutes: 2) ||
          age < const Duration(seconds: -30) ||
          !position.latitude.isFinite ||
          !position.longitude.isFinite ||
          position.latitude.abs() > 90 ||
          position.longitude.abs() > 180 ||
          !position.accuracy.isFinite ||
          position.accuracy < 0 ||
          position.accuracy > 500 ||
          (_last != null &&
              now.difference(_last!) < const Duration(seconds: 10))) {
        return;
      }
      _last = now;
      _sending = true;
      try {
        await api.request('/orders/$orderId/location', method: 'POST', data: {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracyMeters': position.accuracy,
          'capturedAt': position.timestamp.toUtc().toIso8601String()
        });
      } catch (_) {
        if (current()) onError('Location could not be synchronized.');
      } finally {
        if (generation == _generation) _sending = false;
      }
    }, onError: (Object _) {
      if (current()) onError('Live GPS is unavailable.');
    });
  }

  Future<void> stop() async {
    ++_generation;
    final subscription = _subscription;
    _subscription = null;
    _last = null;
    _sending = false;
    await subscription?.cancel();
  }
}
