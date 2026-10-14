import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../models/parcel_order.dart';
import '../../providers/auth_provider.dart';
import '../../services/call_service.dart';
import '../../services/feature_gateway.dart';
import '../../services/local_data_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_page.dart';
import '../../widgets/mini_map.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/delivery_progress.dart';

String orderStatusLabel(OrderStatus status) => switch (status) {
      OrderStatus.pendingOffer => 'Awaiting deliverer',
      OrderStatus.negotiating => 'Negotiating',
      OrderStatus.accepted => 'Picking up',
      OrderStatus.pickedUp => 'In transit',
      OrderStatus.delivered => 'Awaiting confirmation',
      OrderStatus.released => 'Completed',
      OrderStatus.cancelled => 'Cancelled',
    };

class OrderToolsScreen extends StatelessWidget {
  const OrderToolsScreen(
      {super.key,
      required this.orderId,
      this.receipt = false,
      this.completed = false});
  final String orderId;
  final bool receipt;
  final bool completed;
  @override
  Widget build(BuildContext context) => StreamBuilder<ParcelOrder?>(
        stream: context.read<LocalDataService>().watchOrder(orderId),
        builder: (context, snapshot) {
          final order = snapshot.data;
          final uid = context.watch<AuthProvider>().profile?.uid;
          final sender = uid != null && order?.senderId == uid;
          final driver = uid != null && order?.delivererId == uid;
          return AppPage(
              title: completed
                  ? 'Delivery summary'
                  : receipt
                      ? 'Order receipt'
                      : 'Delivery details',
              children: [
                if (snapshot.hasError)
                  LoadError(error: snapshot.error!)
                else if (snapshot.connectionState == ConnectionState.waiting &&
                    order == null)
                  const Center(child: CircularProgressIndicator())
                else if (order == null)
                  const InfoBand(
                      title: 'Order unavailable',
                      body: 'Open a delivery from your orders to continue.',
                      icon: Icons.info_outline)
                else ...[
                  if (driver) DeliveryProgress(status: order.status),
                  InfoBand(
                      title: order.title,
                      body: '${order.code} / ${orderStatusLabel(order.status)}',
                      dark: true,
                      icon: Icons.inventory_2_outlined),
                  MiniMap(
                      pickupLocation: order.pickupLocation,
                      dropoffLocation: order.dropoffLocation,
                      height: 170),
                  const SizedBox(height: 18),
                  const SectionTitle('Delivery route'),
                  DetailRow('Pickup', order.pickupAddress),
                  DetailRow('Destination', order.dropoffAddress),
                  DetailRow('Customer', order.senderName),
                  DetailRow('Deliverer', order.delivererName ?? 'Not assigned'),
                  DetailRow('Service', order.isExpress ? 'Express' : 'P2P'),
                  DetailRow('Created', order.createdAt.toLocal().toString()),
                  if (order.deliveredAt != null)
                    DetailRow(
                        'Delivered', order.deliveredAt!.toLocal().toString()),
                  if (order.releasedAt != null)
                    DetailRow(
                        'Completed', order.releasedAt!.toLocal().toString()),
                  const SectionTitle('Payment'),
                  DetailRow(
                      'Order total', 'NGN ${order.price.toStringAsFixed(2)}'),
                  DetailRow(
                      'Payment status',
                      order.status == OrderStatus.released
                          ? 'Released'
                          : order.status == OrderStatus.cancelled
                              ? 'Cancelled'
                              : 'Not released'),
                  if (driver)
                    DetailRow('Deliverer payout',
                        'NGN ${order.payout.toStringAsFixed(2)}'),
                  const SizedBox(height: 20),
                  if (driver &&
                      [OrderStatus.accepted, OrderStatus.pickedUp]
                          .contains(order.status)) ...[
                    PrimaryButton(
                        label: 'Continue delivery',
                        onPressed: () => Navigator.pushNamed(
                            context,
                            order.status == OrderStatus.accepted
                                ? '/delivery-pickup'
                                : '/delivery-dropoff',
                            arguments: order.id)),
                    const SizedBox(height: 12),
                  ],
                  if (driver && order.status == OrderStatus.delivered)
                    const InfoBand(
                        title: 'Awaiting sender confirmation',
                        body:
                            'Payment stays held until the sender confirms delivery.'),
                  PrimaryButton(
                      label: 'Track order',
                      onPressed: () => Navigator.pushNamed(context, '/live',
                          arguments: orderId)),
                  const SizedBox(height: 12),
                  SecondaryButton(
                      label: 'Share delivery',
                      onPressed: () => Navigator.pushNamed(
                          context, '/share-order',
                          arguments: orderId)),
                  const RouteTile(
                      title: 'Transaction records',
                      icon: Icons.receipt_long_outlined,
                      route: '/transactions'),
                  RouteTile(
                      title: 'Delivery evidence',
                      icon: Icons.fact_check_outlined,
                      route: '/delivery-evidence',
                      arguments: orderId),
                  RouteTile(
                      title: 'Report a delivery problem',
                      icon: Icons.support_agent,
                      route: '/delivery-problem',
                      arguments: orderId),
                  if (driver)
                    RouteTile(
                        title: 'Request a payout review',
                        icon: Icons.account_balance_wallet_outlined,
                        route: '/payout-review',
                        arguments: orderId),
                  RouteTile(
                      title: 'Block or report',
                      icon: Icons.shield_outlined,
                      route: '/safety-reporting',
                      arguments: orderId),
                  RouteTile(
                      title: 'Request a return',
                      icon: Icons.assignment_return_outlined,
                      route: '/return-request',
                      arguments: orderId),
                  RouteTile(
                      title: driver ? 'Contact customer' : 'Contact deliverer',
                      icon: Icons.person_outline,
                      route: '/delivery-contact',
                      arguments: orderId),
                  if (sender && order.status == OrderStatus.delivered)
                    PrimaryButton(
                        label: 'Confirm delivery & release payment',
                        onPressed: () => Navigator.pushNamed(
                            context, '/release',
                            arguments: orderId)),
                  if (sender && order.status == OrderStatus.released)
                    PrimaryButton(
                        label: 'Rate your delivery',
                        onPressed: () => Navigator.pushNamed(
                            context, '/rate-delivery',
                            arguments: orderId)),
                ],
              ]);
        },
      );
}

class ContactScreen extends StatefulWidget {
  const ContactScreen(
      {super.key,
      required this.orderId,
      this.call = false,
      this.profile = false});
  final String orderId;
  final bool call;
  final bool profile;
  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  late Future<AppUser> _contact;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _contact = context.read<LocalDataService>().orderContact(widget.orderId);
  }

  @override
  Widget build(BuildContext context) => AppPage(
        title: widget.call
            ? 'Call customer'
            : widget.profile
                ? 'Deliverer profile'
                : 'Delivery contact',
        children: [
          FutureBuilder<AppUser>(
              future: _contact,
              builder: (context, snapshot) {
                if (snapshot.hasError) return LoadError(error: snapshot.error!);
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final user = snapshot.data!;
                return Column(children: [
                  CircleAvatar(
                      radius: 38,
                      backgroundColor: AppColors.accent,
                      child: Text(user.initials,
                          style: const TextStyle(fontSize: 22))),
                  const SizedBox(height: 18),
                  Text(user.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 20)),
                  const SizedBox(height: 12),
                  if (widget.profile) ...[
                    DetailRow('Rating', user.rating.toStringAsFixed(1)),
                    DetailRow(
                        'Completed deliveries', '${user.totalDeliveries}'),
                    DetailRow('Verification',
                        user.verified ? 'Verified' : 'Not verified'),
                    DetailRow('Transport', user.vehicleType),
                  ],
                  const SizedBox(height: 20),
                  PrimaryButton(
                      label: 'Message',
                      onPressed: () => Navigator.pushNamed(context, '/chat',
                          arguments: widget.orderId)),
                  const SizedBox(height: 12),
                  SecondaryButton(
                      label: 'Call by phone',
                      onPressed: _busy || user.phone.isEmpty
                          ? null
                          : () async {
                              setState(() => _busy = true);
                              try {
                                await const CallService().dial(user.phone);
                              } catch (error) {
                                if (context.mounted) {
                                  showActionError(context, error);
                                }
                              } finally {
                                if (mounted) setState(() => _busy = false);
                              }
                            }),
                  const SizedBox(height: 18),
                  const InfoBand(
                      title: 'In-app voice calls unavailable',
                      body: 'A voice provider has not been configured.',
                      icon: Icons.phone_disabled_outlined),
                  RouteTile(
                      title: 'Block or report',
                      icon: Icons.shield_outlined,
                      route: '/safety-reporting',
                      arguments: widget.orderId),
                ]);
              })
        ],
      );
}

class ShareOrderScreen extends StatelessWidget {
  const ShareOrderScreen({super.key, required this.orderId});
  final String orderId;
  @override
  Widget build(BuildContext context) => StreamBuilder<ParcelOrder?>(
      stream: context.read<LocalDataService>().watchOrder(orderId),
      builder: (context, snapshot) {
        final order = snapshot.data;
        return AppPage(title: 'Share delivery', children: [
          if (order == null)
            const InfoBand(
                title: 'Open an order to share it.', icon: Icons.share_outlined)
          else ...[
            DetailRow('Order', order.code),
            DetailRow('Status', orderStatusLabel(order.status)),
            const SizedBox(height: 20),
            PrimaryButton(
                label: 'Copy delivery reference',
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(
                      text:
                          'MoveTraq ${order.code}: ${orderStatusLabel(order.status)}'));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Delivery reference copied.')));
                  }
                }),
            const SizedBox(height: 18),
            const InfoBand(
                title: 'Public tracking links unavailable',
                body:
                    'Only order participants can access private delivery tracking.',
                icon: Icons.lock_outline),
          ],
        ]);
      });
}

class RatingScreen extends StatefulWidget {
  const RatingScreen({super.key, required this.orderId});
  final String orderId;
  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  int _rating = 0;
  final _review = TextEditingController();
  bool _busy = false;
  Object? _error;
  bool _sent = false;
  @override
  void dispose() {
    _review.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      AppPage(title: 'How was your delivery?', children: [
        if (_sent)
          const InfoBand(
              title: 'Thank you for your review',
              icon: Icons.check_circle_outline)
        else ...[
          Wrap(
              alignment: WrapAlignment.center,
              children: List.generate(
                  5,
                  (index) => IconButton(
                      tooltip: '${index + 1} stars',
                      icon: Icon(
                          index < _rating ? Icons.star : Icons.star_outline,
                          color: const Color(0xFF90AD20),
                          size: 32),
                      onPressed: () => setState(() => _rating = index + 1)))),
          const SizedBox(height: 24),
          TextField(
              controller: _review,
              maxLines: 4,
              maxLength: 2000,
              decoration:
                  const InputDecoration(labelText: 'Tell us more (optional)')),
          const SizedBox(height: 20),
          if (_error != null) LoadError(error: _error!),
          PrimaryButton(
              label: 'Submit review',
              loading: _busy,
              onPressed: _rating == 0
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      try {
                        await FeatureGateway(context.read<LocalDataService>())
                            .request('Delivery ratings', 'POST',
                                '/orders/${widget.orderId}/ratings', body: {
                          'rating': _rating,
                          'review': _review.text.trim()
                        });
                        if (mounted) setState(() => _sent = true);
                      } catch (error) {
                        if (mounted) setState(() => _error = error);
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    }),
        ],
      ]);
}

class DeliveryStageScreen extends StatefulWidget {
  const DeliveryStageScreen(
      {super.key, required this.orderId, this.dropoff = false});
  final String orderId;
  final bool dropoff;
  @override
  State<DeliveryStageScreen> createState() => _DeliveryStageScreenState();
}

class _DeliveryStageScreenState extends State<DeliveryStageScreen> {
  bool _busy = false;
  @override
  Widget build(BuildContext context) => StreamBuilder<ParcelOrder?>(
      stream: context.read<LocalDataService>().watchOrder(widget.orderId),
      builder: (context, snapshot) {
        final order = snapshot.data;
        final uid = context.watch<AuthProvider>().profile?.uid;
        final canAdvance = uid != null &&
            order?.delivererId == uid &&
            order?.status ==
                (widget.dropoff ? OrderStatus.pickedUp : OrderStatus.accepted);
        return AppPage(
            title: widget.dropoff ? 'Delivery drop-off' : 'Pickup delivery',
            children: [
              if (snapshot.hasError)
                LoadError(error: snapshot.error!)
              else if (snapshot.connectionState == ConnectionState.waiting &&
                  order == null)
                const Center(child: CircularProgressIndicator())
              else if (order == null)
                const InfoBand(
                    title: 'Delivery unavailable', icon: Icons.info_outline)
              else ...[
                DeliveryProgress(status: order.status),
                InfoBand(
                    title: order.title,
                    body: '${order.code} / ${orderStatusLabel(order.status)}',
                    icon: Icons.inventory_2_outlined),
                DetailRow(
                    widget.dropoff ? 'Drop-off address' : 'Pickup address',
                    widget.dropoff
                        ? order.dropoffAddress
                        : order.pickupAddress),
                MiniMap(
                    pickupLocation: order.pickupLocation,
                    dropoffLocation: order.dropoffLocation,
                    courierLocation: order.courierLocation,
                    height: 200),
                RouteTile(
                    title: 'Map & navigation',
                    icon: Icons.navigation_outlined,
                    route: '/d-active',
                    arguments: order.id),
                RouteTile(
                    title: 'Contact customer',
                    icon: Icons.chat_bubble_outline,
                    route: '/delivery-contact',
                    arguments: order.id),
                const SizedBox(height: 18),
                PrimaryButton(
                    label:
                        widget.dropoff ? 'Confirm handover' : 'Item collected',
                    loading: _busy,
                    onPressed: _busy || !canAdvance
                        ? null
                        : () async {
                            if (widget.dropoff) {
                              Navigator.pushNamed(context, '/handover',
                                  arguments: order.id);
                              return;
                            }
                            if (order.status != OrderStatus.accepted) {
                              showActionError(
                                  context,
                                  StateError(
                                      'Only an accepted delivery can be collected.'));
                              return;
                            }
                            setState(() => _busy = true);
                            try {
                              await context
                                  .read<LocalDataService>()
                                  .advanceDelivererStage(order.id, 1);
                              if (context.mounted) {
                                Navigator.pushReplacementNamed(
                                    context, '/delivery-dropoff',
                                    arguments: order.id);
                              }
                            } catch (error) {
                              if (context.mounted) {
                                showActionError(context, error);
                              }
                            } finally {
                              if (mounted) setState(() => _busy = false);
                            }
                          }),
                const SizedBox(height: 12),
                SecondaryButton(
                    label: 'Report a delivery problem',
                    onPressed: () => Navigator.pushNamed(
                        context, '/delivery-problem',
                        arguments: order.id)),
              ],
            ]);
      });
}
