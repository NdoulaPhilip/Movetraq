import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.profile;
    if (profile == null) return const Center(child: CircularProgressIndicator());

    final isSender = profile.activeRole == UserRole.sender;
    final menu = [
      ('Personal details', 'Name, phone, email', Icons.person_outline, () {}),
      ('MoveTraq Wallet', '₦${profile.walletBalance.toStringAsFixed(0)} · 2 methods', Icons.account_balance_wallet_outlined,
          () => Navigator.pushNamed(context, '/wallet')),
      ('Saved addresses', 'Home, Work · +2 more', Icons.location_on_outlined, () {}),
      ('Security & PIN', 'Biometrics on', Icons.shield_outlined, () {}),
      ('Notifications', 'Push, SMS, email', Icons.notifications_outlined, () => Navigator.pushNamed(context, '/notifications')),
      ('Help & support', '24/7 live chat', Icons.chat_bubble_outline, () {}),
    ];

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 108),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Profile', style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700, fontSize: 26)),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: AppColors.borderSoft),
                ),
                child: const Icon(Icons.tune, size: 18, color: AppColors.ink),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Dark identity card
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(color: AppColors.ink),
              child: Stack(
                children: [
                  Positioned(
                    right: -30,
                    bottom: -30,
                    child: Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.14), shape: BoxShape.circle),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.accent,
                        child: Text(profile.initials,
                            style: const TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.ink)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(profile.name,
                                style: const TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w600, fontSize: 17, color: Colors.white)),
                            const SizedBox(height: 4),
                            Text(_maskedPhone(profile.phone), style: const TextStyle(color: Color(0xFF8A93A2), fontSize: 13)),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                              decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(100)),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.star, size: 13, color: AppColors.ink),
                                const SizedBox(width: 5),
                                Text('${profile.memberTier.toUpperCase()} MEMBER',
                                    style: const TextStyle(color: AppColors.ink, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                              ]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Switch role card
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: auth.isBusy
                ? null
                : () async {
                    final ok = await auth.toggleRole();
                    if (!context.mounted || ok || auth.errorMessage == null) {
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(auth.errorMessage!)),
                    );
                  },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderSoft),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(13)),
                    child: Icon(isSender ? Icons.local_shipping_outlined : Icons.send_outlined, color: AppColors.ink, size: 20),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isSender ? 'Switch to delivering' : 'Switch to sending',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text(
                          isSender ? 'Earn money delivering nearby jobs' : 'Send & track your own parcels',
                          style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward, size: 18, color: AppColors.ink),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Menu list
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.borderSoft),
            ),
            child: Column(
              children: List.generate(menu.length, (i) {
                final m = menu[i];
                return Column(
                  children: [
                    ListTile(
                      onTap: m.$4,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      leading: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(color: const Color(0xFFF3F2EC), borderRadius: BorderRadius.circular(11)),
                        child: Icon(m.$3, size: 18, color: AppColors.ink),
                      ),
                      title: Text(m.$1, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                      subtitle: Text(m.$2, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                      trailing: const Icon(Icons.chevron_right, color: AppColors.faint, size: 20),
                    ),
                    if (i != menu.length - 1) const Divider(height: 1, indent: 68, color: AppColors.borderSoft),
                  ],
                );
              }),
            ),
          ),
          const SizedBox(height: 16),
          // Sign out
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.danger.withValues(alpha: 0.35)),
            ),
            child: TextButton(
              onPressed: () async {
                await auth.signOut();
                if (context.mounted) Navigator.of(context).pushNamedAndRemoveUntil('/onboard', (r) => false);
              },
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              child: const Text('Sign out', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600, fontSize: 15)),
            ),
          ),
          const SizedBox(height: 14),
          const Center(
            child: Text('MoveTraq · v3.0', style: TextStyle(fontSize: 12, color: AppColors.faint)),
          ),
        ],
      ),
    );
  }

  String _maskedPhone(String phone) {
    if (phone.isEmpty) return '+234 803 •••• 4821';
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7) return phone;
    final start = digits.substring(0, digits.length >= 9 ? digits.length - 7 : 0);
    final end = digits.substring(digits.length - 4);
    return '+$start •••• $end';
  }
}
