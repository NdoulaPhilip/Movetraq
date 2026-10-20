import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/parcel_order.dart';
import '../../providers/auth_provider.dart';
import '../../services/local_data_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_page.dart';
import '../../widgets/design_ui.dart';
import '../../widgets/primary_button.dart';

class ConfirmReceiptScreen extends StatelessWidget {
  const ConfirmReceiptScreen({super.key, required this.orderId});
  final String orderId;
  @override
  Widget build(BuildContext context) => StreamBuilder<ParcelOrder?>(
      stream: context.read<LocalDataService>().watchOrder(orderId),
      builder: (context, snapshot) {
        final order = snapshot.data;
        final sender = order != null &&
            context.watch<AuthProvider>().profile?.uid == order.senderId;
        return AppPage(title: 'Confirm delivery', children: [
          if (snapshot.hasError)
            LoadError(error: snapshot.error!)
          else if (order == null &&
              snapshot.connectionState == ConnectionState.waiting)
            const Center(child: CircularProgressIndicator())
          else if (order == null || !sender)
            const DesignNote(
                title: 'Delivery unavailable',
                body: 'Open one of your orders to confirm receipt.')
          else ...[
            Center(
                child: Container(
                    width: 104,
                    height: 104,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFC4DB98)),
                        borderRadius: BorderRadius.circular(44)),
                    child: Container(
                        decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(27)),
                        child:
                            const Icon(Icons.inventory_2_outlined, size: 28)))),
            const SizedBox(height: 24),
            const Text('Has your item arrived?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            const Text(
                'Check that you have received the item before releasing payment.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12, height: 1.7, color: AppColors.muted)),
            const SizedBox(height: 30),
            DesignCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(order.code, style: const TextStyle(fontSize: 11)),
                  const SizedBox(height: 16),
                  Text(order.title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  Text('${order.pickupAddress} to ${order.dropoffAddress}',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.muted)),
                  const SizedBox(height: 16),
                  DesignCard(
                      dark: true,
                      child: Row(children: [
                        const Expanded(
                            child: Text('Amount to release',
                                style: TextStyle(
                                    fontSize: 10, color: Colors.white60))),
                        Flexible(
                            child: Text(naira(order.price),
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                    fontSize: 23,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.accent))),
                      ])),
                ])),
            const SizedBox(height: 18),
            const InfoBand(
                title: 'Confirm your delivery',
                body:
                    'This releases the payment already held for this order. You will not be charged again.'),
            PrimaryButton(
                label: 'Confirm delivery & release payment',
                onPressed: order.status != OrderStatus.delivered
                    ? null
                    : () => Navigator.pushNamed(context, '/release',
                        arguments: order.id)),
            const SizedBox(height: 12),
            SecondaryButton(
                label: 'Not received yet',
                onPressed: () => Navigator.pushNamed(
                    context, '/delivery-problem',
                    arguments: order.id)),
            const SizedBox(height: 12),
            SecondaryButton(
                label: 'Back to activity',
                onPressed: () => Navigator.pushNamed(context, '/activity')),
          ],
        ]);
      });
}
