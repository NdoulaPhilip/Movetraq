import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/misc_models.dart';
import '../../models/parcel_order.dart';
import '../../providers/auth_provider.dart';
import '../../services/local_data_service.dart';
import '../../widgets/app_page.dart';
import '../../widgets/design_ui.dart';
import '../../widgets/primary_button.dart';
import '../../theme/app_theme.dart';

class DEarningsScreen extends StatefulWidget {
  const DEarningsScreen({super.key});
  @override
  State<DEarningsScreen> createState() => _DEarningsScreenState();
}

class _DEarningsScreenState extends State<DEarningsScreen> {
  String? _uid;
  Stream<List<ParcelOrder>>? _orders;
  Stream<List<WalletTransaction>>? _transactions;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uid = context.watch<AuthProvider>().profile?.uid;
    if (_orders == null || uid != _uid) {
      _uid = uid;
      final data = context.read<LocalDataService>();
      _orders = uid == null ? Stream.value([]) : data.watchDelivererOrders(uid);
      _transactions =
          uid == null ? Stream.value([]) : data.watchWalletTransactions(uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider>().profile;
    return AppPage(title: 'Earnings & payouts', children: [
      DesignCard(
          color: const Color(0xFF172014),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('AVAILABLE BALANCE',
                style: TextStyle(
                    fontSize: 10, letterSpacing: 1, color: Colors.white70)),
            const SizedBox(height: 16),
            Text(profile == null ? '\u2014' : naira(profile.walletBalance),
                style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
            const SizedBox(height: 16),
            const Text('Available for withdrawal',
                style: TextStyle(fontSize: 12, color: Colors.white60)),
            const SizedBox(height: 20),
            PrimaryButton(
                label: 'Withdraw to bank',
                onPressed: profile == null
                    ? null
                    : () => Navigator.pushNamed(context, '/withdraw')),
          ])),
      const SizedBox(height: 24),
      StreamBuilder<List<ParcelOrder>>(
          stream: _orders,
          builder: (context, snapshot) {
            if (snapshot.hasError) return LoadError(error: snapshot.error!);
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final pending = snapshot.data!
                .where((order) => order.status == OrderStatus.delivered)
                .toList();
            final released = snapshot.data!
                .where((order) => order.status == OrderStatus.released)
                .fold<double>(0, (sum, order) => sum + order.payout);
            return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                        child: DesignMetric(
                            value: naira(pending.fold<double>(
                                0, (sum, order) => sum + order.payout)),
                            label: 'Pending payment')),
                    const SizedBox(width: 10),
                    Expanded(
                        child: StreamBuilder<List<WalletTransaction>>(
                            stream: _transactions,
                            builder: (context, tx) => DesignMetric(
                                value: tx.hasData
                                    ? naira(tx.data!
                                        .where((item) =>
                                            item.type ==
                                            WalletTxType.withdrawal)
                                        .fold<double>(
                                            0,
                                            (sum, item) =>
                                                sum + item.amount.abs()))
                                    : '\u2014',
                                label: tx.hasError
                                    ? 'Withdrawn unavailable'
                                    : 'Withdrawn'))),
                  ]),
                  const SizedBox(height: 20),
                  DetailRow('Released delivery earnings', naira(released)),
                  const SectionTitle('Awaiting sender confirmation'),
                  if (pending.isEmpty)
                    const Text('No payments waiting for confirmation.',
                        style: TextStyle(
                            fontSize: 13, height: 1.6, color: AppColors.muted)),
                  for (final order in pending)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: DesignOrderCard(
                            order: order,
                            status: 'Awaiting confirmation',
                            driver: true,
                            onTap: () => Navigator.pushNamed(
                                context, '/delivery-summary',
                                arguments: order.id))),
                ]);
          }),
      const SizedBox(height: 24),
      PrimaryButton(
          label: 'View transactions',
          onPressed: () => Navigator.pushNamed(context, '/transactions')),
      const RouteTile(
          title: 'Payout history',
          icon: Icons.receipt_long_outlined,
          route: '/payouts'),
      const RouteTile(
          title: 'Earnings analytics',
          icon: Icons.insights_outlined,
          route: '/analytics'),
    ]);
  }
}
