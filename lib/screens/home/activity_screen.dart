import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../models/misc_models.dart';
import '../../models/parcel_order.dart';
import '../../providers/auth_provider.dart';
import '../../services/local_data_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_page.dart';
import '../orders/order_tools.dart';

const _olive = Color(0xFF87937B);
const _paleOlive = Color(0xFFEFF3E4);
const _outline = Color(0xFFE0E6D5);

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  String _filter = 'All';
  String? _uid;
  LocalDataService? _data;
  Stream<List<ParcelOrder>>? _orders;
  Stream<List<WalletTransaction>>? _payments;
  int _generation = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uid = context.watch<AuthProvider>().profile?.uid;
    final data = context.read<LocalDataService>();
    if (_uid != uid || _data != data) {
      _uid = uid;
      _data = data;
      _bindStreams();
    }
  }

  void _bindStreams() {
    _generation++;
    _orders = _uid == null ? Stream.value([]) : _data!.watchSenderOrders(_uid!);
    _payments =
        _uid == null ? Stream.value([]) : _data!.watchWalletTransactions(_uid!);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: StreamBuilder<List<ParcelOrder>>(
          key: ValueKey(_generation),
          stream: _orders,
          builder: (context, orders) => StreamBuilder<List<WalletTransaction>>(
            stream: _payments,
            builder: (context, payments) => _page(orders, payments),
          ),
        ),
      );

  Widget _page(AsyncSnapshot<List<ParcelOrder>> orders,
      AsyncSnapshot<List<WalletTransaction>> payments) {
    final deliveries = orders.data ?? [];
    final transactions = payments.data ?? [];
    final active = deliveries.where((order) =>
        order.status != OrderStatus.released &&
        order.status != OrderStatus.cancelled);
    // Sender decisions: agree a courier or confirm the delivered parcel.
    final attention = active.where((order) => const {
          OrderStatus.pendingOffer,
          OrderStatus.negotiating,
          OrderStatus.delivered,
        }.contains(order.status));
    // Net sender spend includes held escrow, excludes wallet funding and payouts.
    final spent = transactions
        .fold<double>(0, (sum, transaction) {
          if (transaction.type == WalletTxType.escrowHold ||
              transaction.type == WalletTxType.refund) {
            return sum - transaction.amount;
          }
          return sum;
        })
        .clamp(0.0, double.infinity)
        .toDouble();
    final updates = <_Update>[
      if (_filter != 'Payments')
        for (final order in deliveries)
          _Update(
            date: order.releasedAt ?? order.deliveredAt ?? order.createdAt,
            tile: RouteTile(
              title: order.title,
              subtitle: '${order.code} · ${orderStatusLabel(order.status)}',
              icon: Icons.inventory_2_outlined,
              route: '/order-detail',
              arguments: order.id,
            ),
          ),
      if (_filter != 'Deliveries')
        for (final transaction in transactions)
          _Update(
            date: transaction.createdAt,
            tile: RouteTile(
              title: transaction.title,
              subtitle:
                  '${transaction.amount < 0 ? '−' : '+'}${_money(transaction.amount.abs())}${transaction.sub.isEmpty ? '' : ' · ${transaction.sub}'}',
              icon: Icons.receipt_long_outlined,
              route: '/transaction-detail',
              arguments: transaction,
            ),
          ),
    ]..sort((a, b) => b.date.compareTo(a.date));
    final hasError = orders.hasError || payments.hasError;
    final ready = orders.hasData && payments.hasData;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        const Text('YOUR DELIVERIES AT A GLANCE',
            style: TextStyle(
                fontSize: 9,
                letterSpacing: 2,
                fontWeight: FontWeight.w700,
                color: _olive)),
        const SizedBox(height: 10),
        const Text('Activity',
            style: TextStyle(
                fontSize: 28,
                height: 1.2,
                fontWeight: FontWeight.w700,
                color: AppColors.ink)),
        const SizedBox(height: 10),
        const Text('See what needs your attention and follow every delivery.',
            style:
                TextStyle(fontSize: 12, height: 1.5, color: AppColors.muted)),
        const SizedBox(height: 22),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: _SummaryCard(
                  value: orders.hasData && !orders.hasError
                      ? '${active.length}'
                      : '—',
                  label: 'Active deliveries',
                  dark: true)),
          const SizedBox(width: 9),
          Expanded(
              child: _SummaryCard(
                  value: orders.hasData && !orders.hasError
                      ? '${attention.length}'
                      : '—',
                  label: 'Needs attention')),
        ]),
        const SizedBox(height: 9),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 14),
          decoration: _decoration(),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 8,
            children: [
              Text(payments.hasData && !payments.hasError ? _money(spent) : '—',
                  key: const ValueKey('delivery-payments'),
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700)),
              const Tooltip(
                message: 'Delivery charges less refunds, including held escrow',
                child: Text('Delivery payments',
                    style: TextStyle(fontSize: 10, color: _olive)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Row(children: [
          const Expanded(
              child: Text('Latest updates',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
          TextButton(
            onPressed: () => Navigator.pushNamed(context, '/transactions'),
            style: TextButton.styleFrom(
                foregroundColor: AppColors.ink,
                padding: EdgeInsets.zero,
                textStyle: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
            child: const Text('Transactions'),
          ),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 7, runSpacing: 8, children: [
          for (final filter in ['All', 'Deliveries', 'Payments'])
            ChoiceChip(
              label: Text(filter),
              selected: _filter == filter,
              showCheckmark: false,
              onSelected: (_) => setState(() => _filter = filter),
              backgroundColor: Colors.white,
              selectedColor: _paleOlive,
              side: const BorderSide(color: _outline),
              shape: const StadiumBorder(),
              labelStyle: const TextStyle(
                  color: _olive, fontSize: 10, fontWeight: FontWeight.w600),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            ),
        ]),
        const SizedBox(height: 18),
        if (hasError)
          LoadError(
              error: 'Unable to load all activity. Please try again.',
              onRetry: () => setState(_bindStreams)),
        if (!ready && !hasError)
          const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator())),
        if (updates.isNotEmpty)
          Container(
            decoration: _decoration(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(children: [
              for (var i = 0; i < updates.length; i++) ...[
                if (i > 0) const Divider(color: _outline, height: 1),
                updates[i].tile,
              ],
            ]),
          )
        else if (ready && !hasError)
          _emptyState(),
      ],
    );
  }

  Widget _emptyState() => Container(
        decoration: _decoration(radius: 20),
        padding: const EdgeInsets.fromLTRB(15, 24, 15, 24),
        child: Column(children: [
          Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                  color: _paleOlive, borderRadius: BorderRadius.circular(17)),
              child: Center(
                  child: SvgPicture.string(
                '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#101319" stroke-width="1.1" stroke-linejoin="round"><path d="M12 2 22 7.5v10L12 23 2 17.5v-10L12 2ZM2 7.5l10 5.5 10-5.5M12 13v10"/></svg>',
                width: 22,
                height: 22,
              ))),
          const SizedBox(height: 17),
          Text(
              _filter == 'Payments'
                  ? 'Your payments will appear here'
                  : 'Your next delivery starts here',
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          const Text(
              'Order updates, payments, and delivery confirmations will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, height: 1.65, color: _olive)),
          const SizedBox(height: 19),
          SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.ink,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15))),
                  onPressed: () => Navigator.pushNamed(context, '/send'),
                  child: const Text('Send an item'))),
        ]),
      );
}

BoxDecoration _decoration({double radius = 17}) => BoxDecoration(
    color: Colors.white,
    border: Border.all(color: _outline),
    borderRadius: BorderRadius.circular(radius));

String _money(double amount) {
  final parts = amount
      .toStringAsFixed(amount == amount.roundToDouble() ? 0 : 2)
      .split('.');
  final whole = parts.first.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match[1]},');
  return '₦$whole${parts.length > 1 ? '.${parts.last}' : ''}';
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard(
      {required this.value, required this.label, this.dark = false});
  final String value;
  final String label;
  final bool dark;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 17),
        decoration: BoxDecoration(
            color: dark ? AppColors.ink : _paleOlive,
            border: Border.all(color: dark ? AppColors.ink : _outline),
            borderRadius: BorderRadius.circular(17)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value,
              style: TextStyle(
                  fontSize: 25,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  color: dark ? Colors.white : AppColors.ink)),
          const SizedBox(height: 3),
          Text(label,
              style: const TextStyle(fontSize: 10, height: 1.4, color: _olive)),
        ]),
      );
}

class _Update {
  const _Update({required this.date, required this.tile});
  final DateTime date;
  final Widget tile;
}
