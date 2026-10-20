import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../models/parcel_order.dart';
import '../../providers/auth_provider.dart';
import '../../services/local_data_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_page.dart';
import '../../widgets/premium_ui.dart';
import '../orders/order_tools.dart';

class TrackListScreen extends StatefulWidget {
  const TrackListScreen({super.key});

  @override
  State<TrackListScreen> createState() => _TrackListScreenState();
}

class _TrackListScreenState extends State<TrackListScreen> {
  String? _uid;
  LocalDataService? _data;
  Stream<List<ParcelOrder>>? _orders;
  int _generation = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uid = context.watch<AuthProvider>().profile?.uid;
    final data = context.read<LocalDataService>();
    if (_uid != uid || _data != data) {
      _uid = uid;
      _data = data;
      _load();
    }
  }

  void _load() {
    _generation++;
    _orders = _uid == null ? Stream.value([]) : _data!.watchSenderOrders(_uid!);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
            child: StreamBuilder<List<ParcelOrder>>(
          key: ValueKey(_generation),
          stream: _orders,
          builder: (context, snapshot) {
            final orders = (snapshot.data ?? [])
                .where((order) =>
                    order.status != OrderStatus.released &&
                    order.status != OrderStatus.cancelled)
                .toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return ListView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
                children: [
                  Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton.outlined(
                          tooltip: 'Back',
                          onPressed: () => Navigator.maybePop(context),
                          style: IconButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFEDEDEB)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(13))),
                          icon: const Icon(Icons.chevron_left, size: 22))),
                  const SizedBox(height: 10),
                  const Text('Active deliveries',
                      style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w500,
                          color: AppColors.ink)),
                  const SizedBox(height: 2),
                  Text(
                      snapshot.hasError
                          ? 'Delivery updates unavailable'
                          : !snapshot.hasData
                              ? 'Loading your deliveries…'
                              : '${orders.length} ${orders.length == 1 ? 'delivery' : 'deliveries'} on the move',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.muted)),
                  const SizedBox(height: 17),
                  if (snapshot.hasError)
                    LoadError(
                        error: 'Unable to load deliveries. Please try again.',
                        onRetry: () => setState(_load))
                  else if (!snapshot.hasData)
                    const Center(child: CircularProgressIndicator())
                  else if (orders.isEmpty)
                    const PremiumEmptyState(
                        icon: Icons.local_shipping_outlined,
                        title: 'No active deliveries',
                        body:
                            'Your deliveries will appear here when you send an item.')
                  else
                    for (final order in orders) ...[
                      _TrackingCard(order: order),
                      const SizedBox(height: 12),
                    ],
                ]);
          },
        )),
      );
}

class _TrackingCard extends StatelessWidget {
  const _TrackingCard({required this.order});
  final ParcelOrder order;

  @override
  Widget build(BuildContext context) {
    final document = order.category.toLowerCase().contains('document');
    final transit = order.status == OrderStatus.pickedUp ||
        order.status == OrderStatus.delivered;
    final inlineStatus = MediaQuery.sizeOf(context).width >= 360 &&
        MediaQuery.textScalerOf(context).scale(12) <= 14;
    final badge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: transit ? const Color(0xFFEAF3DF) : const Color(0xFFFFF3E1),
            borderRadius: BorderRadius.circular(30)),
        child: Text(orderStatusLabel(order.status),
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: transit
                    ? const Color(0xFF608109)
                    : const Color(0xFFB77900))));
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFF0F0ED)),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
                color: Color(0x04000000), blurRadius: 14, offset: Offset(0, 4))
          ]),
      padding: const EdgeInsets.all(14),
      child: Column(children: [
        Row(children: [
          Container(
              width: 41,
              height: 41,
              decoration: BoxDecoration(
                  color: document
                      ? const Color(0xFFE4EDF7)
                      : const Color(0xFFF0F4D9),
                  borderRadius: BorderRadius.circular(13)),
              child: Center(
                  child: SvgPicture.string(
                      document
                          ? '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#101319" stroke-width="1.2" stroke-linejoin="round"><path d="M5 2h9l5 5v17H5V2Zm9 0v5h5M8 13h8M8 18h8"/></svg>'
                          : '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#101319" stroke-width="1.2" stroke-linejoin="round"><path d="M4 7h16l-1.5 16h-13L4 7Zm4 0V6a4 4 0 0 1 8 0v1"/></svg>',
                      width: 19,
                      height: 19))),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(order.title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(order.code,
                    style:
                        const TextStyle(fontSize: 11, color: AppColors.muted)),
              ])),
          if (inlineStatus) ...[
            const SizedBox(width: 8),
            ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 85), child: badge),
          ],
        ]),
        if (!inlineStatus) ...[
          const SizedBox(height: 10),
          Align(alignment: Alignment.centerRight, child: badge),
        ],
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Icon(Icons.circle, size: 7, color: AppColors.faint)),
          const SizedBox(width: 7),
          Expanded(
              child: Text(order.pickupAddress,
                  style:
                      const TextStyle(fontSize: 11, color: AppColors.inkSoft))),
          const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child:
                  Icon(Icons.arrow_forward, size: 13, color: AppColors.faint)),
          const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Icon(Icons.circle, size: 7, color: AppColors.accent)),
          const SizedBox(width: 7),
          Expanded(
              child: Text(order.dropoffAddress,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600))),
        ]),
        const SizedBox(height: 12),
        SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
                onPressed: () =>
                    Navigator.pushNamed(context, '/live', arguments: order.id),
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(41),
                    textStyle: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                icon: const Icon(Icons.near_me, size: 16),
                label: const Text('Track delivery'),
                iconAlignment: IconAlignment.end)),
      ]),
    );
  }
}
