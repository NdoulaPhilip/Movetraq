import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/app_user.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/design_ui.dart';
import '../../models/misc_models.dart';
import '../../models/parcel_order.dart';
import '../../services/local_data_service.dart';
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
        DesignMenuTile(title: 'Sign in', icon: Icons.login, route: '/signin')
      ]);
    }
    final deliverer =
        profile.isApprovedDeliverer && profile.activeRole == UserRole.deliverer;
    return AppPage(title: 'Profile', embedded: true, actions: [
      IconButton(
          tooltip: 'Settings',
          onPressed: () => Navigator.pushNamed(context, '/settings'),
          icon: const Icon(Icons.settings_outlined))
    ], children: [
      Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: AppColors.ink, borderRadius: BorderRadius.circular(21)),
          child: Row(children: [
            CircleAvatar(
                radius: 29,
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
      Material(
        color: const Color(0xFFF3EEDC),
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 17, vertical: 5),
          leading: const Icon(Icons.verified_user_outlined,
              color: Color(0xFF766024)),
          title: Text('${profile.memberTier} member',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF766024))),
          subtitle: const Text('Manage your membership and account details',
              style: TextStyle(fontSize: 11, color: Color(0xFF766024))),
          onTap: () => Navigator.pushNamed(context, '/membership'),
        ),
      ),
      const SizedBox(height: 14),
      DesignCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Switch to delivery work'),
              subtitle: Text(deliverer
                  ? 'Delivery workspace is active'
                  : 'Turn on to open your delivery workspace'),
              value: deliverer,
              onChanged: auth.isBusy
                  ? null
                  : (_) async {
                      if (!deliverer && !profile.isApprovedDeliverer) {
                        Navigator.pushNamed(context, '/verification');
                        return;
                      }
                      await WorkspaceSwitch.open(context,
                          deliverer: !deliverer, changeRole: auth.toggleRole);
                    })),
      const SizedBox(height: 16),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child: StreamBuilder<List<ParcelOrder>>(
                key: ValueKey('orders-${profile.uid}'),
                stream: context
                    .read<LocalDataService>()
                    .watchSenderOrders(profile.uid),
                builder: (context, snapshot) => DesignNote(
                    title: snapshot.hasData
                        ? snapshot.data!.length.toString()
                        : '\u2014',
                    body: 'Deliveries'))),
        const SizedBox(width: 10),
        Expanded(
            child: StreamBuilder<List<SavedAddress>>(
                key: ValueKey('addresses-${profile.uid}'),
                stream: context
                    .read<LocalDataService>()
                    .watchSavedAddresses(profile.uid),
                builder: (context, snapshot) => DesignNote(
                    title: snapshot.hasData
                        ? snapshot.data!.length.toString()
                        : '\u2014',
                    body: 'Addresses'))),
      ]),
      if (deliverer) ...[
        DetailRow('Completed deliveries', '${profile.totalDeliveries}'),
        DetailRow(
            'Customer rating',
            profile.totalDeliveries == 0
                ? 'Not rated yet'
                : profile.rating.toStringAsFixed(1)),
        const SectionTitle('Deliverer account'),
        const DesignMenuTile(
            title: 'Availability & delivery preferences',
            icon: Icons.tune,
            route: '/deliverer-work-settings'),
        const DesignMenuTile(
            title: 'Verification',
            icon: Icons.verified_user_outlined,
            route: '/verification'),
        const DesignMenuTile(
            title: 'Earnings',
            icon: Icons.account_balance_wallet_outlined,
            route: '/deliverer-earnings'),
        const DesignMenuTile(
            title: 'Payouts',
            icon: Icons.account_balance_outlined,
            route: '/payouts'),
        const DesignMenuTile(
            title: 'Performance',
            icon: Icons.insights_outlined,
            route: '/performance'),
        const DesignMenuTile(
            title: 'Past customers',
            icon: Icons.people_outline,
            route: '/past-customers'),
        const DesignMenuTile(
            title: 'My delivery ads',
            icon: Icons.campaign_outlined,
            route: '/my-p2p-ads'),
        const Divider(color: AppColors.borderSoft),
      ],
      const SizedBox(height: 4),
      DesignCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(children: [
            const DesignMenuTile(
                title: 'Delivery verification',
                subtitle: 'Review identity, transport and safety details',
                icon: Icons.verified_user_outlined,
                route: '/verification'),
            const DesignMenuTile(
                title: 'Personal details',
                subtitle: 'Manage your name, phone number and email',
                icon: Icons.person_outline,
                route: '/personal-details'),
            DesignMenuTile(
                title: 'MoveTraq Wallet',
                subtitle: '${naira(profile.walletBalance)} · payment methods',
                icon: Icons.account_balance_wallet_outlined,
                route: '/wallet'),
            const DesignMenuTile(
                title: 'Saved addresses',
                subtitle: 'Manage your saved locations',
                icon: Icons.location_on_outlined,
                route: '/saved-addresses'),
            const DesignMenuTile(
                title: 'Payment history',
                icon: Icons.receipt_long_outlined,
                route: '/transactions'),
            const DesignMenuTile(
                title: 'Payment methods',
                subtitle: 'Add, edit or remove payment options',
                icon: Icons.credit_card,
                route: '/payment-methods'),
            const Divider(color: AppColors.borderSoft),
            const DesignMenuTile(
                title: 'Help & support',
                icon: Icons.help_outline,
                route: '/support'),
            const DesignMenuTile(
                title: 'Safety', icon: Icons.shield_outlined, route: '/safety'),
            const DesignMenuTile(
                title: 'Account settings',
                icon: Icons.settings_outlined,
                route: '/settings'),
          ])),
      const SizedBox(height: 80),
    ]);
  }
}
