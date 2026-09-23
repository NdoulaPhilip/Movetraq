import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/send_flow_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/mini_map.dart';
import '../../widgets/primary_button.dart';

class ConfirmOrderScreen extends StatelessWidget {
  const ConfirmOrderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final flow = context.watch<SendFlowProvider>();
    final auth = context.watch<AuthProvider>();
    final total = (flow.proposal ?? flow.basePrice) + 500;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ScreenHeader(title: 'Confirm'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.borderSoft)),
                child: Column(
                  children: [
                    _Row('Parcel', flow.title.isEmpty ? 'Parcel' : flow.title),
                    _Row('Pickup', flow.pickupAddress.isEmpty ? 'Current location' : flow.pickupAddress),
                    _Row('Drop-off', flow.dropoffAddress.isEmpty ? 'Lekki Phase 1' : flow.dropoffAddress),
                    _Row('Deliverer', flow.selectedDelivererName ?? 'Instant match'),
                    _Row('Speed', flow.isExpress ? 'Express' : 'Standard'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(20)),
                child: Column(
                  children: [
                    _DarkRow('Delivery fee', '₦${(flow.proposal ?? flow.basePrice).toStringAsFixed(0)}'),
                    _DarkRow('Service fee', '₦500'),
                    const Divider(color: Color(0xFF2A2D34), height: 24),
                    _DarkRow('Total', '₦${total.toStringAsFixed(0)}', bold: true),
                  ],
                ),
              ),
              const Spacer(),
              PrimaryButton(
                label: 'Confirm & pay ₦${total.toStringAsFixed(0)}',
                trailingIcon: Icons.arrow_forward,
                onPressed: () async {
                  if (auth.profile == null) return;
                  await flow.submitOrder(auth.profile!);
                  if (context.mounted) Navigator.pushNamed(context, '/send-done');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String k;
  final String v;
  const _Row(this.k, this.v);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
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

class _DarkRow extends StatelessWidget {
  final String k;
  final String v;
  final bool bold;
  const _DarkRow(this.k, this.v, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: TextStyle(fontSize: bold ? 15 : 13, color: bold ? Colors.white : const Color(0xFF8A93A2), fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
          Text(v, style: TextStyle(fontSize: bold ? 18 : 13.5, color: Colors.white, fontWeight: bold ? FontWeight.w700 : FontWeight.w600, fontFamily: bold ? 'SpaceGrotesk' : null)),
        ],
      ),
    );
  }
}
