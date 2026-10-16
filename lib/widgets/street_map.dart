import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

/// Allows an offline tile provider (and isolated widget tests) to supply tiles.
class MapTileSource extends InheritedWidget {
  const MapTileSource({super.key, required this.create, required super.child});
  final TileProvider Function() create;
  @override
  bool updateShouldNotify(MapTileSource oldWidget) =>
      create != oldWidget.create;
}

class StreetMap extends StatefulWidget {
  const StreetMap(
      {super.key,
      this.controller,
      this.initialCenter = const LatLng(0, 0),
      this.initialZoom = 2,
      this.initialFit,
      this.markers = const [],
      this.polylines = const [],
      this.interactive = true,
      this.padding = EdgeInsets.zero,
      this.onTap,
      this.onMapReady});
  final MapController? controller;
  final LatLng initialCenter;
  final double initialZoom;
  final CameraFit? initialFit;
  final List<Marker> markers;
  final List<Polyline> polylines;
  final bool interactive;
  final EdgeInsets padding;
  final void Function(LatLng)? onTap;
  final VoidCallback? onMapReady;
  static const tileUrl = String.fromEnvironment('MAP_TILE_URL',
      defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png');
  static const attribution = String.fromEnvironment('MAP_TILE_ATTRIBUTION',
      defaultValue: '© OpenStreetMap contributors');
  static const attributionUrl = String.fromEnvironment(
      'MAP_TILE_ATTRIBUTION_URL',
      defaultValue: 'https://www.openstreetmap.org/copyright');
  @override
  State<StreetMap> createState() => _StreetMapState();
}

class _StreetMapState extends State<StreetMap> {
  bool _tileError = false;
  int _revision = 0;
  TileProvider? _provider;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _provider ??=
        context.dependOnInheritedWidgetOfExactType<MapTileSource>()?.create();
  }

  void _failed() {
    if (_tileError) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_tileError) setState(() => _tileError = true);
    });
  }

  @override
  Widget build(BuildContext context) => Stack(children: [
        FlutterMap(
          mapController: widget.controller,
          options: MapOptions(
              initialCenter: widget.initialCenter,
              initialZoom: widget.initialZoom,
              initialCameraFit: widget.initialFit,
              minZoom: 1,
              maxZoom: 19,
              interactionOptions: InteractionOptions(
                  flags: widget.interactive
                      ? InteractiveFlag.all & ~InteractiveFlag.rotate
                      : InteractiveFlag.none),
              onMapReady: widget.onMapReady,
              onTap: (_, point) => widget.onTap?.call(point)),
          children: [
            TileLayer(
                key: ValueKey(_revision),
                urlTemplate: StreetMap.tileUrl,
                userAgentPackageName: 'com.example.movetraq',
                maxNativeZoom: 19,
                tileProvider: _provider,
                panBuffer: 0,
                errorTileCallback: (_, __, ___) => _failed()),
            if (widget.polylines.isNotEmpty)
              PolylineLayer(polylines: widget.polylines),
            MarkerLayer(markers: widget.markers),
          ],
        ),
        Positioned(
            left: 4,
            bottom: widget.padding.bottom + 4,
            child: SafeArea(
                top: false,
                child: ColoredBox(
                    color: Colors.white.withValues(alpha: .92),
                    child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 2),
                        child: GestureDetector(
                            onTap: () =>
                                launchUrl(Uri.parse(StreetMap.attributionUrl)),
                            child: const Text(StreetMap.attribution,
                                style: TextStyle(
                                    fontSize: 10, color: Colors.black87))))))),
        if (_tileError)
          Positioned(
              bottom: widget.padding.bottom + 24,
              left: 4,
              right: 4,
              child: Material(
                  color: Colors.white,
                  child: Row(children: [
                    const Expanded(
                        child: Padding(
                            padding: EdgeInsets.all(6),
                            child: Text(
                                'Map tiles unavailable. Check your connection.',
                                style: TextStyle(fontSize: 11)))),
                    TextButton(
                        onPressed: () => setState(() {
                              _tileError = false;
                              _revision++;
                            }),
                        child: const Text('Retry')),
                  ]))),
      ]);
}

Marker locationMarker(String id, LatLng point, String label, Color color,
        {IconData icon = Icons.location_pin}) =>
    Marker(
        key: ValueKey(id),
        point: point,
        width: 40,
        height: 40,
        alignment: Alignment.topCenter,
        child:
            Tooltip(message: label, child: Icon(icon, color: color, size: 36)));
