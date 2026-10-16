import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/parcel_order.dart';
import '../../providers/auth_provider.dart';
import '../../providers/deliverer_tracking_provider.dart';
import '../../services/local_data_service.dart';
import '../../widgets/app_page.dart';
import '../../widgets/live_google_map.dart';
import '../../widgets/delivery_progress.dart';

class DActiveScreen extends StatefulWidget {
  const DActiveScreen({super.key, required this.orderId});
  final String orderId;
  @override
  State<DActiveScreen> createState() => _DActiveScreenState();
}

class _DActiveScreenState extends State<DActiveScreen>
    with WidgetsBindingObserver {
  late DelivererTrackingProvider _tracking;
  late Stream<ParcelOrder?> _order;
  String get orderId => widget.orderId;
  @override
  void initState() {
    super.initState();
    _tracking = context.read<DelivererTrackingProvider>();
    _order = context.read<LocalDataService>().watchOrder(orderId);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant DActiveScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderId != orderId) {
      _tracking.stopTracking();
      _order = context.read<LocalDataService>().watchOrder(orderId);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _tracking.stopTracking();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Avoid notifying listeners while the widget tree is being removed.
    Future.microtask(_tracking.stopTracking);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<ParcelOrder?>(
      stream: _order,
      builder: (context, snapshot) {
        final order = snapshot.data;
        final tracking = context.watch<DelivererTrackingProvider>();
        final active = order != null &&
            order.delivererId == context.watch<AuthProvider>().profile?.uid &&
            [OrderStatus.accepted, OrderStatus.pickedUp].contains(order.status);
        if ((!active || snapshot.hasError) &&
            tracking.activeDeliveryId == orderId) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) tracking.stopTracking();
          });
        }
        return AppPage(title: 'Active delivery', children: [
          if (snapshot.hasError)
            LoadError(error: snapshot.error!)
          else if (order == null &&
              snapshot.connectionState == ConnectionState.waiting)
            const Center(child: CircularProgressIndicator())
          else if (order == null)
            const InfoBand(title: 'Delivery unavailable')
          else ...[
            DeliveryProgress(status: order.status),
            SizedBox(
                height: 340,
                child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: LiveGoogleMap(order: order))),
            const SizedBox(height: 16),
            DetailRow('Pickup', order.pickupAddress),
            DetailRow('Destination', order.dropoffAddress),
            SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Share live delivery location'),
                subtitle: const Text(
                    'Location sharing is limited to this active delivery.'),
                value:
                    tracking.isTracking && tracking.activeDeliveryId == orderId,
                onChanged: !active || tracking.isLoading
                    ? null
                    : (enabled) async {
                        try {
                          if (enabled) {
                            await tracking.startTracking(orderId);
                          } else {
                            await tracking.stopTracking();
                          }
                        } catch (error) {
                          if (context.mounted) showActionError(context, error);
                        }
                      }),
            if (tracking.errorMessage != null)
              LoadError(error: tracking.errorMessage!),
            if (order.status == OrderStatus.accepted)
              RouteTile(
                  title: 'Pickup details',
                  icon: Icons.inventory_2_outlined,
                  route: '/delivery-pickup',
                  arguments: orderId),
            if (order.status == OrderStatus.pickedUp)
              RouteTile(
                  title: 'Drop-off & handover',
                  icon: Icons.local_shipping_outlined,
                  route: '/delivery-dropoff',
                  arguments: orderId),
            if ([
              OrderStatus.delivered,
              OrderStatus.released,
              OrderStatus.cancelled
            ].contains(order.status))
              RouteTile(
                  title: 'Delivery summary',
                  icon: Icons.fact_check_outlined,
                  route: '/delivery-summary',
                  arguments: orderId),
            RouteTile(
                title: 'Contact customer',
                icon: Icons.chat_bubble_outline,
                route: '/delivery-contact',
                arguments: orderId),
            RouteTile(
                title: 'Report a problem',
                icon: Icons.support_agent,
                route: '/delivery-problem',
                arguments: orderId),
          ],
        ]);
      });
}
