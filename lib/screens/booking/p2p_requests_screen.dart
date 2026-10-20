import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/parcel_order.dart';
import '../../providers/auth_provider.dart';
import '../../services/local_data_service.dart';
import '../../widgets/app_page.dart';
import '../../widgets/design_ui.dart';
import '../../widgets/primary_button.dart';
import '../orders/order_tools.dart';

class P2PRequestsScreen extends StatefulWidget {
  const P2PRequestsScreen({super.key});

  @override
  State<P2PRequestsScreen> createState() => _P2PRequestsScreenState();
}

class _P2PRequestsScreenState extends State<P2PRequestsScreen> {
  late final Stream<List<ParcelOrder>> _orders;

  @override
  void initState() {
    super.initState();
    _orders = context
        .read<LocalDataService>()
        .watchSenderOrders(context.read<AuthProvider>().profile?.uid ?? '');
  }

  @override
  Widget build(BuildContext context) => AppPage(
        title: 'Your P2P requests',
        actions: [
          IconButton(
              tooltip: 'Create a delivery request',
              icon: const Icon(Icons.add),
              onPressed: () => Navigator.pushNamed(context, '/p2p-request')),
        ],
        children: [
          const DesignCard(
              color: Color(0xFFF0F4DF),
              child: RouteTile(
                  title: 'Find a P2P deliverer',
                  subtitle: 'Available routes and delivery offers',
                  icon: Icons.local_shipping_outlined,
                  route: '/p2p-ads')),
          const SectionTitle('Your delivery requests'),
          StreamBuilder<List<ParcelOrder>>(
              stream: _orders,
              builder: (context, snapshot) {
                if (snapshot.hasError) return LoadError(error: snapshot.error!);
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final orders = snapshot.data!
                    .where((order) =>
                        !order.isExpress &&
                        (order.isP2P || order.matchingMode == 'p2p'))
                    .toList()
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                if (orders.isEmpty) {
                  return const DesignCard(
                      color: Color(0xFFFAFBF6),
                      child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 25),
                          child: Column(children: [
                            ParcelIcon('parcel'),
                            SizedBox(height: 22),
                            Text('You have no delivery requests',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w700)),
                            SizedBox(height: 14),
                            Text(
                                'Add parcel details, pickup and delivery addresses, and your proposed price.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 13, height: 1.7)),
                          ])));
                }
                return Column(children: [
                  for (final order in orders)
                    RouteTile(
                        title: order.title,
                        subtitle:
                            '${order.code} / ${orderStatusLabel(order.status)}\n${order.pickupAddress} to ${order.dropoffAddress}',
                        icon: Icons.inventory_2_outlined,
                        route: '/order-detail',
                        arguments: order.id),
                ]);
              }),
          const SizedBox(height: 20),
          PrimaryButton(
              label: 'Create a delivery request',
              onPressed: () => Navigator.pushNamed(context, '/p2p-request')),
        ],
      );
}
