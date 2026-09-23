import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/parcel_order.dart';
import '../../providers/auth_provider.dart';
import '../../services/local_data_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/mini_map.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.profile;
    final data = context.read<LocalDataService>();
    final firstName = (profile?.name.split(' ').first ?? 'there');

    final quickActions = [
      ('Send', Icons.send_outlined, '/send'),
      ('Track', Icons.my_location_outlined, '/track-list'),
      ('Wallet', Icons.account_balance_wallet_outlined, '/wallet'),
      ('Deliver', Icons.local_shipping_outlined, '/go-deliverer'),
    ];

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 108),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Deliver to', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                    Row(children: [
                      Icon(Icons.location_on, color: AppColors.accent, size: 16),
                      SizedBox(width: 5),
                      Text('Lekki Phase 1', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                      Icon(Icons.keyboard_arrow_down, size: 18),
                    ]),
                  ],
                ),
              ),
              CircleIconButton(
                icon: Icons.notifications_outlined,
                showDot: true,
                onTap: () => Navigator.pushNamed(context, '/notifications'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text.rich(
            TextSpan(
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 26, height: 1.12),
              children: [
                TextSpan(text: 'Good afternoon, $firstName.\n'),
                const TextSpan(text: 'What are we moving today?', style: TextStyle(color: AppColors.muted)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.pushNamed(context, '/send'),
            child: Container(
              height: 54,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: const Row(children: [
                Icon(Icons.search, color: AppColors.muted),
                SizedBox(width: 11),
                Text('Where to? Enter a destination…', style: TextStyle(color: AppColors.muted, fontSize: 15)),
              ]),
            ),
          ),
          const SizedBox(height: 18),
          if (profile != null)
            StreamBuilder<ParcelOrder?>(
              stream: data.watchActiveSenderOrder(profile.uid),
              builder: (context, snap) {
                final order = snap.data;
                if (order == null) return const SizedBox.shrink();
                return _ActiveDeliveryCard(order: order);
              },
            ),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.85,
            children: quickActions.map((q) {
              return InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () async {
                  if (q.$3 == '/go-deliverer') {
                    final auth = context.read<AuthProvider>();
                    final ok = await auth.toggleRole();
                    if (!context.mounted || ok || auth.errorMessage == null) {
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(auth.errorMessage!)),
                    );
                  } else {
                    Navigator.pushNamed(context, q.$3);
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.borderSoft),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.tint['lime'],
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(q.$2, size: 20, color: AppColors.ink),
                      ),
                      const SizedBox(height: 8),
                      Text(q.$1, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 26),
          const Text('Ways to move', style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w600, fontSize: 19, letterSpacing: -0.2)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.35,
            children: [
              _WayToMoveCard(
                icon: Icons.inventory_2_outlined,
                tint: AppColors.tint['peach']!,
                title: 'Send a parcel',
                sub: 'City-wide, tracked & insured',
                route: '/send',
              ),
              _WayToMoveCard(
                icon: Icons.shopping_bag_outlined,
                tint: AppColors.tint['sky']!,
                title: 'Food & groceries',
                sub: 'From your favourite spots',
                route: '/send',
              ),
              _WayToMoveCard(
                icon: Icons.description_outlined,
                tint: AppColors.tint['sand']!,
                title: 'Documents',
                sub: 'Same-day, signature on arrival',
                route: '/send',
              ),
              _WayToMoveCard(
                icon: Icons.bolt_outlined,
                tint: AppColors.tint['lime']!,
                title: 'Express',
                sub: 'Priority pickup, arrives fast',
                route: '/send',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(22)),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  right: -30,
                  top: -30,
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.14), shape: BoxShape.circle),
                  ),
                ),
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('20% off your next 3 sends',
                              style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w600, fontSize: 17, color: Colors.white, letterSpacing: -0.1)),
                          SizedBox(height: 4),
                          Text('Gold tier perk · auto-applied at checkout', style: TextStyle(fontSize: 12.5, color: Color(0xFF9AA3AF))),
                        ],
                      ),
                    ),
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.card_giftcard, color: AppColors.ink, size: 22),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WayToMoveCard extends StatelessWidget {
  final IconData icon;
  final Color tint;
  final String title;
  final String sub;
  final String route;
  const _WayToMoveCard({required this.icon, required this.tint, required this.title, required this.sub, required this.route});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => Navigator.pushNamed(context, route),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(22)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.62), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, size: 23, color: AppColors.ink),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.ink, letterSpacing: -0.1)),
                const SizedBox(height: 3),
                Text(sub, style: const TextStyle(fontSize: 12, color: Color(0xFF5A616C))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveDeliveryCard extends StatelessWidget {
  final ParcelOrder order;
  const _ActiveDeliveryCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(26),
      onTap: () => Navigator.pushNamed(context, '/live', arguments: order.id),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Container(
          color: AppColors.darkSurface,
          child: Column(
            children: [
              Stack(
                children: [
                  const MiniMap(height: 150),
                  Positioned(
                    left: 14,
                    top: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(100)),
                      child: const Text('In transit', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    const CircleAvatar(radius: 21, backgroundColor: Color(0xFF3A4250), child: Icon(Icons.person, color: Colors.white, size: 18)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(order.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14.5)),
                          const SizedBox(height: 2),
                          Text('${order.code} · ${order.delivererName ?? "Courier"} is on the way',
                              style: const TextStyle(color: Color(0xFF8A93A2), fontSize: 12), overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(12)),
                      child: const Row(children: [
                        Text('Track', style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w600, fontSize: 13.5)),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward, size: 15, color: AppColors.ink),
                      ]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
