import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/parcel_order.dart';
import '../../providers/auth_provider.dart';
import '../../services/local_data_service.dart';
import '../../widgets/app_page.dart';
import '../../widgets/premium_ui.dart';
import '../orders/order_tools.dart';

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});
  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  late Stream<List<ParcelOrder>> _orders;
  String _query = '';
  @override
  void initState() {
    super.initState();
    _orders = context
        .read<LocalDataService>()
        .watchSenderOrders(context.read<AuthProvider>().profile?.uid ?? '');
  }

  @override
  Widget build(BuildContext context) =>
      AppPage(title: 'Receive a parcel', children: [
        TextField(
            decoration: const InputDecoration(
                labelText: 'Order reference', prefixIcon: Icon(Icons.search)),
            onChanged: (value) =>
                setState(() => _query = value.trim().toLowerCase())),
        const SizedBox(height: 18),
        const InfoBand(
            title: 'Your incoming deliveries',
            body: 'Only deliveries linked to your account are shown.',
            icon: Icons.inventory_2_outlined),
        StreamBuilder<List<ParcelOrder>>(
            stream: _orders,
            builder: (context, snapshot) {
              if (snapshot.hasError) return LoadError(error: snapshot.error!);
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final orders = snapshot.data!
                  .where((order) =>
                      order.status != OrderStatus.cancelled &&
                      order.status != OrderStatus.released &&
                      '${order.title} ${order.code}'
                          .toLowerCase()
                          .contains(_query))
                  .toList();
              if (orders.isEmpty) {
                return const PremiumEmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'No incoming parcels',
                    body: 'Your active deliveries will appear here.');
              }
              return Column(children: [
                for (final order in orders)
                  RouteTile(
                      title: order.title,
                      subtitle:
                          '${order.code} - ${orderStatusLabel(order.status)}',
                      icon: Icons.local_shipping_outlined,
                      route: '/live',
                      arguments: order.id)
              ]);
            }),
        const RouteTile(
            title: 'Delivery history',
            icon: Icons.history,
            route: '/track-list'),
      ]);
}
