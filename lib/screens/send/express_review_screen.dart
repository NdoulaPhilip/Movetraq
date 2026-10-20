import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/send_flow_provider.dart';
import '../../widgets/app_page.dart';
import '../../widgets/design_ui.dart';
import '../../widgets/primary_button.dart';

class ExpressReviewScreen extends StatelessWidget {
  const ExpressReviewScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final flow = context.watch<SendFlowProvider>();
    if (flow.isP2P) {
      return AppPage(title: 'Review your delivery', children: [
        const DesignNote(
            title: 'Choose Express delivery',
            body: 'Select Express to review its delivery fee and total.'),
        PrimaryButton(
            label: 'Choose Express', onPressed: () => flow.setMode(p2p: false)),
      ]);
    }
    return AppPage(
        title: 'Review your Express delivery',
        subtitle:
            'Check the addresses, recipient details and total before paying.',
        children: [
          DesignCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const DesignBadge('EXPRESS DELIVERY'),
                const SizedBox(height: 16),
                const Text('Your route',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                DetailRow(
                    'Pickup',
                    flow.pickupAddress.isEmpty
                        ? 'Choose a pickup'
                        : flow.pickupAddress),
                DetailRow(
                    'Destination',
                    flow.dropoffAddress.isEmpty
                        ? 'Choose a destination'
                        : flow.dropoffAddress),
                DetailRow(
                    'Recipient',
                    flow.recipientPhone.isEmpty
                        ? 'Add recipient phone'
                        : flow.recipientPhone),
              ])),
          const SizedBox(height: 14),
          DesignCard(
              child: Column(children: [
            DetailRow('Parcel', flow.category),
            DetailRow('Details',
                flow.title.isEmpty ? 'Add parcel details' : flow.title),
            const DetailRow('Pickup schedule', 'Soonest available'),
          ])),
          const SizedBox(height: 14),
          DesignCard(
              child: Column(children: [
            DetailRow('Delivery fee', naira(flow.effectivePrice)),
            DetailRow('Service fee', naira(flow.serviceFee)),
            const Divider(height: 24),
            DetailRow('Total to pay', naira(flow.totalPrice)),
          ])),
          const SizedBox(height: 24),
          PrimaryButton(
              label: 'Continue to payment',
              onPressed: flow.pickupAddress.isEmpty ||
                      flow.dropoffAddress.isEmpty ||
                      flow.title.isEmpty ||
                      flow.recipientPhone.isEmpty
                  ? null
                  : () => Navigator.pushNamed(context, '/payment')),
          const SizedBox(height: 12),
          SecondaryButton(
              label: 'Edit delivery details',
              onPressed: () => Navigator.pushNamed(context, '/send')),
        ]);
  }
}
