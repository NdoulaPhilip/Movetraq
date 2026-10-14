import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/misc_models.dart';
import '../../providers/auth_provider.dart';
import '../../services/feature_gateway.dart';
import '../../services/local_data_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_page.dart';
import '../../widgets/premium_ui.dart';

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
    _stream = context
        .read<LocalDataService>()
        .watchNotifications(context.read<AuthProvider>().profile?.uid ?? '');
  }

  Future<void> _read(NotificationItem item) async {
    final uid = context.read<AuthProvider>().profile?.uid;
    if (uid == null) return;
    try {
      await context.read<LocalDataService>().markNotificationRead(uid, item.id);
    } catch (error) {
      if (mounted) showActionError(context, error);
    }
  }

  Future<void> _markAll() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      for (final item in _items.where((item) => !item.read).toList()) {
        await _read(item);
      }
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
      await FeatureGateway(context.read<LocalDataService>()).request(
          'Notification deletion',
          'DELETE',
          id == null ? '/notifications' : '/notifications/$id');
    } catch (error) {
      if (mounted) showActionError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      AppPage(title: 'Notifications', actions: [
        IconButton(
            tooltip: 'Mark all read',
            onPressed: _busy ? null : _markAll,
            icon: const Icon(Icons.done_all)),
        IconButton(
            tooltip: 'Clear notifications',
            onPressed: _busy ? null : () => _delete(null),
            icon: const Icon(Icons.clear_all))
      ], children: [
        Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['All', 'Unread', 'Orders', 'Payments']
                .map((value) => ChoiceChip(
                    label: Text(value),
                    selected: value == _filter,
                    onSelected: (_) => setState(() => _filter = value)))
                .toList()),
        const SizedBox(height: 18),
        StreamBuilder<List<NotificationItem>>(
            stream: _stream,
            builder: (context, snapshot) {
              if (snapshot.hasError) return LoadError(error: snapshot.error!);
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
                  .toList();
              return Column(children: [
                if (unread > 0)
                  InfoBand(
                      title: '$unread unread notifications',
                      icon: Icons.notifications_outlined),
                if (items.isEmpty)
                  const PremiumEmptyState(
                      icon: Icons.notifications_none_outlined,
                      title: 'You are all caught up',
                      body: ''),
                for (final item in items)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: PremiumSurface(
                          color: item.read
                              ? Colors.white
                              : AppColors.tint['lime']!,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Expanded(
                                      child: Text(item.title,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600))),
                                  IconButton(
                                      tooltip: 'Mark read',
                                      onPressed: item.read || _busy
                                          ? null
                                          : () => _read(item),
                                      icon: const Icon(Icons.done_outlined,
                                          size: 18)),
                                  IconButton(
                                      tooltip: 'Delete notification',
                                      onPressed:
                                          _busy ? null : () => _delete(item.id),
                                      icon: const Icon(Icons.delete_outline,
                                          size: 18))
                                ]),
                                Text(item.body,
                                    style: const TextStyle(
                                        fontSize: 12, height: 1.5)),
                                const SizedBox(height: 10),
                                Text(item.createdAt.toLocal().toString(),
                                    style: const TextStyle(
                                        fontSize: 10, color: AppColors.muted)),
                              ]))),
              ]);
            }),
        const RouteTile(
            title: 'Notification preferences',
            icon: Icons.tune,
            route: '/notification-preferences'),
      ]);
}
