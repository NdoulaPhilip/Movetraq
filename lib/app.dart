import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/deliverer_tracking_provider.dart';
import 'providers/send_flow_provider.dart';
import 'screens/auth/create_account_screen.dart';
import 'screens/auth/onboarding_screen.dart';
import 'screens/auth/sign_in_screen.dart';
import 'screens/chat/chat_screen.dart';
import 'screens/deliverer/d_active_screen.dart';
import 'screens/deliverer/d_job_screen.dart';
import 'screens/home/home_shell.dart';
import 'screens/notifications/notifications_screen.dart';
import 'screens/release/release_done_screen.dart';
import 'screens/release/release_otp_screen.dart';
import 'screens/release/release_screen.dart';
import 'screens/send/confirm_order_screen.dart';
import 'screens/send/negotiate_screen.dart';
import 'screens/send/pick_deliverer_screen.dart';
import 'screens/send/send_done_screen.dart';
import 'screens/send/send_screen.dart';
import 'screens/track/live_tracking_screen.dart';
import 'screens/track/order_detail_screen.dart';
import 'screens/track/track_list_screen.dart';
import 'screens/wallet/topup_screen.dart';
import 'screens/wallet/wallet_screen.dart';
import 'services/local_data_service.dart';
import 'theme/app_theme.dart';

class MoveTraqApp extends StatelessWidget {
  const MoveTraqApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<LocalDataService>(
          create: (_) => LocalDataService(),
          dispose: (_, data) => data.dispose(),
        ),
        ChangeNotifierProvider<AuthProvider>(
          create: (context) => AuthProvider(
            context.read<LocalDataService>(),
          ),
        ),
        ChangeNotifierProvider<SendFlowProvider>(
          create: (context) => SendFlowProvider(
            context.read<LocalDataService>(),
          ),
        ),
        ChangeNotifierProvider<DelivererTrackingProvider>(
          create: (context) => DelivererTrackingProvider(
            data: context.read<LocalDataService>(),
          ),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'MoveTraq',
        theme: AppTheme.light,
        initialRoute: '/',
        onGenerateRoute: _onGenerateRoute,
      ),
    );
  }

  Route<dynamic> _onGenerateRoute(RouteSettings settings) {
    final name = settings.name ?? '/';
    final args = settings.arguments;

    Widget screen;
    switch (name) {
      case '/':
      case '/onboard':
        screen = const OnboardingScreen();
        break;
      case '/signin':
        screen = const SignInScreen();
        break;
      case '/create':
        screen = const CreateAccountScreen();
        break;
      case '/home':
        screen = const HomeShell();
        break;
      case '/notifications':
        screen = const NotificationsScreen();
        break;
      case '/send':
        screen = const SendScreen();
        break;
      case '/pick-deliverer':
        screen = const PickDelivererScreen();
        break;
      case '/negotiate':
        screen = const NegotiateScreen();
        break;
      case '/confirm-order':
        screen = const ConfirmOrderScreen();
        break;
      case '/send-done':
        screen = const SendDoneScreen();
        break;
      case '/track':
      case '/track-list':
        screen = const TrackListScreen();
        break;
      case '/order-detail':
        screen = OrderDetailScreen(orderId: _idArg(args));
        break;
      case '/live':
        screen = LiveTrackingScreen(orderId: _idArg(args));
        break;
      case '/chat':
        screen = ChatScreen(orderId: _idArg(args));
        break;
      case '/release':
        screen = ReleaseScreen(orderId: _idArg(args));
        break;
      case '/release-otp':
        screen = ReleaseOtpScreen(orderId: _idArg(args));
        break;
      case '/release-done':
        screen = ReleaseDoneScreen(orderId: _idArg(args));
        break;
      case '/wallet':
        screen = const WalletScreen();
        break;
      case '/topup':
        screen = const TopupScreen();
        break;
      case '/d-job':
        screen = DJobScreen(orderId: _idArg(args));
        break;
      case '/d-active':
        screen = DActiveScreen(orderId: _idArg(args));
        break;
      default:
        screen = const OnboardingScreen();
    }

    return MaterialPageRoute(
      settings: settings,
      builder: (_) => screen,
    );
  }

  String _idArg(Object? args) {
    if (args is String && args.isNotEmpty) {
      return args;
    }
    return '';
  }
}
