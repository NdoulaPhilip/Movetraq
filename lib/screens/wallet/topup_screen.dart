import 'package:flutter/material.dart';
import '../shared/feature_screen.dart';

class TopupScreen extends StatelessWidget {
  const TopupScreen({super.key});
  @override
  Widget build(BuildContext context) => const FeatureFormScreen(
          title: 'Add money',
          subtitle:
              'Funds are credited only after payment-provider verification.',
          action: 'Continue to payment',
          path: '/payments/initialize',
          review: true,
          fixedValues: {
            'purpose': 'wallet_topup'
          },
          fields: [
            FormFieldSpec('amountMinor', 'Amount (NGN)', kind: FieldKind.money),
            FormFieldSpec('channel', 'Payment method',
                options: ['card', 'bank_transfer'])
          ]);
}
