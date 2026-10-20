import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/parcel_order.dart';
import '../../providers/auth_provider.dart';
import '../../services/local_data_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_page.dart';
import '../../widgets/live_google_map.dart';
import '../../widgets/map_geometry.dart';
import '../orders/order_tools.dart';

class LiveTrackingScreen extends StatefulWidget {
  const LiveTrackingScreen({super.key, required this.orderId});
  final String orderId;

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  double _sheetExtent = .32;
  late Stream<ParcelOrder?> _order;
  Timer? _freshnessTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _freshnessTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _freshnessTimer?.cancel();
    super.dispose();
  }

  void _load() =>
      _order = context.read<LocalDataService>().watchOrder(widget.orderId);

  @override
  void didUpdateWidget(covariant LiveTrackingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderId != widget.orderId) _load();
  }

  void _open(String route) =>
      Navigator.pushNamed(context, route, arguments: widget.orderId);

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().profile?.uid;
    return Scaffold(
      backgroundColor: AppColors.darkSurface,
      body: StreamBuilder<ParcelOrder?>(
        key: ValueKey(widget.orderId),
        stream: _order,
        builder: (context, snapshot) {
          final order = snapshot.data;
          if (snapshot.hasError) {
            return Material(
                color: Colors.white,
                child: AppPage(title: 'Live tracking', children: [
                  LoadError(
                      error: 'Unable to load delivery updates.',
                      onRetry: () => setState(_load)),
                ]));
          }
          if (!snapshot.hasData &&
              snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (order == null) {
            return const Material(
                color: Colors.white,
                child: AppPage(
                    title: 'Live tracking',
                    children: [InfoBand(title: 'Order unavailable')]));
          }
          final location = order.courierLocationIsSimulated
              ? null
              : mapPoint(order.courierLocation);
          final timestamp = order.courierLocationUpdatedAt;
          final live = location != null &&
              timestamp != null &&
              DateTime.now().difference(timestamp).inSeconds <= 120 &&
              timestamp
                  .isBefore(DateTime.now().add(const Duration(seconds: 30)));
          final completed = order.status == OrderStatus.delivered ||
              order.status == OrderStatus.released;
          final closed = order.status == OrderStatus.released ||
              order.status == OrderStatus.cancelled;
          final progress = completed
              ? 1.0
              : order.status == OrderStatus.pickedUp
                  ? .62
                  : 0.0;
          return LayoutBuilder(builder: (context, constraints) {
            final headerHeight = MediaQuery.paddingOf(context).top + 74;
            return Stack(children: [
              Positioned.fill(
                  child: LiveGoogleMap(
                      order: order,
                      bottomPadding: constraints.maxHeight * _sheetExtent,
                      topPadding: headerHeight)),
              Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                      color: AppColors.darkSurface,
                      child: SafeArea(
                          bottom: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                            child: Row(children: [
                              _headerButton('Back', Icons.chevron_left,
                                  () => Navigator.maybePop(context)),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: Center(
                                      child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 13, vertical: 9),
                                          decoration: BoxDecoration(
                                              color: AppColors.ink,
                                              borderRadius:
                                                  BorderRadius.circular(30),
                                              border: Border.all(
                                                  color:
                                                      const Color(0xFF292D33))),
                                          child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.circle,
                                                    size: 7,
                                                    color: live && !closed
                                                        ? AppColors.accent
                                                        : AppColors.muted),
                                                const SizedBox(width: 7),
                                                Flexible(
                                                    child: Text(
                                                        '${order.code} · ${closed ? orderStatusLabel(order.status) : live ? 'Live' : 'Awaiting GPS'}',
                                                        textAlign:
                                                            TextAlign.center,
                                                        style: const TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w600))),
                                              ])))),
                              const SizedBox(width: 10),
                              _headerButton(
                                  'Share delivery',
                                  Icons.share_outlined,
                                  () => _open('/share-order')),
                            ]),
                          )))),
              NotificationListener<DraggableScrollableNotification>(
                onNotification: (notification) {
                  if ((notification.extent - _sheetExtent).abs() > .005) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() => _sheetExtent = notification.extent);
                      }
                    });
                  }
                  return false;
                },
                child: DraggableScrollableSheet(
                  initialChildSize: .32,
                  minChildSize: .25,
                  maxChildSize: .85,
                  builder: (context, controller) => Container(
                    decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(26))),
                    child: ListView(
                      controller: controller,
                      padding: EdgeInsets.fromLTRB(
                          18, 9, 18, 20 + MediaQuery.paddingOf(context).bottom),
                      children: [
                        Center(
                            child: Container(
                                width: 34,
                                height: 4,
                                decoration: BoxDecoration(
                                    color: const Color(0xFFDDDEDD),
                                    borderRadius: BorderRadius.circular(4)))),
                        const SizedBox(height: 14),
                        Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(
                                        completed
                                            ? 'DELIVERY STATUS'
                                            : 'ARRIVAL ESTIMATE',
                                        style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.muted)),
                                    const SizedBox(height: 4),
                                    Text(
                                        completed
                                            ? 'Delivered'
                                            : order.status ==
                                                    OrderStatus.cancelled
                                                ? 'Cancelled'
                                                : 'ETA unavailable',
                                    style: TextStyle(
                                        fontSize: completed ? 23 : 18,
                                            height: 1.2,
                                            fontWeight: FontWeight.w700)),
                                  ])),
                              const SizedBox(width: 14),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                    const Text('Drop-off',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.muted,
                                            fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 4),
                                    Text(order.dropoffAddress,
                                        textAlign: TextAlign.end,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600)),
                                  ])),
                            ]),
                        const SizedBox(height: 16),
                        ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 5,
                                color: AppColors.accent,
                                backgroundColor: const Color(0xFFECEBE5),
                                semanticsLabel:
                                    orderStatusLabel(order.status))),
                        const SizedBox(height: 5),
                        const Row(children: [
                          Expanded(
                              child: Text('Picked up',
                                  style: TextStyle(
                                      fontSize: 10, color: AppColors.muted))),
                          Expanded(
                              child: Text('On the way',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 10, color: AppColors.muted))),
                          Expanded(
                              child: Text('Delivered',
                                  textAlign: TextAlign.end,
                                  style: TextStyle(
                                      fontSize: 10, color: AppColors.muted))),
                        ]),
                        const SizedBox(height: 13),
                        const Divider(height: 1, color: AppColors.cardBorder),
                        const SizedBox(height: 13),
                        Row(children: [
                          CircleAvatar(
                              radius: 22,
                              backgroundColor: const Color(0xFFEEF1E8),
                              child: Text(_initials(order.delivererName),
                                  style: const TextStyle(
                                      color: AppColors.ink,
                                      fontWeight: FontWeight.w600))),
                          const SizedBox(width: 10),
                          Expanded(
                              child: InkWell(
                                  onTap: order.delivererId == null
                                      ? null
                                      : () => _open('/delivery-contact'),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            order.delivererName ??
                                                'Finding your courier',
                                            style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 3),
                                        Text(orderStatusLabel(order.status),
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.inkSoft)),
                                      ]))),
                          const SizedBox(width: 8),
                          _contactButton(
                              'Message courier',
                              Icons.chat_bubble_outline,
                              order.delivererId == null
                                  ? null
                                  : () => _open('/chat')),
                          const SizedBox(width: 8),
                          _contactButton(
                              'Call courier',
                              Icons.call_outlined,
                              order.delivererId == null
                                  ? null
                                  : () => _open('/call'),
                              dark: true),
                        ]),
                        const SizedBox(height: 16),
                        Text(
                            live
                                ? 'Last reported location'
                                : 'Waiting for deliverer location',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.inkSoft)),
                        if (timestamp != null && location != null)
                          Text('Updated ${timestamp.toLocal()}',
                              style: const TextStyle(
                                  fontSize: 10, color: AppColors.muted)),
                        const SizedBox(height: 8),
                        RouteTile(
                            title: 'Delivery details',
                            icon: Icons.inventory_2_outlined,
                            route: '/delivery-summary',
                            arguments: widget.orderId),
                        RouteTile(
                            title: 'Report a problem',
                            icon: Icons.support_agent,
                            route: '/delivery-problem',
                            arguments: widget.orderId),
                        if (order.status == OrderStatus.delivered &&
                            order.senderId == uid)
                          RouteTile(
                              title: 'Confirm delivery',
                              icon: Icons.verified_outlined,
                              route: '/release',
                              arguments: widget.orderId),
                      ],
                    ),
                  ),
                ),
              ),
            ]);
          });
        },
      ),
    );
  }

  Widget _headerButton(String label, IconData icon, VoidCallback onPressed) =>
      IconButton.outlined(
          tooltip: label,
          onPressed: onPressed,
          style: IconButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: AppColors.ink,
              side: const BorderSide(color: Color(0xFF292D33)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13))),
          icon: Icon(icon, size: 21));

  Widget _contactButton(String label, IconData icon, VoidCallback? onPressed,
          {bool dark = false}) =>
      IconButton.filled(
          tooltip: label,
          onPressed: onPressed,
          style: IconButton.styleFrom(
              backgroundColor: dark ? AppColors.ink : const Color(0xFFF3F2ED),
              foregroundColor: dark ? Colors.white : AppColors.ink,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14))),
          icon: Icon(icon, size: 19));

  static String _initials(String? name) {
    final parts = name
            ?.trim()
            .split(RegExp(r'\s+'))
            .where((part) => part.isNotEmpty)
            .toList() ??
        [];
    if (parts.isEmpty) return '?';
    return '${parts.first[0]}${parts.length > 1 ? parts.last[0] : ''}'
        .toUpperCase();
  }
}
