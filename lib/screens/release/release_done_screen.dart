import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/parcel_order.dart';
import '../../services/local_data_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/primary_button.dart';

class ReleaseDoneScreen extends StatelessWidget {
  final String orderId;
  const ReleaseDoneScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    final data = context.read<LocalDataService>();

    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<ParcelOrder?>(
          stream: data.watchOrder(orderId),
          builder: (context, snap) {
            final order = snap.data;
            if (order == null) return const Center(child: CircularProgressIndicator());

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 110,
                    height: 110,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.25), shape: BoxShape.circle),
                        ),
                        Container(
                          width: 96,
                          height: 96,
                          decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                          child: const Icon(Icons.check, color: AppColors.ink, size: 46),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text('Payment released', style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700, fontSize: 24)),
                  const SizedBox(height: 10),
                  Text(
                    '₦${order.price.toStringAsFixed(0)} has been released from escrow to ${order.delivererName ?? "your courier"}. Thanks for confirming your delivery!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: AppColors.inkSoft, height: 1.5),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    constraints: const BoxConstraints(maxWidth: 300),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.borderSoft),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(radius: 21, backgroundColor: Color(0xFF3A4250), child: Icon(Icons.person, color: Colors.white, size: 18)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Paid to ${order.delivererName ?? "courier"}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              const SizedBox(height: 2),
                              Text('${order.code} · Escrow released', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: PrimaryButton(
                      label: 'Rate your deliverer',
                      onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false),
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false),
                    child: const Text('Back to home', style: TextStyle(color: AppColors.inkSoft, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
