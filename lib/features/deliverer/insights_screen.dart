import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../models/misc_models.dart';
import '../../models/parcel_order.dart';
import '../../providers/auth_provider.dart';
import '../../services/local_data_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_page.dart';
import '../../widgets/design_ui.dart';
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
  int _days = 1;
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
          subtitle: widget.performance
              ? 'Keep track of your completed work and customer connections.'
              : null,
          embedded: widget.embedded,
          children: [
            if (widget.performance)
              const InfoBand(
                  title: 'Keep track of your delivery work',
                  body:
                      'Your progress, service quality and customer connections.',
                  icon: Icons.bar_chart_outlined),
            StreamBuilder<List<ParcelOrder>>(
                stream: _stream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return LoadError(error: snapshot.error!);
                  }
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

                  final profile = context.watch<AuthProvider>().profile;
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!widget.performance) ...[
                          DesignCard(
                              dark: true,
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        _days == 1
                                            ? 'TODAY'
                                            : 'LAST $_days DAYS',
                                        style: const TextStyle(
                                            fontSize: 10,
                                            letterSpacing: 1,
                                            color: Colors.white60)),
                                    const SizedBox(height: 14),
                                    Text(naira(total),
                                        style: const TextStyle(
                                            fontSize: 34,
                                            fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 7),
                                    Text(
                                        '${completed.length} completed deliveries',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.white60)),
                                  ])),
                          const SizedBox(height: 18),
                          DesignCard(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                const Text('Your delivery orders',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 8),
                                Text(
                                    '${completed.length} completed / $active active',
                                    style: const TextStyle(
                                        fontSize: 12, color: AppColors.muted)),
                                const SizedBox(height: 12),
                                Text('Released earnings: ${naira(total)}',
                                    style: const TextStyle(
                                        fontSize: 12, color: AppColors.muted)),
                                const SizedBox(height: 18),
                                SecondaryButton(
                                    label: 'Manage orders',
                                    onPressed: () => Navigator.pushNamed(
                                        context, '/manage-orders')),
                              ])),
                          const SizedBox(height: 14),
                        ] else
                          const SectionTitle('Your delivery work'),
                        Row(children: [
                          for (final days in [1, 7, 30])
                            Expanded(
                                child: Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: ChoiceChip(
                                        label: Text(
                                            days == 1 ? 'Today' : '$days days'),
                                        showCheckmark: false,
                                        selected: _days == days,
                                        onSelected: (_) =>
                                            setState(() => _days = days))))
                        ]),
                        const SizedBox(height: 14),
                        Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                  child: DesignMetric(
                                      value: widget.performance
                                          ? completed.length.toString()
                                          : naira(completed.isEmpty
                                              ? 0
                                              : total / completed.length),
                                      label: widget.performance
                                          ? 'Completed deliveries'
                                          : 'Average per trip')),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: DesignMetric(
                                      value: widget.performance
                                          ? customers.toString()
                                          : profile == null ||
                                                  profile.totalDeliveries == 0
                                              ? '\u2014'
                                              : '${profile.rating.toStringAsFixed(1)} / 5',
                                      label: widget.performance
                                          ? 'Customers served'
                                          : 'Customer rating')),
                            ]),
                        const SizedBox(height: 20),
                        if (widget.performance) ...[
                          RouteTile(
                              title: 'Active deliveries',
                              subtitle: '$active in progress',
                              icon: Icons.local_shipping_outlined,
                              route: '/deliverer-orders'),
                          const RouteTile(
                              title: 'Past customers',
                              subtitle:
                                  'See completed work and previous conversations',
                              icon: Icons.people_outline,
                              route: '/past-customers'),
                          const SectionTitle('Service quality'),
                          DesignNote(
                              title: profile == null ||
                                      profile.totalDeliveries == 0
                                  ? 'Not rated yet'
                                  : '${profile.rating.toStringAsFixed(1)} / 5',
                              body: 'Customer rating'),
                          const InfoBand(
                              title: 'Quality metrics unavailable',
                              body:
                                  'Acceptance and punctuality metrics are not supplied by the current API.',
                              icon: Icons.insights_outlined),
                        ] else ...[
                          DesignCard(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                const Text('Earnings by day',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 22),
                                Semantics(
                                    label:
                                        'Released earnings for each day in the selected period',
                                    child: SizedBox(
                                        height: 125,
                                        child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: List.generate(
                                                _days,
                                                (index) => Expanded(
                                                    child: Tooltip(
                                                        message:
                                                            '${shortDate(start.add(Duration(days: index)))}: ${naira(daily[index])}',
                                                        child: Container(
                                                            margin: const EdgeInsets.symmetric(
                                                                horizontal: 2),
                                                            height: max == 0
                                                                ? 2
                                                                : 4 +
                                                                    daily[index] /
                                                                        max *
                                                                        121,
                                                            decoration: BoxDecoration(
                                                                color: const Color(
                                                                    0xFF90AD20),
                                                                borderRadius:
                                                                    BorderRadius.circular(3))))))))),
                                const SizedBox(height: 10),
                                Text(
                                    '${shortDate(start)} to ${shortDate(today)}',
                                    style: const TextStyle(
                                        fontSize: 11, color: AppColors.muted)),
                                if (completed.isEmpty)
                                  const Padding(
                                      padding: EdgeInsets.only(top: 10),
                                      child: Text(
                                          'No released earnings in this period.',
                                          style: TextStyle(fontSize: 12))),
                              ])),
                          const SizedBox(height: 16),
                          const RouteTile(
                              title: 'Past customers',
                              icon: Icons.people_outline,
                              route: '/past-customers'),
                          const RouteTile(
                              title: 'Earnings & payouts',
                              icon: Icons.payments_outlined,
                              route: '/deliverer-earnings'),
                        ],
                      ]);
                }),
          ]);
}

class PastCustomersScreen extends StatefulWidget {
  const PastCustomersScreen({super.key, this.customerId});
  final String? customerId;
  @override
  State<PastCustomersScreen> createState() => _PastCustomersScreenState();
}

class _PastCustomersScreenState extends State<PastCustomersScreen> {
  String _query = '';
  late final Stream<List<ParcelOrder>> _orders;
  @override
  void initState() {
    super.initState();
    _orders = context
        .read<LocalDataService>()
        .watchDelivererOrders(context.read<AuthProvider>().profile?.uid ?? '');
  }

  @override
  Widget build(BuildContext context) => AppPage(
          title: widget.customerId == null
              ? 'Past customers'
              : 'Customer deliveries',
          subtitle: widget.customerId == null
              ? 'Find previous customers and open their completed delivery records.'
              : null,
          children: [
            if (widget.customerId == null) ...[
              const Text(
                  'Customers from your completed deliveries. Open a customer to revisit your work together.',
                  style: TextStyle(
                      fontSize: 13, height: 1.65, color: AppColors.muted)),
              const SizedBox(height: 14),
              TextField(
                  decoration: const InputDecoration(
                      labelText: 'Search past customers',
                      prefixIcon: Icon(Icons.search)),
                  onChanged: (value) =>
                      setState(() => _query = value.toLowerCase())),
              const SizedBox(height: 18),
            ],
            StreamBuilder<List<ParcelOrder>>(
                stream: _orders,
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
                    if (widget.customerId != null) {
                      return DesignCard(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            const Text(
                                'No completed deliveries found for this customer.',
                                style: TextStyle(
                                    color: AppColors.muted, height: 1.6)),
                            const SizedBox(height: 22),
                            PrimaryButton(
                                label: 'See past customers',
                                onPressed: () => Navigator.pushNamed(
                                    context, '/past-customers')),
                          ]));
                    }
                    return DesignNote(
                        title: _query.isEmpty
                            ? 'Your customer history starts here'
                            : 'No customers found',
                        body: _query.isEmpty
                            ? 'Complete a delivery and the customer will appear here, along with the order and its conversation.'
                            : 'Try another name.');
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
          ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Search conversations',
                  style: TextStyle(fontSize: 13)),
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
              ]),
          const SizedBox(height: 12),
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
                              builder: (context, messages) {
                                final items = [...?messages.data]..sort(
                                    (a, b) =>
                                        a.createdAt.compareTo(b.createdAt));
                                final latest =
                                    items.isEmpty ? null : items.last;
                                final name =
                                    profile?.activeRole == UserRole.deliverer
                                        ? order.senderName
                                        : order.delivererName ??
                                            'Awaiting deliverer';
                                return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: DesignAvatar(name, radius: 21),
                                    title: Row(children: [
                                      Expanded(
                                          child: Text(name,
                                              style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight:
                                                      FontWeight.w600))),
                                      if (latest != null)
                                        Text(
                                            TimeOfDay.fromDateTime(
                                                    latest.createdAt.toLocal())
                                                .format(context),
                                            style: const TextStyle(
                                                fontSize: 10,
                                                color: AppColors.muted))
                                    ]),
                                    subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 6),
                                          Text(
                                              messages.hasError
                                                  ? 'Messages unavailable'
                                                  : latest?.text ??
                                                      'Start your delivery conversation',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.muted)),
                                          const SizedBox(height: 5),
                                          Text('${order.title} / ${order.code}',
                                              style: const TextStyle(
                                                  fontSize: 10,
                                                  color: Color(0xFF899578))),
                                        ]),
                                    onTap: () => Navigator.pushNamed(
                                        context, '/chat',
                                        arguments: order.id));
                              },
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
        DesignCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Deliver on your schedule',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          const Text(
              'Interested in making deliveries? Explore what is involved and apply when you are ready.',
              style:
                  TextStyle(fontSize: 13, height: 1.7, color: AppColors.muted)),
          const SizedBox(height: 20),
          SecondaryButton(
              label: 'Explore delivering',
              onPressed: () =>
                  Navigator.pushNamed(context, '/deliverer-apply')),
        ])),
      ]);
}

class DeliveryWorkScreen extends StatelessWidget {
  const DeliveryWorkScreen({super.key, this.embedded = false});
  final bool embedded;
  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().profile?.uid ?? '';
    return AppPage(title: 'My delivery offers', embedded: embedded, actions: [
      IconButton.filledTonal(
          tooltip: 'Create delivery offer',
          icon: const Icon(Icons.add),
          onPressed: () => Navigator.pushNamed(context, '/create-p2p-ad')),
    ], children: [
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
                                      title: 'Map & navigation',
                                      icon: Icons.navigation_outlined,
                                      route: '/d-active',
                                      arguments: order.id),
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
