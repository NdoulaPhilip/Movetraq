import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/parcel_order.dart';
import '../../providers/auth_provider.dart';
import '../../services/local_data_service.dart';
import '../../theme/app_theme.dart';

class DEarningsScreen extends StatelessWidget {
  const DEarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider>().profile;
    final data = context.read<LocalDataService>();
    if (profile == null) return const Center(child: CircularProgressIndicator());

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 108),
        children: [
          const Text('Earnings', style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700, fontSize: 26)),
          const SizedBox(height: 16),
          StreamBuilder<List<ParcelOrder>>(
            stream: data.watchDelivererOrders(profile.uid),
            builder: (context, snap) {
              final orders = snap.data ?? [];
              final released = orders.where((o) => o.status == OrderStatus.released).toList();
              final total = released.fold<double>(0, (sum, o) => sum + o.payout);
              final now = DateTime.now();
              final weekStart = now.subtract(Duration(days: now.weekday - 1));
              final thisWeek = released.where((o) => (o.releasedAt ?? o.createdAt).isAfter(weekStart));
              final weekTotal = thisWeek.fold<double>(0, (sum, o) => sum + o.payout);

              return Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(24)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('AVAILABLE TO CASH OUT', style: TextStyle(fontSize: 11.5, color: Color(0xFF8A93A2), fontWeight: FontWeight.w600, letterSpacing: 0.3)),
                        const SizedBox(height: 8),
                        Text('₦${total.toStringAsFixed(0)}',
                            style: const TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700, fontSize: 34, color: Colors.white)),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 44,
                          child: ElevatedButton(
                            onPressed: total <= 0
                                ? null
                                : () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Cash out of ₦${total.toStringAsFixed(0)} requested.',
                                        ),
                                      ),
                                    );
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: AppColors.ink,
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              alignment: Alignment.centerLeft,
                            ),
                            child: const Text('Cash out to bank', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.borderSoft)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('₦${weekTotal.toStringAsFixed(0)}',
                                  style: const TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700, fontSize: 20)),
                              const SizedBox(height: 3),
                              const Text('This week', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.borderSoft)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${thisWeek.length}',
                                  style: const TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700, fontSize: 20)),
                              const SizedBox(height: 3),
                              const Text('Trips this week', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Recent payouts', style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w600, fontSize: 16)),
                  ),
                  const SizedBox(height: 10),
                  if (released.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 20),
                      child: Text('No payouts yet', style: TextStyle(color: AppColors.muted)),
                    )
                  else
                    Column(
                      children: released.map((o) {
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.borderSoft))),
                          child: Row(
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(color: AppColors.tint['sand'], borderRadius: BorderRadius.circular(10)),
                                child: const Icon(Icons.check, size: 16, color: AppColors.successDeep),
                              ),
                              const SizedBox(width: 13),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(o.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                    Text('${o.code} · Escrow released', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                                  ],
                                ),
                              ),
                              Text('+₦${o.payout.toStringAsFixed(0)}',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: AppColors.successDeep)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
