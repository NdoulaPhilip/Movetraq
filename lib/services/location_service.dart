import 'package:geolocator/geolocator.dart';

class LocationService {
  const LocationService();

  Future<void> ensurePermission() async {
    final bool serviceEnabled =
        await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw Exception(
        'Location services are disabled. Please enable GPS.',
      );
    }

    LocationPermission permission =
        await Geolocator.checkPermission();

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
    final Position position =
        await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    );

    return position;
  }

  Future<Position> getLastKnownOrCurrentPosition() async {
    await ensurePermission();

    final Position? lastPosition =
        await Geolocator.getLastKnownPosition();

    if (lastPosition != null) {
      return lastPosition;
    }

    return getCurrentPosition();
  }

  Stream<Position> watchPosition() async* {
    await ensurePermission();

    const LocationSettings settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    yield* Geolocator.getPositionStream(
      locationSettings: settings,
    );
  }
}
