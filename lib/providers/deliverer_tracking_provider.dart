import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/parcel_order.dart';
import '../services/local_data_service.dart';
import '../services/location_service.dart';

class DelivererTrackingProvider extends ChangeNotifier {
  DelivererTrackingProvider(
      {required LocalDataService data,
      LocationService locationService = const LocationService()})
      : _data = data,
        _locationService = locationService {
    _authSubscription = data.authStateChanges.listen((user) {
      if (_activeDeliveryId != null &&
          (user?.uid != _owner || user?.isApprovedDeliverer != true)) {
        unawaited(stopTracking());
      }
    });
  }
  final LocalDataService _data;
  final LocationService _locationService;
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<dynamic>? _authSubscription;
  String? _owner;
  Position? _position;
  String? _activeDeliveryId, _errorMessage;
  bool _isTracking = false,
      _isLoading = false,
      _sending = false,
      _disposed = false;
  int _generation = 0;
  DateTime? _lastSent;
  Position? get position => _position;
  double? get latitude => _position?.latitude;
  double? get longitude => _position?.longitude;
  String? get activeDeliveryId => _activeDeliveryId;
  String? get errorMessage => _errorMessage;
  bool get isTracking => _isTracking;
  bool get isLoading => _isLoading;
  bool get hasPosition => _position != null;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> loadCurrentPosition() async {
    _isLoading = true;
    _errorMessage = null;
    _notify();
    try {
      _position = await _locationService.getCurrentPosition();
    } catch (error) {
      _errorMessage = error.toString();
      rethrow;
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  Future<void> startTracking(String deliveryId) async {
    if (deliveryId.trim().isEmpty) {
      throw ArgumentError('A delivery ID is required.');
    }
    await stopTracking();
    final generation = _generation;
    final owner = _data.currentUser?.uid;
    _owner = owner;
    bool current() =>
        !_disposed &&
        generation == _generation &&
        owner != null &&
        _data.currentUser?.uid == owner;
    _isLoading = true;
    _errorMessage = null;
    _notify();
    try {
      final order = await _data.trackingOrder(deliveryId);
      if (!current()) return;
      if (_data.currentUser?.isApprovedDeliverer != true ||
          order.delivererId != owner ||
          ![OrderStatus.accepted, OrderStatus.pickedUp]
              .contains(order.status)) {
        throw StateError(
            'Location sharing is limited to your assigned active delivery.');
      }
      _activeDeliveryId = deliveryId;
      final position = await _locationService.getCurrentPosition();
      if (!current()) return;
      _isTracking = true;
      Future<void> publish(Position position) async {
        if (!current() || !_isTracking || _sending) return;
        final now = DateTime.now();
        if (_lastSent != null &&
            now.difference(_lastSent!) < const Duration(seconds: 10)) {
          return;
        }
        _sending = true;
        try {
          await _data.updateCurrentUserLocation(
              position.latitude, position.longitude);
          if (!current() || !_isTracking) return;
          await _data.updateCourierLocation(
              deliveryId, position.latitude, position.longitude,
              accuracy: position.accuracy, capturedAt: position.timestamp);
          if (!current()) return;
          _lastSent = now;
          _position = position;
          _errorMessage = null;
          _notify();
        } catch (error) {
          if (current()) {
            _errorMessage = 'Location sync failed: $error';
            _notify();
          }
        } finally {
          if (generation == _generation) _sending = false;
        }
      }

      await publish(position);
      if (!current() || !_isTracking) return;
      _positionSubscription =
          _locationService.watchPosition().listen((position) {
        if (!current()) {
          unawaited(stopTracking());
          return;
        }
        unawaited(publish(position));
      }, onError: (Object error) {
        if (current()) {
          _errorMessage = 'Live GPS is unavailable: $error';
          _notify();
        }
      });
    } catch (error) {
      if (current()) {
        _isTracking = false;
        _activeDeliveryId = null;
        _errorMessage = 'Live GPS is unavailable: $error';
      }
    } finally {
      if (generation == _generation) {
        _isLoading = false;
        _notify();
      }
    }
  }

  Future<void> stopTracking() async {
    ++_generation;
    final subscription = _positionSubscription;
    _positionSubscription = null;
    _activeDeliveryId = null;
    _owner = null;
    _isTracking = false;
    _isLoading = false;
    _sending = false;
    _lastSent = null;
    _position = null;
    _errorMessage = null;
    await subscription?.cancel();
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    _positionSubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }
}
