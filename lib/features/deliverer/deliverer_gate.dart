import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_page.dart';
import '../../models/app_user.dart';

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
    if (application ||
        (profile.verified && profile.activeRole == UserRole.deliverer)) {
      return child;
    }
    return const DelivererAccessScreen();
  }
}

class DelivererAccessScreen extends StatelessWidget {
  const DelivererAccessScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const AppPage(title: 'Delivery access', children: [
        InfoBand(title: 'Approval is required for delivery work.'),
        RouteTile(
            title: 'Application and verification',
            icon: Icons.fact_check_outlined,
            route: '/verification'),
        RouteTile(
            title: 'Start an application',
            icon: Icons.person_outline,
            route: '/deliverer-apply'),
      ]);
}
