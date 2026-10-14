import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/parcel_order.dart';
import '../../providers/auth_provider.dart';
import '../../services/local_data_service.dart';
import '../../widgets/app_page.dart';
import '../../widgets/primary_button.dart';

class ReleaseScreen extends StatelessWidget {
  const ReleaseScreen({super.key, required this.orderId});
  final String orderId;
  @override
  Widget build(BuildContext context) => StreamBuilder<ParcelOrder?>(
      stream: context.read<LocalDataService>().watchOrder(orderId),
      builder: (context, snapshot) {
        final order = snapshot.data;
        final sender =
            context.watch<AuthProvider>().profile?.uid == order?.senderId;
        return AppPage(title: 'Release payment', children: [
          if (snapshot.hasError)
            LoadError(error: snapshot.error!)
          else if (order == null)
            const InfoBand(title: 'Order unavailable')
          else ...[
            InfoBand(
                title: 'NGN ${order.price.toStringAsFixed(2)}',
                body: order.code,
                dark: true,
                icon: Icons.shield_outlined),
            DetailRow('Parcel', order.title),
            DetailRow('Destination', order.dropoffAddress),
            DetailRow('Deliverer', order.delivererName ?? 'Not assigned'),
            if (order.deliveredAt != null)
              DetailRow('Delivered', order.deliveredAt!.toLocal().toString()),
            const SizedBox(height: 18),
            const InfoBand(
                title: 'Confirm your delivery',
                body:
                    'Review the parcel and handover evidence before authorizing payment release.'),
            RouteTile(
                title: 'View delivery evidence',
                icon: Icons.fact_check_outlined,
                route: '/delivery-evidence',
                arguments: orderId),
            const SizedBox(height: 24),
            PrimaryButton(
                label: 'Authorize payment release',
                onPressed: !sender || order.status != OrderStatus.delivered
                    ? null
                    : () => Navigator.pushNamed(context, '/release-otp',
                        arguments: orderId)),
            RouteTile(
                title: 'Report a problem',
                icon: Icons.support_agent,
                route: '/delivery-problem',
                arguments: orderId),
          ],
        ]);
      });
}
