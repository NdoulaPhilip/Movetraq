import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/parcel_order.dart';
import '../../providers/auth_provider.dart';
import '../../services/local_data_service.dart';
import '../../theme/app_theme.dart';

class DTripsScreen extends StatelessWidget {
  const DTripsScreen({super.key});

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
      case OrderStatus.released:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
      default:
        return 'In progress';
    }
  }

  Color _statusColor(OrderStatus s) {
    switch (s) {
      case OrderStatus.released:
        return AppColors.success;
      case OrderStatus.cancelled:
        return AppColors.danger;
      default:
        return AppColors.inkSoft;
    }
  }

  String _relativeDay(DateTime d) {
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) return 'Today';
    final yesterday = now.subtract(const Duration(days: 1));
    if (d.year == yesterday.year && d.month == yesterday.month && d.day == yesterday.day) return 'Yesterday';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider>().profile;
    final data = context.read<LocalDataService>();
    if (profile == null) return const Center(child: CircularProgressIndicator());

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 108),
        children: [
          const Text('My trips', style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700, fontSize: 26)),
          const SizedBox(height: 18),
          StreamBuilder<List<ParcelOrder>>(
            stream: data.watchDelivererOrders(profile.uid),
            builder: (context, snap) {
              final trips = snap.data ?? [];
              if (trips.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(child: Text('No trips yet — accept a job to get started', style: TextStyle(color: AppColors.muted), textAlign: TextAlign.center)),
                );
              }
              return Column(
                children: trips.map((t) {
                  final (icon, tint) = _categoryStyle(t.category);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 11),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        if (t.status == OrderStatus.accepted || t.status == OrderStatus.pickedUp) {
                          Navigator.pushNamed(context, '/d-active', arguments: t.id);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.borderSoft)),
                        child: Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(14)),
                              child: Icon(icon, color: AppColors.ink),
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(t.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                                  const SizedBox(height: 3),
                                  Text('${t.code} · ${_relativeDay(t.createdAt)}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('₦${t.payout.toStringAsFixed(0)}', style: const TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w600, fontSize: 14.5)),
                                const SizedBox(height: 4),
                                Text(_statusLabel(t.status), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _statusColor(t.status))),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
