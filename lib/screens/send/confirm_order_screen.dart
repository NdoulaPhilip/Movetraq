import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/send_flow_provider.dart';
import '../../widgets/app_page.dart';
import '../../widgets/primary_button.dart';

class ConfirmOrderScreen extends StatelessWidget {
  const ConfirmOrderScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final flow = context.watch<SendFlowProvider>();
    return AppPage(
        title: flow.isExpress
            ? 'Review your Express delivery'
            : 'Review your delivery',
        children: [
          const SectionTitle('Delivery details'),
          DetailRow('Parcel', flow.title.isEmpty ? 'Parcel' : flow.title),
          DetailRow('Pickup', flow.pickupAddress),
          DetailRow('Destination', flow.dropoffAddress),
          DetailRow(
              'Deliverer', flow.selectedDelivererName ?? 'To be assigned'),
          DetailRow('Service', flow.isExpress ? 'Express' : 'P2P delivery'),
          const SizedBox(height: 20),
          const InfoBand(
              title: 'Payment protection',
              body: 'Confirm your delivery details before payment.',
              icon: Icons.shield_outlined),
          DetailRow('Delivery estimate',
              'NGN ${flow.effectivePrice.toStringAsFixed(2)}'),
          DetailRow(
              'Service estimate', 'NGN ${flow.serviceFee.toStringAsFixed(2)}'),
          DetailRow(
              'Total estimate', 'NGN ${flow.totalPrice.toStringAsFixed(2)}'),
          const SizedBox(height: 24),
          PrimaryButton(
              label: 'Continue to payment',
              onPressed: () => Navigator.pushNamed(context, '/payment')),
        ]);
  }
}
