import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/parcel_order.dart';
import '../../providers/auth_provider.dart';
import '../../services/local_data_service.dart';
import '../../theme/app_theme.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  String _filter = 'All';
  final _filters = const ['All', 'Active', 'Delivered', 'Cancelled'];

  bool _matches(ParcelOrder o) {
    switch (_filter) {
      case 'Active':
        return [OrderStatus.accepted, OrderStatus.pickedUp, OrderStatus.delivered, OrderStatus.pendingOffer, OrderStatus.negotiating]
            .contains(o.status);
      case 'Delivered':
        return o.status == OrderStatus.released;
      case 'Cancelled':
        return o.status == OrderStatus.cancelled;
      default:
        return true;
    }
  }

  (IconData, Color) _categoryStyle(String category) {
    switch (category) {
      case 'document':
        return (Icons.description_outlined, AppColors.tint['sky']!);
      case 'food':
        return (Icons.shopping_bag_outlined, AppColors.tint['mint']!);
      case 'fragile':
        return (Icons.card_giftcard_outlined, AppColors.tint['peach']!);
      default:
        return (Icons.inventory_2_outlined, AppColors.tint['peach']!);
    }
  }

  String _statusLabel(OrderStatus s) {
    switch (s) {
      case OrderStatus.pendingOffer:
        return 'Finding courier';
      case OrderStatus.negotiating:
        return 'Negotiating';
      case OrderStatus.accepted:
        return 'Picking up';
      case OrderStatus.pickedUp:
        return 'In transit';
      case OrderStatus.delivered:
        return 'Awaiting release';
      case OrderStatus.released:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color _statusColor(OrderStatus s) {
    switch (s) {
      case OrderStatus.released:
        return AppColors.success;
      case OrderStatus.cancelled:
        return AppColors.danger;
      case OrderStatus.pickedUp:
        return AppColors.success;
      case OrderStatus.accepted:
        return AppColors.warning;
      default:
        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider>().profile;
    final data = context.read<LocalDataService>();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Orders', style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700, fontSize: 26)),
            const SizedBox(height: 16),
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final f = _filters[i];
                  final selected = f == _filter;
                  return ChoiceChip(
                    label: Text(f),
                    selected: selected,
                    onSelected: (_) => setState(() => _filter = f),
                    selectedColor: AppColors.ink,
                    labelStyle: TextStyle(color: selected ? Colors.white : AppColors.inkSoft, fontWeight: FontWeight.w600, fontSize: 13),
                    backgroundColor: Colors.white,
                    side: BorderSide(color: selected ? AppColors.ink : AppColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: profile == null
                  ? const SizedBox.shrink()
                  : StreamBuilder<List<ParcelOrder>>(
                      stream: data.watchSenderOrders(profile.uid),
                      builder: (context, snap) {
                        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                        final orders = snap.data!.where(_matches).toList();
                        if (orders.isEmpty) {
                          return const Center(
                            child: Text('No orders yet', style: TextStyle(color: AppColors.muted)),
                          );
                        }
                        return ListView.separated(
                          padding: const EdgeInsets.only(bottom: 108),
                          itemCount: orders.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 11),
                          itemBuilder: (context, i) {
                            final o = orders[i];
                            return InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => Navigator.pushNamed(context, '/order-detail', arguments: o.id),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppColors.borderSoft),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(color: _categoryStyle(o.category).$2, borderRadius: BorderRadius.circular(14)),
                                      child: Icon(_categoryStyle(o.category).$1, color: AppColors.ink),
                                    ),
                                    const SizedBox(width: 13),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(o.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                                          const SizedBox(height: 3),
                                          Text('${o.code} · ${_relativeDay(o.createdAt)}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text('₦${o.price.toStringAsFixed(0)}',
                                            style: const TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w600, fontSize: 14.5)),
                                        const SizedBox(height: 4),
                                        Text(_statusLabel(o.status),
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _statusColor(o.status))),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _relativeDay(DateTime d) {
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) return 'Today';
    final yesterday = now.subtract(const Duration(days: 1));
    if (d.year == yesterday.year && d.month == yesterday.month && d.day == yesterday.day) return 'Yesterday';
    return '${d.month}/${d.day}';
  }
}
