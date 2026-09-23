import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/parcel_order.dart';
import '../../providers/auth_provider.dart';
import '../../services/local_data_service.dart';
import '../../theme/app_theme.dart';

class DHomeScreen extends StatelessWidget {
  const DHomeScreen({super.key});

  (IconData, Color) _categoryStyle(String category) {
    switch (category) {
      case 'document':
        return (Icons.description_outlined, AppColors.tint['sky']!);
      case 'food':
        return (Icons.shopping_bag_outlined, AppColors.tint['mint']!);
      case 'fragile':
        return (Icons.card_giftcard_outlined, AppColors.tint['peach']!);
      default:
        return (Icons.inventory_2_outlined, AppColors.tint['lime']!);
    }
  }

  String _categoryLabel(String category) {
    switch (category) {
      case 'document':
        return 'Documents';
      case 'food':
        return 'Food';
      case 'fragile':
        return 'Fragile';
      default:
        return 'Parcel';
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.profile;
    final data = context.read<LocalDataService>();
    if (profile == null) return const Center(child: CircularProgressIndicator());

    final online = profile.delivererOnline;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 108),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Deliverer mode', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                    Text('Find work', style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700, fontSize: 24)),
                  ],
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(100),
                onTap: auth.isBusy
                    ? null
                    : () async {
                        final ok = await auth.setDelivererOnline(!online);
                        if (!context.mounted || ok || auth.errorMessage == null) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(auth.errorMessage!)),
                        );
                      },
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                  decoration: BoxDecoration(
                    color: online ? AppColors.tint['mint'] : const Color(0xFFF3F2EC),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: online ? AppColors.accent.withValues(alpha: 0.5) : AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Text(online ? 'Online' : 'Offline', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: online ? const Color(0xFF5A7A10) : AppColors.muted)),
                      const SizedBox(width: 9),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 38,
                        height: 22,
                        decoration: BoxDecoration(color: online ? AppColors.accent : const Color(0xFFD4D8DE), borderRadius: BorderRadius.circular(100)),
                        child: AnimatedAlign(
                          duration: const Duration(milliseconds: 200),
                          alignment: online ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.all(2),
                            width: 18,
                            height: 18,
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(20)),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TODAY', style: TextStyle(fontSize: 11.5, color: Color(0xFF8A93A2), fontWeight: FontWeight.w600)),
                      SizedBox(height: 4),
                      Text('₦18,500', style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700, fontSize: 24, color: Colors.white)),
                      SizedBox(height: 2),
                      Text('6 trips', style: TextStyle(fontSize: 11.5, color: Color(0xFF8A93A2))),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(20)),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ACCEPTANCE', style: TextStyle(fontSize: 11.5, color: Color(0xFF4A5215), fontWeight: FontWeight.w600)),
                      SizedBox(height: 4),
                      Text('96%', style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700, fontSize: 24, color: AppColors.ink)),
                      SizedBox(height: 2),
                      Text('Keep it up', style: TextStyle(fontSize: 11.5, color: Color(0xFF4A5215))),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          StreamBuilder<List<ParcelOrder>>(
            stream: data.watchOpenJobs(),
            builder: (context, snap) {
              final jobs = snap.data ?? [];
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Open jobs near you', style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w600, fontSize: 19)),
                  Text('${jobs.length} available', style: const TextStyle(fontSize: 12.5, color: AppColors.muted, fontWeight: FontWeight.w600)),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          if (!online)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.borderSoft)),
              child: const Text("You're offline. Go online to see and accept jobs near you.", style: TextStyle(color: AppColors.muted, fontSize: 13.5)),
            )
          else
            StreamBuilder<List<ParcelOrder>>(
              stream: data.watchOpenJobs(),
              builder: (context, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final jobs = snap.data!;
                if (jobs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('No jobs nearby right now', style: TextStyle(color: AppColors.muted))),
                  );
                }
                return Column(
                  children: jobs.map((j) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: () => Navigator.pushNamed(context, '/d-job', arguments: j.id),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.borderSoft)),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(color: _categoryStyle(j.category).$2, borderRadius: BorderRadius.circular(14)),
                                    child: Icon(_categoryStyle(j.category).$1, color: AppColors.ink),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('${j.title} · ${_categoryLabel(j.category)}',
                                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                                        const SizedBox(height: 2),
                                        Text('${j.senderName} · 2.4 km', style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('₦${j.payout.toStringAsFixed(0)}', style: const TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700, fontSize: 18)),
                                      const Text('escrow funded', style: TextStyle(fontSize: 11, color: Color(0xFF5A7A10), fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Icon(Icons.circle, size: 8, color: AppColors.faint),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(j.pickupAddress, style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft), overflow: TextOverflow.ellipsis)),
                                  const Icon(Icons.arrow_forward, size: 14, color: AppColors.faint),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.circle, size: 8, color: AppColors.accent),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(j.dropoffAddress,
                                        textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                                  ),
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
