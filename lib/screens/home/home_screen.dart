import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../models/misc_models.dart';
import '../../models/parcel_order.dart';
import '../../providers/auth_provider.dart';
import '../../providers/send_flow_provider.dart';
import '../../services/local_data_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/mini_map.dart';
import '../../widgets/movetraq_brand.dart';
import '../../features/addresses/home_location_picker.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _userId;
  Future<String>? _greeting;
  Stream<List<SavedAddress>>? _addresses;
  Stream<List<ParcelOrder>>? _orders;
  bool _refreshFailed = false;
  bool _refreshing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uid = context.watch<AuthProvider>().profile?.uid;
    if (_greeting == null || _userId != uid) {
      _userId = uid;
      _refreshFailed = false;
      _loadStreams();
    }
  }

  void _loadStreams() {
    final data = context.read<LocalDataService>();
    _greeting = data.homeContext().then((home) => home.greeting);
    _addresses = _userId == null ? null : data.watchSavedAddresses(_userId!);
    _orders = _userId == null ? null : data.watchSenderOrders(_userId!);
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    final uid = _userId;
    try {
      await context.read<LocalDataService>().refreshRemoteState();
      if (!mounted || uid != _userId) return;
      setState(() {
        _refreshFailed = false;
        _loadStreams();
      });
      await _greeting;
    } catch (_) {
      if (mounted && uid == _userId) setState(() => _refreshFailed = true);
    } finally {
      _refreshing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider>().profile;
    final pickup = context.watch<SendFlowProvider>().pickupAddress.trim();
    return FutureBuilder<String>(
        future: _greeting,
        builder: (context, greeting) => StreamBuilder<List<SavedAddress>>(
            key: ValueKey('home-addresses-$_userId'),
            stream: _addresses,
            builder: (context, addresses) => StreamBuilder<List<ParcelOrder>>(
                key: ValueKey('home-orders-$_userId'),
                stream: _orders,
                builder: (context, orders) {
                  String? current;
                  for (final address in addresses.data ?? <SavedAddress>[]) {
                    if (address.isDefault) {
                      current = address.address;
                      break;
                    }
                  }
                  final active = (orders.data ?? <ParcelOrder>[])
                      .where((order) =>
                          order.senderId == profile?.uid &&
                          order.status != OrderStatus.released &&
                          order.status != OrderStatus.cancelled)
                      .toList()
                    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                  return HomeContent(
                    profile: profile,
                    greeting: greeting.data,
                    currentLocation: pickup.isNotEmpty ? pickup : current,
                    recentOrder: active.isEmpty ? null : active.first,
                    connectionError: _refreshFailed ||
                        greeting.hasError ||
                        addresses.hasError ||
                        orders.hasError,
                    onLocationTap: () => chooseHomeLocation(context),
                    onRefresh: _refresh,
                  );
                })));
  }
}

class HomeContent extends StatelessWidget {
  const HomeContent(
      {super.key,
      this.profile,
      this.recentOrder,
      this.currentLocation,
      this.greeting,
      this.connectionError = false,
      this.onLocationTap,
      this.onRefresh,
      this.onNavigate});
  final AppUser? profile;
  final ParcelOrder? recentOrder;
  final String? currentLocation;
  final String? greeting;
  final bool connectionError;
  final VoidCallback? onLocationTap;
  final Future<void> Function()? onRefresh;
  final void Function(String route, Object? arguments)? onNavigate;

  void _open(BuildContext context, String route, [Object? arguments]) {
    if (onNavigate != null) {
      onNavigate!(route, arguments);
    } else {
      Navigator.pushNamed(context, route, arguments: arguments);
    }
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    return hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
  }

  String _status(OrderStatus status) => switch (status) {
        OrderStatus.pendingOffer => 'Awaiting deliverer',
        OrderStatus.negotiating => 'Offer negotiation',
        OrderStatus.accepted => 'Deliverer assigned',
        OrderStatus.pickedUp => 'On the way',
        OrderStatus.delivered => 'Awaiting your confirmation',
        OrderStatus.released => 'Completed',
        OrderStatus.cancelled => 'Cancelled',
      };

  @override
  Widget build(BuildContext context) {
    final name = profile?.name.trim() ?? '';
    final firstName = name.isEmpty ? 'there' : name.split(RegExp(r'\s+')).first;
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final quick = [
      ('Send', Icons.send_outlined, 'lime', '/send'),
      ('P2P delivery', Icons.local_shipping_outlined, 'lime', '/p2p-requests'),
      ('Receive', Icons.inventory_2_outlined, 'peach', '/receive'),
      ('Schedule', Icons.calendar_today_outlined, 'mint', '/schedule'),
    ];
    final services = [
      (
        'Send a package',
        'Doorstep pickup',
        Icons.send_outlined,
        'lime',
        '/send'
      ),
      (
        'Receive items',
        'Track incoming',
        Icons.inventory_2_outlined,
        'peach',
        '/receive'
      ),
      (
        'Run an errand',
        'Shop & drop',
        Icons.shopping_bag_outlined,
        'sky',
        '/errand'
      ),
      (
        'Big move',
        'Furniture & more',
        Icons.local_shipping_outlined,
        'mint',
        '/big-move'
      ),
    ];
    final list = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 108),
        children: [
          Row(children: [
            Expanded(
                child: InkWell(
                    onTap: onLocationTap ??
                        () => _open(context, '/select-address'),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Current location',
                              style: TextStyle(
                                  fontSize: 11, color: AppColors.muted)),
                          const SizedBox(height: 4),
                          Row(children: [
                            const Icon(Icons.location_on_outlined,
                                size: 16, color: Color(0xFF79913B)),
                            const SizedBox(width: 5),
                            Flexible(
                                child: Text(
                                    currentLocation?.trim().isNotEmpty == true
                                        ? currentLocation!
                                        : 'Choose your location',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600))),
                            const Icon(Icons.keyboard_arrow_down, size: 18),
                          ]),
                        ]))),
            const SizedBox(width: 12),
            CircleIconButton(
                icon: Icons.notifications_outlined,
                onTap: () => _open(context, '/notifications')),
          ]),
          const SizedBox(height: 24),
          Text('${greeting ?? _greeting()}, $firstName.',
              style: const TextStyle(
                  fontSize: 25, fontWeight: FontWeight.w600, letterSpacing: 0)),
          const SizedBox(height: 7),
          const Text('What are we moving today?',
              style: TextStyle(fontSize: 16, color: AppColors.muted)),
          const SizedBox(height: 18),
          InkWell(
              onTap: () => _open(context, '/location-search'),
              child: Container(
                  height: 54,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border)),
                  child: const Row(children: [
                    Icon(Icons.search, size: 20, color: AppColors.muted),
                    SizedBox(width: 11),
                    Expanded(
                        child: Text('Where to? Enter a destination...',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 15, color: AppColors.muted))),
                  ]))),
          const SizedBox(height: 18),
          Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: AppColors.ink, borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                const Icon(Icons.inventory_2_outlined,
                    size: 25, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(
                          recentOrder?.title.trim().isNotEmpty == true
                              ? recentOrder!.title
                              : 'Your next delivery',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(
                          recentOrder == null
                              ? 'Ready when you are.'
                              : _status(recentOrder!.status),
                          style: const TextStyle(
                              color: Color(0xFFADB4BF), fontSize: 12)),
                    ])),
                const SizedBox(width: 8),
                FilledButton.icon(
                    onPressed: () => recentOrder == null
                        ? _open(context, '/service-choice')
                        : _open(context, '/order-detail', recentOrder!.id),
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.ink,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        minimumSize: const Size(0, 44),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8))),
                    icon: Icon(
                        recentOrder == null
                            ? Icons.send_outlined
                            : Icons.navigation_outlined,
                        size: 16),
                    label: Text(recentOrder == null ? 'Send' : 'Track',
                        style: const TextStyle(fontSize: 12))),
              ])),
          const SizedBox(height: 20),
          GridView(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 10,
                  mainAxisExtent: 96 + (scale - 1).clamp(0, 3) * 48),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: quick
                  .map((item) => InkWell(
                      onTap: () => _open(context, item.$4),
                      child: Container(
                          decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: AppColors.borderSoft),
                              borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _IconTile(
                                    icon: item.$2,
                                    tint: AppColors.tint[item.$3]!),
                                const SizedBox(height: 8),
                                Text(item.$1,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600)),
                              ]))))
                  .toList()),
          const SizedBox(height: 26),
          const Text('Ways to move',
              style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontSize: 19,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          GridView(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent:
                      (MediaQuery.sizeOf(context).width < 360 ? 164.0 : 142.0) +
                          (scale - 1).clamp(0, 3) * 160),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: services
                  .map((item) => InkWell(
                      onTap: () => _open(context, item.$5),
                      child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                              color: AppColors.tint[item.$4],
                              borderRadius: BorderRadius.circular(8)),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _IconTile(
                                    icon: item.$3,
                                    tint: Colors.white.withValues(alpha: .65)),
                                Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(item.$1,
                                          style: const TextStyle(
                                              fontFamily: 'SpaceGrotesk',
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 3),
                                      Text(item.$2,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF5A616C))),
                                    ]),
                              ]))))
                  .toList()),
          const SizedBox(height: 14),
          Container(
              padding: const EdgeInsets.all(18),
              color: AppColors.ink,
              child: const Row(children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Your world. Delivered.',
                          style: TextStyle(
                              fontFamily: 'SpaceGrotesk',
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                      SizedBox(height: 4),
                      Text('Send it with care.',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFFADB4BF))),
                    ])),
                SizedBox(width: 14),
                ColoredBox(
                    color: AppColors.accent,
                    child: Padding(
                        padding: EdgeInsets.all(8),
                        child: MoveTraqMark(size: 30)))
              ])),
          if (connectionError)
            Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Unable to refresh your home screen.',
                          style:
                              TextStyle(fontSize: 12, color: AppColors.muted)),
                      if (onRefresh != null)
                        TextButton.icon(
                            onPressed: () {
                              onRefresh!();
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry')),
                    ])),
        ]);
    return SafeArea(
        child: onRefresh == null
            ? list
            : RefreshIndicator(onRefresh: onRefresh!, child: list));
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon, required this.tint});
  final IconData icon;
  final Color tint;
  @override
  Widget build(BuildContext context) => Container(
      width: 40,
      height: 40,
      decoration:
          BoxDecoration(color: tint, borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, size: 21, color: AppColors.ink));
}
