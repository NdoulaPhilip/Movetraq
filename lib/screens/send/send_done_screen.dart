import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/send_flow_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/primary_button.dart';

class SendDoneScreen extends StatelessWidget {
  const SendDoneScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final flow = context.watch<SendFlowProvider>();
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                child: const Icon(Icons.check, color: AppColors.ink, size: 46),
              ),
              const SizedBox(height: 28),
              const Text("You're all set!", style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700, fontSize: 27)),
              const SizedBox(height: 10),
              const Text(
                "We're matching you with a nearby courier. You'll get a notification once it's picked up.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14.5, color: AppColors.inkSoft, height: 1.5),
              ),
              const SizedBox(height: 24),
              Container(
                constraints: const BoxConstraints(maxWidth: 300),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.borderSoft)),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(color: AppColors.tint['lime'], borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.inventory_2_outlined, color: AppColors.ink),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Order created', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          Text(flow.isP2P ? 'Sent to ${flow.selectedDelivererName ?? "your deliverer"}' : 'Finding you a courier',
                              style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: PrimaryButton(
                  label: 'Track it live',
                  onPressed: () {
                    final id = flow.createdOrderId;
                    Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false);
                    if (id != null) Navigator.pushNamed(context, '/live', arguments: id);
                  },
                ),
              ),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: TextButton(
                  onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false),
                  child: const Text('Back to home', style: TextStyle(color: AppColors.inkSoft, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
