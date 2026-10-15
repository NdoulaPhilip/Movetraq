import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as maps;
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

class _TestData extends LocalDataService {
  _TestData({this.orderOverride});
  final ParcelOrder? orderOverride;
  ParcelOrder get _order => orderOverride ?? _defaultOrder;
  final supportRequests = <Map<String, String>>[];
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
  GoogleFonts.config.allowRuntimeFetching = false;
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
          const MethodChannel('movetraq/map_config'), (call) async => false);
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
        verified: deliverer,
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
    expect(
        find.text('Withdraw earnings is not connected to the mobile API yet.'),
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
          delivererId: driver,
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
    expect(find.text('Pickup delivery'), findsOneWidget);
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
        final action = tester.widget<PrimaryButton>(find.byWidgetPredicate(
            (widget) =>
                widget is PrimaryButton &&
                widget.label ==
                    (dropoff ? 'Confirm handover' : 'Item collected')));
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
    final action = tester.widget<PrimaryButton>(find.byWidgetPredicate(
        (widget) =>
            widget is PrimaryButton && widget.label == 'Confirm handover'));
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
              ? 'Pickup delivery'
              : 'Delivery drop-off'),
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
    await tester.ensureVisible(find.text('Confirm delivery'));
    await tester.tap(find.text('Confirm delivery'));
    await tester.pumpAndSettle();
    expect(
        find.text('Delivery handover is not connected to the mobile API yet.'),
        findsOneWidget);
    expect(find.text('Confirm handover'), findsOneWidget);
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
    await mount(tester, const MapPickerScreen());
    maps.GoogleMap map() => tester
        .widget<ConfiguredGoogleMap>(find.byType(ConfiguredGoogleMap))
        .map;
    expect(map().markers, isEmpty);
    expect(tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed,
        isNull);
    map().onTap!(const maps.LatLng(6.6, 3.3));
    await tester.pumpAndSettle();
    expect(map().markers.single.draggable, isTrue);
    map().markers.single.onDragEnd!(const maps.LatLng(6.4, 3.5));
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
      'Updated home uses real default pickup and includes pending deliveries',
      (tester) async {
    await mount(tester, const Scaffold(body: HomeScreen()),
        dataOverride: _HomeData());
    expect(find.text('Default pickup address'), findsOneWidget);
    expect(find.text('Awaiting deliverer'), findsOneWidget);
    final flow =
        tester.element(find.byType(HomeScreen)).read<SendFlowProvider>();
    flow.setDetails(pickupAddress: 'Selected pickup address');
    await tester.pumpAndSettle();
    expect(find.text('Selected pickup address'), findsOneWidget);
    expect(find.text('Default pickup address'), findsNothing);
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
