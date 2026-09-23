import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/misc_models.dart';
import '../../models/parcel_order.dart';
import '../../providers/auth_provider.dart';
import '../../services/local_data_service.dart';
import '../../theme/app_theme.dart';

enum _EventKind { delivered, outForDelivery, payment, tier, cancelled }

class _ActivityEvent {
  final _EventKind kind;
  final String title;
  final String sub;
  final DateTime time;
  _ActivityEvent({required this.kind, required this.title, required this.sub, required this.time});
}

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  (IconData, Color, Color) _style(_EventKind k) {
    switch (k) {
      case _EventKind.delivered:
        return (Icons.check, AppColors.tint['mint']!, const Color(0xFF12B76A));
      case _EventKind.outForDelivery:
        return (Icons.navigation, AppColors.ink, AppColors.ink);
      case _EventKind.payment:
        return (Icons.credit_card, AppColors.tint['sky']!, AppColors.ink);
      case _EventKind.tier:
        return (Icons.star, AppColors.tint['peach']!, AppColors.warning);
      case _EventKind.cancelled:
        return (Icons.close, const Color(0xFFFBE3E1), AppColors.danger);
    }
  }

  String _relative(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inHours < 1) return diff.inMinutes <= 1 ? 'Just now' : '${diff.inMinutes}m';
    if (diff.inHours < 24 && d.day == now.day) return '${diff.inHours}h';
    final yesterday = now.subtract(const Duration(days: 1));
    if (d.year == yesterday.year && d.month == yesterday.month && d.day == yesterday.day) return 'Yst';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}';
  }

  List<_ActivityEvent> _buildFeed(List<ParcelOrder> orders, List<WalletTransaction> txs, String memberTier) {
    final events = <_ActivityEvent>[];
    for (final o in orders) {
      if (o.status == OrderStatus.released) {
        events.add(_ActivityEvent(
          kind: _EventKind.delivered,
          title: 'Delivered to ${o.dropoffAddress}',
          sub: '${o.code} · ${o.title}',
          time: o.releasedAt ?? o.createdAt,
        ));
      } else if (o.status == OrderStatus.pickedUp) {
        events.add(_ActivityEvent(
          kind: _EventKind.outForDelivery,
          title: 'Out for delivery',
          sub: '${o.code} · ${o.title}',
          time: o.createdAt,
        ));
      } else if (o.status == OrderStatus.cancelled) {
        events.add(_ActivityEvent(
          kind: _EventKind.cancelled,
          title: 'Order cancelled',
          sub: '${o.code} · ${o.title} · refunded',
          time: o.createdAt,
        ));
      }
    }
    for (final t in txs) {
      if (t.type == WalletTxType.escrowHold || t.type == WalletTxType.released) {
        events.add(_ActivityEvent(
          kind: _EventKind.payment,
          title: 'Payment successful',
          sub: '₦${t.amount.abs().toStringAsFixed(0)} · ${t.sub}',
          time: t.createdAt,
        ));
      }
    }
    if (memberTier.toLowerCase() == 'gold') {
      events.add(_ActivityEvent(
        kind: _EventKind.tier,
        title: 'You reached Gold tier',
        sub: 'Enjoy free pickups & 20% off',
        time: DateTime.now().subtract(const Duration(days: 6)),
      ));
    }
    events.sort((a, b) => b.time.compareTo(a.time));
    return events;
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider>().profile;
    final data = context.read<LocalDataService>();
    if (profile == null) return const Center(child: CircularProgressIndicator());

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 108),
        children: [
          const Text('Activity', style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700, fontSize: 26)),
          const SizedBox(height: 4),
          const Text('Your delivery timeline', style: TextStyle(fontSize: 13.5, color: AppColors.muted)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(20)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${profile.totalDeliveries}',
                          style: const TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700, fontSize: 26, color: Colors.white)),
                      const SizedBox(height: 2),
                      const Text('Total deliveries', style: TextStyle(fontSize: 12, color: Color(0xFF9AA3AF))),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(20)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(profile.memberTier,
                          style: const TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700, fontSize: 26, color: AppColors.ink)),
                      const SizedBox(height: 2),
                      const Text('Member tier', style: TextStyle(fontSize: 12, color: Color(0xFF4A5215), fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          StreamBuilder<List<ParcelOrder>>(
            stream: data.watchSenderOrders(profile.uid),
            builder: (context, orderSnap) {
              return StreamBuilder<List<WalletTransaction>>(
                stream: data.watchWalletTransactions(profile.uid),
                builder: (context, txSnap) {
                  final feed = _buildFeed(orderSnap.data ?? [], txSnap.data ?? [], profile.memberTier);
                  if (feed.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Center(child: Text('Nothing here yet', style: TextStyle(color: AppColors.muted))),
                    );
                  }
                  return Column(
                    children: feed.map((e) {
                      final (icon, bg, iconColor) = _style(e.kind);
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.borderSoft))),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: e.kind == _EventKind.outForDelivery ? AppColors.ink : bg,
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Icon(icon, size: 19,
                                  color: e.kind == _EventKind.outForDelivery ? AppColors.accent : iconColor),
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(e.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                  const SizedBox(height: 2),
                                  Text(e.sub, style: const TextStyle(fontSize: 12.5, color: AppColors.muted), overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                            Text(_relative(e.time), style: const TextStyle(fontSize: 12, color: AppColors.faint, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
