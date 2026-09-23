import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as maps;

import '../models/parcel_order.dart';
import '../theme/app_theme.dart';
import 'mini_map.dart';

class LiveGoogleMap extends StatelessWidget {
  const LiveGoogleMap({
    super.key,
    required this.order,
    this.showFallbackWhenNoRoute = true,
  });

  final ParcelOrder order;
  final bool showFallbackWhenNoRoute;

  static const _lagosCenter = maps.LatLng(6.5244, 3.3792);
  static const _googleMapsApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');

  @override
  Widget build(BuildContext context) {
    final pickup = _toMapLatLng(order.pickupLocation);
    final dropoff = _toMapLatLng(order.dropoffLocation);
    final courier = _toMapLatLng(order.courierLocation);
    if (_googleMapsApiKey.isEmpty) {
      return MiniMap(
        height: null,
        courierLocation: order.courierLocation,
      );
    }

    final points = <maps.LatLng>[
      if (pickup != null) pickup,
      if (courier != null) courier,
      if (dropoff != null) dropoff,
    ];

    if (points.isEmpty && showFallbackWhenNoRoute) {
      return MiniMap(
        height: null,
        courierLocation: order.courierLocation,
      );
    }

    final initialTarget = courier ?? pickup ?? dropoff ?? _lagosCenter;
    final markers = <maps.Marker>{
      if (pickup != null)
        maps.Marker(
          markerId: const maps.MarkerId('pickup'),
          position: pickup,
          infoWindow: maps.InfoWindow(
            title: 'Pickup',
            snippet: order.pickupAddress,
          ),
        ),
      if (dropoff != null)
        maps.Marker(
          markerId: const maps.MarkerId('dropoff'),
          position: dropoff,
          infoWindow: maps.InfoWindow(
            title: 'Drop-off',
            snippet: order.dropoffAddress,
          ),
        ),
      if (courier != null)
        maps.Marker(
          markerId: const maps.MarkerId('courier'),
          position: courier,
          infoWindow: maps.InfoWindow(
            title: order.delivererName ?? 'Courier',
            snippet: 'Live courier location',
          ),
          icon: maps.BitmapDescriptor.defaultMarkerWithHue(
            maps.BitmapDescriptor.hueGreen,
          ),
        ),
    };

    final polylines = points.length < 2
        ? <maps.Polyline>{}
        : {
            maps.Polyline(
              polylineId: const maps.PolylineId('route'),
              points: points,
              color: AppColors.accent,
              width: 5,
            ),
          };

    return maps.GoogleMap(
      initialCameraPosition: maps.CameraPosition(
        target: initialTarget,
        zoom: points.length > 1 ? 12.5 : 14,
      ),
      markers: markers,
      polylines: polylines,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
      tiltGesturesEnabled: false,
      rotateGesturesEnabled: false,
      padding: const EdgeInsets.only(bottom: 250),
      onMapCreated: (controller) {
        if (points.length > 1) {
          controller.animateCamera(
            maps.CameraUpdate.newLatLngBounds(_boundsFor(points), 72),
          );
        }
      },
    );
  }

  static maps.LatLng? _toMapLatLng(LatLng? value) {
    if (value == null) return null;
    return maps.LatLng(value.latitude, value.longitude);
  }

  static maps.LatLngBounds _boundsFor(List<maps.LatLng> points) {
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;

    for (final point in points.skip(1)) {
      minLat = point.latitude < minLat ? point.latitude : minLat;
      maxLat = point.latitude > maxLat ? point.latitude : maxLat;
      minLng = point.longitude < minLng ? point.longitude : minLng;
      maxLng = point.longitude > maxLng ? point.longitude : maxLng;
    }

    if (minLat == maxLat) {
      minLat -= 0.01;
      maxLat += 0.01;
    }
    if (minLng == maxLng) {
      minLng -= 0.01;
      maxLng += 0.01;
    }

    return maps.LatLngBounds(
      southwest: maps.LatLng(minLat, minLng),
      northeast: maps.LatLng(maxLat, maxLng),
    );
  }
}
