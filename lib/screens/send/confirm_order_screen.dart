import 'express_review_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/send_flow_provider.dart';
import '../../widgets/app_page.dart';
import '../../widgets/design_ui.dart';
import '../../widgets/primary_button.dart';

class ConfirmOrderScreen extends StatelessWidget {
  const ConfirmOrderScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final flow = context.watch<SendFlowProvider>();
    if (!flow.isP2P) return const ExpressReviewScreen();
    return AppPage(
        title: 'Review your delivery',
        footer: PrimaryButton(
            label: 'Continue to payment · ${naira(flow.totalPrice)}',
            onPressed: () => Navigator.pushNamed(context, '/payment')),
        children: [
          const DesignSection('SELECTED DELIVERER'),
          DesignCard(
              child: Row(children: [
            DesignAvatar(flow.selectedDelivererName ?? 'Courier'),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(flow.selectedDelivererName ?? 'To be assigned',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 5),
                  Text(flow.isP2P ? 'P2P delivery' : 'Express delivery',
                      style: const TextStyle(fontSize: 11)),
                ])),
            TextButton(
                onPressed: () =>
                    Navigator.pushNamed(context, '/pick-deliverer'),
                child: const Text('Change selection')),
          ])),
          const DesignSection('DELIVERY ROUTE'),
          DesignCard(
              child: DesignRoute(
                  pickup: flow.pickupAddress,
                  destination: flow.dropoffAddress)),
          if (flow.recipientPhone.isNotEmpty) ...[
            const SizedBox(height: 13),
            DesignCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('Recipient phone number',
                      style: TextStyle(fontSize: 12, color: Color(0xFF98A1AF))),
                  const SizedBox(height: 7),
                  Text(flow.recipientPhone,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                ])),
          ],
          const DesignSection('PARCEL DETAILS'),
          DesignCard(
              child: Row(children: [
            ParcelIcon(flow.category),
            const SizedBox(width: 11),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                      flow.category == 'document' ? 'Documents' : flow.category,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 5),
                  Text(flow.title.isEmpty ? 'Parcel' : flow.title,
                      style: const TextStyle(fontSize: 11)),
                ])),
          ])),
          const SizedBox(height: 20),
          DesignCard(
              dark: true,
              child: Column(children: [
                DetailRow('Delivery fee', naira(flow.effectivePrice),
                    dark: true),
                if (flow.isP2P) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/negotiate'),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white),
                      icon: const Icon(Icons.chat_bubble_outline, size: 17),
                      label: const Text('Discuss delivery fee')),
                ],
                DetailRow('Service fee', naira(flow.serviceFee), dark: true),
                const Divider(color: Colors.white24, height: 24),
                DetailRow('Total payment', naira(flow.totalPrice), dark: true),
              ])),
        ]);
  }
}
