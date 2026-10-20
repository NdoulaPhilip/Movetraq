import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../models/parcel_order.dart';
import '../../providers/auth_provider.dart';
import '../../screens/orders/order_tools.dart';
import '../../services/local_data_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_page.dart';
import '../../widgets/premium_ui.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  bool _history = false;
  String _filter = 'All';
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
      _bindOrders();
    }
  }

  void _bindOrders() {
    _generation++;
    _orders = _uid == null ? Stream.value([]) : _data!.watchSenderOrders(_uid!);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: StreamBuilder<List<ParcelOrder>>(
          key: ValueKey(_generation),
          stream: _orders,
          builder: (context, snapshot) {
            final orders = (snapshot.data ?? []).where((order) {
              final closed = order.status == OrderStatus.released ||
                  order.status == OrderStatus.cancelled;
              if (closed != _history) return false;
              return switch (_filter) {
                'Active' => const {
                    OrderStatus.accepted,
                    OrderStatus.pickedUp,
                    OrderStatus.delivered
                  }.contains(order.status),
                'Completed' => order.status == OrderStatus.released,
                'Cancelled' => order.status == OrderStatus.cancelled,
                _ => true,
              };
            }).toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
              children: [
                const Text('Orders',
                    style: TextStyle(
                        fontSize: 24,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink)),
                const SizedBox(height: 17),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                      color: const Color(0xFFEEF1E8),
                      borderRadius: BorderRadius.circular(15)),
                  child: Row(children: [
                    _tab('Current orders', false),
                    _tab('Order history', true),
                  ]),
                ),
                const SizedBox(height: 16),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final filter in _history
                      ? ['All', 'Completed', 'Cancelled']
                      : ['All', 'Active'])
                    ChoiceChip(
                      label: Text(filter),
                      selected: _filter == filter,
                      onSelected: (_) => setState(() => _filter = filter),
                      showCheckmark: false,
                      selectedColor: AppColors.ink,
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFFE2E6DA)),
                      shape: const StadiumBorder(),
                      labelStyle: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _filter == filter
                              ? Colors.white
                              : AppColors.inkSoft),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                    ),
                ]),
                const SizedBox(height: 18),
                if (snapshot.hasError)
                  LoadError(
                      error: 'Unable to load orders. Please try again.',
                      onRetry: () => setState(_bindOrders))
                else if (!snapshot.hasData)
                  const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()))
                else if (orders.isEmpty) ...[
                  PremiumEmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: _history
                          ? 'No order history yet'
                          : _filter == 'Active'
                              ? 'No active deliveries yet'
                              : 'No current orders yet',
                      body: _history
                          ? 'Completed and cancelled orders will appear here.'
                          : 'Your deliveries will appear here when you send an item.'),
                  if (!_history)
                    TextButton(
                        onPressed: () => Navigator.pushNamed(context, '/send'),
                        child: const Text('Send an item')),
                ] else
                  for (final order in orders) ...[
                    _OrderCard(order: order),
                    const SizedBox(height: 10),
                  ],
              ],
            );
          },
        ),
      );

  Widget _tab(String label, bool history) => Expanded(
        child: Semantics(
          selected: _history == history,
          child: TextButton(
            onPressed: () => setState(() {
              _history = history;
              _filter = 'All';
            }),
            style: TextButton.styleFrom(
                backgroundColor:
                    _history == history ? Colors.white : Colors.transparent,
                foregroundColor: _history == history
                    ? AppColors.ink
                    : const Color(0xFF7C8792),
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            child: Text(label, textAlign: TextAlign.center),
          ),
        ),
      );
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});
  final ParcelOrder order;

  @override
  Widget build(BuildContext context) {
    final document = order.category.toLowerCase().contains('document');
    final status = Text(orderStatusLabel(order.status),
        style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: switch (order.status) {
              OrderStatus.pickedUp ||
              OrderStatus.released =>
                const Color(0xFF608109),
              OrderStatus.accepted ||
              OrderStatus.negotiating =>
                const Color(0xFFB77900),
              OrderStatus.cancelled => AppColors.danger,
              _ => AppColors.inkSoft,
            }));
    final amount = Text(_price(order.price),
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600));
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFF0F0ED))),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () =>
            Navigator.pushNamed(context, '/order-detail', arguments: order.id),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: LayoutBuilder(builder: (context, constraints) {
            final compact = constraints.maxWidth < 310 ||
                MediaQuery.textScalerOf(context).scale(12) > 14;
            return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                      width: 43,
                      height: 43,
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
                              width: 20,
                              height: 20))),
                  const SizedBox(width: 11),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(order.title,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 3),
                        Text('${order.code} · ${_date(order.createdAt)}',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.muted)),
                        if (compact) ...[
                          const SizedBox(height: 7),
                          Wrap(
                              spacing: 10,
                              runSpacing: 4,
                              children: [amount, status]),
                        ],
                      ])),
                  if (!compact) ...[
                    const SizedBox(width: 8),
                    ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 95),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              amount,
                              const SizedBox(height: 3),
                              status
                            ])),
                  ],
                ]);
          }),
        ),
      ),
    );
  }

  static String _date(DateTime value) {
    final date = value.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    if (day == today) return 'Today';
    if (day == DateTime(today.year, today.month, today.day - 1)) {
      return 'Yesterday';
    }
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${date.day} ${months[date.month - 1]}${date.year == now.year ? '' : ' ${date.year}'}';
  }

  static String _price(double amount) {
    final parts = amount
        .toStringAsFixed(amount == amount.roundToDouble() ? 0 : 2)
        .split('.');
    final whole = parts.first.replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match[1]},');
    return '₦$whole${parts.length > 1 ? '.${parts.last}' : ''}';
  }
}
