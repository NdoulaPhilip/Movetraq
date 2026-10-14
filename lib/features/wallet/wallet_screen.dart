import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/misc_models.dart';
import '../../providers/auth_provider.dart';
import '../../services/local_data_service.dart';
import '../../widgets/app_page.dart';
import '../../widgets/primary_button.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider>().profile;
    return AppPage(title: 'MoveTraq Wallet', children: [
      InfoBand(
          title: 'Available balance',
          body: profile == null
              ? 'Sign in to view your wallet.'
              : 'NGN ${profile.walletBalance.toStringAsFixed(2)}',
          dark: true,
          icon: Icons.account_balance_wallet_outlined),
      PrimaryButton(
          label: 'Add money',
          onPressed: () => Navigator.pushNamed(context, '/topup')),
      const SizedBox(height: 12),
      SecondaryButton(
          label: 'Withdraw',
          onPressed: () => Navigator.pushNamed(context, '/withdraw')),
      const SizedBox(height: 20),
      const SectionTitle('Recent transactions'),
      if (profile != null)
        StreamBuilder<List<WalletTransaction>>(
            stream: context
                .read<LocalDataService>()
                .watchWalletTransactions(profile.uid),
            builder: (context, snapshot) {
              if (snapshot.hasError) return LoadError(error: snapshot.error!);
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final items = snapshot.data!.take(5);
              if (items.isEmpty) {
                return const InfoBand(
                    title: 'No transactions yet',
                    icon: Icons.receipt_long_outlined);
              }
              return Column(children: [
                for (final item in items)
                  RouteTile(
                      title: item.title,
                      subtitle:
                          '${item.amount < 0 ? '-' : '+'}NGN ${item.amount.abs().toStringAsFixed(2)}',
                      icon: Icons.receipt_long_outlined,
                      route: '/transaction-detail',
                      arguments: item)
              ]);
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
          title: 'Payment methods',
          icon: Icons.credit_card,
          route: '/payment-methods'),
      const RouteTile(
          title: 'Payout history',
          icon: Icons.account_balance_outlined,
          route: '/payouts'),
    ]);
  }
}
