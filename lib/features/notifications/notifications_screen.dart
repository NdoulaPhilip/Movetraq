import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/misc_models.dart';
import '../../providers/auth_provider.dart';
import '../../services/feature_gateway.dart';
import '../../services/local_data_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_page.dart';
import '../../widgets/design_ui.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Stream<List<NotificationItem>> _stream;
  String _filter = 'All';
  List<NotificationItem> _items = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    _stream = context
        .read<LocalDataService>()
        .watchNotifications(context.read<AuthProvider>().profile?.uid ?? '');
  }

  Future<void> _markRead([NotificationItem? item]) async {
    if (_busy) return;
    final uid = context.read<AuthProvider>().profile?.uid;
    if (uid == null) return;
    final pending = item == null
        ? _items.where((item) => !item.read).toList()
        : [if (!item.read) item];
    if (pending.isEmpty) return;
    setState(() => _busy = true);
    try {
      final data = context.read<LocalDataService>();
      for (final notification in pending) {
        await data.markNotificationRead(uid, notification.id);
      }
    } catch (error) {
      if (mounted) showActionError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(String? id) async {
    if (_busy ||
        !await confirmAction(
            context,
            id == null ? 'Clear notifications?' : 'Delete notification?',
            'This cannot be undone.') ||
        !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      final data = context.read<LocalDataService>();
      await FeatureGateway(data).request('Notification deletion', 'DELETE',
          id == null ? '/notifications' : '/notifications/$id');
      await data.refreshRemoteState();
      if (mounted) setState(_subscribe);
    } catch (error) {
      if (mounted) showActionError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _time(DateTime date) {
    final local = date.toLocal();
    final now = DateTime.now();
    final elapsed = now.difference(local);
    if (elapsed.isNegative || elapsed.inMinutes < 1) return 'Just now';
    if (elapsed.inHours < 1) return '${elapsed.inMinutes} min ago';
    if (elapsed.inHours < 24) return '${elapsed.inHours} hours ago';
    return shortDate(local);
  }

  (IconData, Color, Color) _appearance(String type) => switch (type) {
        'arriving' => (Icons.near_me, AppColors.ink, AppColors.accent),
        'payment' || 'wallet' => (
            Icons.account_balance_wallet_outlined,
            const Color(0xFFE5EEF9),
            const Color(0xFF2675E8)
          ),
        'promo' || 'reward' || 'rewards' => (
            Icons.card_giftcard_outlined,
            const Color(0xFFFFF1D8),
            const Color(0xFFDA8A0B)
          ),
        _ => (
            Icons.inventory_2_outlined,
            const Color(0xFFF0F4D9),
            AppColors.ink
          ),
      };

  @override
  Widget build(BuildContext context) => AppPage(
        title: 'Notifications',
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Filter notifications',
            initialValue: _filter,
            icon: const Icon(Icons.filter_list),
            onSelected: (value) => setState(() => _filter = value),
            itemBuilder: (_) => ['All', 'Unread', 'Orders', 'Payments']
                .map((value) => PopupMenuItem(value: value, child: Text(value)))
                .toList(),
          )
        ],
        children: [
          StreamBuilder<List<NotificationItem>>(
            stream: _stream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return LoadError(
                    error: snapshot.error!,
                    onRetry: () => setState(_subscribe));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              _items = snapshot.data!;
              final unread = _items.where((item) => !item.read).length;
              final items = _items
                  .where((item) =>
                      _filter == 'All' ||
                      (_filter == 'Unread' && !item.read) ||
                      (_filter == 'Orders' &&
                          ['delivery', 'pickup', 'arriving']
                              .contains(item.type)) ||
                      (_filter == 'Payments' &&
                          ['payment', 'wallet'].contains(item.type)))
                  .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        children: [
                          Text('$unread unread',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.muted)),
                          TextButton(
                              onPressed: _busy || unread == 0
                                  ? null
                                  : () => _markRead(),
                              child: const Text('Mark all read')),
                          TextButton(
                              onPressed: _busy || _items.isEmpty
                                  ? null
                                  : () => _delete(null),
                              child: const Text('Clear all')),
                        ]),
                    if (_filter != 'All')
                      Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: DesignBadge(_filter)),
                    const SizedBox(height: 18),
                    if (items.isEmpty)
                      DesignNote(
                          title: _filter == 'All'
                              ? 'You are all caught up'
                              : 'No ${_filter.toLowerCase()} notifications',
                          body:
                              'Delivery, payment and account updates will appear here.'),
                    for (final item in items) ...[
                      _notification(item),
                      const SizedBox(height: 12),
                    ],
                  ]);
            },
          ),
          const RouteTile(
              title: 'Notification preferences',
              icon: Icons.tune,
              route: '/notification-preferences'),
        ],
      );

  Widget _notification(NotificationItem item) {
    final (icon, background, foreground) = _appearance(item.type);
    return DesignCard(
        color: item.read ? const Color(0xFFFAFBF7) : Colors.white,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  color: background, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: foreground, size: 21)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(item.title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(item.body,
                    style: const TextStyle(
                        fontSize: 13, height: 1.6, color: AppColors.muted)),
                const SizedBox(height: 8),
                Text(_time(item.createdAt),
                    style:
                        const TextStyle(fontSize: 11, color: AppColors.muted)),
                if (!item.read)
                  TextButton(
                      style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          alignment: Alignment.centerLeft),
                      onPressed: _busy ? null : () => _markRead(item),
                      child: const Text('Mark read')),
              ])),
          IconButton(
              tooltip: 'Delete notification',
              visualDensity: VisualDensity.compact,
              onPressed: _busy ? null : () => _delete(item.id),
              icon: const Icon(Icons.close, size: 19, color: AppColors.muted)),
        ]));
  }
}
