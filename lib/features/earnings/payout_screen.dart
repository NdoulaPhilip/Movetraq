import 'package:flutter/material.dart';
import '../../screens/shared/feature_screen.dart';

class PayoutScreen extends StatelessWidget {
  const PayoutScreen({super.key});
  @override
  Widget build(BuildContext context) => const FeatureListScreen(
      title: 'Payout history',
      path: '/payouts',
      fields: ['amount_minor', 'status', 'reference'],
      createRoute: '/withdraw');
}
