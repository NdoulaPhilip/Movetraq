import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as maps;

import '../models/parcel_order.dart';

maps.LatLng? mapPoint(LatLng? value) {
  if (value == null ||
      !value.latitude.isFinite ||
      !value.longitude.isFinite ||
      value.latitude.abs() > 90 ||
      value.longitude.abs() > 180) {
    return null;
  }
  return maps.LatLng(value.latitude, value.longitude);
}

LatLngBounds mapBounds(List<maps.LatLng> points) {
  if (points.isEmpty) throw ArgumentError('At least one location is required.');
  final latitudes = points.map((point) => point.latitude).toList()..sort();
  final longitudes = points.map((point) => point.longitude).toList()..sort();
  var south = latitudes.first;
  var north = latitudes.last;
  var west = longitudes.first;
  var east = longitudes.last;
  // Omit the largest longitude gap so routes across the date line stay visible.
  var largestGap = longitudes.first + 360 - longitudes.last;
  for (var i = 0; i < longitudes.length - 1; i++) {
    final gap = longitudes[i + 1] - longitudes[i];
    if (gap > largestGap) {
      largestGap = gap;
      west = longitudes[i + 1];
      east = longitudes[i];
    }
  }
  if (south == north) {
    south = (south - .001).clamp(-90.0, 90.0);
    north = (north + .001).clamp(-90.0, 90.0);
  }
  if (west == east) {
    west = ((west - .001 + 180) % 360) - 180;
    east = ((east + .001 + 180) % 360) - 180;
  }
  final width = (east - west + 360) % 360;
  return LatLngBounds.worldSafe(
      north: north,
      south: south,
      longitudeCenter: west + width / 2,
      longitudeWidth: width);
}
