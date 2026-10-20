import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/parcel_order.dart';
import '../../services/local_data_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/premium_ui.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/completion_layout.dart';
import '../../widgets/app_page.dart';
import '../../widgets/design_ui.dart';

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
            if (order == null) {
              if (snap.hasError) {
                return AppPage(
                    title: 'Payment release',
                    children: [LoadError(error: snap.error!)]);
              }
              if (snap.connectionState == ConnectionState.done) {
                return const AppPage(
                    title: 'Payment release',
                    children: [InfoBand(title: 'Order unavailable')]);
              }
              return const Center(child: CircularProgressIndicator());
            }
            if (order.status != OrderStatus.released) {
              return const AppPage(title: 'Payment release', children: [
                InfoBand(
                    title: 'Payment is not released',
                    body:
                        'A confirmed server release is required before a receipt is available.')
              ]);
            }

            return CompletionLayout(
              children: [
                Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accent,
                        border: Border.all(
                            color: const Color(0xFFE6F8AA), width: 7)),
                    child: const Icon(Icons.check,
                        size: 44, color: Color(0xFF678326))),
                const SizedBox(height: 28),
                const Text('Payment released successfully',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontWeight: FontWeight.w700,
                        fontSize: 24)),
                const SizedBox(height: 10),
                Text(
                  '${naira(order.price)} has been released from escrow to ${order.delivererName ?? "your courier"}. Thanks for confirming your delivery!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 14, color: AppColors.inkSoft, height: 1.5),
                ),
                const SizedBox(height: 22),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 266),
                  child: PremiumSurface(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        const CircleAvatar(
                            radius: 21, child: Icon(Icons.person_outline)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  'Paid to ${order.delivererName ?? "courier"}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14)),
                              const SizedBox(height: 2),
                              Text('${order.code} · Escrow released',
                                  style: const TextStyle(
                                      fontSize: 12, color: AppColors.muted)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: PrimaryButton(
                    label: 'Rate your deliverer',
                    onPressed: () => Navigator.pushNamed(
                        context, '/rate-delivery',
                        arguments: orderId),
                  ),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () => Navigator.of(context)
                      .pushNamedAndRemoveUntil('/home', (r) => false),
                  child: const Text('Back to home',
                      style: TextStyle(
                          color: AppColors.inkSoft,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
