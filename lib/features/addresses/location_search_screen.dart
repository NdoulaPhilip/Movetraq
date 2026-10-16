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
  const LocationSearchScreen(
      {super.key, this.pickup = false, this.returnSelection = false});
  final bool pickup;
  final bool returnSelection;
  @override
  State<LocationSearchScreen> createState() => _LocationSearchScreenState();
}

class _LocationSearchScreenState extends State<LocationSearchScreen> {
  final _search = TextEditingController();
  int _revision = 0;
  bool _busy = false;
  Object? _error;
  List<AddressSuggestion> _results = [];
  bool _searched = false;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _changed(String value) {
    _revision++;
    setState(() {
      _results = [];
      _busy = false;
      _error = null;
      _searched = false;
    });
  }

  Future<void> _submitSearch() async {
    final value = _search.text.trim();
    if (value.length < 3 || _busy) return;
    final revision = ++_revision;
    setState(() {
      _results = [];
      _error = null;
      _busy = true;
      _searched = true;
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
  }

  void _select(AddressSuggestion value) {
    if (widget.returnSelection) {
      Navigator.pop(context, value);
      return;
    }
    if (widget.pickup) {
      context.read<SendFlowProvider>().setDetails(
          pickupAddress: value.address,
          pickupLocation: LatLng(value.latitude!, value.longitude!));
      Navigator.pop(context, value);
      return;
    }
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
        if (!widget.pickup) ...[
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
          TextButton.icon(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                      builder: (_) =>
                          const LocationSearchScreen(pickup: true))),
              icon: const Icon(Icons.search),
              label: const Text('Search pickup address')),
        ],
        const SizedBox(height: 18),
        TextField(
            controller: _search,
            onChanged: _changed,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _submitSearch(),
            decoration: InputDecoration(
                labelText: widget.pickup
                    ? 'Pickup address'
                    : 'Where should we deliver?',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                    tooltip: 'Search addresses',
                    onPressed: _busy ? null : _submitSearch,
                    icon: const Icon(Icons.arrow_forward)))),
        if (_busy)
          const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator())),
        if (_error != null) LoadError(error: _error!),
        if (_searched &&
            !_busy &&
            _error == null &&
            _search.text.trim().length >= 3 &&
            _results.isEmpty)
          const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No matching addresses')),
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
              final value = await Navigator.push<AddressSuggestion>(
                  context,
                  MaterialPageRoute(
                      builder: (_) => MapPickerScreen(pickup: widget.pickup)));
              if (value != null && mounted) _select(value);
            }),
      ]);
}

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen(
      {super.key,
      this.pickup = false,
      this.locationService = const LocationService()});
  final bool pickup;
  final LocationService locationService;
  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  maps.LatLng? _selected;
  maps.GoogleMapController? _controller;
  bool _locating = false;
  bool _resolving = false;
  AddressSuggestion? _address;
  Object? _error;
  int _revision = 0;
  Timer? _debounce;
  @override
  void initState() {
    super.initState();
    final flow = context.read<SendFlowProvider>();
    _selected =
        mapPoint(widget.pickup ? flow.pickupLocation : flow.dropoffLocation);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_selected != null) {
        _pin(_selected!);
      } else {
        _locate();
      }
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _pin(maps.LatLng point) {
    final revision = ++_revision;
    _debounce?.cancel();
    setState(() {
      _selected = point;
      _address = null;
      _error = null;
      _resolving = true;
    });
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final address = await context
            .read<LocalDataService>()
            .reverseAddress(LatLng(point.latitude, point.longitude));
        if (mounted && revision == _revision) {
          setState(() => _address = address);
        }
      } catch (error) {
        if (mounted && revision == _revision) setState(() => _error = error);
      } finally {
        if (mounted && revision == _revision) {
          setState(() => _resolving = false);
        }
      }
    });
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    try {
      final position = await widget.locationService.getCurrentPosition();
      if (!mounted) return;
      final point = maps.LatLng(position.latitude, position.longitude);
      _pin(point);
      await _controller
          ?.animateCamera(maps.CameraUpdate.newLatLngZoom(point, 16));
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
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
                        target: _selected ?? const maps.LatLng(0, 0),
                        zoom: _selected == null ? 1 : 16),
                    onMapCreated: (controller) => _controller = controller,
                    onTap: (point) {
                      if (!_locating) _pin(point);
                    },
                    markers: {
                      if (_selected != null)
                        maps.Marker(
                            markerId: const maps.MarkerId('selection'),
                            position: _selected!,
                            draggable: !_locating,
                            onDragEnd: _pin),
                    },
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                  ),
                ))),
        const SizedBox(height: 18),
        if (_address != null) Text(_address!.address),
        if (_resolving) const LinearProgressIndicator(),
        if (_error != null)
          LoadError(
              error: _error!,
              onRetry: () {
                if (_selected != null) {
                  _pin(_selected!);
                } else {
                  _locate();
                }
              }),
        if (_selected != null)
          DetailRow('Pinned location',
              '${_selected!.latitude.toStringAsFixed(5)}, ${_selected!.longitude.toStringAsFixed(5)}'),
        TextButton.icon(
            icon: const Icon(Icons.my_location),
            label: Text(_locating ? 'Locating...' : 'Use my location'),
            onPressed: _locating ? null : _locate),
        const SizedBox(height: 12),
        PrimaryButton(
            label: 'Use this pin',
            onPressed: _address == null || _locating || _resolving
                ? null
                : () => Navigator.pop(context, _address)),
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
