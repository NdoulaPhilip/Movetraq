import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../services/local_data_service.dart';
import '../services/location_service.dart';

class DelivererTrackingProvider extends ChangeNotifier {
  DelivererTrackingProvider({
    required LocalDataService data,
    LocationService locationService = const LocationService(),
  })  : _data = data,
        _locationService = locationService;

  final LocalDataService _data;
  final LocationService _locationService;

  StreamSubscription<Position>? _positionSubscription;
  Position? _position;
  String? _activeDeliveryId;
  String? _errorMessage;
  bool _isTracking = false;
  bool _isLoading = false;

  Position? get position => _position;
  double? get latitude => _position?.latitude;
  double? get longitude => _position?.longitude;
  String? get activeDeliveryId => _activeDeliveryId;
  String? get errorMessage => _errorMessage;
  bool get isTracking => _isTracking;
  bool get isLoading => _isLoading;
  bool get hasPosition => _position != null;

  Future<void> loadCurrentPosition() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _position = await _locationService.getCurrentPosition();
    } catch (error) {
      _errorMessage = error.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> startTracking(String deliveryId) async {
    if (deliveryId.trim().isEmpty) {
      throw ArgumentError('A delivery ID is required.');
    }

    await stopTracking();

    _activeDeliveryId = deliveryId;
    _isTracking = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final position = await _locationService.getLastKnownOrCurrentPosition();
      _position = position;
      await _data.updateCurrentUserLocation(
        position.latitude,
        position.longitude,
      );
      await _data.updateCourierLocation(
        deliveryId,
        position.latitude,
        position.longitude,
      );
      notifyListeners();
    } catch (error) {
      _errorMessage = 'Initial location sync failed: $error';
      notifyListeners();
    }

    _positionSubscription = _locationService.watchPosition().listen(
      (Position position) async {
        _position = position;
        _errorMessage = null;
        notifyListeners();

        try {
          await _data.updateCurrentUserLocation(
            position.latitude,
            position.longitude,
          );
          await _data.updateCourierLocation(
            deliveryId,
            position.latitude,
            position.longitude,
          );
        } catch (error) {
          _errorMessage = 'Location sync failed: $error';
          notifyListeners();
        }
      },
      onError: (Object error) {
        _errorMessage = error.toString();
        _isTracking = false;
        notifyListeners();
      },
    );
  }

  Future<void> stopTracking() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _activeDeliveryId = null;
    _isTracking = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }
}
