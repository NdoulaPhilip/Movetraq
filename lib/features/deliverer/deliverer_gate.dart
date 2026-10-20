import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_page.dart';

/// A presentation guard only. Backend matching and commands still authorize every action.
class DelivererGate extends StatelessWidget {
  const DelivererGate(
      {super.key, required this.child, this.application = false});
  final Widget child;
  final bool application;
  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider>().profile;
    if (profile == null) {
      return const AppPage(title: 'Delivery workspace', children: [
        InfoBand(title: 'Sign in to access delivery work.'),
        RouteTile(title: 'Sign in', icon: Icons.login, route: '/signin')
      ]);
    }
    if (application || profile.isApprovedDeliverer) {
      return child;
    }
    return const DelivererAccessScreen();
  }
}

class DelivererAccessScreen extends StatelessWidget {
  const DelivererAccessScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      AppPage(title: 'Delivery access', children: [
        if (context.watch<AuthProvider>().approvalErrorMessage != null)
          LoadError(
              error: context.watch<AuthProvider>().approvalErrorMessage!,
              onRetry: () => context.read<AuthProvider>().refreshApproval()),
        InfoBand(
            title: 'Approval is required for delivery work.',
            body: context
                .watch<AuthProvider>()
                .profile
                ?.delivererVerificationStatus
                .replaceAll('_', ' ')),
        const RouteTile(
            title: 'Application and verification',
            icon: Icons.fact_check_outlined,
            route: '/verification'),
        const RouteTile(
            title: 'Start an application',
            icon: Icons.person_outline,
            route: '/deliverer-apply'),
      ]);
}
