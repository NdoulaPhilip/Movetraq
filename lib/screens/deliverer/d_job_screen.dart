import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/app_user.dart';
import '../../models/parcel_order.dart';
import '../../providers/auth_provider.dart';
import '../../services/local_data_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_page.dart';
import '../../widgets/mini_map.dart';
import '../../widgets/design_ui.dart';
import '../../widgets/primary_button.dart';

class DJobScreen extends StatefulWidget {
  const DJobScreen({super.key, required this.orderId});
  final String orderId;
  @override
  State<DJobScreen> createState() => _DJobScreenState();
}

class _DJobScreenState extends State<DJobScreen> {
  bool _busy = false;
  late Stream<ParcelOrder?> _order;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() =>
      _order = context.read<LocalDataService>().watchOrder(widget.orderId);
  @override
  void didUpdateWidget(covariant DJobScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderId != widget.orderId) _load();
  }

  Future<void> _accept(ParcelOrder order) async {
    if (_busy) return;
    final profile = context.read<AuthProvider>().profile;
    if (profile == null) {
      showActionError(context, 'Sign in to accept a delivery.');
      return;
    }
    if (!await confirmAction(context, 'Accept this delivery?', order.title) ||
        !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      await context.read<LocalDataService>().acceptJob(order.id,
          delivererId: profile.uid, delivererName: profile.name);
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/delivery-pickup',
            arguments: order.id);
      }
    } catch (error) {
      if (mounted) showActionError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<ParcelOrder?>(
      key: ValueKey(widget.orderId),
      stream: _order,
      builder: (context, snapshot) {
        final order = snapshot.data;
        final profile = context.watch<AuthProvider>().profile;
        final allowed = order != null &&
            order.status == OrderStatus.pendingOffer &&
            profile?.activeRole == UserRole.deliverer &&
            profile?.uid != order.senderId;
        return AppPage(
            title: 'Delivery details',
            footer: order == null
                ? null
                : PrimaryButton(
                    label: 'Accept delivery · ${naira(order.payout)} →',
                    background: AppColors.accent,
                    foreground: AppColors.ink,
                    loading: _busy,
                    onPressed: !allowed || _busy ? null : () => _accept(order)),
            children: [
              if (snapshot.hasError)
                LoadError(error: snapshot.error!)
              else if (!snapshot.hasData &&
                  snapshot.connectionState == ConnectionState.waiting)
                const Center(child: CircularProgressIndicator())
              else if (order == null)
                const InfoBand(title: 'Delivery unavailable')
              else ...[
                PrimaryButton(
                    label: 'Chat or call customer',
                    onPressed: () => Navigator.pushNamed(
                        context, '/delivery-contact',
                        arguments: order.id)),
                const SizedBox(height: 14),
                MiniMap(
                    pickupLocation: order.pickupLocation,
                    dropoffLocation: order.dropoffLocation,
                    height: 140),
                const SizedBox(height: 16),
                DesignCard(
                    dark: true,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('YOUR EARNINGS',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.white54)),
                          const SizedBox(height: 12),
                          Text(naira(order.payout),
                              style: const TextStyle(
                                  fontSize: 34, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 12),
                          const Text('Delivery payout',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.white70)),
                        ])),
                const SizedBox(height: 13),
                DesignCard(
                    child: Column(children: [
                  Row(children: [
                    ParcelIcon(order.category),
                    const SizedBox(width: 11),
                    Expanded(
                        child: Text(order.title,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600)))
                  ]),
                  const SizedBox(height: 18),
                  DesignRoute(
                      pickup: order.pickupAddress,
                      destination: order.dropoffAddress),
                ])),
                const SizedBox(height: 13),
                DesignCard(
                    child: Row(children: [
                  DesignAvatar(order.senderName),
                  const SizedBox(width: 11),
                  Expanded(
                      child: Text(order.senderName,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)))
                ])),
                const SizedBox(height: 14),
                SecondaryButton(
                    label: 'Back to deliveries',
                    onPressed: () => Navigator.maybePop(context)),
              ],
            ]);
      });
}
