import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as geo;
import '../models/parcel_order.dart';
import 'map_geometry.dart';
import 'provider_route.dart';
import 'street_map.dart';

class LiveDeliveryMap extends StatefulWidget {
  const LiveDeliveryMap(
      {super.key,
      required this.order,
      this.followCourier = true,
      this.bottomPadding = 0,
      this.topPadding = 0});
  final ParcelOrder order;
  final bool followCourier;
  final double bottomPadding, topPadding;
  @override
  State<LiveDeliveryMap> createState() => _LiveDeliveryMapState();
}

class _LiveDeliveryMapState extends State<LiveDeliveryMap> {
  final _controller = MapController();
  bool _ready = false;
  late bool _following;
  geo.LatLng? get _courier => widget.order.courierLocationIsSimulated
      ? null
      : mapPoint(widget.order.courierLocation);
  EdgeInsets get _padding => EdgeInsets.fromLTRB(
      32, widget.topPadding + 32, 32, widget.bottomPadding + 32);
  List<geo.LatLng> get _points => [
        mapPoint(widget.order.pickupLocation),
        mapPoint(widget.order.dropoffLocation),
        _courier
      ].whereType<geo.LatLng>().toList();
  @override
  void initState() {
    super.initState();
    _following = widget.followCourier;
  }

  @override
  void didUpdateWidget(covariant LiveDeliveryMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.followCourier != widget.followCourier) {
      _following = widget.followCourier;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_ready) return;
      if (oldWidget.order.id != widget.order.id) {
        _fit();
        return;
      }
      if (_following &&
          _courier != null &&
          oldWidget.order.courierLocation != widget.order.courierLocation) {
        _controller.move(_courier!, _controller.camera.zoom);
      }
    });
  }

  void _fit() {
    if (_ready && _points.isNotEmpty) {
      _controller.fitCamera(CameraFit.bounds(
          bounds: mapBounds(_points), padding: _padding, maxZoom: 16));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pickup = mapPoint(widget.order.pickupLocation),
        destination = mapPoint(widget.order.dropoffLocation);
    final courier = _courier;
    final trail = widget.order.courierLocationIsSimulated
        ? <geo.LatLng>[]
        : widget.order.courierLocationTrail
            .map(mapPoint)
            .whereType<geo.LatLng>()
            .toList();
    return ProviderRoute(
        pickup: widget.order.pickupLocation,
        destination: widget.order.dropoffLocation,
        topPadding: widget.topPadding,
        builder: (route, metrics, error, busy) => LayoutBuilder(
            builder: (context, constraints) => Stack(children: [
                  Positioned.fill(
                      child: StreetMap(
                          controller: _controller,
                          initialCenter: courier ??
                              pickup ??
                              destination ??
                              const geo.LatLng(0, 0),
                          initialZoom: _points.isEmpty ? 2 : 13,
                          padding: EdgeInsets.only(
                              top: widget.topPadding,
                              bottom: widget.bottomPadding),
                          onMapReady: () {
                            setState(() => _ready = true);
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) _fit();
                            });
                          },
                          markers: [
                        if (pickup != null)
                          locationMarker('pickup', pickup,
                              widget.order.pickupAddress, Colors.red),
                        if (destination != null)
                          locationMarker('dropoff', destination,
                              widget.order.dropoffAddress, Colors.blue),
                        if (courier != null)
                          locationMarker(
                              'courier',
                              courier,
                              widget.order.delivererName ?? 'Courier',
                              Colors.green,
                              icon: Icons.local_shipping),
                      ],
                          polylines: [
                        if (route.length > 1)
                          Polyline(
                              points: route
                                  .map((point) => geo.LatLng(
                                      point.latitude, point.longitude))
                                  .toList(),
                              color: const Color(0xFF3A4250),
                              strokeWidth: 4,
                              pattern: StrokePattern.dashed(
                                  segments: const [10, 8])),
                        if (courier != null && trail.length > 1)
                          Polyline(points: [
                            ...trail,
                            if (trail.last != courier) courier
                          ], color: const Color(0xFF19B56B), strokeWidth: 6),
                      ])),
                  if (constraints.maxHeight -
                          widget.topPadding -
                          widget.bottomPadding >=
                      210)
                    Positioned(
                        right: 12,
                        top: widget.topPadding + 42,
                        child: Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                      tooltip: 'Show delivery locations',
                                      icon: const Icon(Icons.fit_screen),
                                      onPressed: _ready ? _fit : null),
                                  IconButton(
                                      tooltip: _following
                                          ? 'Stop following courier'
                                          : 'Follow courier',
                                      icon: Icon(_following
                                          ? Icons.gps_fixed
                                          : Icons.gps_not_fixed),
                                      onPressed: !_ready || courier == null
                                          ? null
                                          : () {
                                              setState(() =>
                                                  _following = !_following);
                                              if (_following) {
                                                _controller.move(courier,
                                                    _controller.camera.zoom);
                                              }
                                            }),
                                  IconButton(
                                      tooltip: 'Zoom in',
                                      icon: const Icon(Icons.add),
                                      onPressed: !_ready
                                          ? null
                                          : () => _controller.move(
                                              _controller.camera.center,
                                              (_controller.camera.zoom + 1)
                                                  .clamp(1, 19))),
                                  IconButton(
                                      tooltip: 'Zoom out',
                                      icon: const Icon(Icons.remove),
                                      onPressed: !_ready
                                          ? null
                                          : () => _controller.move(
                                              _controller.camera.center,
                                              (_controller.camera.zoom - 1)
                                                  .clamp(1, 19))),
                                ]))),
                ])));
  }
}
