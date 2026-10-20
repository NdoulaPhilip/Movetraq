import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as maps;
import 'package:geolocator/geolocator.dart';
import 'package:movetraq/services/location_service.dart';
import 'package:provider/provider.dart';
import 'package:movetraq/models/app_user.dart';
import 'package:movetraq/models/misc_models.dart';
import 'package:movetraq/screens/additional_screens.dart';
import 'package:movetraq/screens/home/profile_screen.dart';
import 'package:movetraq/screens/home/activity_screen.dart';
import 'package:movetraq/screens/home/orders_screen.dart';
import 'package:movetraq/screens/receive/receive_screen.dart';
import 'package:movetraq/screens/send/send_screen.dart';
import 'package:movetraq/screens/send/confirm_order_screen.dart';
import 'package:movetraq/screens/wallet/wallet_screen.dart';
import 'package:movetraq/screens/wallet/topup_screen.dart';
import 'package:movetraq/screens/deliverer/d_home_screen.dart';
import 'package:movetraq/services/feature_gateway.dart';
import 'package:movetraq/providers/deliverer_tracking_provider.dart';
import 'package:movetraq/screens/deliverer/deliverer_shell.dart';
import 'package:movetraq/screens/deliverer/d_active_screen.dart';
import 'package:movetraq/screens/deliverer/d_job_screen.dart';
import 'package:movetraq/screens/deliverer/d_trips_screen.dart';
import 'package:movetraq/screens/orders/order_tools.dart';
import 'package:movetraq/widgets/primary_button.dart';
import 'package:movetraq/widgets/app_page.dart';
import 'package:movetraq/screens/chat/chat_screen.dart';
import 'package:movetraq/screens/track/live_tracking_screen.dart';
import 'package:movetraq/screens/track/order_detail_screen.dart';
import 'package:movetraq/screens/track/track_list_screen.dart';
import 'package:movetraq/screens/send/pick_deliverer_screen.dart';
import 'package:movetraq/screens/send/negotiate_screen.dart';
import 'package:movetraq/screens/release/release_screen.dart';
import 'package:movetraq/screens/release/release_otp_screen.dart';
import 'package:movetraq/screens/notifications/notifications_screen.dart';
import 'package:movetraq/widgets/google_map_status.dart';
import 'package:movetraq/widgets/live_google_map.dart';
import 'package:movetraq/screens/booking/location_screens.dart';
import 'package:movetraq/models/parcel_order.dart';
import 'package:movetraq/providers/auth_provider.dart';
import 'package:movetraq/providers/send_flow_provider.dart';
import 'package:movetraq/screens/auth/create_account_screen.dart';
import 'package:movetraq/screens/auth/onboarding_screen.dart';
import 'package:movetraq/screens/auth/sign_in_screen.dart';
import 'package:movetraq/screens/home/home_screen.dart';
import 'package:movetraq/screens/send/send_done_screen.dart';
import 'package:movetraq/screens/release/release_done_screen.dart';
import 'package:movetraq/services/local_data_service.dart';
import 'package:movetraq/services/node_api_client.dart';
import 'package:movetraq/theme/app_theme.dart';
import 'package:movetraq/widgets/app_bottom_nav.dart';
import 'package:movetraq/app.dart';
import 'package:movetraq/features/deliverer/deliverer_gate.dart';
import 'package:movetraq/features/p2p/ads_screen.dart';

class _UnavailableLocation extends LocationService {
  const _UnavailableLocation();
  @override
  Future<Position> getCurrentPosition() async =>
      throw StateError('Fixture GPS unavailable');
}

class _TestData extends LocalDataService {
  _TestData({this.orderOverride});
  final ParcelOrder? orderOverride;
  ParcelOrder get _order => orderOverride ?? _defaultOrder;
  final supportRequests = <Map<String, String>>[];
  @override
  Future<AddressSuggestion> currentAddress() async => const AddressSuggestion(
      id: 'device',
      name: 'Device pickup',
      address: 'Device pickup address',
      latitude: 6.5,
      longitude: 3.4);
  @override
  Future<AddressSuggestion> reverseAddress(LatLng point) async =>
      AddressSuggestion(
          id: 'pin',
          name: 'Selected pin',
          address: 'Resolved pin address',
          latitude: point.latitude,
          longitude: point.longitude);
  @override
  Future<void> createSupportTicket(String uid,
      {required String subject, required String message}) async {
    supportRequests.add({'uid': uid, 'subject': subject, 'message': message});
  }

  final _defaultOrder = ParcelOrder(
    id: 'test-order',
    code: 'MT-4821',
    senderId: 'layout-test',
    senderName: 'Adeola Johnson',
    title: 'Wireless Headphones',
    category: 'parcel',
    pickupAddress: 'Ikeja',
    dropoffAddress: 'Lekki',
    price: 3500,
    payout: 3000,
    createdAt: DateTime(2026, 10, 10),
    status: OrderStatus.released,
    releasedAt: DateTime(2026, 10, 10),
  );
  @override
  Stream<AppUser?> get authStateChanges => const Stream.empty();

  @override
  Stream<ParcelOrder?> watchActiveSenderOrder(String uid) =>
      Stream.value(_order);

  @override
  Stream<ParcelOrder?> watchOrder(String id) => Stream.value(_order);

  @override
  Stream<List<ParcelOrder>> watchSenderOrders(String uid) =>
      Stream.value([_order]);
  @override
  Stream<List<ParcelOrder>> watchDelivererOrders(String uid) =>
      Stream.value([_order]);
  @override
  Stream<List<ParcelOrder>> watchOpenJobs() => Stream.value([_order]);
  @override
  Stream<List<WalletTransaction>> watchWalletTransactions(String uid) =>
      Stream.value([]);
  @override
  Stream<List<SavedAddress>> watchSavedAddresses(String uid) =>
      Stream.value([]);
  @override
  Stream<List<SupportTicket>> watchSupportTickets(String uid) =>
      Stream.value([]);
  @override
  Stream<List<ChatMessage>> watchMessages(String id) => Stream.value([]);
  @override
  Future<AppUser> orderContact(String id) async => AppUser(
      uid: 'courier',
      name: 'Delivery Contact',
      email: '',
      phone: '+2348000000001');
  @override
  Stream<List<AppUser>> watchAvailableDeliverers() => Stream.value([
        AppUser(
            uid: 'courier',
            name: 'Delivery Contact',
            email: '',
            phone: '',
            verified: true,
            totalDeliveries: 12)
      ]);
  @override
  Stream<List<NotificationItem>> watchNotifications(String uid) =>
      Stream.value([]);

  @override
  Future<HomeContext> homeContext() async => HomeContext(
        greeting: 'Good afternoon',
        period: 'afternoon',
        serverTime: DateTime(2026, 10, 10, 14),
        timezone: 'Africa/Lagos',
      );
}

class _ReferenceData extends _TestData {
  _ReferenceData({super.orderOverride});
  final sent = <String>[];
  bool failSend = false;
  @override
  Future<Map<String, dynamic>> delivererAccess() async =>
      {'id': 'application-fixture', 'status': 'not_started'};
  @override
  Stream<List<SavedAddress>> watchSavedAddresses(String uid) => Stream.value([
        SavedAddress(
            id: 'home',
            label: 'Home',
            address: '12 Admiralty Way, Lekki Phase 1, Lagos',
            isDefault: true,
            createdAt: DateTime(2026)),
        SavedAddress(
            id: 'work',
            label: 'Work',
            address: 'Victoria Island, Lagos',
            createdAt: DateTime(2026)),
      ]);
  @override
  Stream<List<ChatMessage>> watchMessages(String id) => Stream.value([
        ChatMessage(
            id: 'received',
            senderId: 'customer',
            text: 'The parcel is at reception.',
            createdAt: DateTime(2026, 10, 19, 10, 32)),
        ChatMessage(
            id: 'sent',
            senderId: 'layout-test',
            text: 'Thank you. I am on my way.',
            createdAt: DateTime(2026, 10, 19, 10, 34)),
      ]);
  @override
  Future<void> sendMessage(String orderId, String senderId, String text) async {
    if (failSend) throw StateError('Message could not be sent');
    sent.add(text);
  }
}

class _NotificationData extends _ReferenceData {
  final updates = StreamController<List<NotificationItem>>.broadcast();
  final reads = <String>[];
  bool failRead = false;
  final notifications = [
    NotificationItem(
        id: 'arriving',
        title: 'Courier arriving',
        body: 'Your delivery is approaching the drop-off.',
        type: 'arriving',
        read: false,
        createdAt: DateTime.now()),
    NotificationItem(
        id: 'pickup',
        title: 'Picked up',
        body: 'Your parcel was collected from the pickup location.',
        type: 'pickup',
        read: false,
        createdAt: DateTime.now().subtract(const Duration(minutes: 18))),
    NotificationItem(
        id: 'payment',
        title: 'Payment confirmed',
        body: 'Your delivery payment was confirmed.',
        type: 'payment',
        read: true,
        createdAt: DateTime.now().subtract(const Duration(minutes: 20))),
    NotificationItem(
        id: 'reward',
        title: 'Reward update',
        body: 'Check your available delivery rewards.',
        type: 'promo',
        read: true,
        createdAt: DateTime.now().subtract(const Duration(days: 1))),
  ];
  @override
  Stream<List<NotificationItem>> watchNotifications(String uid) async* {
    yield List.of(notifications);
    yield* updates.stream;
  }

  @override
  Future<void> markNotificationRead(String uid, String notifId) async {
    reads.add(notifId);
    if (failRead) throw StateError('Unable to mark notification read');
    final index = notifications.indexWhere((item) => item.id == notifId);
    notifications[index] = notifications[index].copyWith(read: true);
    updates.add(List.of(notifications));
  }

  @override
  void dispose() {
    updates.close();
    super.dispose();
  }
}

const _navItems = [
  NavItem(icon: Icons.home_outlined, selectedIcon: Icons.home, label: 'Home'),
  NavItem(
      icon: Icons.bar_chart_outlined,
      selectedIcon: Icons.bar_chart,
      label: 'Activity'),
  NavItem(
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2,
      label: 'Orders'),
  NavItem(
      icon: Icons.person_outline, selectedIcon: Icons.person, label: 'Profile'),
];

class _ActivityData extends _TestData {
  _ActivityData({this.empty = false, this.fail = false});
  final bool empty;
  bool fail;
  int orderSubscriptions = 0;
  int paymentSubscriptions = 0;

  ParcelOrder order(String id, OrderStatus status) => ParcelOrder(
      id: id,
      code: id,
      senderId: 'layout-test',
      senderName: 'Sender',
      title: id,
      category: 'parcel',
      pickupAddress: 'Ikeja',
      dropoffAddress: 'Lekki',
      price: 3500,
      payout: 3000,
      status: status,
      createdAt: DateTime(2026, 10, 10));

  @override
  Stream<List<ParcelOrder>> watchSenderOrders(String uid) {
    orderSubscriptions++;
    if (fail) return Stream.error(StateError('Offline'));
    return Stream.value(empty
        ? []
        : [
            _defaultOrder.copyWith(status: OrderStatus.pickedUp),
            order('Confirm this parcel', OrderStatus.delivered),
            order('complete', OrderStatus.released),
            order('cancelled', OrderStatus.cancelled),
          ]);
  }

  @override
  Stream<List<WalletTransaction>> watchWalletTransactions(String uid) {
    paymentSubscriptions++;
    return Stream.value(empty
        ? []
        : [
            for (final entry in [
              (WalletTxType.escrowHold, -3500.0, 'Delivery charge'),
              (WalletTxType.refund, 500.0, 'Delivery refund'),
              (WalletTxType.topup, 10000.0, 'Wallet funding'),
            ])
              WalletTransaction(
                  id: entry.$3,
                  type: entry.$1,
                  title: entry.$3,
                  sub: '',
                  amount: entry.$2,
                  createdAt: DateTime(2026, 10, 11)),
          ]);
  }
}

class _OrdersData extends _TestData {
  _OrdersData({this.empty = false, this.fail = false});
  final bool empty;
  bool fail;
  int subscriptions = 0;

  @override
  Stream<List<ParcelOrder>> watchSenderOrders(String uid) {
    subscriptions++;
    if (fail) return Stream.error(StateError('Offline'));
    return Stream.value(empty
        ? []
        : [
            for (final item in [
              ('Wireless Headphones', OrderStatus.pickedUp, 'parcel', 3500.0),
              ('Legal Documents', OrderStatus.accepted, 'documents', 2000.0),
              ('Waiting parcel', OrderStatus.pendingOffer, 'parcel', 1200.0),
              ('Completed parcel', OrderStatus.released, 'parcel', 500.0),
              ('Cancelled parcel', OrderStatus.cancelled, 'parcel', 1000.0),
            ])
              ParcelOrder(
                  id: item.$1,
                  code: 'MT-${4821 - [
                        'Wireless Headphones',
                        'Legal Documents',
                        'Waiting parcel',
                        'Completed parcel',
                        'Cancelled parcel'
                      ].indexOf(item.$1)}',
                  senderId: uid,
                  senderName: 'Sender',
                  title: item.$1,
                  category: item.$3,
                  pickupAddress: 'Ikeja',
                  dropoffAddress: 'Lekki',
                  price: item.$4,
                  payout: item.$4,
                  status: item.$2,
                  createdAt: DateTime.now().subtract(Duration(
                      minutes: item.$1 == 'Wireless Headphones' ? 0 : 1))),
          ]);
  }
}

class _TrackingData extends _OrdersData {
  _TrackingData(
      {this.simulated = false,
      this.stale = false,
      this.status = OrderStatus.pickedUp});
  final bool simulated;
  final bool stale;
  final OrderStatus status;
  @override
  Stream<ParcelOrder?> watchOrder(String id) => Stream.value(
      _defaultOrder.copyWith(
          status: status,
          delivererId: 'courier',
          delivererName: 'Daniel Okafor',
          courierLocation: const LatLng(6.5, 3.4),
          courierLocationIsSimulated: simulated,
          courierLocationUpdatedAt:
              DateTime.now().subtract(Duration(minutes: stale ? 5 : 0))));
}

class _SendData extends _TestData {
  ParcelOrder? saved;
  @override
  Future<String> createOrder(ParcelOrder draft) async {
    saved = ParcelOrder.fromJson(
        {...draft.toJson(), 'id': 'created-order', 'code': 'MT-4822'});
    return saved!.id;
  }

  @override
  Stream<ParcelOrder?> watchOrder(String id) => Stream.value(saved);
}

class _HomeData extends _TestData {
  _HomeData({this.failOrders = false, this.failRefresh = false});
  bool failOrders;
  bool failRefresh;
  int refreshCalls = 0;
  @override
  Stream<List<ParcelOrder>> watchSenderOrders(String uid) => failOrders
      ? Stream.error(StateError('Connection unavailable'))
      : Stream.value(
          [_defaultOrder.copyWith(status: OrderStatus.pendingOffer)]);
  @override
  Stream<List<SavedAddress>> watchSavedAddresses(String uid) => Stream.value([
        SavedAddress(
            id: 'home-address',
            label: 'Home',
            address: 'Default pickup address',
            createdAt: DateTime(2026, 10, 10),
            isDefault: true),
      ]);
  @override
  Future<void> refreshRemoteState() async {
    refreshCalls++;
    if (failRefresh) throw StateError('Refresh failed');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(ConfiguredGoogleMap.resetConfigurationCache);
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
          const MethodChannel('movetraq/map_config'), (call) async => false);
  GoogleFonts.config.allowRuntimeFetching = false;
  setUpAll(() async {
    final heading = FontLoader('SpaceGrotesk');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      heading.addFont(rootBundle.load('assets/fonts/SpaceGrotesk-$weight.ttf'));
    }
    await heading.load();
    final body = FontLoader('Inter');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      body.addFont(rootBundle.load('assets/fonts/Inter-$weight.ttf'));
    }
    await body.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  Future<void> mount(
    WidgetTester tester,
    Widget screen, {
    double width = 390,
    double height = 844,
    double scale = 1,
    GlobalKey? captureKey,
    bool deliverer = false,
    bool online = false,
    LocalDataService? dataOverride,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, height);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final data = dataOverride ?? _TestData();
    final auth = AuthProvider(data)
      ..profile = AppUser(
        uid: 'layout-test',
        name: 'Adeola Johnson',
        email: 'test@example.com',
        phone: '+2348000000000',
        activeRole: deliverer ? UserRole.deliverer : UserRole.sender,
        delivererOnline: online,
        verified: deliverer,
        canDeliver: deliverer,
        delivererVerificationStatus: deliverer ? 'approved' : 'not_started',
      );
    addTearDown(auth.dispose);
    final flow = SendFlowProvider(data);
    final tracking = DelivererTrackingProvider(data: data);
    addTearDown(tracking.dispose);
    addTearDown(flow.dispose);
    addTearDown(data.dispose);
    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider<LocalDataService>.value(value: data),
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider<SendFlowProvider>.value(value: flow),
        ChangeNotifierProvider<DelivererTrackingProvider>.value(
            value: tracking),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: RepaintBoundary(key: captureKey, child: child!),
        ),
        home: screen,
        routes: {
          '/create': (_) => const CreateAccountScreen(),
          '/signin': (_) => const SignInScreen(),
          '/send': (_) => const Scaffold(body: Text('Delivery route')),
          '/transactions': (_) =>
              const Scaffold(body: Text('Transaction history')),
          '/order-detail': (_) =>
              const Scaffold(body: Text('Delivery details')),
          '/transaction-detail': (_) =>
              const Scaffold(body: Text('Payment details')),
          '/live': (_) => const Scaffold(body: Text('Live delivery route')),
          '/home': (_) => const Scaffold(body: Text('Home route')),
          '/pick-deliverer': (_) =>
              const Scaffold(body: Text('Pick deliverer route')),
          '/confirm-order': (_) =>
              const Scaffold(body: Text('Confirm order route')),
          '/share-order': (_) => const Scaffold(body: Text('Share route')),
          '/chat': (_) => const Scaffold(body: Text('Courier chat route')),
          '/call': (_) => const Scaffold(body: Text('Courier call route')),
          '/p2p-requests': (_) => additionalScreen('/p2p-requests', null)!,
          '/delivery-pickup': (_) =>
              const DeliveryStageScreen(orderId: 'test-order'),
          '/delivery-dropoff': (_) =>
              const DeliveryStageScreen(orderId: 'test-order', dropoff: true),
          '/handover': (_) => additionalScreen('/handover', 'test-order')!,
        },
      ),
    ));
    await tester.pumpAndSettle();
    await tester.runAsync(() => GoogleFonts.pendingFonts());
    await tester.pumpAndSettle();
  }

  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('Auth and home layouts: $width px, text scale $scale',
          (tester) async {
        for (final screen in [
          const OnboardingScreen(),
          const SignInScreen(),
          const CreateAccountScreen(),
          const SendDoneScreen(),
          const ReleaseDoneScreen(orderId: 'test-order'),
          Scaffold(
              body: const HomeScreen(),
              bottomNavigationBar: AppBottomNav(
                  currentIndex: 0, items: _navItems, onTap: (_) {})),
        ]) {
          await mount(tester, screen, width: width, height: 640, scale: scale);
          expect(tester.takeException(), isNull,
              reason: screen.runtimeType.toString());
          final scroll = find.byType(Scrollable).first;
          await tester.drag(scroll, const Offset(0, -800));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull,
              reason: 'Scrolled ${screen.runtimeType}');
        }
      });
    }
  }

  testWidgets('Welcome actions navigate to account screens', (tester) async {
    await mount(tester, const OnboardingScreen());
    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(find.byType(CreateAccountScreen), findsOneWidget);
  });

  testWidgets('Password visibility and unavailable OAuth are explicit',
      (tester) async {
    await mount(tester, const SignInScreen());
    expect(
        tester.widget<EditableText>(find.byType(EditableText).last).obscureText,
        isTrue);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pumpAndSettle();
    expect(
        tester.widget<EditableText>(find.byType(EditableText).last).obscureText,
        isFalse);
    await tester.ensureVisible(find.text('Google'));
    await tester.tap(find.text('Google'));
    await tester.pump();
    expect(find.text('Google sign-in is not configured.'), findsOneWidget);
  });

  testWidgets('Activity empty design and send action', (tester) async {
    final captureKey = GlobalKey();
    await mount(
        tester,
        Scaffold(
            body: const ActivityScreen(),
            bottomNavigationBar:
                AppBottomNav(currentIndex: 1, items: _navItems, onTap: (_) {})),
        dataOverride: _ActivityData(empty: true),
        captureKey: captureKey);
    expect(find.text('YOUR DELIVERIES AT A GLANCE'), findsOneWidget);
    expect(find.text('0'), findsNWidgets(2));
    expect(find.text('₦0'), findsOneWidget);
    expect(find.text('Your next delivery starts here'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      final boundary = captureKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory('build/ui-review').createSync(recursive: true);
      File('build/ui-review/activity.png')
          .writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
    await tester.ensureVisible(find.text('Send an item'));
    await tester.tap(find.text('Send an item'));
    await tester.pumpAndSettle();
    expect(find.text('Delivery route'), findsOneWidget);
  });

  testWidgets(
      'Activity uses live totals, sorts updates and keeps subscriptions',
      (tester) async {
    final data = _ActivityData();
    await mount(tester, const Scaffold(body: ActivityScreen()),
        dataOverride: data);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('₦3,000'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Delivery charge')).dy,
        lessThan(tester.getTopLeft(find.text('Wireless Headphones').first).dy));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Deliveries'));
    await tester.pumpAndSettle();
    expect(find.text('Delivery charge'), findsNothing);
    expect(find.text('Confirm this parcel'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Payments'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm this parcel'), findsNothing);
    expect(find.text('Delivery charge'), findsOneWidget);
    expect(data.orderSubscriptions, 1);
    expect(data.paymentSubscriptions, 1);
    await tester.tap(find.text('Delivery charge'));
    await tester.pumpAndSettle();
    expect(find.text('Payment details'), findsOneWidget);
  });

  testWidgets('Activity errors retry without showing a false empty state',
      (tester) async {
    final data = _ActivityData(empty: true, fail: true);
    await mount(tester, const Scaffold(body: ActivityScreen()),
        dataOverride: data, width: 320, height: 640, scale: 1.3);
    expect(find.text('Your next delivery starts here'), findsNothing);
    expect(find.text('Currently unavailable'), findsOneWidget);
    data.fail = false;
    await tester.ensureVisible(find.text('Try again'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Your next delivery starts here'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Activity transaction action opens history', (tester) async {
    await mount(tester, const Scaffold(body: ActivityScreen()),
        dataOverride: _ActivityData(empty: true));
    await tester.tap(find.text('Transactions'));
    await tester.pumpAndSettle();
    expect(find.text('Transaction history'), findsOneWidget);
  });

  testWidgets(
      'Orders current and history filters keep real data and navigation',
      (tester) async {
    final data = _OrdersData();
    await mount(tester, const Scaffold(body: OrdersScreen()),
        dataOverride: data);
    expect(find.text('Wireless Headphones'), findsOneWidget);
    expect(find.text('Legal Documents'), findsOneWidget);
    expect(find.text('Waiting parcel'), findsOneWidget);
    expect(find.text('Completed parcel'), findsNothing);
    expect(find.text('₦3,500'), findsOneWidget);
    expect(find.text('MT-4821 · Today'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Wireless Headphones')).dy,
        lessThan(tester.getTopLeft(find.text('Legal Documents')).dy));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Active'));
    await tester.pumpAndSettle();
    expect(find.text('Waiting parcel'), findsNothing);
    expect(find.text('Wireless Headphones'), findsOneWidget);
    await tester.tap(find.text('Order history'));
    await tester.pumpAndSettle();
    expect(find.text('Wireless Headphones'), findsNothing);
    expect(find.text('Completed parcel'), findsOneWidget);
    expect(find.text('Cancelled parcel'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Cancelled'));
    await tester.pumpAndSettle();
    expect(find.text('Completed parcel'), findsNothing);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Completed'));
    await tester.pumpAndSettle();
    expect(find.text('Cancelled parcel'), findsNothing);
    expect(data.subscriptions, 1);
    await tester.tap(find.text('Completed parcel'));
    await tester.pumpAndSettle();
    expect(find.text('Delivery details'), findsOneWidget);
    expect(
        ModalRoute.of(tester.element(find.text('Delivery details')))!
            .settings
            .arguments,
        'Completed parcel');
  });

  testWidgets('Orders design preview', (tester) async {
    final key = GlobalKey();
    await mount(
        tester,
        Scaffold(
            body: const OrdersScreen(),
            bottomNavigationBar:
                AppBottomNav(currentIndex: 2, items: _navItems, onTap: (_) {})),
        captureKey: key,
        dataOverride: _OrdersData());
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory('build/ui-review').createSync(recursive: true);
      File('build/ui-review/orders.png')
          .writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
  });

  testWidgets('Orders cards fit a small phone with larger text',
      (tester) async {
    await mount(tester, const Scaffold(body: OrdersScreen()),
        dataOverride: _OrdersData(), width: 320, height: 640, scale: 1.3);
    expect(find.text('₦3,500'), findsOneWidget);
    expect(find.text('In transit'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Order history'));
    await tester.pumpAndSettle();
    expect(find.text('Completed parcel'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Orders empty and error states allow sending and retry',
      (tester) async {
    final data = _OrdersData(empty: true, fail: true);
    await mount(tester, const Scaffold(body: OrdersScreen()),
        dataOverride: data);
    expect(find.text('Currently unavailable'), findsOneWidget);
    expect(find.text('No current orders yet'), findsNothing);
    data.fail = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('No current orders yet'), findsOneWidget);
    await tester.tap(find.text('Order history'));
    await tester.pumpAndSettle();
    expect(find.text('No order history yet'), findsOneWidget);
    await tester.tap(find.text('Current orders'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send an item'));
    await tester.pumpAndSettle();
    expect(find.text('Delivery route'), findsOneWidget);
  });

  testWidgets(
      'Send booking design preserves fields, validation and delivery modes',
      (tester) async {
    final key = GlobalKey();
    await mount(tester, const SendScreen(), captureKey: key);
    expect(find.text('Book a delivery'), findsOneWidget);
    expect(find.text('Recipient phone number'), findsOneWidget);
    final flow =
        tester.element(find.byType(SendScreen)).read<SendFlowProvider>();
    flow.setDetails(
        pickupAddress: 'Ikeja City Mall',
        dropoffAddress: '12 Admiralty Way, Lekki');
    flow.toggleTermsAgreed();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose deliverer'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid recipient phone number.'), findsOneWidget);
    ScaffoldMessenger.of(tester.element(find.byType(SendScreen)))
        .hideCurrentSnackBar();
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('recipient-phone')), '+234 800 000 0000');
    await tester.enterText(
        find.byKey(const ValueKey('parcel-details')), 'Legal documents');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    expect(flow.recipientPhone, '+234 800 000 0000');
    expect(flow.title, 'Legal documents');
    await tester.drag(find.byType(ListView).first, const Offset(0, -260));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Documents'));
    await tester.pumpAndSettle();
    expect(flow.category, 'document');
    await tester.drag(find.byType(ListView).first, const Offset(0, 800));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory('build/ui-review').createSync(recursive: true);
      File('build/ui-review/send.png')
          .writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
    await tester.tap(find.text('Choose deliverer'));
    await tester.pumpAndSettle();
    expect(find.text('Pick deliverer route'), findsOneWidget);
    Navigator.of(tester.element(find.text('Pick deliverer route'))).pop();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Express'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Express'));
    await tester.pumpAndSettle();
    expect(flow.isExpress, isTrue);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm order route'), findsOneWidget);
  });

  testWidgets(
      'Send completion uses the saved order and preserves recipient contact',
      (tester) async {
    final data = _SendData();
    final key = GlobalKey();
    await mount(tester, const SendDoneScreen(),
        dataOverride: data, captureKey: key);
    expect(find.text('No delivery request yet'), findsOneWidget);
    expect(find.text('Track it live'), findsNothing);
    final context = tester.element(find.byType(SendDoneScreen));
    final flow = context.read<SendFlowProvider>();
    flow.setDetails(
        pickupAddress: 'Ikeja',
        dropoffAddress: 'Lekki',
        pickupLocation: const LatLng(6.5, 3.4),
        dropoffLocation: const LatLng(6.4, 3.5),
        recipientPhone: '+2348000000000',
        title: 'Documents');
    await flow.submitOrder(context.read<AuthProvider>().profile!);
    await tester.pumpAndSettle();
    expect(data.saved!.recipientPhone, '+2348000000000');
    expect(data.saved!.copyWith(status: OrderStatus.accepted).recipientPhone,
        '+2348000000000');
    expect(find.text('MT-4822 created'), findsOneWidget);
    expect(find.text('P2P · ₦4,000'), findsOneWidget);
    expect(find.textContaining('Nearby deliverers can accept'), findsOneWidget);
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory('build/ui-review').createSync(recursive: true);
      File('build/ui-review/send-done.png')
          .writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
    await tester.tap(find.text('Track it live'));
    await tester.pumpAndSettle();
    expect(find.text('Live delivery route'), findsOneWidget);
    expect(
        ModalRoute.of(tester.element(find.text('Live delivery route')))!
            .settings
            .arguments,
        'created-order');
    flow.reset();
    expect(flow.recipientPhone, isEmpty);
  });

  testWidgets('Send completion home action and small layouts', (tester) async {
    for (final screen in [const SendScreen(), const SendDoneScreen()]) {
      await tester.pumpWidget(const SizedBox());
      await mount(tester, screen, width: 320, height: 640, scale: 1.3);
      expect(tester.takeException(), isNull);
      final scroll = find.byType(Scrollable).first;
      await tester.drag(scroll, const Offset(0, -700));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.text('Back to home'));
    await tester.pumpAndSettle();
    expect(find.text('Home route'), findsOneWidget);
  });

  testWidgets('Home quick action opens delivery workflow', (tester) async {
    await mount(tester, const Scaffold(body: HomeScreen()));
    await tester.tap(find.text('Send').last);
    await tester.pumpAndSettle();
    expect(find.text('Delivery route'), findsOneWidget);
  });

  test('Money input is converted to exact integer minor units', () {
    expect(parseMinorUnits('3500.25'), 350025);
    expect(parseMinorUnits('10.1'), 1010);
    expect(parseMinorUnits('1.234'), isNull);
    expect(parseMinorUnits('-1'), isNull);
  });

  for (final width in [320.0, 390.0]) {
    testWidgets('All additional routes render at $width px with larger text',
        (tester) async {
      for (final route in additionalScreenRoutes) {
        final screen = additionalScreen(route, 'test-order');
        expect(screen, isNotNull, reason: route);
        await tester.pumpWidget(const SizedBox());
        try {
          await mount(tester, screen!, width: width, height: 640, scale: 1.3);
        } catch (error) {
          throw TestFailure('Failed to mount $route: $error');
        }
        expect(tester.takeException(), isNull, reason: route);
        final scroll = find.byType(Scrollable);
        if (scroll.evaluate().isNotEmpty) {
          await tester.drag(scroll.first, const Offset(0, -1200));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'Scrolled $route');
        }
      }
    });
  }

  testWidgets('Existing account and booking screens render on a small phone',
      (tester) async {
    for (final screen in [
      const ProfileScreen(),
      const ActivityScreen(),
      const OrdersScreen(),
      const ReceiveScreen(),
      const SendScreen(),
      const ConfirmOrderScreen(),
      const WalletScreen(),
      const TopupScreen(),
      const DHomeScreen(),
      const PickDelivererScreen(),
      const NegotiateScreen(),
      const ChatScreen(orderId: 'test-order'),
      const OrderDetailScreen(orderId: 'test-order'),
      const LiveTrackingScreen(orderId: 'test-order'),
      const TrackListScreen(),
      const DJobScreen(orderId: 'test-order'),
      const DActiveScreen(orderId: 'test-order'),
      const ReleaseScreen(orderId: 'test-order'),
      const ReleaseOtpScreen(orderId: 'test-order'),
      const NotificationsScreen()
    ]) {
      await tester.pumpWidget(const SizedBox());
      await mount(tester, Scaffold(body: screen),
          width: 320, height: 640, scale: 1.3);
      expect(tester.takeException(), isNull,
          reason: screen.runtimeType.toString());
    }
  });

  testWidgets('Five-tab deliverer workspace fits a small phone',
      (tester) async {
    await mount(tester, const DelivererShell(),
        width: 320, height: 640, scale: 1.3, deliverer: true);
    expect(tester.takeException(), isNull);
    for (final label in ['My work', 'Analytics', 'Messages', 'Profile']) {
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: label);
    }
  });

  testWidgets('Errand validates its steps and keeps shopping spend separate',
      (tester) async {
    await mount(tester, additionalScreen('/errand', null)!);
    await tester.scrollUntilVisible(find.text('Continue'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Required'), findsWidgets);
    final fields = find.byType(TextFormField);
    for (final entry in <int, String>{
      0: 'Groceries',
      1: 'Buy the items on my list',
      2: '5000.25',
      3: '2'
    }.entries) {
      await tester.ensureVisible(fields.at(entry.key));
      await tester.enterText(fields.at(entry.key), entry.value);
    }
    tester.testTextInput.hide();
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    for (final entry in <int, String>{
      0: 'Ikeja City Mall',
      1: 'Lekki Phase 1',
      2: 'Recipient Name',
      3: '+2348000000000'
    }.entries) {
      await tester.ensureVisible(fields.at(entry.key));
      await tester.enterText(fields.at(entry.key), entry.value);
    }
    tester.testTextInput.hide();
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Shopping spending limit'), findsOneWidget);
    expect(find.text('NGN 5000.25'), findsOneWidget);
    await tester.ensureVisible(find.text('Get delivery quote'));
    await tester.tap(find.text('Get delivery quote'));
    await tester.pumpAndSettle();
    expect(find.text('Service quotes is not connected to the mobile API yet.'),
        findsOneWidget);
    expect(find.text('Submitted successfully'), findsNothing);
  });

  testWidgets('Missing API never pretends a payout succeeded', (tester) async {
    await mount(tester, additionalScreen('/withdraw', null)!);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '3500');
    await tester.enterText(fields.at(1), '058');
    await tester.enterText(fields.at(2), '0123456789');
    tester.testTextInput.hide();
    await tester.tap(find.text('Review details'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review withdrawal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(find.text('Withdraw money is not connected to the mobile API yet.'),
        findsOneWidget);
    expect(find.text('Submitted successfully'), findsNothing);
  });

  testWidgets('Home P2P action opens the sender request list', (tester) async {
    await mount(tester, const Scaffold(body: HomeScreen()));
    await tester.tap(find.text('P2P delivery'));
    await tester.pumpAndSettle();
    expect(find.text('Your P2P requests'), findsOneWidget);
    expect(find.text('Wireless Headphones'), findsOneWidget);
    expect(find.text('Create a delivery request'), findsOneWidget);
  });

  testWidgets('Payment confirmation validates references and fails truthfully',
      (tester) async {
    await mount(tester, additionalScreen('/confirm-payment', null)!);
    await tester.tap(find.text('Check payment status'));
    await tester.pumpAndSettle();
    expect(find.text('Enter the reference from your checkout'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'mt-${'a' * 64}');
    tester.testTextInput.hide();
    await tester.ensureVisible(find.text('Check payment status'));
    await tester.tap(find.text('Check payment status'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Sign in before checking payment.'),
        findsOneWidget);
    expect(find.text('Payment confirmed'), findsNothing);
  });

  testWidgets(
      'Payout review validates and submits the actual delivery reference',
      (tester) async {
    final data = _TestData();
    await mount(tester, additionalScreen('/payout-review', 'test-order')!,
        dataOverride: data);
    await tester.ensureVisible(find.text('Request payment review'));
    await tester.tap(find.text('Request payment review'));
    await tester.pumpAndSettle();
    expect(find.text('Describe why payment needs review'), findsOneWidget);
    expect(data.supportRequests, isEmpty);
    await tester.enterText(
        find.byType(TextFormField), 'My delivery payment is pending.');
    tester.testTextInput.hide();
    await tester.ensureVisible(find.text('Request payment review'));
    await tester.tap(find.text('Request payment review'));
    await tester.pumpAndSettle();
    expect(data.supportRequests.single['subject'], 'Payment review / MT-4821');
    expect(
        data.supportRequests.single['message'], contains('Order: test-order'));
    expect(find.text('Payment review requested'), findsOneWidget);
  });

  testWidgets(
      'Safety reports identify the delivery contact; unavailable blocking never succeeds',
      (tester) async {
    final data = _TestData();
    await mount(tester, additionalScreen('/safety-reporting', 'test-order')!,
        dataOverride: data);
    await tester.ensureVisible(find.text('Save report'));
    await tester.tap(find.text('Save report'));
    await tester.pumpAndSettle();
    expect(find.text('Choose a reason'), findsOneWidget);
    expect(data.supportRequests, isEmpty);
    await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Harassment').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save report'));
    await tester.tap(find.text('Save report'));
    await tester.pumpAndSettle();
    expect(
        data.supportRequests.single['message'], contains('Contact: courier'));
    expect(find.text('Report submitted'), findsOneWidget);
    await tester.ensureVisible(find.text('Block contact'));
    await tester.tap(find.text('Block contact'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(
        find.text('Blocking contacts is not connected to the mobile API yet.'),
        findsOneWidget);
    expect(find.text('Contact blocked'), findsNothing);
  });

  ParcelOrder driverOrder(OrderStatus status,
          {String driver = 'layout-test', String sender = 'customer'}) =>
      ParcelOrder(
          id: 'test-order',
          code: 'MT-4821',
          senderId: sender,
          senderName: 'Delivery Customer',
          delivererId: status == OrderStatus.pendingOffer ? null : driver,
          delivererName:
              status == OrderStatus.pendingOffer ? null : 'Delivery Contact',
          title: 'Wireless Headphones',
          category: 'parcel',
          pickupAddress: 'Ikeja',
          dropoffAddress: 'Lekki',
          price: 3500,
          payout: 3000,
          createdAt: DateTime(2026, 10, 10),
          status: status);

  testWidgets('Driver summary resumes delivery without sender release controls',
      (tester) async {
    await mount(tester, const OrderToolsScreen(orderId: 'test-order'),
        deliverer: true,
        dataOverride:
            _TestData(orderOverride: driverOrder(OrderStatus.accepted)));
    final activePage = tester.widget<AppPage>(find.byType(AppPage));
    expect(
        activePage.children
            .whereType<RouteTile>()
            .any((tile) => tile.title == 'Contact customer'),
        isTrue);
    await tester.scrollUntilVisible(find.text('Continue delivery'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Continue delivery'));
    await tester.pumpAndSettle();
    expect(find.text('Pickup instructions'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await mount(tester, const OrderToolsScreen(orderId: 'test-order'),
        deliverer: true,
        dataOverride:
            _TestData(orderOverride: driverOrder(OrderStatus.delivered)));
    final deliveredPage = tester.widget<AppPage>(find.byType(AppPage));
    expect(
        deliveredPage.children
            .whereType<InfoBand>()
            .any((band) => band.title == 'Awaiting sender confirmation'),
        isTrue);
    expect(
        deliveredPage.children.whereType<PrimaryButton>().any(
            (button) => button.label == 'Confirm delivery & release payment'),
        isFalse);
    expect(
        deliveredPage.children
            .whereType<RouteTile>()
            .any((tile) => tile.title == 'Request a payout review'),
        isTrue);
  });

  testWidgets('Sender sees confirmation but no driver payout actions',
      (tester) async {
    await mount(tester, const OrderToolsScreen(orderId: 'test-order'),
        dataOverride: _TestData(
            orderOverride: driverOrder(OrderStatus.delivered,
                driver: 'courier', sender: 'layout-test')));
    final page = tester.widget<AppPage>(find.byType(AppPage));
    expect(
        page.children.whereType<PrimaryButton>().any(
            (button) => button.label == 'Confirm delivery & release payment'),
        isTrue);
    expect(
        page.children
            .whereType<RouteTile>()
            .any((tile) => tile.title == 'Request a payout review'),
        isFalse);
    expect(
        page.children
            .whereType<PrimaryButton>()
            .any((button) => button.label == 'Continue delivery'),
        isFalse);
  });

  testWidgets(
      'Pickup and handover controls require the assigned driver and correct stage',
      (tester) async {
    for (final status in [
      OrderStatus.accepted,
      OrderStatus.pickedUp,
      OrderStatus.delivered,
      OrderStatus.released,
      OrderStatus.cancelled
    ]) {
      for (final dropoff in [false, true]) {
        await tester.pumpWidget(const SizedBox());
        await mount(tester,
            DeliveryStageScreen(orderId: 'test-order', dropoff: dropoff),
            deliverer: true,
            width: 320,
            scale: 1.3,
            dataOverride: _TestData(orderOverride: driverOrder(status)));
        final action = tester
            .widget<AppPage>(find.byType(AppPage))
            .children
            .whereType<PrimaryButton>()
            .singleWhere((button) =>
                button.label ==
                (dropoff ? 'Confirm handover' : 'Item collected'));
        expect(action.onPressed != null,
            status == (dropoff ? OrderStatus.pickedUp : OrderStatus.accepted));
        expect(tester.takeException(), isNull);
      }
    }
    await tester.pumpWidget(const SizedBox());
    await mount(
        tester, const DeliveryStageScreen(orderId: 'test-order', dropoff: true),
        dataOverride: _TestData(
            orderOverride:
                driverOrder(OrderStatus.pickedUp, driver: 'other-driver')));
    final action = tester
        .widget<AppPage>(find.byType(AppPage))
        .children
        .whereType<PrimaryButton>()
        .singleWhere((button) => button.label == 'Confirm handover');
    expect(action.onPressed, isNull);
  });

  testWidgets('Driver order history opens the current delivery stage',
      (tester) async {
    for (final status in [OrderStatus.accepted, OrderStatus.pickedUp]) {
      await tester.pumpWidget(const SizedBox());
      await mount(tester, const DTripsScreen(),
          deliverer: true,
          dataOverride: _TestData(orderOverride: driverOrder(status)));
      await tester.tap(find.text('Wireless Headphones'));
      await tester.pumpAndSettle();
      expect(
          find.text(status == OrderStatus.accepted
              ? 'Pickup instructions'
              : 'Delivery instructions'),
          findsOneWidget);
    }
  });

  testWidgets(
      'Handover is restricted to in-transit assigned deliveries and never fakes completion',
      (tester) async {
    await mount(tester, additionalScreen('/handover', 'test-order')!,
        deliverer: true,
        dataOverride:
            _TestData(orderOverride: driverOrder(OrderStatus.released)));
    expect(find.text('Handover unavailable'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await mount(tester, additionalScreen('/handover', 'test-order')!,
        deliverer: true,
        dataOverride:
            _TestData(orderOverride: driverOrder(OrderStatus.pickedUp)));
    await tester.enterText(find.byType(TextFormField).at(0), 'Recipient Name');
    await tester.enterText(find.byType(TextFormField).at(1), '123456');
    tester.testTextInput.hide();
    await tester.ensureVisible(find.text('Confirm handover and finish'));
    await tester.tap(find.text('Confirm handover and finish'));
    await tester.pumpAndSettle();
    expect(
        find.text('Delivery handover is not connected to the mobile API yet.'),
        findsOneWidget);
    expect(find.text('Confirm parcel handover'), findsOneWidget);
  });

  testWidgets('Redesign wallet and transactions use real amounts and search',
      (tester) async {
    await mount(tester, const WalletScreen(), dataOverride: _ActivityData());
    expect(find.text('₦7,000'), findsOneWidget);
    expect(find.text('₦42,300'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await mount(tester, additionalScreen('/transactions', null)!,
        dataOverride: _ActivityData());
    expect(find.text('₦10,500'), findsOneWidget);
    expect(find.text('₦3,500'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Delivery charge');
    await tester.pumpAndSettle();
    expect(find.text('1 transactions'), findsOneWidget);
    expect(find.text('Wallet funding'), findsNothing);
    expect(find.widgetWithText(ListTile, 'Delivery charge'), findsOneWidget);
  });

  testWidgets('Redesign job acceptance keeps role and ownership checks',
      (tester) async {
    for (final entry in [
      (false, OrderStatus.pendingOffer, 'customer', false),
      (true, OrderStatus.pendingOffer, 'layout-test', false),
      (true, OrderStatus.delivered, 'customer', false),
      (true, OrderStatus.pendingOffer, 'customer', true),
    ]) {
      await tester.pumpWidget(const SizedBox());
      await mount(tester, const DJobScreen(orderId: 'test-order'),
          deliverer: entry.$1,
          dataOverride: _TestData(
              orderOverride: driverOrder(entry.$2, sender: entry.$3)));
      final finder = find.byWidgetPredicate((widget) =>
          widget is PrimaryButton &&
          widget.label.startsWith('Accept delivery'));
      expect(tester.widget<PrimaryButton>(finder).onPressed != null, entry.$4);
      if (entry.$4) {
        await tester.tap(finder);
        await tester.pumpAndSettle();
        expect(find.text('Accept this delivery?'), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(find.byType(DJobScreen), findsOneWidget);
      }
    }
  });

  testWidgets('Summary route cannot claim an unfinished delivery is completed',
      (tester) async {
    await mount(
        tester, const OrderToolsScreen(orderId: 'test-order', completed: true),
        deliverer: true,
        dataOverride:
            _TestData(orderOverride: driverOrder(OrderStatus.accepted)));
    expect(find.text('DELIVERY COMPLETED'), findsNothing);
    expect(find.text('Parcel delivered'), findsNothing);
    expect(find.text('Picking up'), findsOneWidget);
    expect(
        tester
            .widget<AppPage>(find.byType(AppPage))
            .children
            .whereType<PrimaryButton>()
            .any((button) => button.label == 'Continue delivery'),
        isTrue);
  });

  testWidgets(
      'Account screen safeguards retain real delivery and verification states',
      (tester) async {
    for (final status in [OrderStatus.accepted, OrderStatus.released]) {
      await tester.pumpWidget(const SizedBox());
      await mount(tester, additionalScreen('/completion', 'test-order')!,
          dataOverride: _TestData(
              orderOverride: driverOrder(status,
                  sender: 'layout-test', driver: 'courier')));
      expect(
          tester.widget<AppPage>(find.byType(AppPage)).title,
          status == OrderStatus.released
              ? 'Delivery completed'
              : 'Delivery status');
      expect(find.text('Your delivery is complete and the item has arrived.'),
          status == OrderStatus.released ? findsOneWidget : findsNothing);
    }
    await tester.pumpWidget(const SizedBox());
    await mount(tester,
        additionalScreen('/verify-email', {'email': 'test@example.com'})!);
    await tester.scrollUntilVisible(find.text('Verify email & continue'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Verify email & continue'));
    await tester.pumpAndSettle();
    expect(find.text('Enter verification code'), findsOneWidget);
    expect(find.text('Submitted successfully'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await mount(tester, additionalScreen('/delivery-preferences', null)!);
    expect(
        tester
            .widget<AppPage>(find.byType(AppPage))
            .children
            .whereType<SecondaryButton>()
            .any((button) => button.label == 'Go offline'),
        isFalse);
    await tester.pumpWidget(const SizedBox());
    await mount(tester, additionalScreen('/deliverer-work-settings', null)!,
        deliverer: true);
    expect(
        tester
            .widget<AppPage>(find.byType(AppPage))
            .children
            .whereType<SecondaryButton>()
            .any((button) => button.label == 'Go offline'),
        isTrue);
    for (final ownJob in [true, false]) {
      await tester.pumpWidget(const SizedBox());
      await mount(tester, additionalScreen('/manage-orders', null)!,
          deliverer: true,
          dataOverride: _TestData(
              orderOverride: driverOrder(OrderStatus.pendingOffer,
                  sender: ownJob ? 'layout-test' : 'customer')));
      expect(
          find.text('Manage delivery'), ownJob ? findsNothing : findsOneWidget);
      if (!ownJob) {
        await tester.tap(find.text('Active'));
        await tester.pumpAndSettle();
        expect(find.text('No matching deliveries'), findsOneWidget);
      }
    }
  });

  testWidgets(
      'Delivery chat retains unsent text on failure and clears after success',
      (tester) async {
    final data =
        _ReferenceData(orderOverride: driverOrder(OrderStatus.pickedUp));
    await mount(tester, const ChatScreen(orderId: 'test-order'),
        dataOverride: data, deliverer: true);
    expect(find.text('The parcel is at reception.'), findsOneWidget);
    expect(find.textContaining('Wireless Headphones / In transit'),
        findsOneWidget);
    await tester.enterText(find.byType(TextField), '  At the gate  ');
    data.failSend = true;
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '  At the gate  ');
    expect(data.sent, isEmpty);
    ScaffoldMessenger.of(tester.element(find.byType(ChatScreen)))
        .hideCurrentSnackBar();
    await tester.pumpAndSettle();
    data.failSend = false;
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();
    expect(data.sent, ['At the gate']);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Notifications show actual unread totals and preserve read failures',
      (tester) async {
    final data = _NotificationData();
    await mount(tester, const NotificationsScreen(), dataOverride: data);
    expect(find.text('2 unread'), findsOneWidget);
    data.failRead = true;
    await tester.tap(find.text('Mark read').first);
    await tester.pumpAndSettle();
    expect(find.text('2 unread'), findsOneWidget);
    expect(data.notifications.first.read, isFalse);
    ScaffoldMessenger.of(tester.element(find.byType(NotificationsScreen)))
        .hideCurrentSnackBar();
    await tester.pumpAndSettle();
    data.failRead = false;
    await tester.tap(find.text('Mark all read'));
    await tester.pumpAndSettle();
    expect(find.text('0 unread'), findsOneWidget);
    expect(data.reads, ['arriving', 'arriving', 'pickup']);
    expect(find.text('Mark read'), findsNothing);
    await tester.tap(find.byTooltip('Filter notifications'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Payments'));
    await tester.pumpAndSettle();
    expect(find.text('Payment confirmed'), findsOneWidget);
    expect(find.text('Courier arriving'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Notification clearing stays visible when the API is unavailable',
      (tester) async {
    final data = _NotificationData();
    await mount(tester, const NotificationsScreen(), dataOverride: data);
    await tester.tap(find.text('Clear all'));
    await tester.pumpAndSettle();
    expect(find.text('Clear notifications?'), findsOneWidget);
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(find.text('Courier arriving'), findsOneWidget);
    expect(find.textContaining('Notification deletion is not connected'),
        findsOneWidget);
    expect(data.notifications.length, 4);
  });

  testWidgets('Account reference gallery validates all thirty-eight screens',
      (tester) async {
    final entries = <String, Widget>{
      'about': additionalScreen('/about', null)!,
      'accessibility': additionalScreen('/display-preferences', null)!,
      'account-tools': additionalScreen('/account-controls', null)!,
      'address-edit': additionalScreen('/address-edit', null)!,
      'application-form': additionalScreen('/application-form', null)!,
      'application-review': additionalScreen('/application-form', null)!,
      'blocked-people': additionalScreen('/blocked-users', null)!,
      'completion': additionalScreen('/completion', 'test-order')!,
      'delete-account': additionalScreen('/delete-account', null)!,
      'delivery-choice': additionalScreen('/service-choice', null)!,
      'delivery-prefs': additionalScreen('/delivery-preferences', null)!,
      'd-orders': additionalScreen('/manage-orders', null)!,
      'email-otp':
          additionalScreen('/verify-email', {'email': 'test@example.com'})!,
      'express-review': additionalScreen('/express-review', null)!,
      'forgot': additionalScreen('/password-recovery', null)!,
      'locations': additionalScreen('/location-search', null)!,
      'map-picker':
          const MapPickerScreen(locationService: _UnavailableLocation()),
      'p2p-preview': additionalScreen('/create-p2p-ad', null)!,
      'payment-setup': additionalScreen('/add-payment-method', null)!,
      'payment-authorize': additionalScreen('/confirm-payment', null)!,
      'preferences': additionalScreen('/notification-preferences', null)!,
      'privacy': additionalScreen('/privacy', null)!,
      'security': additionalScreen('/security', null)!,
      'sessions': additionalScreen('/sessions', null)!,
      'addresses': additionalScreen('/saved-addresses', null)!,
      'application-status': additionalScreen('/application-status', null)!,
      'contact': additionalScreen('/delivery-contact', 'test-order')!,
      'd-call': additionalScreen('/call', 'test-order')!,
      'd-chat': const ChatScreen(orderId: 'test-order'),
      'd-customer-history':
          additionalScreen('/customer-deliveries', 'unknown-customer')!,
      'd-dropoff': additionalScreen('/delivery-dropoff', 'test-order')!,
      'd-order-detail': const OrderToolsScreen(orderId: 'test-order'),
      'd-pickup': additionalScreen('/delivery-pickup', 'test-order')!,
      'p2p-browse': const BrowseAdsScreen(),
      'personal': additionalScreen('/personal-details', null)!,
      'photo': additionalScreen('/parcel-photo', null)!,
      'ticket': additionalScreen('/report-issue', 'test-order')!,
      'notifs': const NotificationsScreen(),
    };
    Future<void> tapVisible(Finder finder) async {
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    for (final width in [390.0, 320.0]) {
      for (final entry in entries.entries) {
        await tester.pumpWidget(const SizedBox());
        final driver = entry.key.startsWith('d-') || entry.key == 'p2p-preview';
        final key = GlobalKey();
        await mount(tester, Scaffold(body: entry.value),
            width: width,
            scale: width == 320 ? 1.3 : 1,
            captureKey: key,
            deliverer: driver,
            dataOverride: entry.key == 'notifs'
                ? _NotificationData()
                : _ReferenceData(
                    orderOverride: driverOrder(
                        entry.key == 'completion'
                            ? OrderStatus.released
                            : entry.key == 'd-dropoff' ||
                                    entry.key == 'd-order-detail' ||
                                    entry.key == 'd-chat'
                                ? OrderStatus.pickedUp
                                : OrderStatus.accepted,
                        driver: driver ? 'layout-test' : 'courier',
                        sender: driver ? 'customer' : 'layout-test')));
        if (entry.key == 'express-review') {
          final flow = key.currentContext!.read<SendFlowProvider>();
          flow.setDetails(
              title: 'Wireless headphones',
              pickupAddress: 'Ikeja City Mall',
              dropoffAddress: 'Lekki Phase 1',
              recipientPhone: '+2348000000000');
          flow.setMode(p2p: false);
          await tester.pumpAndSettle();
        }
        if (entry.key == 'application-review') {
          await tester.enterText(
              find.widgetWithText(TextFormField, 'Legal full name'),
              'Adeola Johnson');
          await tapVisible(find.text('Date of birth'));
          await tester.tap(find.text('OK').last);
          await tester.pumpAndSettle();
          await tapVisible(find.text('Continue'));
          await tapVisible(find.byType(DropdownButtonFormField<String>));
          await tester.tap(find.text('Motorcycle').last);
          await tester.pumpAndSettle();
          await tapVisible(find.text('Continue'));
          for (var index = 0; index < 3; index++) {
            await tapVisible(find.byType(CheckboxListTile).at(index));
          }
          await tapVisible(find.text('Continue'));
          expect(tester.widget<AppPage>(find.byType(AppPage)).title,
              'Review application');
          expect(key.currentContext!.read<AuthProvider>().profile!.activeRole,
              UserRole.sender);
        }
        if (entry.key == 'p2p-preview') {
          final values = [
            'Ikeja to Lekki delivery',
            'Ikeja City Mall',
            'Lekki Phase 1',
            '3500',
            'Today',
            'Handle with care'
          ];
          for (var index = 0; index < values.length; index++) {
            final field = find.byType(TextFormField).at(index);
            await tester.ensureVisible(field);
            await tester.enterText(field, values[index]);
          }
          await tapVisible(find.byType(DropdownButtonFormField<String>));
          await tester.tap(find.text('motorcycle').last);
          await tester.pumpAndSettle();
          await tapVisible(find.text('Preview ad'));
          expect(tester.widget<AppPage>(find.byType(AppPage)).title,
              'Preview your offer');
        }
        if (['application-review', 'p2p-preview'].contains(entry.key)) {
          tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position
              .jumpTo(0);
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull,
            reason: '${entry.key} at $width');
        if (width == 390) {
          await tester.runAsync(() async {
            final boundary = key.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes =
                await image.toByteData(format: ui.ImageByteFormat.png);
            Directory('build/ui-review/account').createSync(recursive: true);
            File('build/ui-review/account/${entry.key}.png')
                .writeAsBytesSync(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      }
    }
  });

  testWidgets('New reference screens render and produce a review gallery',
      (tester) async {
    final entries = <String, Widget>{
      'confirm-receipt': additionalScreen('/confirm-receipt', 'test-order')!,
      'courier-support': additionalScreen('/courier-support', null)!,
      'd-analytics': additionalScreen('/analytics', null)!,
      'd-contacts': additionalScreen('/messages', null)!,
      'd-customers': additionalScreen('/past-customers', null)!,
      'd-earnings': additionalScreen('/deliverer-earnings', null)!,
      'deliverer-apply': additionalScreen('/deliverer-apply', null)!,
      'd-performance': additionalScreen('/performance', null)!,
      'express-payment': additionalScreen('/payment', null)!,
      'input': const AppPage(title: 'Input field', children: [
        TextField(decoration: InputDecoration(hintText: 'Enter a value'))
      ]),
      'move': additionalScreen('/big-move', null)!,
      'order-tracking': additionalScreen('/order-tracking', 'test-order')!,
      'p2p-ads': additionalScreen('/delivery-work', null)!,
      'p2p-edit': additionalScreen('/create-p2p-ad', null)!,
      'payment-methods': additionalScreen('/payment-methods', null)!,
      'rating': additionalScreen('/rate-delivery', 'test-order')!,
      'receive': const ReceiveScreen(),
      'roles': additionalScreen('/delivery-opportunities', null)!,
      'safety-actions': additionalScreen('/safety-reporting', 'test-order')!,
      'schedule': additionalScreen('/schedule', null)!,
      'sender-p2p': additionalScreen('/p2p-requests', null)!,
      'sender-p2p-form': additionalScreen('/p2p-request', null)!,
      'sender-p2p-review': additionalScreen('/p2p-request', null)!,
      'settings': additionalScreen('/settings', null)!,
    };
    for (final width in [390.0, 320.0]) {
      for (final entry in entries.entries) {
        await tester.pumpWidget(const SizedBox());
        final driver = entry.key.startsWith('d-') ||
            entry.key == 'p2p-ads' ||
            entry.key == 'p2p-edit';
        final key = GlobalKey();
        await mount(tester, Scaffold(body: entry.value),
            width: width,
            scale: width == 320 ? 1.3 : 1,
            captureKey: key,
            deliverer: driver,
            dataOverride: _TestData(
                orderOverride: driverOrder(OrderStatus.delivered,
                    driver: driver ? 'layout-test' : 'courier',
                    sender: driver ? 'customer' : 'layout-test')));
        if (entry.key == 'sender-p2p-review') {
          for (final field in <String, String>{
            'Pickup address': 'Ikeja City Mall',
            'Drop-off address': 'Lekki Phase 1',
            'Parcel': 'Legal documents',
            'Recipient name': 'Delivery Recipient',
            'Contact phone': '+2348000000000',
            'Your offer (NGN)': '3500',
            'Estimated weight (kg)': '1',
            'Handling notes': 'Keep documents flat and dry',
          }.entries) {
            final finder = find.widgetWithText(TextFormField, field.key);
            await tester.ensureVisible(finder);
            await tester.enterText(finder, field.value);
          }
          await tester.scrollUntilVisible(find.text('Review request'), 250,
              scrollable: find.byType(Scrollable).first);
          await tester.tap(find.text('Review request'));
          await tester.pumpAndSettle();
          expect(tester.widget<AppPage>(find.byType(AppPage)).title,
              'Review your request');
          tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position
              .jumpTo(0);
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull,
            reason: '${entry.key} at $width');
        if (width == 390) {
          await tester.runAsync(() async {
            final boundary = key.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes =
                await image.toByteData(format: ui.ImageByteFormat.png);
            Directory('build/ui-review/additional').createSync(recursive: true);
            File('build/ui-review/additional/${entry.key}.png')
                .writeAsBytesSync(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      }
    }
  });

  testWidgets('Confirm receipt requires the sender and delivered status',
      (tester) async {
    for (final status in [
      OrderStatus.accepted,
      OrderStatus.pickedUp,
      OrderStatus.delivered,
      OrderStatus.released
    ]) {
      await tester.pumpWidget(const SizedBox());
      await mount(tester, additionalScreen('/confirm-receipt', 'test-order')!,
          dataOverride: _TestData(
              orderOverride: driverOrder(status,
                  sender: 'layout-test', driver: 'courier')));
      final button = tester
          .widget<AppPage>(find.byType(AppPage))
          .children
          .whereType<PrimaryButton>()
          .single;
      expect(button.onPressed != null, status == OrderStatus.delivered);
    }
    await tester.pumpWidget(const SizedBox());
    await mount(tester, additionalScreen('/confirm-receipt', 'test-order')!,
        deliverer: true,
        dataOverride:
            _TestData(orderOverride: driverOrder(OrderStatus.delivered)));
    expect(find.text('Delivery unavailable'), findsOneWidget);
    expect(find.text('Confirm delivery & release payment'), findsNothing);
  });

  testWidgets('Redesign gallery renders all supplied screens', (tester) async {
    final entries = <String, Widget>{
      'confirm-order': const ConfirmOrderScreen(),
      'courier-prefs': additionalScreen('/deliverer-work-settings', null)!,
      'd-active': const DActiveScreen(orderId: 'test-order'),
      'd-done': const OrderToolsScreen(orderId: 'test-order', completed: true),
      'deliverer': const ContactScreen(orderId: 'test-order', profile: true),
      'delivery-issue': additionalScreen('/delivery-problem', 'test-order')!,
      'delivery-issue-status': additionalScreen(
          '/support-case',
          SupportTicket(
              id: 'case-1',
              subject: 'Recipient unreachable',
              message: 'The recipient has not answered two calls.',
              createdAt: DateTime(2026, 10, 10)))!,
      'delivery-proof': additionalScreen('/handover', 'test-order')!,
      'd-home': const DHomeScreen(),
      'd-job': const DJobScreen(orderId: 'test-order'),
      'd-trips': const DTripsScreen(),
      'express-receipt':
          const OrderToolsScreen(orderId: 'test-order', receipt: true),
      'negotiate': const NegotiateScreen(),
      'payment-review': additionalScreen('/payout-review', 'test-order')!,
      'pick-deliverer': const PickDelivererScreen(),
      'profile': const ProfileScreen(),
      'release': const ReleaseScreen(orderId: 'test-order'),
      'release-done': const ReleaseDoneScreen(orderId: 'test-order'),
      'release-otp': const ReleaseOtpScreen(orderId: 'test-order'),
      'sender-order-detail': const OrderDetailScreen(orderId: 'test-order'),
      'share': const ShareOrderScreen(orderId: 'test-order'),
      'support': additionalScreen('/support', null)!,
      'topup': const TopupScreen(),
      'transactions': additionalScreen('/transactions', null)!,
      'wallet': const WalletScreen(),
      'withdraw': additionalScreen('/withdraw', null)!,
    };
    for (final entry in entries.entries) {
      await tester.pumpWidget(const SizedBox());
      final driver =
          entry.key.startsWith('d-') || entry.key == 'delivery-proof';
      final status = ['d-home', 'd-job'].contains(entry.key)
          ? OrderStatus.pendingOffer
          : entry.key == 'delivery-proof'
              ? OrderStatus.pickedUp
              : ['d-done', 'release-done'].contains(entry.key)
                  ? OrderStatus.released
                  : entry.key == 'd-active'
                      ? OrderStatus.accepted
                      : OrderStatus.delivered;
      final key = GlobalKey();
      await mount(tester, Scaffold(body: entry.value),
          captureKey: key,
          deliverer: driver,
          online: driver,
          dataOverride: _TestData(
              orderOverride: driverOrder(status,
                  driver: driver ? 'layout-test' : 'courier',
                  sender: driver ? 'customer' : 'layout-test')));
      final draft = key.currentContext!.read<SendFlowProvider>();
      draft.setDetails(
          title: 'Wireless Headphones',
          pickupAddress: 'Ikeja',
          dropoffAddress: 'Lekki',
          recipientPhone: '+2348000000000');
      draft.pickDeliverer('courier', 'Delivery Contact');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: entry.key);
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        Directory('build/ui-review/redesign').createSync(recursive: true);
        File('build/ui-review/redesign/${entry.key}.png')
            .writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });

  testWidgets('Capture driver delivery screens in their active stages',
      (tester) async {
    for (final entry in <String, Widget>{
      'driver-summary': const OrderToolsScreen(orderId: 'test-order'),
      'driver-pickup': const DeliveryStageScreen(orderId: 'test-order'),
      'driver-dropoff':
          const DeliveryStageScreen(orderId: 'test-order', dropoff: true),
      'driver-active': const DActiveScreen(orderId: 'test-order'),
      'driver-orders': const DTripsScreen(),
      'driver-handover': additionalScreen('/handover', 'test-order')!,
    }.entries) {
      final key = GlobalKey();
      final dropoff =
          entry.key == 'driver-dropoff' || entry.key == 'driver-handover';
      await mount(tester, entry.value,
          deliverer: true,
          captureKey: key,
          dataOverride: _TestData(
              orderOverride: driverOrder(
                  dropoff ? OrderStatus.pickedUp : OrderStatus.accepted)));
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final directory = Directory('build/ui-review')
          ..createSync(recursive: true);
        File('${directory.path}/${entry.key}.png')
            .writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Capture redesigned screens with bundled fonts', (tester) async {
    for (final entry in <String, Widget>{
      'welcome': const OnboardingScreen(),
      'signin': const SignInScreen(),
      'signup': const CreateAccountScreen(),
      'home': Scaffold(
          body: const HomeScreen(),
          bottomNavigationBar:
              AppBottomNav(currentIndex: 0, items: _navItems, onTap: (_) {})),
      'profile': const Scaffold(body: ProfileScreen()),
      'settings': additionalScreen('/settings', null)!,
      'errand': additionalScreen('/errand', null)!,
      'big-move': additionalScreen('/big-move', null)!,
      'verification': additionalScreen('/deliverer-apply', null)!,
      'analytics': additionalScreen('/analytics', null)!,
      'support': additionalScreen('/support', null)!,
      'payment': additionalScreen('/payment', null)!,
      'p2p-requests': additionalScreen('/p2p-requests', null)!,
      'payment-confirmation': additionalScreen('/confirm-payment', null)!,
      'payout-review': additionalScreen('/payout-review', 'test-order')!,
      'safety-reporting': additionalScreen('/safety-reporting', 'test-order')!,
      'map-picker': const MapPickerScreen(),
      'live-tracking': const LiveTrackingScreen(orderId: 'test-order'),
    }.entries) {
      final key = GlobalKey();
      await mount(tester, entry.value, captureKey: key);
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final directory = Directory('build/ui-review')
          ..createSync(recursive: true);
        File('${directory.path}/${entry.key}.png')
            .writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
      'Map pin selection supports taps, dragging, and retained destination',
      (tester) async {
    await mount(
        tester, const MapPickerScreen(locationService: _UnavailableLocation()));
    maps.GoogleMap map() => tester
        .widget<ConfiguredGoogleMap>(find.byType(ConfiguredGoogleMap))
        .map;
    expect(map().markers, isEmpty);
    expect(tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed,
        isNull);
    map().onTap!(const maps.LatLng(6.6, 3.3));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(map().markers.single.draggable, isTrue);
    map().markers.single.onDragEnd!(const maps.LatLng(6.4, 3.5));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('6.40000, 3.50000'), findsOneWidget);
    expect(tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed,
        isNotNull);
    final flow =
        tester.element(find.byType(MapPickerScreen)).read<SendFlowProvider>();
    flow.setDetails(dropoffLocation: const LatLng(6.7, 3.6));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(ChangeNotifierProvider<SendFlowProvider>.value(
        value: flow, child: const MaterialApp(home: MapPickerScreen())));
    await tester.pumpAndSettle();
    expect(map().initialCameraPosition.target, const maps.LatLng(6.7, 3.6));
    expect(map().markers.single.position, const maps.LatLng(6.7, 3.6));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Tracking list uses active orders and opens the selected delivery',
      (tester) async {
    final data = _OrdersData();
    final key = GlobalKey();
    await mount(tester, const TrackListScreen(),
        dataOverride: data, captureKey: key);
    expect(find.text('3 deliveries on the move'), findsOneWidget);
    expect(find.text('Completed parcel'), findsNothing);
    expect(find.text('Cancelled parcel'), findsNothing);
    expect(find.text('Wireless Headphones'), findsOneWidget);
    expect(find.textContaining('10 min'), findsNothing);
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory('build/ui-review').createSync(recursive: true);
      File('build/ui-review/track-list.png')
          .writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
    await tester.tap(find.text('Track delivery').first);
    await tester.pumpAndSettle();
    expect(find.text('Live delivery route'), findsOneWidget);
    expect(
        ModalRoute.of(tester.element(find.text('Live delivery route')))!
            .settings
            .arguments,
        'Wireless Headphones');
    expect(data.subscriptions, 1);
  });

  testWidgets('Tracking list handles errors, empty data and larger text',
      (tester) async {
    final data = _OrdersData(empty: true, fail: true);
    await mount(tester, const TrackListScreen(),
        dataOverride: data, width: 320, height: 640, scale: 1.3);
    expect(find.text('Currently unavailable'), findsOneWidget);
    data.fail = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('No active deliveries'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await mount(tester, const TrackListScreen(),
        dataOverride: _OrdersData(), width: 320, height: 640, scale: 1.3);
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tracking live design preserves Google Maps and courier actions',
      (tester) async {
    final key = GlobalKey();
    await mount(tester, const LiveTrackingScreen(orderId: 'test-order'),
        dataOverride: _TrackingData(), captureKey: key);
    expect(find.text('MT-4821 · Live'), findsOneWidget);
    expect(find.byType(LiveGoogleMap), findsOneWidget);
    expect(find.text('ETA unavailable'), findsOneWidget);
    expect(
        tester
            .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator))
            .value,
        .62);
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory('build/ui-review').createSync(recursive: true);
      File('build/ui-review/live-tracking.png')
          .writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
    await tester.tap(find.byTooltip('Share delivery'));
    await tester.pumpAndSettle();
    expect(find.text('Share route'), findsOneWidget);
    Navigator.of(tester.element(find.text('Share route'))).pop();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Message courier'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Message courier'));
    await tester.pumpAndSettle();
    expect(find.text('Courier chat route'), findsOneWidget);
    Navigator.of(tester.element(find.text('Courier chat route'))).pop();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Call courier'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Call courier'));
    await tester.pumpAndSettle();
    expect(find.text('Courier call route'), findsOneWidget);
  });

  testWidgets('Tracking never labels stale or simulated GPS as live',
      (tester) async {
    for (final data in [
      _TrackingData(stale: true),
      _TrackingData(simulated: true)
    ]) {
      await tester.pumpWidget(const SizedBox());
      await mount(tester, const LiveTrackingScreen(orderId: 'test-order'),
          dataOverride: data);
      expect(find.text('MT-4821 · Awaiting GPS'), findsOneWidget);
      expect(find.text('MT-4821 · Live'), findsNothing);
    }
  });

  testWidgets('Tracking delivered progress offers sender confirmation',
      (tester) async {
    await mount(tester, const LiveTrackingScreen(orderId: 'test-order'),
        dataOverride: _TrackingData(status: OrderStatus.delivered));
    expect(
        tester
            .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator))
            .value,
        1);
    final sheet = find.descendant(
        of: find.byType(DraggableScrollableSheet),
        matching: find.byType(ListView));
    await tester.drag(sheet, const Offset(0, -650));
    await tester.pumpAndSettle();
    expect(find.text('Confirm delivery'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tracking camera padding follows the sheet on narrow phones',
      (tester) async {
    for (final width in [320.0, 390.0]) {
      await tester.pumpWidget(const SizedBox());
      await mount(tester, const LiveTrackingScreen(orderId: 'test-order'),
          width: width, scale: 1.3);
      final before = tester
          .widget<LiveGoogleMap>(find.byType(LiveGoogleMap))
          .bottomPadding;
      final sheet = find.descendant(
          of: find.byType(DraggableScrollableSheet),
          matching: find.byType(ListView));
      await tester.dragFrom(tester.getTopLeft(sheet) + const Offset(100, 28),
          const Offset(0, -190));
      await tester.pumpAndSettle();
      final after = tester
          .widget<LiveGoogleMap>(find.byType(LiveGoogleMap))
          .bottomPadding;
      expect(after, greaterThan(before));
      expect(tester.takeException(), isNull);
      await tester.dragFrom(tester.getTopLeft(sheet) + const Offset(100, 28),
          const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<LiveGoogleMap>(find.byType(LiveGoogleMap))
              .bottomPadding,
          closeTo(844 * .85, 1));
      expect(find.byTooltip('Zoom in'), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
      'Updated home shows the device address and includes pending deliveries',
      (tester) async {
    await mount(tester, const Scaffold(body: HomeScreen()),
        dataOverride: _HomeData());
    expect(find.text('Device pickup address'), findsOneWidget);
    expect(find.text('Default pickup address'), findsNothing);
    expect(find.text('Awaiting deliverer'), findsOneWidget);
    final flow =
        tester.element(find.byType(HomeScreen)).read<SendFlowProvider>();
    flow.setDetails(pickupAddress: 'Selected pickup address');
    await tester.pumpAndSettle();
    expect(find.text('Selected pickup address'), findsOneWidget);
    expect(find.text('Device pickup address'), findsNothing);
  });

  testWidgets('Updated home does not show completed orders as active',
      (tester) async {
    await mount(tester, const Scaffold(body: HomeScreen()));
    expect(find.text('Your next delivery'), findsOneWidget);
    expect(find.text('Track'), findsNothing);
    expect(find.text('Wireless Headphones'), findsNothing);
  });

  testWidgets('Updated home retry executes refresh and recovers from errors',
      (tester) async {
    final data = _HomeData(failOrders: true, failRefresh: true);
    await mount(tester, const Scaffold(body: HomeScreen()), dataOverride: data);
    await tester.drag(find.byType(ListView).first, const Offset(0, -1200));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(data.refreshCalls, 1);
    expect(find.text('Unable to refresh your home screen.'), findsOneWidget);
    data.failOrders = false;
    data.failRefresh = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(data.refreshCalls, 2);
    expect(find.text('Unable to refresh your home screen.'), findsNothing);
  });

  testWidgets('Updated home presentation routes and fits small phones',
      (tester) async {
    final destinations = <(String, Object?)>[];
    for (final width in [320.0, 390.0]) {
      await tester.pumpWidget(const SizedBox());
      await mount(
          tester,
          Scaffold(
              body: HomeContent(
                  greeting: 'Good afternoon',
                  currentLocation:
                      'A long pickup address that must remain inside its header',
                  onNavigate: (route, args) =>
                      destinations.add((route, args)))),
          width: width,
          scale: 1.3);
      await tester.tap(find.text('P2P delivery'));
      expect(destinations.last, ('/p2p-requests', null));
      await tester.tap(find.text('Schedule'));
      expect(destinations.last, ('/schedule', null));
      await tester.drag(find.byType(ListView).first, const Offset(0, -600));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Run an errand'));
      expect(destinations.last, ('/errand', null));
      expect(tester.takeException(), isNull);
    }
  });

  test('Saved addresses parse default flags without inferring a default', () {
    expect(SavedAddress.fromJson({'is_default': true}).isDefault, isTrue);
    expect(SavedAddress.fromJson({'isDefault': true}).isDefault, isTrue);
    expect(SavedAddress.fromJson({}).isDefault, isFalse);
  });

  testWidgets('Feature gates do not grant unverified sender delivery access',
      (tester) async {
    await mount(
        tester, const DelivererGate(child: Text('Private delivery jobs')));
    expect(find.text('Private delivery jobs'), findsNothing);
    expect(
        find.text('Approval is required for delivery work.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await mount(
        tester, const DelivererGate(child: Text('Private delivery jobs')),
        deliverer: true);
    expect(find.text('Private delivery jobs'), findsOneWidget);
  });

  testWidgets('Ad refresh never invents listings when the API is unavailable',
      (tester) async {
    await mount(tester, const AdsScreen());
    expect(find.text('Delivery ads is not connected to the mobile API yet.'),
        findsOneWidget);
    await tester.tap(find.byTooltip('Refresh ads'));
    await tester.pumpAndSettle();
    expect(find.text('Delivery ads is not connected to the mobile API yet.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('App boot uses the centralized route and preference providers',
      (tester) async {
    await tester.pumpWidget(const MoveTraqApp());
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
