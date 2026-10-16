import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/parcel_order.dart';
import '../services/local_data_service.dart';

/// Only provider-returned road geometry is drawable as a delivery route.
class ProviderRoute extends StatefulWidget {
  const ProviderRoute(
      {super.key,
      required this.pickup,
      required this.destination,
      this.topPadding = 0,
      required this.builder});
  final double topPadding;
  final LatLng? pickup, destination;
  final Widget Function(List<LatLng> points, Map<String, dynamic>? metrics,
      Object? error, bool busy) builder;
  @override
  State<ProviderRoute> createState() => _ProviderRouteState();
}

class _ProviderRouteState extends State<ProviderRoute> {
  Future<Map<String, dynamic>>? _request;
  String? _key;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  @override
  void didUpdateWidget(covariant ProviderRoute oldWidget) {
    super.didUpdateWidget(oldWidget);
    _load();
  }

  void _load() {
    final from = widget.pickup, to = widget.destination;
    final key =
        '${from?.latitude},${from?.longitude}:${to?.latitude},${to?.longitude}';
    if (key == _key) return;
    _key = key;
    if (from == null || to == null) {
      _request = null;
      return;
    }
    try {
      _request = context.read<LocalDataService>().route(from, to);
    } catch (error) {
      _request = Future.error(error);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
      future: _request,
      builder: (context, snapshot) {
        final data = snapshot.connectionState == ConnectionState.done &&
                !snapshot.hasError
            ? snapshot.data
            : null;
        final points = (data?['points'] as List? ?? [])
            .map((value) =>
                LatLng.fromJson(Map<String, dynamic>.from(value as Map)))
            .toList();
        return Stack(children: [
          widget.builder(points, data, snapshot.error,
              snapshot.connectionState == ConnectionState.waiting),
          if (widget.pickup != null && widget.destination != null)
            Positioned(
                left: 8,
                right: 8,
                top: widget.topPadding + 8,
                child: Align(
                    alignment: Alignment.topLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      color: Colors.white,
                      child: Text(
                          snapshot.hasError
                              ? 'Route unavailable'
                              : data == null
                                  ? 'Loading route...'
                                  : '${((data['distanceMeters'] as num) / 1000).toStringAsFixed(1)} km · ${((data['durationSeconds'] as num) / 60).ceil()} min',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black87)),
                    ))),
        ]);
      });
}
