import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/parcel_order.dart';
import '../../providers/auth_provider.dart';
import '../../services/local_data_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/mini_map.dart';

class TrackListScreen extends StatelessWidget {
  const TrackListScreen({super.key});

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

  (String, Color, Color) _statusStyle(OrderStatus s) {
    switch (s) {
      case OrderStatus.pickedUp:
        return ('In transit', AppColors.tint['mint']!, const Color(0xFF0F9D58));
      case OrderStatus.delivered:
        return ('Arriving', AppColors.tint['mint']!, const Color(0xFF0F9D58));
      case OrderStatus.accepted:
        return ('Picking up', AppColors.tint['peach']!, const Color(0xFFB2650A));
      default:
        return ('Finding courier', const Color(0xFFF3F2EC), AppColors.muted);
    }
  }

  int _etaMinutes(ParcelOrder o) {
    switch (o.status) {
      case OrderStatus.pickedUp:
        return 1;
      case OrderStatus.accepted:
        return 32;
      default:
        return 45;
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider>().profile;
    final data = context.read<LocalDataService>();

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: CircleIconButton(icon: Icons.arrow_back, onTap: () => Navigator.maybePop(context)),
            ),
            Expanded(
              child: profile == null
                  ? const SizedBox.shrink()
                  : StreamBuilder<List<ParcelOrder>>(
                      stream: data.watchSenderOrders(profile.uid),
                      builder: (context, snap) {
                        final orders = (snap.data ?? [])
                            .where((o) => [
                                  OrderStatus.accepted,
                                  OrderStatus.pickedUp,
                                  OrderStatus.delivered,
                                  OrderStatus.pendingOffer,
                                  OrderStatus.negotiating,
                                ].contains(o.status))
                            .toList();
                        return ListView(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                          children: [
                            const Text('Active shipments',
                                style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w600, fontSize: 24)),
                            const SizedBox(height: 4),
                            Text('${orders.length} on the move right now', style: const TextStyle(fontSize: 13.5, color: AppColors.muted)),
                            const SizedBox(height: 18),
                            if (orders.isEmpty)
                              const Padding(
                                padding: EdgeInsets.only(top: 24),
                                child: Center(child: Text('Nothing to track right now', style: TextStyle(color: AppColors.muted))),
                              ),
                            ...orders.map((o) {
                              final (statusLabel, statusBg, statusFg) = _statusStyle(o.status);
                              final (icon, tint) = _categoryStyle(o.category);
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(color: AppColors.borderSoft),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 46,
                                          height: 46,
                                          decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(14)),
                                          child: Icon(icon, color: AppColors.ink, size: 21),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(o.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                                              const SizedBox(height: 2),
                                              Text(o.code, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                                          decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(100)),
                                          child: Text(statusLabel, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: statusFg)),
                                        ),
                                      ],
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(2, 14, 2, 12),
                                      child: Row(
                                        children: [
                                          Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.faint, shape: BoxShape.circle)),
                                          const SizedBox(width: 8),
                                          Expanded(child: Text(o.pickupAddress, style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft), overflow: TextOverflow.ellipsis)),
                                          const Icon(Icons.arrow_forward, size: 14, color: AppColors.faint),
                                          const SizedBox(width: 8),
                                          Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle)),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Text(o.dropoffAddress,
                                                textAlign: TextAlign.right,
                                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                                                overflow: TextOverflow.ellipsis),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 46,
                                      child: ElevatedButton(
                                        onPressed: () => Navigator.pushNamed(context, '/live', arguments: o.id),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.ink,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text('Track live · ETA ${_etaMinutes(o)} min',
                                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                            const SizedBox(width: 7),
                                            const Icon(Icons.navigation, size: 16),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
