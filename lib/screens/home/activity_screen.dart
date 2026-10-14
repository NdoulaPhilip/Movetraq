import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/misc_models.dart';
import '../../models/parcel_order.dart';
import '../../providers/auth_provider.dart';
import '../../services/local_data_service.dart';
import '../../widgets/app_page.dart';
import '../../widgets/premium_ui.dart';
import '../orders/order_tools.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});
  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  String _filter = 'All';
  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().profile?.uid ?? '';
    final data = context.read<LocalDataService>();
    return AppPage(title: 'Activity', embedded: true, children: [
      Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ['All', 'Deliveries', 'Payments']
              .map((value) => ChoiceChip(
                  label: Text(value),
                  selected: value == _filter,
                  onSelected: (_) => setState(() => _filter = value)))
              .toList()),
      const SizedBox(height: 18),
      if (_filter != 'Payments')
        StreamBuilder<List<ParcelOrder>>(
            stream: data.watchSenderOrders(uid),
            builder: (context, snapshot) {
              if (snapshot.hasError) return LoadError(error: snapshot.error!);
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final orders = snapshot.data!.toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
              if (orders.isEmpty) {
                return const PremiumEmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'No delivery activity yet',
                    body: '');
              }
              return Column(children: [
                for (final order in orders)
                  RouteTile(
                      title: order.title,
                      subtitle:
                          '${order.code} - ${orderStatusLabel(order.status)}',
                      icon: Icons.local_shipping_outlined,
                      route: '/order-detail',
                      arguments: order.id)
              ]);
            }),
      if (_filter != 'Deliveries') ...[
        const SectionTitle('Payments'),
        StreamBuilder<List<WalletTransaction>>(
            stream: data.watchWalletTransactions(uid),
            builder: (context, snapshot) {
              if (snapshot.hasError) return LoadError(error: snapshot.error!);
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final items = snapshot.data!.toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
              if (items.isEmpty) {
                return const InfoBand(
                    title: 'No payment activity yet',
                    icon: Icons.receipt_long_outlined);
              }
              return Column(children: [
                for (final item in items)
                  RouteTile(
                      title: item.title,
                      subtitle:
                          'NGN ${item.amount.abs().toStringAsFixed(2)} - ${item.createdAt.toLocal()}',
                      icon: Icons.receipt_long_outlined,
                      route: '/transaction-detail',
                      arguments: item)
              ]);
            })
      ],
      const RouteTile(title: 'Send a parcel', icon: Icons.add, route: '/send'),
      const SizedBox(height: 80),
    ]);
  }
}
