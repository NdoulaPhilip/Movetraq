import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/app_user.dart';
import '../../models/parcel_order.dart';
import '../../providers/auth_provider.dart';
import '../../services/local_data_service.dart';
import '../../widgets/app_page.dart';
import '../../widgets/mini_map.dart';
import '../../widgets/primary_button.dart';

class DJobScreen extends StatefulWidget {
  const DJobScreen({super.key, required this.orderId});
  final String orderId;
  @override
  State<DJobScreen> createState() => _DJobScreenState();
}

class _DJobScreenState extends State<DJobScreen> {
  bool _busy = false;
  @override
  Widget build(BuildContext context) => StreamBuilder<ParcelOrder?>(
      stream: context.read<LocalDataService>().watchOrder(widget.orderId),
      builder: (context, snapshot) {
        final order = snapshot.data;
        return AppPage(title: 'Delivery details', children: [
          if (snapshot.hasError)
            LoadError(error: snapshot.error!)
          else if (!snapshot.hasData &&
              snapshot.connectionState == ConnectionState.waiting)
            const Center(child: CircularProgressIndicator())
          else if (order == null)
            const InfoBand(title: 'Delivery unavailable')
          else ...[
            MiniMap(
                pickupLocation: order.pickupLocation,
                dropoffLocation: order.dropoffLocation,
                height: 230),
            const SizedBox(height: 18),
            InfoBand(
                title: 'NGN ${order.payout.toStringAsFixed(2)}',
                body: 'Delivery payout',
                dark: true,
                icon: Icons.payments_outlined),
            DetailRow('Reference', order.code),
            DetailRow('Parcel', order.title),
            DetailRow('Pickup', order.pickupAddress),
            DetailRow('Destination', order.dropoffAddress),
            DetailRow('Sender', order.senderName),
            const SizedBox(height: 24),
            PrimaryButton(
                label: 'Accept delivery',
                loading: _busy,
                onPressed: _busy ||
                        order.status != OrderStatus.pendingOffer ||
                        context.watch<AuthProvider>().profile?.activeRole !=
                            UserRole.deliverer ||
                        context.watch<AuthProvider>().profile?.uid ==
                            order.senderId
                    ? null
                    : () async {
                        if (_busy) return;
                        final profile = context.read<AuthProvider>().profile;
                        if (profile == null) {
                          showActionError(
                              context, 'Sign in to accept a delivery.');
                          return;
                        }
                        if (!await confirmAction(context,
                                'Accept this delivery?', order.title) ||
                            !context.mounted) {
                          return;
                        }
                        setState(() => _busy = true);
                        try {
                          await context.read<LocalDataService>().acceptJob(
                              order.id,
                              delivererId: profile.uid,
                              delivererName: profile.name);
                          if (context.mounted) {
                            Navigator.pushReplacementNamed(
                                context, '/delivery-pickup',
                                arguments: order.id);
                          }
                        } catch (error) {
                          if (context.mounted) showActionError(context, error);
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      }),
            const SizedBox(height: 12),
            SecondaryButton(
                label: 'Back to deliveries',
                onPressed: () => Navigator.maybePop(context)),
          ],
        ]);
      });
}
