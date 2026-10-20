import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import 'order_overview.dart';
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
import '../../widgets/design_ui.dart';

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
              title: (completed ||
                      driver &&
                          [OrderStatus.delivered, OrderStatus.released]
                              .contains(order?.status))
                  ? 'Delivery summary'
                  : receipt
                      ? 'Order confirmed'
                      : driver
                          ? 'Delivery details'
                          : 'Order details',
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
                  if (driver &&
                      !completed &&
                      ![OrderStatus.delivered, OrderStatus.released]
                          .contains(order.status))
                    DeliveryProgress(status: order.status),
                  OrderOverview(
                      order: order,
                      driver: driver,
                      receipt: receipt,
                      completed: completed,
                      statusLabel: orderStatusLabel(order.status)),
                  const SizedBox(height: 24),
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
                  const SizedBox(height: 12),
                  SecondaryButton(
                      label: 'Transaction records',
                      onPressed: () =>
                          Navigator.pushNamed(context, '/transactions')),
                  if (receipt) ...[
                    const SizedBox(height: 12),
                    PrimaryButton(
                        label: 'View all orders',
                        onPressed: () =>
                            Navigator.pushNamed(context, '/track-list')),
                    const SizedBox(height: 12),
                    SecondaryButton(
                        label: 'Back to home',
                        onPressed: () => Navigator.pushNamed(context, '/home')),
                  ],
                  const DesignSection('DELIVERY OPTIONS'),
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
                            context, '/confirm-receipt',
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
  Stream<ParcelOrder?>? _order;
  bool _busy = false;
  Future<void> _dial(AppUser user) async {
    if (_busy || user.phone.isEmpty) return;
    setState(() => _busy = true);
    try {
      await const CallService().dial(user.phone);
    } catch (error) {
      if (mounted) showActionError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _contact = context.read<LocalDataService>().orderContact(widget.orderId);
    if (widget.call) {
      _order = context.read<LocalDataService>().watchOrder(widget.orderId);
    }
  }

  @override
  Widget build(BuildContext context) => AppPage(
        title: widget.call
            ? context.watch<AuthProvider>().profile?.activeRole ==
                    UserRole.deliverer
                ? 'Call customer'
                : 'Call courier'
            : widget.profile
                ? 'Deliverer profile'
                : context.watch<AuthProvider>().profile?.activeRole ==
                        UserRole.deliverer
                    ? 'Contact your customer'
                    : 'Contact your courier',
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
                  if (!widget.profile)
                    DesignCard(
                        child: Column(
                      crossAxisAlignment: widget.call
                          ? CrossAxisAlignment.center
                          : CrossAxisAlignment.start,
                      children: [
                        if (widget.call) ...[
                          const Icon(Icons.call_outlined, size: 32),
                          const SizedBox(height: 24),
                        ],
                        Text(user.name,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        Text(
                            context.read<AuthProvider>().profile?.activeRole !=
                                    UserRole.deliverer
                                ? [
                                    'Your courier',
                                    user.vehicleType,
                                    if (user.totalDeliveries > 0)
                                      '${user.rating.toStringAsFixed(1)} rating'
                                  ].where((part) => part.isNotEmpty).join(' · ')
                                : 'Delivery customer',
                            style: const TextStyle(
                                color: AppColors.muted, height: 1.6)),
                        if (widget.call) ...[
                          StreamBuilder<ParcelOrder?>(
                              stream: _order,
                              builder: (context, snapshot) => snapshot.data ==
                                      null
                                  ? const SizedBox.shrink()
                                  : Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(snapshot.data!.code,
                                          style: const TextStyle(
                                              color: AppColors.muted)),
                                    )),
                          const SizedBox(height: 16),
                          Text(
                              user.phone.isEmpty
                                  ? 'Phone number unavailable'
                                  : 'Ready to call',
                              style: const TextStyle(color: AppColors.muted)),
                        ],
                      ],
                    )),
                  if (widget.profile) ...[
                    DesignAvatar(user.name, radius: 48),
                    const SizedBox(height: 18),
                    Text(user.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 20)),
                    const SizedBox(height: 12),
                  ],
                  if (widget.profile) ...[
                    Text(user.delivererOnline ? 'Available' : 'Offline',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: user.delivererOnline
                                ? const Color(0xFF0CB46A)
                                : AppColors.muted)),
                    const SizedBox(height: 22),
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              child: DesignMetric(
                                  value: user.totalDeliveries == 0
                                      ? '\u2014'
                                      : user.rating.toStringAsFixed(1),
                                  label: 'Customer rating')),
                          const SizedBox(width: 10),
                          Expanded(
                              child: DesignMetric(
                                  value: '${user.totalDeliveries}',
                                  label: 'Completed')),
                        ]),
                    const SizedBox(height: 12),
                    DesignCard(
                        dark: true,
                        child: Row(children: [
                          Container(
                              padding: const EdgeInsets.all(13),
                              decoration: BoxDecoration(
                                  color: AppColors.accent,
                                  borderRadius: BorderRadius.circular(13)),
                              child: const Icon(Icons.verified_user_outlined,
                                  color: AppColors.ink)),
                          const SizedBox(width: 13),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(
                                    user.verified
                                        ? 'Verified profile'
                                        : 'Verification pending',
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text(user.vehicleType,
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.white54)),
                              ])),
                        ])),
                  ],
                  const SizedBox(height: 20),
                  if (widget.call) ...[
                    PrimaryButton(
                        label: 'Call by phone',
                        loading: _busy,
                        onPressed:
                            user.phone.isEmpty ? null : () => _dial(user)),
                    const SizedBox(height: 12),
                    SecondaryButton(
                        label: 'Send a message',
                        onPressed: () => Navigator.pushNamed(context, '/chat',
                            arguments: widget.orderId)),
                  ] else ...[
                    PrimaryButton(
                        label: widget.profile
                            ? 'Message'
                            : context
                                        .read<AuthProvider>()
                                        .profile
                                        ?.activeRole ==
                                    UserRole.deliverer
                                ? 'Message customer'
                                : 'Message courier',
                        onPressed: () => Navigator.pushNamed(context, '/chat',
                            arguments: widget.orderId)),
                    const SizedBox(height: 12),
                    SecondaryButton(
                        label: 'Call by phone',
                        onPressed: _busy || user.phone.isEmpty
                            ? null
                            : () => _dial(user)),
                  ],
                  const SizedBox(height: 18),
                  Text(
                      user.phone.isEmpty
                          ? 'Phone calling becomes available when a contact phone number is connected.'
                          : 'Calls open in your phone app.',
                      style:
                          const TextStyle(color: AppColors.muted, height: 1.6)),
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
        return AppPage(
            title: 'Share delivery',
            subtitle:
                'Share this delivery reference and its current status with the recipient.',
            children: [
              if (order == null)
                const InfoBand(
                    title: 'Open an order to share it.',
                    icon: Icons.share_outlined)
              else ...[
                DesignCard(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const Icon(Icons.share_outlined, size: 20),
                      const SizedBox(height: 18),
                      const Text('Share this delivery',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 16),
                      Text('${order.code} / ${orderStatusLabel(order.status)}',
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.muted)),
                      const SizedBox(height: 14),
                      const Text('Delivery reference',
                          style: TextStyle(fontSize: 12)),
                      const SizedBox(height: 8),
                      DesignCard(
                          color: const Color(0xFFFAFAF8),
                          padding: const EdgeInsets.all(14),
                          child: SelectableText(
                              'MoveTraq ${order.code}: ${orderStatusLabel(order.status)}',
                              style: const TextStyle(fontSize: 12))),
                    ])),
                const SizedBox(height: 20),
                PrimaryButton(
                    label: 'Copy delivery reference',
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(
                          text:
                              'MoveTraq ${order.code}: ${orderStatusLabel(order.status)}'));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Delivery reference copied.')));
                      }
                    }),
                const SizedBox(height: 18),
                const InfoBand(
                    title: 'Public tracking links unavailable',
                    body:
                        'Only order participants can access private delivery tracking.',
                    icon: Icons.lock_outline),
                const SizedBox(height: 16),
                SecondaryButton(
                    label: 'Back to tracking',
                    onPressed: () => Navigator.pushNamed(context, '/live',
                        arguments: orderId)),
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
  Widget build(BuildContext context) => AppPage(
          title: 'How was your delivery?',
          subtitle: 'Your feedback helps make every delivery better.',
          children: [
            if (_sent)
              const InfoBand(
                  title: 'Thank you for your review',
                  icon: Icons.check_circle_outline)
            else ...[
              DesignCard(
                  child: Wrap(
                      alignment: WrapAlignment.spaceEvenly,
                      children: List.generate(
                          5,
                          (index) => IconButton(
                              tooltip: '${index + 1} stars',
                              icon: Icon(
                                  index < _rating
                                      ? Icons.star
                                      : Icons.star_outline,
                                  color: const Color(0xFF90AD20),
                                  size: 32),
                              onPressed: () =>
                                  setState(() => _rating = index + 1))))),
              const SizedBox(height: 24),
              TextField(
                  controller: _review,
                  maxLines: 4,
                  maxLength: 2000,
                  decoration: const InputDecoration(
                      labelText: 'Tell us more (optional)')),
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
                            await FeatureGateway(
                                    context.read<LocalDataService>())
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
  late final Stream<ParcelOrder?> _order;
  @override
  void initState() {
    super.initState();
    _order = context.read<LocalDataService>().watchOrder(widget.orderId);
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<ParcelOrder?>(
      stream: _order,
      builder: (context, snapshot) {
        final order = snapshot.data;
        final uid = context.watch<AuthProvider>().profile?.uid;
        final canAdvance = uid != null &&
            order?.delivererId == uid &&
            order?.status ==
                (widget.dropoff ? OrderStatus.pickedUp : OrderStatus.accepted);
        return AppPage(
            title: widget.dropoff
                ? 'Delivery instructions'
                : 'Pickup instructions',
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
                const SizedBox(height: 20),
                DesignCard(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(order.code, style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 6),
                      Text(
                          !canAdvance
                              ? orderStatusLabel(order.status)
                              : widget.dropoff
                                  ? 'Travel to the delivery address'
                                  : 'Delivery accepted',
                          style: const TextStyle(
                              fontSize: 21, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 14),
                      Text(
                          widget.dropoff
                              ? order.dropoffAddress
                              : order.pickupAddress,
                          style: const TextStyle(
                              color: AppColors.muted, height: 1.6)),
                      const SizedBox(height: 12),
                      Text(naira(order.payout),
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text(
                          widget.dropoff
                              ? 'Meet the recipient, hand over the parcel and record the required delivery evidence.'
                              : 'At pickup, check the parcel and confirm that it matches the order before marking it collected.',
                          style: const TextStyle(
                              color: AppColors.muted, height: 1.7)),
                    ])),
                const SizedBox(height: 14),
                DesignCard(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(order.senderName,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 16),
                      PrimaryButton(
                          label: 'Message',
                          onPressed: () => Navigator.pushNamed(context, '/chat',
                              arguments: order.id)),
                      const SizedBox(height: 10),
                      SecondaryButton(
                          label: 'Call customer',
                          onPressed: () => Navigator.pushNamed(context, '/call',
                              arguments: order.id)),
                    ])),
                const SizedBox(height: 18),
                if (widget.dropoff)
                  DesignCard(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(
                            widget.dropoff
                                ? 'Drop-off location'
                                : 'Pickup location',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 14),
                        ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: MiniMap(
                                pickupLocation: order.pickupLocation,
                                dropoffLocation: order.dropoffLocation,
                                courierLocation: order.courierLocation,
                                height: 235)),
                        RouteTile(
                            title: widget.dropoff
                                ? 'Navigate to drop-off'
                                : 'Start journey to pickup',
                            icon: Icons.navigation_outlined,
                            route: '/d-active',
                            arguments: order.id),
                      ])),
                if (!widget.dropoff)
                  PrimaryButton(
                      label: 'Start journey to pickup',
                      onPressed: () => Navigator.pushNamed(context, '/d-active',
                          arguments: order.id)),
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
