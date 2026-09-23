import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/parcel_order.dart';
import '../../providers/auth_provider.dart';
import '../../services/local_data_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/mini_map.dart';
import '../../widgets/primary_button.dart';

class DJobScreen extends StatelessWidget {
  final String orderId;
  const DJobScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    final data = context.read<LocalDataService>();
    final auth = context.read<AuthProvider>();

    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<ParcelOrder?>(
          stream: data.watchOrder(orderId),
          builder: (context, snap) {
            final order = snap.data;
            if (order == null) return const Center(child: CircularProgressIndicator());

            return Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                  children: [
                    const ScreenHeader(title: 'Job details'),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: const MiniMap(height: 150),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(22)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("YOU'LL EARN", style: TextStyle(fontSize: 12, color: Color(0xFF8A93A2), fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text('₦${order.payout.toStringAsFixed(0)}', style: const TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700, fontSize: 38, color: Colors.white)),
                          const SizedBox(height: 10),
                          Row(children: [
                            const Icon(Icons.shield_outlined, size: 16, color: AppColors.accent),
                            const SizedBox(width: 7),
                            const Expanded(
                              child: Text('Payment secured in escrow — released on delivery', style: TextStyle(fontSize: 12.5, color: Color(0xFFC9CDD4))),
                            ),
                          ]),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.borderSoft)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(color: AppColors.tint['peach'], borderRadius: BorderRadius.circular(14)),
                                child: const Icon(Icons.card_giftcard_outlined, color: AppColors.ink),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(order.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                                    const Text('Handle with care', style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                children: [
                                  Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.ink, width: 3))),
                                  Container(width: 2, height: 30, color: AppColors.border),
                                  Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle)),
                                ],
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('PICKUP', style: TextStyle(fontSize: 11.5, color: AppColors.muted, fontWeight: FontWeight.w600)),
                                    Text(order.pickupAddress, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                    const SizedBox(height: 16),
                                    const Text('DROP-OFF', style: TextStyle(fontSize: 11.5, color: AppColors.muted, fontWeight: FontWeight.w600)),
                                    Text(order.dropoffAddress, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.borderSoft)),
                      child: Row(
                        children: [
                          CircleAvatar(radius: 23, backgroundColor: AppColors.accent, child: Text(order.senderName.isNotEmpty ? order.senderName[0] : '?', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink))),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${order.senderName} · Sender', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                                const Row(children: [
                                  Icon(Icons.star, size: 13, color: AppColors.warning),
                                  SizedBox(width: 5),
                                  Text('4.9 · 128 orders', style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft)),
                                ]),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                            decoration: BoxDecoration(color: AppColors.tint['mint'], borderRadius: BorderRadius.circular(100)),
                            child: const Text('2.4 km', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF5A7A10))),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 20,
                  child: PrimaryButton(
                    label: 'Accept job · ₦${order.payout.toStringAsFixed(0)}',
                    background: AppColors.accent,
                    foreground: AppColors.ink,
                    trailingIcon: Icons.arrow_forward,
                    onPressed: () async {
                      if (auth.profile == null) return;
                      await data.acceptJob(order.id, delivererId: auth.profile!.uid, delivererName: auth.profile!.name);
                      if (context.mounted) Navigator.pushReplacementNamed(context, '/d-active', arguments: order.id);
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
