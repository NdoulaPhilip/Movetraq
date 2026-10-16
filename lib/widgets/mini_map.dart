import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as geo;
import '../models/parcel_order.dart';
import '../theme/app_theme.dart';
import 'map_geometry.dart';
import 'provider_route.dart';
import 'street_map.dart';

class MiniMap extends StatelessWidget {
  const MiniMap(
      {super.key,
      this.height = 150,
      this.pickupLocation,
      this.dropoffLocation,
      this.courierLocation,
      this.courierHeadingToPickup = false});
  final double? height;
  final LatLng? pickupLocation, dropoffLocation, courierLocation;
  final bool courierHeadingToPickup;
  @override
  Widget build(BuildContext context) {
    final pickup = mapPoint(pickupLocation),
        destination = mapPoint(dropoffLocation),
        courier = mapPoint(courierLocation);
    final points =
        [pickup, destination, courier].whereType<geo.LatLng>().toList();
    final map = ProviderRoute(
        pickup: pickupLocation,
        destination: dropoffLocation,
        builder: (route, metrics, error, busy) => StreetMap(
              key: ValueKey(points
                  .map((point) => '${point.latitude},${point.longitude}')
                  .join(':')),
              initialCenter: points.isEmpty
                  ? const geo.LatLng(0, 0)
                  : mapBounds(points).simpleCenter,
              initialZoom: points.isEmpty ? 2 : 13,
              initialFit: points.isEmpty
                  ? null
                  : CameraFit.bounds(
                      bounds: mapBounds(points),
                      padding: const EdgeInsets.all(24),
                      maxZoom: 16),
              interactive: false,
              markers: [
                if (pickup != null)
                  locationMarker('pickup', pickup, 'Pickup', Colors.red),
                if (destination != null)
                  locationMarker(
                      'dropoff', destination, 'Drop-off', Colors.blue),
                if (courier != null)
                  locationMarker(
                      'courier', courier, 'Current location', Colors.green),
              ],
              polylines: route.length < 2
                  ? []
                  : [
                      Polyline(
                          points: route
                              .map((point) =>
                                  geo.LatLng(point.latitude, point.longitude))
                              .toList(),
                          color: AppColors.accent,
                          strokeWidth: 4,
                          pattern:
                              StrokePattern.dashed(segments: const [10, 8]))
                    ],
            ));
    return height == null
        ? SizedBox.expand(child: map)
        : SizedBox(height: height, child: map);
  }
}

/// Circular icon button used repeatedly for back / bell / etc.
class CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color background;
  final Color iconColor;
  final bool showDot;

  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.background = Colors.white,
    this.iconColor = AppColors.ink,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE4E8DD)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, size: 20, color: iconColor),
              if (showDot)
                Positioned(
                  top: 9,
                  right: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A simple header row: back button + title, used on detail-style screens.
class ScreenHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const ScreenHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        CircleIconButton(
            icon: Icons.chevron_left,
            onTap: () => Navigator.of(context).maybePop()),
        const Spacer(),
        if (trailing != null) trailing!
      ]),
      if (title.isNotEmpty) ...[
        const SizedBox(height: 20),
        Text(title,
            style: const TextStyle(
                fontFamily: 'SpaceGrotesk',
                fontWeight: FontWeight.w700,
                fontSize: 24,
                color: AppColors.ink))
      ],
      const SizedBox(height: 18),
    ]);
  }
}
