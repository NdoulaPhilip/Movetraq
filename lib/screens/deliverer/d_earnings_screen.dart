import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/parcel_order.dart';
import '../../providers/auth_provider.dart';
import '../../services/local_data_service.dart';
import '../../widgets/app_page.dart';

class DEarningsScreen extends StatelessWidget {
  const DEarningsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider>().profile;
    return AppPage(title: 'My earnings', children: [
      InfoBand(
          title: 'Available balance',
          body: 'NGN ${(profile?.walletBalance ?? 0).toStringAsFixed(2)}',
          dark: true,
          icon: Icons.account_balance_wallet_outlined),
      StreamBuilder<List<ParcelOrder>>(
          stream: context
              .read<LocalDataService>()
              .watchDelivererOrders(profile?.uid ?? ''),
          builder: (context, snapshot) {
            if (snapshot.hasError) return LoadError(error: snapshot.error!);
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final orders = snapshot.data!;
            final completed = orders
                .where((order) => order.status == OrderStatus.released)
                .toList();
            final pending = orders
                .where((order) => order.status == OrderStatus.delivered)
                .fold<double>(0, (sum, order) => sum + order.payout);
            final earned =
                completed.fold<double>(0, (sum, order) => sum + order.payout);
            return Column(children: [
              DetailRow('Released delivery earnings',
                  'NGN ${earned.toStringAsFixed(2)}'),
              DetailRow('Awaiting sender confirmation',
                  'NGN ${pending.toStringAsFixed(2)}'),
              DetailRow('Completed deliveries', '${completed.length}')
            ]);
          }),
      const SizedBox(height: 18),
      const RouteTile(
          title: 'Withdraw earnings',
          icon: Icons.account_balance_outlined,
          route: '/withdraw'),
      const RouteTile(
          title: 'Payout history',
          icon: Icons.receipt_long_outlined,
          route: '/payouts'),
      const RouteTile(
          title: 'Transactions', icon: Icons.swap_vert, route: '/transactions'),
      const RouteTile(
          title: 'Earnings analytics',
          icon: Icons.insights_outlined,
          route: '/analytics'),
      const RouteTile(
          title: 'Payment methods',
          icon: Icons.credit_card,
          route: '/payment-methods'),
    ]);
  }
}
