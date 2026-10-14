import 'package:flutter/material.dart';
import '../../widgets/app_page.dart';

class ReleaseOtpScreen extends StatelessWidget {
  const ReleaseOtpScreen({super.key, required this.orderId});
  final String orderId;
  @override
  Widget build(BuildContext context) =>
      AppPage(title: 'Authorize payment release', children: [
        const InfoBand(
            title: 'Release verification unavailable',
            body:
                'A verified authorization code is required. No code has been sent and funds will not be released from this screen.',
            icon: Icons.lock_outline),
        RouteTile(
            title: 'Delivery summary',
            icon: Icons.inventory_2_outlined,
            route: '/delivery-summary',
            arguments: orderId),
        const SizedBox(height: 16),
        const TextField(
            enabled: false,
            keyboardType: TextInputType.number,
            decoration:
                InputDecoration(labelText: '6-digit authorization code')),
        const SizedBox(height: 24),
        const RouteTile(
            title: 'Contact support',
            icon: Icons.support_agent,
            route: '/support'),
      ]);
}
