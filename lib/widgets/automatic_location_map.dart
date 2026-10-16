import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../models/parcel_order.dart';
import '../providers/auth_provider.dart';
import '../services/local_data_service.dart';
import '../services/node_api_client.dart';
import 'mini_map.dart';

/// A dashboard requests GPS once for each signed-in account. No tracking stream
/// starts here; delivery sharing has its own explicit switch and lifecycle.
class AutomaticLocationMap extends StatefulWidget {
  const AutomaticLocationMap({super.key});
  @override
  State<AutomaticLocationMap> createState() => _AutomaticLocationMapState();
}

class _AutomaticLocationMapState extends State<AutomaticLocationMap> {
  String? _owner;
  Future<AddressSuggestion>? _request;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final owner = context.watch<AuthProvider>().profile?.uid;
    if (owner != _owner) {
      _owner = owner;
      _request = owner == null
          ? null
          : context.read<LocalDataService>().currentAddress();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<AddressSuggestion>(
      future: _request,
      builder: (context, snapshot) {
        final value = snapshot.connectionState == ConnectionState.done
            ? snapshot.data
            : null;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          MiniMap(
              courierLocation:
                  value?.latitude == null || value?.longitude == null
                      ? null
                      : LatLng(value!.latitude!, value.longitude!),
              height: 180),
          if (snapshot.connectionState == ConnectionState.waiting)
            const Text('Finding your location...'),
          if (value != null) Text(value.address),
          if (value?.syncWarning != null) Text(value!.syncWarning!),
          if (snapshot.hasError) ...[
            const Text(
                'Your location is unavailable. You can continue using the app.'),
            Wrap(children: [
              TextButton(
                  onPressed: _owner == null
                      ? null
                      : () => setState(() {
                            _request = context
                                .read<LocalDataService>()
                                .currentAddress();
                          }),
                  child: const Text('Retry location')),
              const TextButton(
                  onPressed: Geolocator.openLocationSettings,
                  child: Text('Location settings')),
            ]),
          ],
        ]);
      });
}
