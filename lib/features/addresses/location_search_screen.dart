import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as maps;
import 'package:provider/provider.dart';

import '../../models/parcel_order.dart';
import '../../providers/send_flow_provider.dart';
import '../../services/local_data_service.dart';
import '../../services/node_api_client.dart';
import '../../services/location_service.dart';
import '../../widgets/app_page.dart';
import '../../widgets/google_map_status.dart';
import '../../widgets/mini_map.dart';
import '../../widgets/map_geometry.dart';
import '../../widgets/primary_button.dart';

class LocationSearchScreen extends StatefulWidget {
  const LocationSearchScreen({super.key});
  @override
  State<LocationSearchScreen> createState() => _LocationSearchScreenState();
}

class _LocationSearchScreenState extends State<LocationSearchScreen> {
  final _search = TextEditingController();
  Timer? _timer;
  int _revision = 0;
  bool _busy = false;
  Object? _error;
  List<AddressSuggestion> _results = [];
  @override
  void dispose() {
    _timer?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _changed(String value) {
    _timer?.cancel();
    final revision = ++_revision;
    if (value.trim().length < 2) {
      setState(() {
        _results = [];
        _busy = false;
        _error = null;
      });
      return;
    }
    _timer = Timer(const Duration(milliseconds: 350), () async {
      setState(() {
        _busy = true;
        _error = null;
      });
      try {
        final results =
            await context.read<LocalDataService>().searchAddresses(value);
        if (mounted && revision == _revision) {
          setState(() => _results = results);
        }
      } catch (error) {
        if (mounted && revision == _revision) setState(() => _error = error);
      } finally {
        if (mounted && revision == _revision) setState(() => _busy = false);
      }
    });
  }

  void _select(AddressSuggestion value) {
    context.read<SendFlowProvider>().setDetails(
        dropoffAddress: value.address,
        dropoffLocation: value.latitude == null || value.longitude == null
            ? null
            : LatLng(value.latitude!, value.longitude!),
        clearDropoffLocation:
            value.latitude == null || value.longitude == null);
    Navigator.pushNamed(context, '/service-choice');
  }

  @override
  Widget build(BuildContext context) =>
      AppPage(title: 'Where are we going?', children: [
        const SectionTitle('Pickup address'),
        Text(context.watch<SendFlowProvider>().pickupAddress),
        TextButton.icon(
            onPressed: () async {
              final value =
                  await Navigator.pushNamed(context, '/select-address');
              if (value != null && mounted) setState(() {});
            },
            icon: const Icon(Icons.location_on_outlined),
            label: const Text('Use a saved address')),
        const SizedBox(height: 18),
        TextField(
            controller: _search,
            onChanged: _changed,
            decoration: const InputDecoration(
                labelText: 'Where should we deliver?',
                prefixIcon: Icon(Icons.search))),
        if (_busy)
          const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator())),
        if (_error != null) LoadError(error: _error!),
        for (final value in _results)
          ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.place_outlined),
              title: Text(value.name),
              subtitle: Text(value.address),
              onTap: () => _select(value)),
        const SizedBox(height: 18),
        SecondaryButton(
            label: 'Choose on map',
            onPressed: () async {
              final point = await Navigator.pushNamed(context, '/map-picker');
              if (point is LatLng && context.mounted) {
                context.read<SendFlowProvider>().setDetails(
                    dropoffLocation: point,
                    dropoffAddress:
                        '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}');
                Navigator.pushNamed(context, '/service-choice');
              }
            }),
      ]);
}

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key});
  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  maps.LatLng? _selected;
  maps.GoogleMapController? _controller;
  bool _locating = false;
  @override
  void initState() {
    super.initState();
    _selected = mapPoint(context.read<SendFlowProvider>().dropoffLocation);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      AppPage(title: 'Choose a map pin', children: [
        SizedBox(
            height: 320,
            child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ConfiguredGoogleMap(
                  map: maps.GoogleMap(
                      initialCameraPosition: maps.CameraPosition(
                          target:
                              _selected ?? const maps.LatLng(6.5244, 3.3792),
                          zoom: _selected == null ? 12 : 16),
                      onMapCreated: (controller) => _controller = controller,
                      onTap: (point) {
                        if (!_locating) setState(() => _selected = point);
                      },
                      markers: {
                        if (_selected != null)
                          maps.Marker(
                              markerId: const maps.MarkerId('selection'),
                              position: _selected!,
                              draggable: !_locating,
                              onDragEnd: (point) =>
                                  setState(() => _selected = point))
                      },
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false),
                ))),
        const SizedBox(height: 18),
        if (_selected != null)
          DetailRow('Pinned location',
              '${_selected!.latitude.toStringAsFixed(5)}, ${_selected!.longitude.toStringAsFixed(5)}'),
        TextButton.icon(
            icon: const Icon(Icons.my_location),
            label: Text(_locating ? 'Locating...' : 'Use my location'),
            onPressed: _locating
                ? null
                : () async {
                    setState(() => _locating = true);
                    try {
                      final position =
                          await const LocationService().getCurrentPosition();
                      if (mounted) {
                        final point =
                            maps.LatLng(position.latitude, position.longitude);
                        setState(() => _selected = point);
                        await _controller?.animateCamera(
                            maps.CameraUpdate.newLatLngZoom(point, 16));
                      }
                    } catch (error) {
                      if (context.mounted) showActionError(context, error);
                    } finally {
                      if (mounted) setState(() => _locating = false);
                    }
                  }),
        const SizedBox(height: 12),
        PrimaryButton(
            label: 'Use this pin',
            onPressed: _selected == null || _locating
                ? null
                : () => Navigator.pop(context,
                    LatLng(_selected!.latitude, _selected!.longitude))),
      ]);
}

class ServiceChoiceScreen extends StatelessWidget {
  const ServiceChoiceScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final flow = context.watch<SendFlowProvider>();
    return AppPage(title: 'How should we deliver?', children: [
      MiniMap(
          pickupLocation: flow.pickupLocation,
          dropoffLocation: flow.dropoffLocation,
          height: 190),
      const SizedBox(height: 18),
      DetailRow('Pickup', flow.pickupAddress),
      DetailRow('Destination', flow.dropoffAddress),
      const SectionTitle('Delivery service'),
      RouteTile(
          title: 'P2P delivery',
          subtitle: 'Choose a deliverer',
          icon: Icons.local_shipping_outlined,
          onTap: () {
            flow.setMode(p2p: true);
            Navigator.pushNamed(context, '/send');
          }),
      RouteTile(
          title: 'Express delivery',
          subtitle: 'Immediate dispatch',
          icon: Icons.bolt_outlined,
          onTap: () {
            flow.setMode(p2p: false);
            Navigator.pushNamed(context, '/send');
          }),
      const RouteTile(
          title: 'Run an errand',
          icon: Icons.shopping_bag_outlined,
          route: '/errand'),
      const RouteTile(
          title: 'Big move',
          icon: Icons.local_shipping_outlined,
          route: '/big-move'),
    ]);
  }
}
