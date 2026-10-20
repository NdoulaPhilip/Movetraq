import 'package:flutter/material.dart';
import '../../models/parcel_order.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_page.dart';
import '../../widgets/design_ui.dart';
import '../../widgets/primary_button.dart';

/// Distinct receipt, sender detail and courier summary compositions.
class OrderOverview extends StatelessWidget {
  const OrderOverview(
      {super.key,
      required this.order,
      required this.driver,
      required this.receipt,
      required this.completed,
      required this.statusLabel});
  final ParcelOrder order;
  final bool driver, receipt, completed;
  final String statusLabel;

  @override
  Widget build(BuildContext context) {
    final finished = (completed || driver) &&
        [OrderStatus.delivered, OrderStatus.released].contains(order.status);
    if (finished) {
      return Column(children: [
        const SizedBox(height: 8),
        Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFBEDB8E)),
                borderRadius: BorderRadius.circular(42)),
            padding: const EdgeInsets.all(14),
            child: Container(
                decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(26)),
                child:
                    const Icon(Icons.check, size: 34, color: AppColors.ink))),
        const SizedBox(height: 22),
        const Text('DELIVERY COMPLETED',
            style: TextStyle(
                fontSize: 9,
                letterSpacing: 2,
                fontWeight: FontWeight.w700,
                color: Color(0xFF879578))),
        const SizedBox(height: 14),
        Text(
            order.status == OrderStatus.delivered ||
                    order.status == OrderStatus.released
                ? 'Parcel delivered'
                : 'Delivery summary',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        const Text(
            'Review the completed route, customer details and payout below.',
            textAlign: TextAlign.center,
            style:
                TextStyle(fontSize: 12, height: 1.7, color: AppColors.muted)),
        const SizedBox(height: 24),
        DesignCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                              child: Text(order.code,
                                  style: const TextStyle(
                                      fontSize: 10, color: AppColors.muted))),
                          DesignBadge(order.isExpress
                              ? 'Express delivery'
                              : 'P2P delivery')
                        ]),
                        const SizedBox(height: 22),
                        Text(order.title,
                            style: const TextStyle(
                                fontSize: 21, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 20),
                        DesignRoute(
                            pickup: order.pickupAddress,
                            destination: order.dropoffAddress),
                        const SizedBox(height: 22),
                        DetailRow('Customer', order.senderName),
                        if (order.deliveredAt != null)
                          DetailRow('Delivered', shortDate(order.deliveredAt!)),
                        if (order.releasedAt != null)
                          DetailRow('Completed', shortDate(order.releasedAt!)),
                      ])),
              Container(
                  color: AppColors.ink,
                  padding: const EdgeInsets.all(20),
                  child: Row(children: [
                    const Expanded(
                        child: Text('Delivery earnings',
                            style: TextStyle(
                                fontSize: 11, color: Color(0xFFB0B8A5)))),
                    Text(naira(order.payout),
                        style: const TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent))
                  ])),
            ])),
        const SizedBox(height: 18),
        const InfoBand(
            title: 'Payout status',
            body:
                'Check your transaction history for the status of this payout.',
            icon: Icons.account_balance_wallet_outlined),
      ]);
    }
    if (receipt) {
      return DesignCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.check, color: Color(0xFF608109), size: 28),
        const SizedBox(height: 20),
        Text(order.code,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 18),
        _receiptLine(statusLabel),
        _receiptLine('Deliverer: ${order.delivererName ?? 'Not assigned'}'),
        _receiptLine('${order.pickupAddress} \u2192 ${order.dropoffAddress}'),
        _receiptLine('${order.category} \u00b7 ${shortDate(order.createdAt)}'),
        Text('Order total ${naira(order.price)}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        _receiptLine(order.status == OrderStatus.released
            ? 'Payment released'
            : 'Payment not released'),
      ]));
    }
    if (driver) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        DesignBadge(statusLabel),
        const SizedBox(height: 16),
        DesignCard(
            dark: true,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(16)),
                    child: const Icon(Icons.inventory_2_outlined,
                        color: AppColors.ink)),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const Text('DELIVERY ORDER',
                          style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 1.5,
                              color: Colors.white60)),
                      const SizedBox(height: 8),
                      Text(order.title,
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text(order.code,
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 12)),
                    ])),
              ]),
              const SizedBox(height: 24),
              const Divider(color: Colors.white24),
              const SizedBox(height: 12),
              const Text('Your payout',
                  style: TextStyle(color: Colors.white60)),
              const SizedBox(height: 8),
              Text(naira(order.payout),
                  style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent)),
            ])),
        const DesignSection('DELIVERY ROUTE'),
        DesignCard(
            child: DesignRoute(
                pickup: order.pickupAddress,
                destination: order.dropoffAddress)),
        const DesignSection('CUSTOMER'),
        DesignCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            DesignAvatar(order.senderName),
            const SizedBox(width: 12),
            Expanded(
                child: Text(order.senderName,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)))
          ]),
          const SizedBox(height: 20),
          PrimaryButton(
              label: 'Message',
              onPressed: () =>
                  Navigator.pushNamed(context, '/chat', arguments: order.id)),
          const SizedBox(height: 10),
          SecondaryButton(
              label: 'Call customer',
              onPressed: () =>
                  Navigator.pushNamed(context, '/call', arguments: order.id)),
        ])),
      ]);
    }
    return Column(children: [
      DesignCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${order.code} / $statusLabel',
            style: const TextStyle(fontSize: 11)),
        const SizedBox(height: 5),
        Text(order.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 7),
        Text(naira(driver ? order.payout : order.price),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 5),
        Text(shortDate(order.createdAt),
            style: const TextStyle(fontSize: 13, color: AppColors.muted)),
        const SizedBox(height: 18),
        Text('${order.pickupAddress} to ${order.dropoffAddress}',
            style: const TextStyle(
                fontSize: 13, height: 1.65, color: AppColors.muted)),
      ])),
      const SizedBox(height: 14),
      DesignNote(
          title: switch (order.status) {
            OrderStatus.released => 'Delivery completed',
            OrderStatus.delivered => 'Delivery awaiting confirmation',
            OrderStatus.cancelled => 'Delivery cancelled',
            _ => 'Delivery in progress',
          },
          body: 'Open tracking for this order status and delivery stages.'),
    ]);
  }

  Widget _receiptLine(String value) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(value,
          style: const TextStyle(
              fontSize: 13, height: 1.6, color: AppColors.muted)));
}
