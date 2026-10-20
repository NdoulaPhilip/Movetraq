import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/parcel_order.dart';
import '../../providers/auth_provider.dart';
import '../../services/local_data_service.dart';
import '../../widgets/app_page.dart';
import '../../widgets/design_ui.dart';
import '../../widgets/primary_button.dart';
import '../../theme/app_theme.dart';
import '../orders/order_tools.dart';

class ManageOrdersScreen extends StatefulWidget {
  const ManageOrdersScreen({super.key});
  @override
  State<ManageOrdersScreen> createState() => _ManageOrdersScreenState();
}

class _ManageOrdersScreenState extends State<ManageOrdersScreen> {
  String _query = '', _filter = 'All';
  String? _uid;
  Stream<List<ParcelOrder>>? _assigned;
  late final Stream<List<ParcelOrder>> _available;
  @override
  void initState() {
    super.initState();
    _available = context.read<LocalDataService>().watchOpenJobs();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uid = context.watch<AuthProvider>().profile?.uid;
    if (_assigned == null || _uid != uid) {
      _uid = uid;
      _assigned = uid == null
          ? Stream.value([])
          : context.read<LocalDataService>().watchDelivererOrders(uid);
    }
  }

  bool _isAvailable(ParcelOrder order) =>
      order.status == OrderStatus.pendingOffer && order.delivererId == null;
  @override
  Widget build(BuildContext context) => AppPage(
          title: 'Manage orders',
          subtitle: 'Accept jobs, manage pickups and complete deliveries.',
          children: [
            TextField(
                decoration: const InputDecoration(
                    hintText: 'Search deliveries',
                    prefixIcon: Icon(Icons.search)),
                onChanged: (value) =>
                    setState(() => _query = value.trim().toLowerCase())),
            const SizedBox(height: 18),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final filter in ['All', 'Available', 'Active', 'Completed'])
                ChoiceChip(
                    label: Text(filter),
                    selected: _filter == filter,
                    showCheckmark: false,
                    selectedColor: AppColors.accent,
                    onSelected: (_) => setState(() => _filter = filter)),
            ]),
            const SizedBox(height: 16),
            StreamBuilder<List<ParcelOrder>>(
                stream: _available,
                builder: (context, jobs) => StreamBuilder<List<ParcelOrder>>(
                    stream: _assigned,
                    builder: (context, assigned) {
                      if (jobs.hasError) return LoadError(error: jobs.error!);
                      if (assigned.hasError) {
                        return LoadError(error: assigned.error!);
                      }
                      if (!jobs.hasData || !assigned.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final merged = <String, ParcelOrder>{};
                      for (final order in jobs.data!) {
                        if (_uid != null &&
                            order.senderId != _uid &&
                            _isAvailable(order)) {
                          merged[order.id] = order;
                        }
                      }
                      for (final order in assigned.data!) {
                        if (_uid != null && order.delivererId == _uid) {
                          merged[order.id] = order;
                        }
                      }
                      final orders = merged.values
                          .where((order) =>
                              '${order.title} ${order.code} ${order.pickupAddress} ${order.dropoffAddress}'
                                  .toLowerCase()
                                  .contains(_query) &&
                              switch (_filter) {
                                'Available' => _isAvailable(order),
                                'Active' => [
                                    OrderStatus.accepted,
                                    OrderStatus.pickedUp,
                                    OrderStatus.delivered
                                  ].contains(order.status),
                                'Completed' =>
                                  order.status == OrderStatus.released,
                                _ => true,
                              })
                          .toList()
                        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                      if (orders.isEmpty) {
                        return const DesignNote(
                            title: 'No matching deliveries',
                            body: 'Try another search or delivery filter.');
                      }
                      return Column(children: [
                        for (final order in orders)
                          Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: DesignCard(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(
                                        '${order.code} / ${_isAvailable(order) ? 'Available' : orderStatusLabel(order.status)}',
                                        style: const TextStyle(fontSize: 11)),
                                    const SizedBox(height: 14),
                                    Text(order.title,
                                        style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 16),
                                    Text(
                                        '${order.pickupAddress} to ${order.dropoffAddress}',
                                        style: const TextStyle(
                                            fontSize: 13,
                                            color: AppColors.muted)),
                                    const SizedBox(height: 14),
                                    Text(naira(order.payout),
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 14),
                                    PrimaryButton(
                                        label: 'Manage delivery',
                                        onPressed: () => Navigator.pushNamed(
                                            context,
                                            _isAvailable(order)
                                                ? '/d-job'
                                                : order.status ==
                                                        OrderStatus.accepted
                                                    ? '/delivery-pickup'
                                                    : order.status ==
                                                            OrderStatus.pickedUp
                                                        ? '/delivery-dropoff'
                                                        : '/delivery-summary',
                                            arguments: order.id)),
                                  ]))),
                      ]);
                    })),
          ]);
}
