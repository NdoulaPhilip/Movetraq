import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/parcel_order.dart';
import '../../services/local_data_service.dart';
import '../../widgets/app_page.dart';
import '../../widgets/design_ui.dart';
import '../../widgets/movetraq_brand.dart';
import '../../widgets/primary_button.dart';
import '../../theme/app_theme.dart';

class DeliveryCompletionScreen extends StatelessWidget {
  const DeliveryCompletionScreen({super.key, required this.orderId});
  final String orderId;
  @override
  Widget build(BuildContext context) => StreamBuilder<ParcelOrder?>(
      stream: context.read<LocalDataService>().watchOrder(orderId),
      builder: (context, snapshot) {
        final order = snapshot.data;
        final finished = order != null &&
            [OrderStatus.delivered, OrderStatus.released]
                .contains(order.status);
        return AppPage(
            title: finished ? 'Delivery completed' : 'Delivery status',
            children: [
              if (snapshot.hasError)
                LoadError(error: snapshot.error!)
              else if (snapshot.connectionState == ConnectionState.waiting &&
                  order == null)
                const Center(child: CircularProgressIndicator())
              else if (!finished)
                const DesignNote(
                    title: 'Delivery not completed',
                    body: 'Open your delivery to follow its current status.')
              else ...[
                const SizedBox(height: 28),
                Center(
                    child: Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(28)),
                        child: const Icon(Icons.check, size: 30))),
                const SizedBox(height: 28),
                const Text(
                    'Your delivery is complete and the item has arrived.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13, height: 1.7, color: AppColors.muted)),
                const SizedBox(height: 24),
                PrimaryButton(
                    label: 'Continue',
                    onPressed: () => Navigator.pushNamed(
                        context, '/order-detail',
                        arguments: order.id)),
                const SizedBox(height: 34),
                const Center(child: MoveTraqMark(size: 42)),
              ],
            ]);
      });
}
