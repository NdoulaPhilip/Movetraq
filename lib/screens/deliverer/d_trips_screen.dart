import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/parcel_order.dart';
import '../../providers/auth_provider.dart';
import '../../services/local_data_service.dart';
import '../../widgets/app_page.dart';
import '../../widgets/premium_ui.dart';
import '../orders/order_tools.dart';

class DTripsScreen extends StatefulWidget {
  const DTripsScreen({super.key});
  @override
  State<DTripsScreen> createState() => _DTripsScreenState();
}

class _DTripsScreenState extends State<DTripsScreen> {
  String _filter = 'Active';
  @override
  Widget build(BuildContext context) =>
      AppPage(title: 'My delivery orders', children: [
        Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['Active', 'Completed', 'Cancelled']
                .map((value) => ChoiceChip(
                    label: Text(value),
                    selected: value == _filter,
                    onSelected: (_) => setState(() => _filter = value)))
                .toList()),
        const SizedBox(height: 18),
        StreamBuilder<List<ParcelOrder>>(
            stream: context.read<LocalDataService>().watchDelivererOrders(
                context.read<AuthProvider>().profile?.uid ?? ''),
            builder: (context, snapshot) {
              if (snapshot.hasError) return LoadError(error: snapshot.error!);
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final orders = snapshot.data!
                  .where((order) => _filter == 'Active'
                      ? ![OrderStatus.released, OrderStatus.cancelled]
                          .contains(order.status)
                      : _filter == 'Completed'
                          ? order.status == OrderStatus.released
                          : order.status == OrderStatus.cancelled)
                  .toList();
              if (orders.isEmpty) {
                return const PremiumEmptyState(
                    icon: Icons.local_shipping_outlined,
                    title: 'No deliveries here yet',
                    body: '');
              }
              return Column(children: [
                for (final order in orders)
                  RouteTile(
                      title: order.title,
                      subtitle:
                          '${order.code} - ${orderStatusLabel(order.status)}',
                      icon: Icons.inventory_2_outlined,
                      route: order.status == OrderStatus.accepted
                          ? '/delivery-pickup'
                          : order.status == OrderStatus.pickedUp
                              ? '/delivery-dropoff'
                              : '/delivery-summary',
                      arguments: order.id)
              ]);
            }),
      ]);
}
