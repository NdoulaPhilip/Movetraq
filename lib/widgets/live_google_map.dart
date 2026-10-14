import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as maps;

import '../models/parcel_order.dart';
import '../theme/app_theme.dart';
import 'google_map_status.dart';
import 'map_geometry.dart';

class LiveGoogleMap extends StatefulWidget {
  const LiveGoogleMap({
    super.key,
    required this.order,
    this.followCourier = true,
    this.bottomPadding = 0,
    this.topPadding = 0,
  });

  final ParcelOrder order;
  final bool followCourier;
  final double bottomPadding;
  final double topPadding;

  @override
  State<LiveGoogleMap> createState() => _LiveGoogleMapState();
}

class _LiveGoogleMapState extends State<LiveGoogleMap>
    with SingleTickerProviderStateMixin {
  maps.GoogleMapController? _controller;
  LatLng? _lastCourierLocation;
  maps.LatLng? _displayCourierLocation;
  late final AnimationController _courierAnimationController;
  Animation<double>? _courierAnimation;
  VoidCallback? _courierAnimationListener;
  bool _hasFitInitialRoute = false;
  bool _mapReadyForCameraUpdates = false;
  late bool _following;

  static const _lagosCenter = maps.LatLng(6.5244, 3.3792);

  @override
  void initState() {
    super.initState();
    _following = widget.followCourier;
    _displayCourierLocation = widget.order.courierLocationIsSimulated
        ? null
        : _toMapLatLng(widget.order.courierLocation);
    _lastCourierLocation =
        _displayCourierLocation == null ? null : widget.order.courierLocation;
    _courierAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );
  }

  @override
  void didUpdateWidget(covariant LiveGoogleMap oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.followCourier != widget.followCourier) {
      _following = widget.followCourier;
    }
    if (oldWidget.order.id != widget.order.id ||
        oldWidget.order.pickupLocation != widget.order.pickupLocation ||
        oldWidget.order.dropoffLocation != widget.order.dropoffLocation) {
      _hasFitInitialRoute = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _fitRoute([
          if (_toMapLatLng(widget.order.pickupLocation)
              case final maps.LatLng point)
            point,
          if (_toMapLatLng(widget.order.dropoffLocation)
              case final maps.LatLng point)
            point,
          if (_displayCourierLocation != null) _displayCourierLocation!,
        ]);
      });
    }

    if (oldWidget.order.id != widget.order.id) {
      _hasFitInitialRoute = false;
      _lastCourierLocation = null;
      _displayCourierLocation = null;
      _courierAnimationController.stop();
      if (_courierAnimationListener != null) {
        _courierAnimationController.removeListener(_courierAnimationListener!);
        _courierAnimationListener = null;
      }
    }

    final courier = widget.order.courierLocationIsSimulated
        ? null
        : widget.order.courierLocation;
    if (_toMapLatLng(courier) == null) {
      _courierAnimationController.stop();
      if (_courierAnimationListener != null) {
        _courierAnimationController.removeListener(_courierAnimationListener!);
        _courierAnimationListener = null;
      }
      _displayCourierLocation = null;
      _lastCourierLocation = null;
      return;
    }
    if (_sameLatLng(courier, _lastCourierLocation)) {
      return;
    }

    _animateCourierTo(courier!);
    _lastCourierLocation = courier;
  }

  @override
  void dispose() {
    if (_courierAnimationListener != null) {
      _courierAnimationController.removeListener(_courierAnimationListener!);
    }
    _courierAnimationController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pickup = _toMapLatLng(widget.order.pickupLocation);
    final dropoff = _toMapLatLng(widget.order.dropoffLocation);
    final courier = _displayCourierLocation;
    final trailPoints = (widget.order.courierLocationIsSimulated
            ? <LatLng>[]
            : widget.order.courierLocationTrail)
        .map(_toMapLatLng)
        .whereType<maps.LatLng>()
        .toList();
    final liveTrailPoints = <maps.LatLng>[
      ...trailPoints,
      if (courier != null &&
          (trailPoints.isEmpty || !_sameMapLatLng(courier, trailPoints.last)))
        courier,
    ];

    final activePoints = _activeRoutePoints(
      pickup: pickup,
      dropoff: dropoff,
      courier: courier,
      headingToPickup: widget.order.status == OrderStatus.accepted,
    );
    final fullRoutePoints = _fullRoutePoints(pickup: pickup, dropoff: dropoff);
    final fitPoints = <maps.LatLng>[
      ...fullRoutePoints,
      ...liveTrailPoints,
      if (courier != null) courier,
    ];

    final initialTarget = courier ?? pickup ?? dropoff ?? _lagosCenter;

    final markers = <maps.Marker>{
      if (pickup != null)
        maps.Marker(
          markerId: const maps.MarkerId('pickup'),
          position: pickup,
          infoWindow: maps.InfoWindow(
            title: 'Pickup',
            snippet: widget.order.pickupAddress,
          ),
        ),
      if (dropoff != null)
        maps.Marker(
          markerId: const maps.MarkerId('dropoff'),
          position: dropoff,
          infoWindow: maps.InfoWindow(
            title: 'Drop-off',
            snippet: widget.order.dropoffAddress,
          ),
          icon: maps.BitmapDescriptor.defaultMarkerWithHue(
              maps.BitmapDescriptor.hueAzure),
        ),
      if (courier != null)
        maps.Marker(
          markerId: const maps.MarkerId('courier'),
          position: courier,
          infoWindow: maps.InfoWindow(
            title: widget.order.delivererName ?? 'Courier',
            snippet: 'Last reported location',
          ),
          icon: maps.BitmapDescriptor.defaultMarkerWithHue(
            maps.BitmapDescriptor.hueGreen,
          ),
        ),
    };

    final polylines = <maps.Polyline>{
      if (fullRoutePoints.length > 1)
        maps.Polyline(
          polylineId: const maps.PolylineId('planned-route'),
          points: fullRoutePoints,
          color: const Color(0xFF3A4250).withValues(alpha: 0.45),
          width: 4,
          patterns: [maps.PatternItem.dash(10), maps.PatternItem.gap(8)],
        ),
      if (activePoints.length > 1)
        maps.Polyline(
          polylineId: const maps.PolylineId('live-route'),
          points: activePoints,
          color: AppColors.accent,
          width: 6,
          patterns: [maps.PatternItem.dash(10), maps.PatternItem.gap(8)],
        ),
      if (liveTrailPoints.length > 1)
        maps.Polyline(
          polylineId: const maps.PolylineId('courier-gps-trail'),
          points: liveTrailPoints,
          color: const Color(0xFF19B56B),
          width: 7,
        ),
    };

    return LayoutBuilder(
        builder: (context, constraints) => Stack(children: [
              Positioned.fill(
                  child: ConfiguredGoogleMap(
                map: maps.GoogleMap(
                  initialCameraPosition: maps.CameraPosition(
                    target: initialTarget,
                    zoom: fitPoints.length > 1 ? 12.5 : 14,
                  ),
                  markers: markers,
                  polylines: polylines,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  compassEnabled: true,
                  tiltGesturesEnabled: false,
                  rotateGesturesEnabled: false,
                  padding: EdgeInsets.only(
                      bottom: widget.bottomPadding, top: widget.topPadding),
                  onMapCreated: (controller) {
                    setState(() => _controller = controller);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      _mapReadyForCameraUpdates = true;
                      if (fitPoints.isNotEmpty) {
                        _fitRoute(fitPoints);
                      }
                    });
                  },
                ),
              )),
              if (constraints.maxHeight -
                      widget.topPadding -
                      widget.bottomPadding >=
                  210)
                Positioned(
                    right: 12,
                    top: widget.topPadding + 12,
                    child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                              tooltip: 'Show delivery locations',
                              icon: const Icon(Icons.fit_screen),
                              onPressed: _controller == null
                                  ? null
                                  : () => _fitRoute(fitPoints, force: true)),
                          IconButton(
                              tooltip: _following
                                  ? 'Stop following courier'
                                  : 'Follow courier',
                              icon: Icon(_following
                                  ? Icons.gps_fixed
                                  : Icons.gps_not_fixed),
                              onPressed: _controller == null || courier == null
                                  ? null
                                  : () {
                                      setState(() => _following = !_following);
                                      if (_following) {
                                        _moveCameraAfterFrame(
                                            maps.CameraUpdate.newLatLng(
                                                courier));
                                      }
                                    }),
                          IconButton(
                              tooltip: 'Zoom in',
                              icon: const Icon(Icons.add),
                              onPressed: _controller == null
                                  ? null
                                  : () => _moveCameraAfterFrame(
                                      maps.CameraUpdate.zoomIn())),
                          IconButton(
                              tooltip: 'Zoom out',
                              icon: const Icon(Icons.remove),
                              onPressed: _controller == null
                                  ? null
                                  : () => _moveCameraAfterFrame(
                                      maps.CameraUpdate.zoomOut())),
                        ]))),
            ]));
  }

  static maps.LatLng? _toMapLatLng(LatLng? value) {
    return mapPoint(value);
  }

  static List<maps.LatLng> _fullRoutePoints({
    required maps.LatLng? pickup,
    required maps.LatLng? dropoff,
  }) {
    return [
      if (pickup != null) pickup,
      if (dropoff != null) dropoff,
    ];
  }

  static List<maps.LatLng> _activeRoutePoints({
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

  void _fitRoute(List<maps.LatLng> points, {bool force = false}) {
    if (_controller == null || !_mapReadyForCameraUpdates) return;
    if ((!force && _hasFitInitialRoute) || points.isEmpty) return;
    _hasFitInitialRoute = true;
    _moveCameraAfterFrame(
      maps.CameraUpdate.newLatLngBounds(mapBounds(points), 32),
    );
  }

  void _animateCourierTo(LatLng destination) {
    final end = maps.LatLng(destination.latitude, destination.longitude);
    final start = _displayCourierLocation ?? end;

    _courierAnimationController.stop();
    if (_courierAnimationListener != null) {
      _courierAnimationController.removeListener(_courierAnimationListener!);
      _courierAnimationListener = null;
    }
    _courierAnimationController.reset();
    _courierAnimation = CurvedAnimation(
      parent: _courierAnimationController,
      curve: Curves.easeInOutCubic,
    );

    void tick() {
      if (!mounted) return;
      final t = _courierAnimation?.value ?? 1;
      setState(() {
        _displayCourierLocation = maps.LatLng(
          start.latitude + (end.latitude - start.latitude) * t,
          start.longitude + (end.longitude - start.longitude) * t,
        );
      });
    }

    _courierAnimationListener = tick;

    _courierAnimationController
      ..addListener(tick)
      ..forward().whenComplete(() {
        _courierAnimationController.removeListener(tick);
        if (_courierAnimationListener == tick) {
          _courierAnimationListener = null;
        }
        if (!mounted) return;
        setState(() {
          _displayCourierLocation = end;
        });
      });

    if (_following) {
      _moveCameraAfterFrame(
        maps.CameraUpdate.newCameraPosition(
          maps.CameraPosition(
            target: end,
            zoom: 15,
          ),
        ),
      );
    }
  }

  void _moveCameraAfterFrame(maps.CameraUpdate update) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_mapReadyForCameraUpdates) return;
      _controller?.animateCamera(update).catchError((Object error) {
        debugPrint('Map camera update unavailable: $error');
      });
    });
  }

  static bool _sameLatLng(LatLng? a, LatLng? b) {
    if (a == null || b == null) return a == b;
    return (a.latitude - b.latitude).abs() < 0.000001 &&
        (a.longitude - b.longitude).abs() < 0.000001;
  }

  static bool _sameMapLatLng(maps.LatLng a, maps.LatLng b) {
    return (a.latitude - b.latitude).abs() < 0.000001 &&
        (a.longitude - b.longitude).abs() < 0.000001;
  }
}
