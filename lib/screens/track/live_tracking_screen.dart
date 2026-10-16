import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/parcel_order.dart';
import '../../providers/auth_provider.dart';
import '../../services/local_data_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_page.dart';
import '../../widgets/live_google_map.dart';
import '../../widgets/map_geometry.dart';
import '../../widgets/mini_map.dart';
import '../orders/order_tools.dart';

class LiveTrackingScreen extends StatefulWidget {
  const LiveTrackingScreen({super.key, required this.orderId});
  final String orderId;
  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  double _sheetExtent = .44;
  late Stream<ParcelOrder?> _order;
  String get orderId => widget.orderId;

  @override
  void initState() {
    super.initState();
    _order = context.read<LocalDataService>().watchOrder(orderId);
  }

  @override
  void didUpdateWidget(covariant LiveTrackingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderId != orderId) {
      _order = context.read<LocalDataService>().watchOrder(orderId);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      body: StreamBuilder<ParcelOrder?>(
          stream: _order,
          builder: (context, snapshot) {
            final order = snapshot.data;
            if (snapshot.hasError) {
              return AppPage(
                  title: 'Live tracking',
                  children: [LoadError(error: snapshot.error!)]);
            }
            if (order == null &&
                snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (order == null) {
              return const AppPage(
                  title: 'Live tracking',
                  children: [InfoBand(title: 'Order unavailable')]);
            }
            final location = order.courierLocationIsSimulated
                ? null
                : mapPoint(order.courierLocation);
            return LayoutBuilder(
                builder: (context, constraints) => Stack(children: [
                      Positioned.fill(
                          child: LiveGoogleMap(
                              order: order,
                              bottomPadding:
                                  constraints.maxHeight * _sheetExtent,
                              topPadding:
                                  MediaQuery.paddingOf(context).top + 70)),
                      SafeArea(
                          child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(children: [
                                CircleIconButton(
                                    icon: Icons.chevron_left,
                                    onTap: () => Navigator.maybePop(context)),
                                const Spacer(),
                                CircleIconButton(
                                    icon: Icons.ios_share_outlined,
                                    onTap: () => Navigator.pushNamed(
                                        context, '/share-order',
                                        arguments: orderId)),
                              ]))),
                      NotificationListener<DraggableScrollableNotification>(
                          onNotification: (notification) {
                            if ((notification.extent - _sheetExtent).abs() >
                                .005) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) {
                                  setState(
                                      () => _sheetExtent = notification.extent);
                                }
                              });
                            }
                            return false;
                          },
                          child: DraggableScrollableSheet(
                              initialChildSize: .44,
                              minChildSize: .28,
                              maxChildSize: .85,
                              builder: (context, controller) => Container(
                                    decoration: const BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.vertical(
                                            top: Radius.circular(20))),
                                    child: ListView(
                                        controller: controller,
                                        padding: const EdgeInsets.fromLTRB(
                                            20, 12, 20, 24),
                                        children: [
                                          Center(
                                              child: Container(
                                                  width: 36,
                                                  height: 4,
                                                  decoration: BoxDecoration(
                                                      color: AppColors.border,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              4)))),
                                          const SizedBox(height: 18),
                                          Text(orderStatusLabel(order.status),
                                              style: const TextStyle(
                                                  fontFamily: 'SpaceGrotesk',
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 22)),
                                          const SizedBox(height: 8),
                                          Text(order.code,
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.muted)),
                                          const SizedBox(height: 16),
                                          DetailRow('Destination',
                                              order.dropoffAddress),
                                          const DetailRow(
                                              'ETA', 'Not available'),
                                          InfoBand(
                                              title: location == null ||
                                                      order
                                                          .courierLocationIsSimulated
                                                  ? 'Waiting for deliverer location'
                                                  : 'Last reported location',
                                              body: location == null
                                                  ? null
                                                  : '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}${order.courierLocationUpdatedAt == null ? '' : ' / ${order.courierLocationUpdatedAt!.toLocal()}'}',
                                              icon: Icons.my_location),
                                          RouteTile(
                                              title: order.delivererName ??
                                                  'Delivery contact',
                                              icon: Icons.person_outline,
                                              route: '/delivery-contact',
                                              arguments: orderId),
                                          Row(children: [
                                            Expanded(
                                                child: OutlinedButton.icon(
                                                    onPressed: () =>
                                                        Navigator.pushNamed(
                                                            context, '/chat',
                                                            arguments: orderId),
                                                    icon: const Icon(Icons
                                                        .chat_bubble_outline),
                                                    label:
                                                        const Text('Message'))),
                                            const SizedBox(width: 12),
                                            Expanded(
                                                child: OutlinedButton.icon(
                                                    onPressed: () =>
                                                        Navigator.pushNamed(
                                                            context, '/call',
                                                            arguments: orderId),
                                                    icon: const Icon(
                                                        Icons.call_outlined),
                                                    label: const Text('Call')))
                                          ]),
                                          RouteTile(
                                              title: 'Delivery details',
                                              icon: Icons.inventory_2_outlined,
                                              route: '/delivery-summary',
                                              arguments: orderId),
                                          RouteTile(
                                              title: 'Report a problem',
                                              icon: Icons.support_agent,
                                              route: '/delivery-problem',
                                              arguments: orderId),
                                          if (order.status ==
                                                  OrderStatus.delivered &&
                                              order.senderId ==
                                                  context
                                                      .watch<AuthProvider>()
                                                      .profile
                                                      ?.uid)
                                            RouteTile(
                                                title: 'Confirm delivery',
                                                icon: Icons.verified_outlined,
                                                route: '/release',
                                                arguments: orderId),
                                        ]),
                                  ))),
                    ]));
          }));
}
