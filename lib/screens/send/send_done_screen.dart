import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/send_flow_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/premium_ui.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/completion_layout.dart';

class SendDoneScreen extends StatelessWidget {
  const SendDoneScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final flow = context.watch<SendFlowProvider>();
    return Scaffold(
      body: SafeArea(
        child: CompletionLayout(
          children: [
            const _SuccessMark(),
            const SizedBox(height: 28),
            const Text("You're all set!",
                style: TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontWeight: FontWeight.w700,
                    fontSize: 27)),
            const SizedBox(height: 10),
            const Text(
              "We're matching you with a nearby courier. You'll get a notification once it's picked up.",
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14.5, color: AppColors.inkSoft, height: 1.5),
            ),
            const SizedBox(height: 24),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: PremiumSurface(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                          color: AppColors.tint['lime'],
                          borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.inventory_2_outlined,
                          color: AppColors.ink),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Order created',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14)),
                          Text(
                              flow.isP2P
                                  ? 'Sent to ${flow.selectedDelivererName ?? "your deliverer"}'
                                  : 'Finding you a courier',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.muted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 26),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: PrimaryButton(
                label: 'Track it live',
                onPressed: () {
                  final id = flow.createdOrderId;
                  Navigator.of(context)
                      .pushNamedAndRemoveUntil('/home', (r) => false);
                  if (id != null) {
                    Navigator.pushNamed(context, '/live', arguments: id);
                  }
                },
              ),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: TextButton(
                onPressed: () => Navigator.of(context)
                    .pushNamedAndRemoveUntil('/home', (r) => false),
                child: const Text('Back to home',
                    style: TextStyle(
                        color: AppColors.inkSoft, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessMark extends StatelessWidget {
  const _SuccessMark();
  @override
  Widget build(BuildContext context) => Container(
        width: 104,
        height: 104,
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.accent,
            border: Border.all(color: const Color(0xFFE6F8AA), width: 7)),
        child: const Icon(Icons.check, size: 44, color: Color(0xFF678326)),
      );
}
