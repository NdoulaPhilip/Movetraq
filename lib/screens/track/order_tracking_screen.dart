import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/parcel_order.dart';
import '../../services/local_data_service.dart';
import '../../widgets/app_page.dart';
import '../../widgets/design_ui.dart';
import '../../widgets/mini_map.dart';
import '../../widgets/primary_button.dart';
import '../orders/order_tools.dart';

class OrderTrackingScreen extends StatelessWidget {
  const OrderTrackingScreen({super.key, required this.orderId});
  final String orderId;
  @override
  Widget build(BuildContext context) => StreamBuilder<ParcelOrder?>(
      stream: context.read<LocalDataService>().watchOrder(orderId),
      builder: (context, snapshot) {
        final order = snapshot.data;
        return AppPage(title: 'Track order', children: [
          if (snapshot.hasError)
            LoadError(error: snapshot.error!)
          else if (order == null &&
              snapshot.connectionState == ConnectionState.waiting)
            const Center(child: CircularProgressIndicator())
          else if (order == null)
            const DesignNote(title: 'Order unavailable')
          else ...[
            ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: MiniMap(
                    pickupLocation: order.pickupLocation,
                    dropoffLocation: order.dropoffLocation,
                    courierLocation: order.courierLocationIsSimulated
                        ? null
                        : order.courierLocation,
                    height: 210)),
            const SizedBox(height: 18),
            DesignCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    Expanded(
                        child: Text(order.code,
                            style: const TextStyle(fontSize: 11))),
                    DesignBadge(order.isExpress ? 'Express' : 'P2P')
                  ]),
                  const SizedBox(height: 16),
                  Text(orderStatusLabel(order.status),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Text(
                      switch (order.status) {
                        OrderStatus.accepted =>
                          'Your deliverer is heading to pickup.',
                        OrderStatus.pickedUp =>
                          'Your parcel is on its way to the drop-off.',
                        OrderStatus.delivered =>
                          'Your parcel is awaiting sender confirmation.',
                        OrderStatus.released =>
                          'Delivery completed and payment released.',
                        OrderStatus.cancelled => 'This delivery was cancelled.',
                        _ => 'Waiting for a deliverer to accept this request.',
                      },
                      style: const TextStyle(fontSize: 13, height: 1.6)),
                  const SizedBox(height: 12),
                  const Text('Arrival estimate: unavailable',
                      style: TextStyle(fontSize: 12)),
                ])),
            const SizedBox(height: 14),
            DesignCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('Pickup and drop-off',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 20),
                  DesignRoute(
                      pickup: order.pickupAddress,
                      destination: order.dropoffAddress),
                ])),
            const SizedBox(height: 14),
            DesignNote(
                title: 'Parcel details',
                body: '${order.title}\n${order.category}'),
            PrimaryButton(
                label: 'Open live tracking',
                onPressed: () =>
                    Navigator.pushNamed(context, '/live', arguments: order.id)),
            const SizedBox(height: 12),
            SecondaryButton(
                label: 'Order details',
                onPressed: () => Navigator.pushNamed(context, '/order-detail',
                    arguments: order.id)),
          ],
        ]);
      });
}
