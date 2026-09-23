import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/misc_models.dart';
import '../../providers/auth_provider.dart';
import '../../services/local_data_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/mini_map.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  (IconData, Color, Color) _visualFor(String type) {
    switch (type) {
      case 'pickup':
        return (Icons.inventory_2_outlined, AppColors.tint['lime']!, const Color(0xFFF6F9EC));
      case 'payment':
        return (Icons.credit_card, AppColors.tint['sky']!, const Color(0xFFF2F6FB));
      case 'promo':
        return (Icons.card_giftcard, AppColors.tint['peach']!, const Color(0xFFFCF3E9));
      case 'arriving':
      default:
        return (Icons.navigation_outlined, AppColors.ink, Colors.white);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider>().profile;
    final data = context.read<LocalDataService>();

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: CircleIconButton(icon: Icons.arrow_back, onTap: () => Navigator.maybePop(context)),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 14),
              child: Text('Notifications', style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700, fontSize: 24)),
            ),
            Expanded(
              child: profile == null
                  ? const SizedBox.shrink()
                  : StreamBuilder<List<NotificationItem>>(
                      stream: data.watchNotifications(profile.uid),
                      builder: (context, snap) {
                        final items = snap.data ?? [];
                        if (items.isEmpty) {
                          return const Center(child: Text('You\'re all caught up', style: TextStyle(color: AppColors.muted)));
                        }
                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 11),
                          itemBuilder: (context, i) {
                            final n = items[i];
                            final (icon, iconBoxBg, cardBg) = _visualFor(n.type);
                            final isDarkIcon = n.type == 'arriving';
                            return InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () => data.markNotificationRead(profile.uid, n.id),
                              child: Container(
                                padding: const EdgeInsets.all(15),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: AppColors.borderSoft),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: isDarkIcon ? AppColors.ink : iconBoxBg,
                                        borderRadius: BorderRadius.circular(13),
                                      ),
                                      child: Icon(icon, size: 20, color: isDarkIcon ? AppColors.accent : AppColors.ink),
                                    ),
                                    const SizedBox(width: 13),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(children: [
                                            Flexible(child: Text(n.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
                                            if (!n.read) ...[
                                              const SizedBox(width: 7),
                                              Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle)),
                                            ],
                                          ]),
                                          const SizedBox(height: 3),
                                          Text(n.body, style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft, height: 1.45)),
                                          const SizedBox(height: 6),
                                          Text(_relative(n.createdAt), style: const TextStyle(fontSize: 11.5, color: AppColors.faint, fontWeight: FontWeight.w500)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _relative(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }
}
