import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/parcel_order.dart';
import '../../providers/auth_provider.dart';
import '../../services/local_data_service.dart';
import '../../widgets/app_page.dart';
import '../../widgets/design_ui.dart';
import '../orders/order_tools.dart';

class DTripsScreen extends StatefulWidget {
  const DTripsScreen({super.key});
  @override
  State<DTripsScreen> createState() => _DTripsScreenState();
}

class _DTripsScreenState extends State<DTripsScreen> {
  String _filter = 'All';
  String? _uid;
  Stream<List<ParcelOrder>>? _orders;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uid = context.watch<AuthProvider>().profile?.uid;
    if (_orders == null || uid != _uid) {
      _uid = uid;
      _orders = uid == null
          ? Stream.value([])
          : context.read<LocalDataService>().watchDelivererOrders(uid);
    }
  }

  @override
  Widget build(BuildContext context) => AppPage(title: 'My trips', children: [
        Wrap(spacing: 7, runSpacing: 7, children: [
          for (final filter in ['All', 'Active', 'Completed', 'Cancelled'])
            ChoiceChip(
                label: Text(filter),
                selected: _filter == filter,
                onSelected: (_) => setState(() => _filter = filter)),
        ]),
        const SizedBox(height: 18),
        StreamBuilder<List<ParcelOrder>>(
            key: ValueKey(_uid),
            stream: _orders,
            builder: (context, snapshot) {
              if (snapshot.hasError) return LoadError(error: snapshot.error!);
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final orders = snapshot.data!
                  .where((order) => switch (_filter) {
                        'Active' => ![
                            OrderStatus.released,
                            OrderStatus.cancelled
                          ].contains(order.status),
                        'Completed' => order.status == OrderStatus.released,
                        'Cancelled' => order.status == OrderStatus.cancelled,
                        _ => true,
                      })
                  .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
              return Column(children: [
                if (orders.isEmpty)
                  const DesignNote(
                      title: 'No deliveries here yet',
                      body: 'Your trips will appear here.'),
                for (final order in orders)
                  DesignOrderCard(
                      order: order,
                      driver: true,
                      status: orderStatusLabel(order.status),
                      onTap: () => Navigator.pushNamed(
                          context,
                          order.status == OrderStatus.accepted
                              ? '/delivery-pickup'
                              : order.status == OrderStatus.pickedUp
                                  ? '/delivery-dropoff'
                                  : '/delivery-summary',
                          arguments: order.id)),
              ]);
            }),
      ]);
}
