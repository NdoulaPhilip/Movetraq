import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as maps;

import '../models/parcel_order.dart';
import '../theme/app_theme.dart';
import 'google_map_status.dart';
import 'map_geometry.dart';
import 'provider_route.dart';

class MiniMap extends StatefulWidget {
  /// Fixed height for the map card. Pass null to fill all available space
  /// (e.g. wrapped in `Positioned.fill` for a full-screen live map).
  final double? height;
  final LatLng? pickupLocation;
  final LatLng? dropoffLocation;
  final LatLng? courierLocation;
  final bool courierHeadingToPickup;
  const MiniMap({
    super.key,
    this.height = 150,
    this.pickupLocation,
    this.dropoffLocation,
    this.courierLocation,
    this.courierHeadingToPickup = false,
  });

  @override
  State<MiniMap> createState() => _MiniMapState();
}

class _MiniMapState extends State<MiniMap> {
  maps.GoogleMapController? _controller;
  double? get height => widget.height;
  LatLng? get pickupLocation => widget.pickupLocation;
  LatLng? get dropoffLocation => widget.dropoffLocation;
  LatLng? get courierLocation => widget.courierLocation;
  bool get courierHeadingToPickup => widget.courierHeadingToPickup;

  @override
  void didUpdateWidget(covariant MiniMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pickupLocation != pickupLocation ||
        oldWidget.dropoffLocation != dropoffLocation ||
        oldWidget.courierLocation != courierLocation) {
      _fitCamera();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _fitCamera() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _controller == null) return;
      final points = [
        mapPoint(pickupLocation),
        mapPoint(dropoffLocation),
        mapPoint(courierLocation)
      ].whereType<maps.LatLng>().toList();
      if (points.isEmpty) return;
      _controller!
          .moveCamera(maps.CameraUpdate.newLatLngBounds(mapBounds(points), 20))
          .catchError(
              (Object error) => debugPrint('Map framing unavailable: $error'));
    });
  }

  @override
  Widget build(BuildContext context) {
    final pickup = _toMapLatLng(pickupLocation);
    final dropoff = _toMapLatLng(dropoffLocation);
    final courier = _toMapLatLng(courierLocation);
    final points = _routePoints(
      pickup: pickup,
      dropoff: dropoff,
      courier: courier,
      headingToPickup: courierHeadingToPickup,
    );

    final map = ProviderRoute(
        pickup: pickupLocation,
        destination: dropoffLocation,
        builder: (route, metrics, error, busy) => ConfiguredGoogleMap(
              compact: height != null,
              map: maps.GoogleMap(
                onMapCreated: (controller) {
                  _controller = controller;
                  _fitCamera();
                },
                initialCameraPosition: maps.CameraPosition(
                  target: _initialTarget(points),
                  zoom: points.length > 1 ? 12.5 : 13.5,
                ),
                markers: {
                  if (pickup != null)
                    maps.Marker(
                      markerId: const maps.MarkerId('pickup'),
                      position: pickup,
                      infoWindow: const maps.InfoWindow(title: 'Pickup'),
                    ),
                  if (dropoff != null)
                    maps.Marker(
                      markerId: const maps.MarkerId('dropoff'),
                      position: dropoff,
                      infoWindow: const maps.InfoWindow(title: 'Drop-off'),
                      icon: maps.BitmapDescriptor.defaultMarkerWithHue(
                        maps.BitmapDescriptor.hueAzure,
                      ),
                    ),
                  if (courier != null)
                    maps.Marker(
                      markerId: const maps.MarkerId('courier'),
                      position: courier,
                      infoWindow: const maps.InfoWindow(title: 'Courier'),
                      icon: maps.BitmapDescriptor.defaultMarkerWithHue(
                        maps.BitmapDescriptor.hueGreen,
                      ),
                    ),
                },
                polylines: route.length < 2
                    ? const <maps.Polyline>{}
                    : {
                        maps.Polyline(
                          polylineId: const maps.PolylineId('route'),
                          points: route
                              .map((point) =>
                                  maps.LatLng(point.latitude, point.longitude))
                              .toList(),
                          color: AppColors.accent,
                          patterns: [
                            maps.PatternItem.dash(10),
                            maps.PatternItem.gap(8)
                          ],
                          width: 4,
                        ),
                      },
                liteModeEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                compassEnabled: false,
                scrollGesturesEnabled: false,
                zoomGesturesEnabled: false,
                rotateGesturesEnabled: false,
                tiltGesturesEnabled: false,
              ),
            ));

    if (height == null) {
      return SizedBox.expand(child: map);
    }
    return SizedBox(height: height, child: map);
  }

  static const _worldCenter = maps.LatLng(0, 0);

  static maps.LatLng? _toMapLatLng(LatLng? value) {
    return mapPoint(value);
  }

  static maps.LatLng _initialTarget(List<maps.LatLng> points) {
    if (points.isEmpty) return _worldCenter;
    if (points.length == 1) return points.first;

    final bounds = mapBounds(points);
    final west = bounds.southwest.longitude;
    final east = bounds.northeast.longitude;
    final span = (east - west + 360) % 360;
    return maps.LatLng(
        (bounds.southwest.latitude + bounds.northeast.latitude) / 2,
        ((west + span / 2 + 180) % 360) - 180);
  }

  static List<maps.LatLng> _routePoints({
    required maps.LatLng? pickup,
    required maps.LatLng? dropoff,
    required maps.LatLng? courier,
    required bool headingToPickup,
  }) {
    if (headingToPickup && courier != null) {
      return [
        courier,
        if (pickup != null) pickup,
        if (dropoff != null) dropoff,
      ];
    }

    return [
      if (pickup != null) pickup,
      if (courier != null) courier,
      if (dropoff != null) dropoff,
    ];
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
