import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../screens/shared/feature_screen.dart';
import '../../widgets/design_ui.dart';
import '../../theme/app_theme.dart';

class WithdrawScreen extends StatelessWidget {
  const WithdrawScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider>().profile;
    return FeatureFormScreen(
        title: 'Withdraw money',
        subtitle:
            'Choose an amount and payout method, then review your withdrawal.',
        intro: DesignNote(
            title: profile == null
                ? 'Sign in to view your balance'
                : naira(profile.walletBalance),
            body: 'Available balance'),
        action: 'Review withdrawal',
        path: '/payouts',
        review: true,
        dangerous: true,
        buttonColor: AppColors.ink,
        fields: const [
          FormFieldSpec('amountMinor', 'Amount (NGN)', kind: FieldKind.money),
          FormFieldSpec('bankCode', 'Bank code'),
          FormFieldSpec('accountNumber', 'Account number'),
        ]);
  }
}
