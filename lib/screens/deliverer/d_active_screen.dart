import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/parcel_order.dart';
import '../../providers/auth_provider.dart';
import '../../providers/deliverer_tracking_provider.dart';
import '../../services/local_data_service.dart';
import '../../widgets/app_page.dart';
import '../../widgets/live_google_map.dart';
import '../../widgets/design_ui.dart';
import '../../widgets/primary_button.dart';
import '../../theme/app_theme.dart';

class DActiveScreen extends StatefulWidget {
  const DActiveScreen({super.key, required this.orderId});
  final String orderId;
  @override
  State<DActiveScreen> createState() => _DActiveScreenState();
}

class _DActiveScreenState extends State<DActiveScreen>
    with WidgetsBindingObserver {
  late DelivererTrackingProvider _tracking;
  late Stream<ParcelOrder?> _order;
  double _extent = .4;
  String get orderId => widget.orderId;
  @override
  void initState() {
    super.initState();
    _tracking = context.read<DelivererTrackingProvider>();
    _order = context.read<LocalDataService>().watchOrder(orderId);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant DActiveScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderId != orderId) {
      _tracking.stopTracking();
      _order = context.read<LocalDataService>().watchOrder(orderId);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _tracking.stopTracking();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Avoid notifying listeners while the widget tree is being removed.
    Future.microtask(_tracking.stopTracking);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<ParcelOrder?>(
      stream: _order,
      builder: (context, snapshot) {
        final order = snapshot.data;
        final tracking = context.watch<DelivererTrackingProvider>();
        final active = order != null &&
            order.delivererId == context.watch<AuthProvider>().profile?.uid &&
            [OrderStatus.accepted, OrderStatus.pickedUp].contains(order.status);
        if ((!active || snapshot.hasError) &&
            tracking.activeDeliveryId == orderId) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) tracking.stopTracking();
          });
        }
        return Scaffold(
            backgroundColor: AppColors.ink,
            body: LayoutBuilder(
                builder: (context, bounds) => Stack(children: [
                      if (order != null)
                        Positioned.fill(
                            child: LiveGoogleMap(
                                order: order,
                                topPadding:
                                    MediaQuery.paddingOf(context).top + 72,
                                bottomPadding: bounds.maxHeight * _extent)),
                      Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: ColoredBox(
                              color: AppColors.ink,
                              child: SafeArea(
                                  child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Row(children: [
                                        IconButton.outlined(
                                            tooltip: 'Back',
                                            style: IconButton.styleFrom(
                                                foregroundColor: Colors.white,
                                                side: const BorderSide(
                                                    color: Colors.white24),
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            13))),
                                            onPressed: () =>
                                                Navigator.maybePop(context),
                                            icon:
                                                const Icon(Icons.chevron_left)),
                                        const SizedBox(width: 10),
                                        Expanded(
                                            child: Text(
                                                order?.status ==
                                                        OrderStatus.accepted
                                                    ? 'Heading to pickup'
                                                    : 'Active delivery',
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.white,
                                                    fontWeight:
                                                        FontWeight.w600))),
                                        const SizedBox(width: 10),
                                        IconButton.outlined(
                                            tooltip: 'Message customer',
                                            style: IconButton.styleFrom(
                                                foregroundColor: Colors.white,
                                                side: const BorderSide(
                                                    color: Colors.white24),
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            13))),
                                            onPressed: () =>
                                                Navigator.pushNamed(
                                                    context, '/chat',
                                                    arguments: orderId),
                                            icon: const Icon(
                                                Icons.chat_bubble_outline)),
                                      ]))))),
                      NotificationListener<DraggableScrollableNotification>(
                          onNotification: (notification) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) {
                                setState(() => _extent = notification.extent);
                              }
                            });
                            return false;
                          },
                          child: DraggableScrollableSheet(
                            initialChildSize: .4,
                            minChildSize: .3,
                            maxChildSize: .85,
                            builder: (context, controller) => Container(
                                decoration: const BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(25))),
                                child: ListView(
                                    controller: controller,
                                    padding: const EdgeInsets.all(18),
                                    children: [
                                      Center(
                                          child: Container(
                                              width: 34,
                                              height: 4,
                                              color: AppColors.faint)),
                                      const SizedBox(height: 18),
                                      if (snapshot.hasError)
                                        LoadError(error: snapshot.error!)
                                      else if (order == null &&
                                          snapshot.connectionState ==
                                              ConnectionState.waiting)
                                        const Center(
                                            child: CircularProgressIndicator())
                                      else if (order == null)
                                        const InfoBand(
                                            title: 'Delivery unavailable')
                                      else ...[
                                        Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                  child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                    Text(
                                                        order.status ==
                                                                OrderStatus
                                                                    .accepted
                                                            ? 'PICK UP FROM'
                                                            : 'DELIVER TO',
                                                        style: const TextStyle(
                                                            fontSize: 10,
                                                            color: AppColors
                                                                .muted)),
                                                    const SizedBox(height: 5),
                                                    Text(
                                                        order.status ==
                                                                OrderStatus
                                                                    .accepted
                                                            ? order
                                                                .pickupAddress
                                                            : order
                                                                .dropoffAddress,
                                                        style: const TextStyle(
                                                            fontSize: 21,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w700)),
                                                  ])),
                                              const SizedBox(width: 12),
                                              Text(naira(order.payout),
                                                  style: const TextStyle(
                                                      fontSize: 21,
                                                      fontWeight:
                                                          FontWeight.w700)),
                                            ]),
                                        const SizedBox(height: 14),
                                        DesignCard(
                                            color: const Color(0xFFF3F2ED),
                                            child: Row(children: [
                                              DesignAvatar(order.senderName),
                                              const SizedBox(width: 11),
                                              Expanded(
                                                  child: Text(order.senderName,
                                                      style: const TextStyle(
                                                          fontSize: 14,
                                                          fontWeight: FontWeight
                                                              .w600))),
                                              IconButton(
                                                  tooltip: 'Call customer',
                                                  onPressed: () =>
                                                      Navigator.pushNamed(
                                                          context, '/call',
                                                          arguments: orderId),
                                                  icon: const Icon(
                                                      Icons.call_outlined)),
                                            ])),
                                        const SizedBox(height: 12),
                                        if (order.status ==
                                                OrderStatus.accepted ||
                                            order.status ==
                                                OrderStatus.pickedUp)
                                          PrimaryButton(
                                              label: order.status ==
                                                      OrderStatus.accepted
                                                  ? 'Confirm pickup'
                                                  : 'Confirm handover',
                                              background: AppColors.accent,
                                              foreground: AppColors.ink,
                                              onPressed: !active
                                                  ? null
                                                  : () => Navigator.pushNamed(
                                                      context,
                                                      order.status ==
                                                              OrderStatus
                                                                  .accepted
                                                          ? '/delivery-pickup'
                                                          : '/delivery-dropoff',
                                                      arguments: orderId)),
                                        const SizedBox(height: 14),
                                        SwitchListTile(
                                            contentPadding: EdgeInsets.zero,
                                            title: const Text(
                                                'Share live delivery location'),
                                            subtitle: const Text(
                                                'Location sharing is limited to this active delivery.'),
                                            value: tracking.isTracking &&
                                                tracking.activeDeliveryId ==
                                                    orderId,
                                            onChanged:
                                                !active || tracking.isLoading
                                                    ? null
                                                    : (enabled) async {
                                                        try {
                                                          if (enabled) {
                                                            await tracking
                                                                .startTracking(
                                                                    orderId);
                                                          } else {
                                                            await tracking
                                                                .stopTracking();
                                                          }
                                                        } catch (error) {
                                                          if (context.mounted) {
                                                            showActionError(
                                                                context, error);
                                                          }
                                                        }
                                                      }),
                                        if (tracking.errorMessage != null)
                                          LoadError(
                                              error: tracking.errorMessage!),
                                        if ([
                                          OrderStatus.delivered,
                                          OrderStatus.released,
                                          OrderStatus.cancelled
                                        ].contains(order.status))
                                          RouteTile(
                                              title: 'Delivery summary',
                                              icon: Icons.fact_check_outlined,
                                              route: '/delivery-summary',
                                              arguments: orderId),
                                        RouteTile(
                                            title: 'Contact customer',
                                            icon: Icons.chat_bubble_outline,
                                            route: '/delivery-contact',
                                            arguments: orderId),
                                        RouteTile(
                                            title: 'Report a problem',
                                            icon: Icons.support_agent,
                                            route: '/delivery-problem',
                                            arguments: orderId),
                                      ],
                                    ])),
                          )),
                    ])));
      });
}
