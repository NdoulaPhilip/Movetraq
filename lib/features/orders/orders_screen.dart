import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/parcel_order.dart';
import '../../providers/auth_provider.dart';
import '../../services/local_data_service.dart';
import '../../widgets/app_page.dart';
import '../../widgets/premium_ui.dart';
import '../../screens/orders/order_tools.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  String _filter = 'Current';
  String _query = '';
  @override
  Widget build(BuildContext context) =>
      AppPage(title: 'Orders', embedded: true, children: [
        Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['Current', 'History', 'Cancelled']
                .map((value) => ChoiceChip(
                    label: Text(value),
                    selected: value == _filter,
                    onSelected: (_) => setState(() => _filter = value)))
                .toList()),
        const SizedBox(height: 16),
        TextField(
            decoration: const InputDecoration(
                hintText: 'Search orders', prefixIcon: Icon(Icons.search)),
            onChanged: (value) => setState(() => _query = value.toLowerCase())),
        const SizedBox(height: 18),
        StreamBuilder<List<ParcelOrder>>(
            stream: context.read<LocalDataService>().watchSenderOrders(
                context.read<AuthProvider>().profile?.uid ?? ''),
            builder: (context, snapshot) {
              if (snapshot.hasError) return LoadError(error: snapshot.error!);
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final orders = snapshot.data!
                  .where((order) =>
                      (_filter == 'Current'
                          ? ![OrderStatus.released, OrderStatus.cancelled]
                              .contains(order.status)
                          : _filter == 'History'
                              ? order.status == OrderStatus.released
                              : order.status == OrderStatus.cancelled) &&
                      '${order.title} ${order.code}'
                          .toLowerCase()
                          .contains(_query))
                  .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
              if (orders.isEmpty) {
                return const PremiumEmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'No orders here yet',
                    body: '');
              }
              return Column(children: [
                for (final order in orders)
                  RouteTile(
                      title: order.title,
                      subtitle:
                          '${order.code} - ${orderStatusLabel(order.status)}',
                      icon: Icons.inventory_2_outlined,
                      route: '/order-detail',
                      arguments: order.id)
              ]);
            }),
        const RouteTile(
            title: 'Create a delivery', icon: Icons.add, route: '/send'),
        const SizedBox(height: 80),
      ]);
}
