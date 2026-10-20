import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/misc_models.dart';
import '../../models/parcel_order.dart';
import '../../providers/auth_provider.dart';
import '../../services/local_data_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_page.dart';
import '../../widgets/design_ui.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});
  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  String? _uid;
  Stream<List<WalletTransaction>>? _transactions;
  Stream<List<ParcelOrder>>? _orders;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uid = context.watch<AuthProvider>().profile?.uid;
    if (_transactions == null || _uid != uid) {
      _uid = uid;
      final data = context.read<LocalDataService>();
      _transactions =
          uid == null ? Stream.value([]) : data.watchWalletTransactions(uid);
      _orders = uid == null ? Stream.value([]) : data.watchSenderOrders(uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider>().profile;
    return AppPage(title: 'Wallet', actions: [
      TextButton(
          onPressed: () => Navigator.pushNamed(context, '/transactions'),
          child: const Text('Transaction history'))
    ], children: [
      DesignCard(
          dark: true,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('AVAILABLE TO SPEND',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.white54,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 14),
            Text(profile == null ? '—' : naira(profile.walletBalance),
                style:
                    const TextStyle(fontSize: 36, fontWeight: FontWeight.w700)),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(
                  child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 46),
                          backgroundColor: AppColors.accent,
                          foregroundColor: AppColors.ink),
                      onPressed: profile == null
                          ? null
                          : () => Navigator.pushNamed(context, '/topup'),
                      icon: const Icon(Icons.add),
                      label: const Text('Add money'))),
              const SizedBox(width: 10),
              Expanded(
                  child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 46),
                          backgroundColor: Colors.white.withValues(alpha: .09),
                          side: const BorderSide(color: Colors.white24),
                          foregroundColor: Colors.white),
                      onPressed: profile == null
                          ? null
                          : () => Navigator.pushNamed(context, '/withdraw'),
                      child: const Text('Withdraw'))),
            ]),
          ])),
      const SizedBox(height: 13),
      StreamBuilder<List<ParcelOrder>>(
          key: ValueKey(_uid),
          stream: _orders,
          builder: (context, snapshot) {
            final held = (snapshot.data ?? []).where((order) =>
                order.status != OrderStatus.released &&
                order.status != OrderStatus.cancelled);
            return DesignNote(
                title: snapshot.hasData
                    ? naira(
                        held.fold<double>(0, (sum, order) => sum + order.price))
                    : '—',
                body: snapshot.hasError
                    ? 'Held funds unavailable'
                    : 'Held for deliveries${snapshot.hasData ? ' · ${held.length} active orders' : ''}');
          }),
      SectionTitle('Payment methods',
          trailing: TextButton(
              onPressed: () => Navigator.pushNamed(context, '/payment-methods'),
              child: const Text('Manage', style: TextStyle(fontSize: 12)))),
      DesignCard(
          child: Column(children: [
        ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                    color: const Color(0xFFF0F4D9),
                    borderRadius: BorderRadius.circular(13)),
                child: const Icon(Icons.account_balance_wallet_outlined,
                    size: 20)),
            title: const Text('MoveTraq Wallet',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: Text(
                profile == null
                    ? 'Sign in to view your balance'
                    : 'Balance ${naira(profile.walletBalance)}',
                style: const TextStyle(fontSize: 11, color: AppColors.muted))),
        const Align(
            alignment: Alignment.centerRight,
            child: DesignBadge('Default method')),
      ])),
      const SectionTitle('Recent transactions'),
      StreamBuilder<List<WalletTransaction>>(
          key: ValueKey('tx-$_uid'),
          stream: _transactions,
          builder: (context, snapshot) {
            if (snapshot.hasError) return LoadError(error: snapshot.error!);
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final items = snapshot.data!.toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
            if (items.isEmpty) {
              return const DesignNote(
                  title: 'No transactions yet',
                  body:
                      'Payments, top-ups, refunds and withdrawals will appear here.');
            }
            return DesignCard(
                child: Column(children: [
              for (final item in items.take(5))
                RouteTile(
                    title: item.title,
                    subtitle:
                        '${item.amount < 0 ? '−' : '+'}${naira(item.amount.abs())}',
                    icon: Icons.receipt_long_outlined,
                    route: '/transaction-detail',
                    arguments: item),
            ]));
          }),
      const RouteTile(
          title: 'All transactions',
          icon: Icons.history,
          route: '/transactions'),
      const RouteTile(
          title: 'Check a payment',
          icon: Icons.fact_check_outlined,
          route: '/confirm-payment'),
      const RouteTile(
          title: 'Payout history',
          icon: Icons.account_balance_outlined,
          route: '/payouts'),
    ]);
  }
}
