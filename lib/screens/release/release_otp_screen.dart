import 'package:flutter/material.dart';
import '../../widgets/app_page.dart';

class ReleaseOtpScreen extends StatelessWidget {
  const ReleaseOtpScreen({super.key, required this.orderId});
  final String orderId;
  @override
  Widget build(BuildContext context) => AppPage(
          title: 'Authorize release',
          subtitle:
              'Enter your six-digit authorization code when verification is available.',
          children: [
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
            Row(children: [
              for (var i = 0; i < 6; i++)
                Expanded(
                    child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: TextField(
                            enabled: false,
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 18),
                                semanticCounterText: 'Authorization digit',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(13))))))
            ]),
            const SizedBox(height: 18),
            const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.verified_user_outlined,
                  size: 16, color: Color(0xFF98A1AF)),
              SizedBox(width: 8),
              Flexible(
                  child: Text('Protected by MoveTraq escrow',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 12, color: Color(0xFF98A1AF)))),
            ]),
            const SizedBox(height: 24),
            const RouteTile(
                title: 'Contact support',
                icon: Icons.support_agent,
                route: '/support'),
          ]);
}
