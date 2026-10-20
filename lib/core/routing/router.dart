import 'package:flutter/material.dart';
import '../../screens/auth/create_account_screen.dart';
import '../../screens/additional_screens.dart';
import '../../widgets/app_page.dart';
import '../../features/auth/welcome_screen.dart';
import '../../features/auth/auth_screen.dart';
import '../../screens/auth/sign_in_screen.dart';
import '../../features/chat/chat_screen.dart';
import '../../screens/deliverer/d_active_screen.dart';
import '../../screens/deliverer/deliverer_shell.dart';
import '../../screens/deliverer/d_job_screen.dart';
import '../../screens/home/home_shell.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../screens/receive/receive_screen.dart';
import '../../screens/release/release_done_screen.dart';
import '../../screens/release/release_otp_screen.dart';
import '../../screens/release/release_screen.dart';
import '../../screens/send/confirm_order_screen.dart';
import '../../screens/send/negotiate_screen.dart';
import '../../screens/send/pick_deliverer_screen.dart';
import '../../screens/send/send_done_screen.dart';
import '../../screens/send/send_screen.dart';
import '../../screens/splash/splash_screen.dart';
import '../../screens/track/live_tracking_screen.dart';
import '../../screens/track/track_list_screen.dart';
import '../../screens/wallet/topup_screen.dart';
import '../../features/wallet/wallet_screen.dart';
import '../../features/deliverer/deliverer_gate.dart';
import '../../features/tracking/order_screen.dart';

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final args = settings.arguments;

    final screen = switch (settings.name) {
      '/' || '/splash' => const SplashScreen(),
      '/onboarding' || '/onboard' || '/welcome' => const WelcomeScreen(),
      '/auth/login' => const AuthScreen(mode: 'login'),
      '/auth/signup' => const AuthScreen(mode: 'signup'),
      '/auth/reset' => const AuthScreen(mode: 'reset'),
      '/auth/verify' => const AuthScreen(mode: 'verify'),
      '/signin' => const SignInScreen(),
      '/create-account' || '/create' => const CreateAccountScreen(),
      '/home' => const HomeShell(),
      '/activity' => const HomeShell(initialIndex: 1),
      '/notifications' => const NotificationsScreen(),
      '/receive' => const ReceiveScreen(),
      '/send' => const SendScreen(),
      '/pick-deliverer' => const PickDelivererScreen(),
      '/confirm-order' => const ConfirmOrderScreen(),
      '/negotiate' => const NegotiateScreen(),
      '/send-done' => const SendDoneScreen(),
      '/tracking' || '/track' || '/track-list' => const TrackListScreen(),
      '/order-detail' => OrderScreen(id: _idArg(args)),
      '/live-tracking' || '/live' => LiveTrackingScreen(orderId: _idArg(args)),
      '/chat' => ChatScreen(orderId: _idArg(args)),
      '/wallet' => const WalletScreen(),
      '/topup' => const TopupScreen(),
      '/release-payment' || '/release' => ReleaseScreen(orderId: _idArg(args)),
      '/release-otp' => ReleaseOtpScreen(orderId: _idArg(args)),
      '/release-success' ||
      '/release-done' =>
        ReleaseDoneScreen(orderId: _idArg(args)),
      '/deliverer-home' ||
      '/deliverer' =>
        const DelivererGate(child: DelivererShell()),
      '/deliverer-job' || '/d-job' => DJobScreen(orderId: _idArg(args)),
      '/deliverer-active' ||
      '/d-active' =>
        DActiveScreen(orderId: _idArg(args)),
      '/deliverer-profile' => const ProfileScreen(),
      _ => additionalScreen(
              const {
                    '/addresses': '/saved-addresses',
                    '/personal': '/personal-details',
                    '/blocked': '/blocked-users',
                    '/application': '/deliverer-apply',
                    '/delivery-choice': '/service-choice',
                    '/locations': '/location-search'
                  }[settings.name] ??
                  settings.name,
              args) ??
          const AppPage(
              title: 'Page unavailable',
              children: [InfoBand(title: 'This page could not be found.')]),
    };

    return MaterialPageRoute(
      settings: settings,
      builder: (_) => _delivererRoutes.contains(settings.name)
          ? DelivererGate(child: screen)
          : screen,
    );
  }

  static const _delivererRoutes = {
    '/delivery-pickup',
    '/delivery-dropoff',
    '/handover',
    '/evidence-upload',
    '/deliverer-job',
    '/d-job',
    '/deliverer-active',
    '/d-active',
    '/deliverer-profile',
    '/delivery-work',
    '/analytics',
    '/performance',
    '/past-customers',
    '/customer-deliveries',
    '/deliverer-earnings',
    '/manage-orders',
    '/deliverer-orders',
    '/deliverer-work-settings',
    '/payouts',
    '/payout-history',
    '/my-p2p-ads',
    '/create-p2p-ad',
    '/edit-p2p-ad',
  };

  static String _idArg(Object? args) {
    if (args is String && args.isNotEmpty) {
      return args;
    }
    return '';
  }
}
