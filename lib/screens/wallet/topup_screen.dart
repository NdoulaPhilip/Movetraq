import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/misc_models.dart';
import '../../providers/auth_provider.dart';
import '../../services/local_data_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/mini_map.dart';
import '../../widgets/primary_button.dart';

class TopupScreen extends StatefulWidget {
  const TopupScreen({super.key});

  @override
  State<TopupScreen> createState() => _TopupScreenState();
}

class _TopupScreenState extends State<TopupScreen> {
  double _amount = 5000;
  String _method = 'wallet_card';
  bool _busy = false;

  Future<void> _confirm() async {
    final auth = context.read<AuthProvider>();
    final data = context.read<LocalDataService>();
    final uid = auth.profile?.uid;
    if (uid == null) return;
    setState(() => _busy = true);
    await data.addWalletTransaction(
      uid,
      WalletTransaction(
        id: '',
        type: WalletTxType.topup,
        title: 'Wallet top-up',
        sub: _method == 'wallet_card' ? 'Debit card' : 'Bank transfer',
        amount: _amount,
        createdAt: DateTime.now(),
      ),
      balanceDelta: _amount,
    );
    if (mounted) {
      setState(() => _busy = false);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final presets = [2000.0, 5000.0, 10000.0];
    final methods = [
      ('wallet_card', 'Debit card', 'Mastercard ••8901', Icons.credit_card),
      ('wallet_bank', 'Bank transfer', 'GTBank ••4471', Icons.account_balance_outlined),
    ];

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            const ScreenHeader(title: 'Add money'),
            const SizedBox(height: 12),
            const Text('Add money', style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700, fontSize: 24)),
            const SizedBox(height: 6),
            const Text('Top up your wallet to fund deliveries instantly.', style: TextStyle(fontSize: 13.5, color: AppColors.muted)),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(22)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('AMOUNT TO ADD', style: TextStyle(fontSize: 12, color: Color(0xFF8A93A2), fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text('₦${_amount.toStringAsFixed(0)}', style: const TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700, fontSize: 40, color: Colors.white)),
                  const SizedBox(height: 16),
                  Row(
                    children: presets.map((p) {
                      final selected = _amount == p;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: OutlinedButton(
                            onPressed: () => setState(() => _amount = p),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: selected ? AppColors.accent : Colors.transparent,
                              foregroundColor: selected ? AppColors.ink : Colors.white,
                              side: BorderSide(color: selected ? AppColors.accent : Colors.white.withValues(alpha: 0.18)),
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text('₦${p.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const Text('Pay with', style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 12),
            ...methods.map((m) {
              final selected = _method == m.$1;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => setState(() => _method = m.$1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: selected ? AppColors.ink : AppColors.border, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(color: AppColors.tint['sky'], borderRadius: BorderRadius.circular(12)),
                          child: Icon(m.$4, color: AppColors.ink),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m.$2, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                              Text(m.$3, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
                            ],
                          ),
                        ),
                        Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: selected ? AppColors.ink : AppColors.faint),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 10),
            PrimaryButton(label: 'Add ₦${_amount.toStringAsFixed(0)} to wallet', loading: _busy, onPressed: _confirm),
          ],
        ),
      ),
    );
  }
}
