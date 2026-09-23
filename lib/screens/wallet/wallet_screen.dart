import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/misc_models.dart';
import '../../providers/auth_provider.dart';
import '../../services/local_data_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/mini_map.dart';
import '../../widgets/primary_button.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  Future<void> _withdraw(BuildContext context) async {
    final profile = context.read<AuthProvider>().profile;
    if (profile == null) return;
    final amount = profile.walletBalance <= 5000
        ? profile.walletBalance
        : 5000.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No available balance to withdraw.')),
      );
      return;
    }

    await context.read<LocalDataService>().addWalletTransaction(
          profile.uid,
          WalletTransaction(
            id: '',
            type: WalletTxType.withdrawal,
            title: 'Bank withdrawal',
            sub: 'GTBank **4471',
            amount: -amount,
            createdAt: DateTime.now(),
          ),
          balanceDelta: -amount,
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Withdrawal of ₦${amount.toStringAsFixed(0)} requested.')),
    );
  }

  IconData _iconFor(WalletTxType t) {
    switch (t) {
      case WalletTxType.escrowHold:
        return Icons.shield_outlined;
      case WalletTxType.topup:
        return Icons.account_balance_wallet_outlined;
      case WalletTxType.released:
        return Icons.check_circle_outline;
      case WalletTxType.refund:
        return Icons.replay_outlined;
      case WalletTxType.cashback:
        return Icons.star_outline;
      case WalletTxType.withdrawal:
        return Icons.arrow_upward;
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider>().profile;
    final data = context.read<LocalDataService>();
    if (profile == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            const ScreenHeader(title: 'Wallet'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(24)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('AVAILABLE BALANCE', style: TextStyle(fontSize: 12.5, color: Color(0xFF8A93A2), fontWeight: FontWeight.w600)),
                      Row(children: [
                        Icon(Icons.shield_outlined, size: 14, color: Color(0xFFC9CDD4)),
                        SizedBox(width: 5),
                        Text('Insured', style: TextStyle(fontSize: 11.5, color: Color(0xFFC9CDD4), fontWeight: FontWeight.w600)),
                      ]),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('₦${profile.walletBalance.toStringAsFixed(0)}',
                      style: const TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700, fontSize: 40, color: Colors.white)),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: PrimaryButton(
                          label: 'Add money',
                          height: 48,
                          background: AppColors.accent,
                          foreground: AppColors.ink,
                          trailingIcon: null,
                          onPressed: () => Navigator.pushNamed(context, '/topup'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton(
                            onPressed: () => _withdraw(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text('Withdraw', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('Transactions', style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w600, fontSize: 17)),
            const SizedBox(height: 12),
            StreamBuilder<List<WalletTransaction>>(
              stream: data.watchWalletTransactions(profile.uid),
              builder: (context, snap) {
                final txs = snap.data ?? [];
                if (txs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('No transactions yet', style: TextStyle(color: AppColors.muted))),
                  );
                }
                return Column(
                  children: txs.map((t) {
                    final credit = t.amount >= 0;
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.borderSoft))),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(color: AppColors.tint['sky'], borderRadius: BorderRadius.circular(13)),
                            child: Icon(_iconFor(t.type), size: 19, color: AppColors.ink),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                const SizedBox(height: 2),
                                Text(t.sub, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
                              ],
                            ),
                          ),
                          Text('${credit ? '+' : '-'}₦${t.amount.abs().toStringAsFixed(0)}',
                              style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700, fontSize: 14.5, color: credit ? AppColors.successDeep : AppColors.ink)),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
