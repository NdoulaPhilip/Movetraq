import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../models/misc_models.dart';
import '../../models/parcel_order.dart';
import '../../providers/auth_provider.dart';
import '../../services/local_data_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_page.dart';
import '../../widgets/premium_ui.dart';
import '../../widgets/primary_button.dart';
import '../../screens/orders/order_tools.dart';

class DelivererAnalyticsScreen extends StatefulWidget {
  const DelivererAnalyticsScreen(
      {super.key, this.embedded = false, this.performance = false});
  final bool embedded;
  final bool performance;
  @override
  State<DelivererAnalyticsScreen> createState() =>
      _DelivererAnalyticsScreenState();
}

class _DelivererAnalyticsScreenState extends State<DelivererAnalyticsScreen> {
  int _days = 7;
  late Stream<List<ParcelOrder>> _stream;
  @override
  void initState() {
    super.initState();
    _stream = context
        .read<LocalDataService>()
        .watchDelivererOrders(context.read<AuthProvider>().profile?.uid ?? '');
  }

  @override
  Widget build(BuildContext context) => AppPage(
        title: widget.performance ? 'My performance' : 'Delivery analytics',
        embedded: widget.embedded,
        children: [
          Wrap(
              spacing: 8,
              children: [1, 7, 30]
                  .map((days) => ChoiceChip(
                      label: Text(days == 1 ? 'Today' : '$days days'),
                      selected: days == _days,
                      onSelected: (_) => setState(() => _days = days)))
                  .toList()),
          const SizedBox(height: 18),
          StreamBuilder<List<ParcelOrder>>(
              stream: _stream,
              builder: (context, snapshot) {
                if (snapshot.hasError) return LoadError(error: snapshot.error!);
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final today = DateUtils.dateOnly(DateTime.now());
                final start = today.subtract(Duration(days: _days - 1));
                final orders = snapshot.data!;
                final completed = orders
                    .where((order) =>
                        order.status == OrderStatus.released &&
                        order.releasedAt != null &&
                        !order.releasedAt!.toLocal().isBefore(start) &&
                        order.releasedAt!
                            .toLocal()
                            .isBefore(today.add(const Duration(days: 1))))
                    .toList();
                final total = completed.fold<double>(
                    0, (sum, order) => sum + order.payout);
                final active = orders
                    .where((order) => ![
                          OrderStatus.cancelled,
                          OrderStatus.released
                        ].contains(order.status))
                    .length;
                final customers = completed
                    .map((order) => order.senderId)
                    .where((id) => id.isNotEmpty)
                    .toSet()
                    .length;
                final daily = List<double>.filled(_days, 0);
                for (final order in completed) {
                  final day = DateUtils.dateOnly(order.releasedAt!.toLocal())
                      .difference(start)
                      .inDays;
                  if (day >= 0 && day < daily.length) {
                    daily[day] += order.payout;
                  }
                }
                final max = daily.fold<double>(0, (a, b) => a > b ? a : b);
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InfoBand(
                          title: 'NGN ${total.toStringAsFixed(2)}',
                          body: 'Released delivery earnings',
                          dark: true,
                          icon: Icons.payments_outlined),
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                                child: PremiumStatCard(
                                    label: 'Completed',
                                    value: '${completed.length}')),
                            const SizedBox(width: 10),
                            Expanded(
                                child: PremiumStatCard(
                                    label: 'Active deliveries',
                                    value: '$active')),
                          ]),
                      const SizedBox(height: 12),
                      DetailRow('Customers served', '$customers'),
                      DetailRow(
                          'Average per delivery',
                          completed.isEmpty
                              ? 'NGN 0.00'
                              : 'NGN ${(total / completed.length).toStringAsFixed(2)}'),
                      const SectionTitle('Earnings by day'),
                      SizedBox(
                          height: 150,
                          child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: List.generate(
                                  _days,
                                  (index) => Expanded(
                                        child: Tooltip(
                                            message:
                                                '${start.add(Duration(days: index)).day}/${start.add(Duration(days: index)).month}: NGN ${daily[index].toStringAsFixed(2)}',
                                            child: Container(
                                                margin:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 2),
                                                height: max == 0
                                                    ? 2
                                                    : 4 +
                                                        daily[index] /
                                                            max *
                                                            146,
                                                decoration: BoxDecoration(
                                                    color: AppColors.accent,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            3)))),
                                      )))),
                      const SizedBox(height: 18),
                      const RouteTile(
                          title: 'Past customers',
                          icon: Icons.people_outline,
                          route: '/past-customers'),
                      const RouteTile(
                          title: 'Earnings & payouts',
                          icon: Icons.payments_outlined,
                          route: '/deliverer-earnings'),
                      if (widget.performance)
                        const InfoBand(
                            title: 'Quality metrics unavailable',
                            body:
                                'Acceptance and punctuality metrics are not supplied by the current API.',
                            icon: Icons.insights_outlined),
                    ]);
              }),
        ],
      );
}

class PastCustomersScreen extends StatefulWidget {
  const PastCustomersScreen({super.key, this.customerId});
  final String? customerId;
  @override
  State<PastCustomersScreen> createState() => _PastCustomersScreenState();
}

class _PastCustomersScreenState extends State<PastCustomersScreen> {
  String _query = '';
  @override
  Widget build(BuildContext context) => AppPage(
          title: widget.customerId == null
              ? 'Past customers'
              : 'Customer deliveries',
          children: [
            TextField(
                decoration: const InputDecoration(
                    hintText: 'Search customers',
                    prefixIcon: Icon(Icons.search)),
                onChanged: (value) =>
                    setState(() => _query = value.toLowerCase())),
            const SizedBox(height: 18),
            StreamBuilder<List<ParcelOrder>>(
                stream: context.read<LocalDataService>().watchDelivererOrders(
                    context.read<AuthProvider>().profile?.uid ?? ''),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return LoadError(error: snapshot.error!);
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final completed = (snapshot.data ?? [])
                      .where((order) =>
                          order.status == OrderStatus.released &&
                          (widget.customerId == null ||
                              widget.customerId == order.senderId) &&
                          order.senderName.toLowerCase().contains(_query))
                      .toList();
                  if (completed.isEmpty) {
                    return const PremiumEmptyState(
                        icon: Icons.people_outline,
                        title: 'Your customer history starts here',
                        body: 'No completed deliveries found.');
                  }
                  if (widget.customerId != null) {
                    return Column(
                        children: completed
                            .map((order) => RouteTile(
                                title: order.title,
                                subtitle: order.code,
                                icon: Icons.inventory_2_outlined,
                                route: '/delivery-summary',
                                arguments: order.id))
                            .toList());
                  }
                  final grouped = <String, List<ParcelOrder>>{};
                  for (final order in completed) {
                    grouped.putIfAbsent(order.senderId, () => []).add(order);
                  }
                  return Column(
                      children: grouped.entries
                          .map((entry) => RouteTile(
                              title: entry.value.first.senderName,
                              subtitle:
                                  '${entry.value.length} completed deliveries',
                              icon: Icons.person_outline,
                              route: '/customer-deliveries',
                              arguments: entry.key))
                          .toList());
                }),
          ]);
}

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key, this.embedded = false});
  final bool embedded;
  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  bool _activeOnly = false;
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider>().profile;
    final data = context.read<LocalDataService>();
    final stream = profile?.activeRole == UserRole.deliverer
        ? data.watchDelivererOrders(profile?.uid ?? '')
        : data.watchSenderOrders(profile?.uid ?? '');
    return AppPage(
        title: 'Conversations',
        embedded: widget.embedded,
        children: [
          TextField(
              decoration: const InputDecoration(
                  hintText: 'Search conversations',
                  prefixIcon: Icon(Icons.search)),
              onChanged: (value) =>
                  setState(() => _query = value.toLowerCase())),
          SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active deliveries only',
                  style: TextStyle(fontSize: 13)),
              value: _activeOnly,
              onChanged: (value) => setState(() => _activeOnly = value)),
          StreamBuilder<List<ParcelOrder>>(
              stream: stream,
              builder: (context, snapshot) {
                if (snapshot.hasError) return LoadError(error: snapshot.error!);
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final orders = (snapshot.data ?? [])
                    .where((order) =>
                        (!_activeOnly ||
                            ![OrderStatus.released, OrderStatus.cancelled]
                                .contains(order.status)) &&
                        '${order.title} ${order.senderName} ${order.delivererName ?? ''}'
                            .toLowerCase()
                            .contains(_query))
                    .toList();
                if (orders.isEmpty) {
                  return const PremiumEmptyState(
                      icon: Icons.chat_bubble_outline,
                      title: 'No conversations yet',
                      body: '');
                }
                return Column(
                    children: orders
                        .map((order) => StreamBuilder<List<ChatMessage>>(
                              stream: data.watchMessages(order.id),
                              builder: (context, messages) => RouteTile(
                                title: profile?.activeRole == UserRole.deliverer
                                    ? order.senderName
                                    : order.delivererName ??
                                        'Awaiting deliverer',
                                subtitle: messages.hasError
                                    ? 'Messages unavailable'
                                    : messages.data?.isNotEmpty == true
                                        ? messages.data!.last.text
                                        : '${order.code} / ${order.title}',
                                icon: Icons.chat_bubble_outline,
                                route: '/chat',
                                arguments: order.id,
                              ),
                            ))
                        .toList());
              }),
        ]);
  }
}

class DeliveryOpportunitiesScreen extends StatelessWidget {
  const DeliveryOpportunitiesScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      AppPage(title: 'Delivery opportunities', children: [
        const InfoBand(
            title: 'Deliver on your schedule',
            body:
                'Identity, transport and safety checks are required before delivery work is approved.',
            icon: Icons.local_shipping_outlined),
        const RouteTile(
            title: 'Personal details',
            subtitle: 'Contact and identity information',
            icon: Icons.person_outline,
            route: '/deliverer-apply'),
        const RouteTile(
            title: 'Identity & transport',
            subtitle: 'Verification documents',
            icon: Icons.fact_check_outlined,
            route: '/verification'),
        const RouteTile(
            title: 'Safety essentials',
            icon: Icons.shield_outlined,
            route: '/safety'),
        const SizedBox(height: 24),
        PrimaryButton(
            label: 'Start application',
            onPressed: () => Navigator.pushNamed(context, '/deliverer-apply')),
      ]);
}

class DeliveryWorkScreen extends StatelessWidget {
  const DeliveryWorkScreen({super.key, this.embedded = false});
  final bool embedded;
  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().profile?.uid ?? '';
    return AppPage(title: 'My delivery offers', embedded: embedded, children: [
      const RouteTile(
          title: 'My P2P ads',
          icon: Icons.campaign_outlined,
          route: '/my-p2p-ads'),
      const RouteTile(
          title: 'All delivery orders',
          icon: Icons.inventory_2_outlined,
          route: '/deliverer-orders'),
      const SectionTitle('Ongoing deliveries'),
      StreamBuilder<List<ParcelOrder>>(
          stream: context.read<LocalDataService>().watchDelivererOrders(uid),
          builder: (context, snapshot) {
            if (snapshot.hasError) return LoadError(error: snapshot.error!);
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final orders = (snapshot.data ?? [])
                .where((order) => ![OrderStatus.released, OrderStatus.cancelled]
                    .contains(order.status))
                .toList();
            if (orders.isEmpty) {
              return const PremiumEmptyState(
                  icon: Icons.local_shipping_outlined,
                  title: 'No active deliveries',
                  body: '');
            }
            return Column(
                children: orders
                    .map((order) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: PremiumSurface(
                            color: const Color(0xFFF7FAEF),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      '${order.code} / ${orderStatusLabel(order.status)}',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.muted)),
                                  const SizedBox(height: 10),
                                  Text(order.title,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 8),
                                  Text(order.status == OrderStatus.accepted
                                      ? order.pickupAddress
                                      : order.dropoffAddress),
                                  const SizedBox(height: 18),
                                  PrimaryButton(
                                      label: 'View delivery',
                                      onPressed: () => Navigator.pushNamed(
                                          context,
                                          order.status == OrderStatus.accepted
                                              ? '/delivery-pickup'
                                              : order.status ==
                                                      OrderStatus.pickedUp
                                                  ? '/delivery-dropoff'
                                                  : '/delivery-summary',
                                          arguments: order.id)),
                                  RouteTile(
                                      title: 'Message customer',
                                      icon: Icons.chat_bubble_outline,
                                      route: '/chat',
                                      arguments: order.id),
                                ]))))
                    .toList());
          }),
    ]);
  }
}
