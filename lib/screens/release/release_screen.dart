import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/parcel_order.dart';
import '../../providers/auth_provider.dart';
import '../../services/local_data_service.dart';
import '../../widgets/app_page.dart';
import '../../widgets/design_ui.dart';
import '../../widgets/primary_button.dart';

class ReleaseScreen extends StatelessWidget {
  const ReleaseScreen({super.key, required this.orderId});
  final String orderId;
  @override
  Widget build(BuildContext context) => StreamBuilder<ParcelOrder?>(
      stream: context.read<LocalDataService>().watchOrder(orderId),
      builder: (context, snapshot) {
        final order = snapshot.data;
        final profile = context.watch<AuthProvider>().profile;
        final allowed = profile != null &&
            profile.uid == order?.senderId &&
            order?.status == OrderStatus.delivered;
        return AppPage(
            title: 'Release payment',
            subtitle:
                'Confirm your parcel was delivered. Releasing escrow pays your deliverer for the trip.',
            footer: order == null
                ? null
                : PrimaryButton(
                    label: 'Confirm & release ${naira(order.price)} →',
                    onPressed: !allowed
                        ? null
                        : () => Navigator.pushNamed(context, '/release-otp',
                            arguments: orderId)),
            children: [
              if (snapshot.hasError)
                LoadError(error: snapshot.error!)
              else if (!snapshot.hasData &&
                  snapshot.connectionState == ConnectionState.waiting)
                const Center(child: CircularProgressIndicator())
              else if (order == null)
                const InfoBand(title: 'Order unavailable')
              else ...[
                const InfoBand(
                    title: 'Escrow protected',
                    body: 'Funds released only when you confirm',
                    dark: true,
                    icon: Icons.shield_outlined),
                DesignCard(
                    child: Column(children: [
                  Row(children: [
                    const Expanded(
                        child: Text('Order details',
                            style: TextStyle(fontSize: 14))),
                    DesignBadge(order.status == OrderStatus.delivered
                        ? 'Delivered'
                        : order.status.name)
                  ]),
                  const SizedBox(height: 12),
                  DetailRow('Parcel', order.title),
                  DetailRow('Destination', order.dropoffAddress),
                  DetailRow('Order reference', order.code),
                  if (order.deliveredAt != null)
                    DetailRow(
                        'Delivered', order.deliveredAt!.toLocal().toString()),
                  const Divider(height: 24),
                  DetailRow('Amount to release', naira(order.price)),
                ])),
                const SectionTitle('Released from'),
                DesignNote(
                    title: 'MoveTraq Wallet',
                    body: profile == null
                        ? 'Sign in to view your balance'
                        : 'Balance ${naira(profile.walletBalance)}'),
                RouteTile(
                    title: 'View delivery evidence',
                    icon: Icons.fact_check_outlined,
                    route: '/delivery-evidence',
                    arguments: orderId),
                RouteTile(
                    title: 'Report a problem',
                    icon: Icons.support_agent,
                    route: '/delivery-problem',
                    arguments: orderId),
              ],
            ]);
      });
}
