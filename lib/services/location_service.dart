import 'package:geolocator/geolocator.dart';

class LocationService {
  const LocationService();

  Future<void> ensurePermission() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw Exception(
        'Location services are disabled. Please enable GPS.',
      );
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception('Location permission was denied.');
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permission is permanently denied. '
        'Enable it from your device settings.',
      );
    }
  }

  Future<Position> getCurrentPosition() async {
    await ensurePermission();
    final Position position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 3,
        timeLimit: Duration(seconds: 20),
      ),
    );

    return _validate(position);
  }

  Position _validate(Position position) {
    final age = DateTime.now().difference(position.timestamp);
    if (position.isMocked ||
        age > const Duration(minutes: 2) ||
        age < const Duration(seconds: -30) ||
        !position.accuracy.isFinite ||
        position.accuracy < 0 ||
        position.accuracy > 500 ||
        !position.latitude.isFinite ||
        !position.longitude.isFinite ||
        position.latitude.abs() > 90 ||
        position.longitude.abs() > 180) {
      throw StateError(
          'A fresh, accurate GPS position is unavailable. Try again outdoors.');
    }
    return position;
  }

  Future<Position> getLastKnownOrCurrentPosition() async {
    return getCurrentPosition();
  }

  Stream<Position> watchPosition() async* {
    await ensurePermission();

    const LocationSettings settings = LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 10,
    );

    yield* Geolocator.getPositionStream(
      locationSettings: settings,
    ).map(_validate);
  }
}
