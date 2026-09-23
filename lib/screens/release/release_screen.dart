import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/parcel_order.dart';
import '../../providers/auth_provider.dart';
import '../../services/local_data_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/mini_map.dart';
import '../../widgets/primary_button.dart';

class ReleaseScreen extends StatelessWidget {
  final String orderId;
  const ReleaseScreen({super.key, required this.orderId});

  String _fmtTime(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ap = d.hour >= 12 ? 'PM' : 'AM';
    return '$h:${d.minute.toString().padLeft(2, '0')} $ap';
  }

  @override
  Widget build(BuildContext context) {
    final data = context.read<LocalDataService>();
    final profile = context.watch<AuthProvider>().profile;

    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<ParcelOrder?>(
          stream: data.watchOrder(orderId),
          builder: (context, snap) {
            final order = snap.data;
            if (order == null || profile == null) return const Center(child: CircularProgressIndicator());

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                CircleIconButton(icon: Icons.arrow_back, onTap: () => Navigator.maybePop(context)),
                const SizedBox(height: 18),
                const Text('Release payment', style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700, fontSize: 24)),
                const SizedBox(height: 8),
                Text(
                  'Confirm your parcel was delivered. Your payment has been held safely in escrow — releasing it pays ${order.delivererName ?? "your courier"} for the trip.',
                  style: const TextStyle(fontSize: 13.5, color: AppColors.inkSoft, height: 1.5),
                ),
                const SizedBox(height: 18),
                // Escrow protected banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(color: AppColors.tint['mint'], borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.shield_outlined, size: 17, color: AppColors.ink),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Escrow protected', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13.5)),
                            SizedBox(height: 2),
                            Text('Funds released only when you confirm', style: TextStyle(color: Color(0xFFC9CDD4), fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Order details card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.borderSoft),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Order details', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                            decoration: BoxDecoration(color: AppColors.tint['mint'], borderRadius: BorderRadius.circular(100)),
                            child: const Text('Delivered', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF0F9D58))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _kv('Parcel', order.title),
                      _kv('Destination', order.dropoffAddress),
                      _kv('Transaction ID', '${order.code}-77G'),
                      _kv('Delivered', _fmtTime(order.deliveredAt ?? DateTime.now())),
                      const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1, color: AppColors.borderSoft)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Amount to release', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                          Text('₦${order.price.toStringAsFixed(0)}',
                              style: const TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700, fontSize: 18)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const Text('Released from', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: AppColors.inkSoft)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.borderSoft),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(color: AppColors.tint['lime'], borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.account_balance_wallet_outlined, size: 19, color: AppColors.ink),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('MoveTraq Wallet', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                            Text('Balance ₦${profile.walletBalance.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                          ],
                        ),
                      ),
                      Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                        child: const Icon(Icons.check, size: 14, color: AppColors.ink),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                PrimaryButton(
                  label: 'Confirm & release ₦${order.price.toStringAsFixed(0)}',
                  trailingIcon: Icons.arrow_forward,
                  onPressed: () => Navigator.pushNamed(context, '/release-otp', arguments: order.id),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          Flexible(child: Text(v, textAlign: TextAlign.end, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
