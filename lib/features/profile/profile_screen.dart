import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/app_user.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_page.dart';
import '../../core/routing/workspace_switch.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.profile;
    if (profile == null) {
      return const AppPage(title: 'Profile', embedded: true, children: [
        InfoBand(title: 'Sign in to view your profile'),
        RouteTile(title: 'Sign in', icon: Icons.login, route: '/signin')
      ]);
    }
    final deliverer = profile.activeRole == UserRole.deliverer;
    return AppPage(title: 'Profile', embedded: true, actions: [
      IconButton(
          tooltip: 'Settings',
          onPressed: () => Navigator.pushNamed(context, '/settings'),
          icon: const Icon(Icons.settings_outlined))
    ], children: [
      Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: AppColors.ink, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            CircleAvatar(
                radius: 25,
                backgroundColor: AppColors.accent,
                child: Text(profile.initials,
                    style: const TextStyle(
                        color: AppColors.ink, fontWeight: FontWeight.w700))),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(profile.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 5),
                  Text(profile.email,
                      style: const TextStyle(
                          color: Color(0xFFBAC3BE), fontSize: 12)),
                  if (profile.phone.isNotEmpty)
                    Text(profile.phone,
                        style: const TextStyle(
                            color: Color(0xFFBAC3BE), fontSize: 12)),
                ]))
          ])),
      const SizedBox(height: 16),
      RouteTile(
          title: '${profile.memberTier} membership',
          icon: Icons.workspace_premium_outlined,
          route: '/membership'),
      SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Deliverer mode'),
          subtitle: Text(deliverer ? 'Delivery workspace' : 'Sender workspace'),
          value: deliverer,
          onChanged: auth.isBusy
              ? null
              : (_) async {
                  if (!deliverer && !profile.verified) {
                    Navigator.pushNamed(context, '/delivery-opportunities');
                    return;
                  }
                  await WorkspaceSwitch.open(context,
                      deliverer: !deliverer, changeRole: auth.toggleRole);
                }),
      const Divider(color: AppColors.borderSoft),
      if (deliverer) ...[
        DetailRow('Completed deliveries', '${profile.totalDeliveries}'),
        DetailRow(
            'Customer rating',
            profile.totalDeliveries == 0
                ? 'Not rated yet'
                : profile.rating.toStringAsFixed(1)),
        const SectionTitle('Deliverer account'),
        const RouteTile(
            title: 'Availability & delivery preferences',
            icon: Icons.tune,
            route: '/deliverer-work-settings'),
        const RouteTile(
            title: 'Verification',
            icon: Icons.verified_user_outlined,
            route: '/verification'),
        const RouteTile(
            title: 'Earnings',
            icon: Icons.account_balance_wallet_outlined,
            route: '/deliverer-earnings'),
        const RouteTile(
            title: 'Payouts',
            icon: Icons.account_balance_outlined,
            route: '/payouts'),
        const RouteTile(
            title: 'Performance',
            icon: Icons.insights_outlined,
            route: '/performance'),
        const RouteTile(
            title: 'Past customers',
            icon: Icons.people_outline,
            route: '/past-customers'),
        const RouteTile(
            title: 'My delivery ads',
            icon: Icons.campaign_outlined,
            route: '/my-p2p-ads'),
        const Divider(color: AppColors.borderSoft),
      ],
      const SectionTitle('Your account'),
      const RouteTile(
          title: 'Personal details',
          icon: Icons.person_outline,
          route: '/personal-details'),
      RouteTile(
          title: 'MoveTraq Wallet',
          subtitle: 'NGN ${profile.walletBalance.toStringAsFixed(2)}',
          icon: Icons.account_balance_wallet_outlined,
          route: '/wallet'),
      const RouteTile(
          title: 'Saved addresses',
          icon: Icons.location_on_outlined,
          route: '/saved-addresses'),
      const RouteTile(
          title: 'Payment history',
          icon: Icons.receipt_long_outlined,
          route: '/transactions'),
      const RouteTile(
          title: 'Payment methods',
          icon: Icons.credit_card,
          route: '/payment-methods'),
      const Divider(color: AppColors.borderSoft),
      const RouteTile(
          title: 'Help & support', icon: Icons.help_outline, route: '/support'),
      const RouteTile(
          title: 'Safety', icon: Icons.shield_outlined, route: '/safety'),
      const RouteTile(
          title: 'Account settings',
          icon: Icons.settings_outlined,
          route: '/settings'),
      const SizedBox(height: 80),
    ]);
  }
}
