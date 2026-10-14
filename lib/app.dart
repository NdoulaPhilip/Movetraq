import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/routing/router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/preferences.dart';
import 'providers/auth_provider.dart';
import 'providers/deliverer_tracking_provider.dart';
import 'providers/send_flow_provider.dart';
import 'services/local_data_service.dart';

class MoveTraqApp extends StatelessWidget {
  const MoveTraqApp({super.key});
  @override
  Widget build(BuildContext context) => MultiProvider(
          providers: [
            Provider<LocalDataService>(
                create: (_) => LocalDataService(),
                dispose: (_, data) => data.dispose()),
            ChangeNotifierProvider<AuthProvider>(
                create: (context) =>
                    AuthProvider(context.read<LocalDataService>())),
            ChangeNotifierProvider<SendFlowProvider>(
                create: (context) =>
                    SendFlowProvider(context.read<LocalDataService>())),
            ChangeNotifierProvider<DelivererTrackingProvider>(
                create: (context) => DelivererTrackingProvider(
                    data: context.read<LocalDataService>())),
            ChangeNotifierProxyProvider<AuthProvider, DisplayPreferences>(
                create: (_) => DisplayPreferences(),
                update: (_, auth, preferences) =>
                    preferences!..resetForUser(auth.profile?.uid)),
          ],
          child: Consumer<DisplayPreferences>(
              builder: (context, preferences, _) => MaterialApp(
                    debugShowCheckedModeBanner: false,
                    title: 'MoveTraq',
                    theme: preferences.reduceMotion
                        ? AppTheme.light.copyWith(
                            pageTransitionsTheme:
                                PageTransitionsTheme(builders: {
                            for (final platform in TargetPlatform.values)
                              platform: const NoMotionTransitions()
                          }))
                        : AppTheme.light,
                    builder: (context, child) => MediaQuery(
                        data: preferences.mediaQuery(MediaQuery.of(context)),
                        child: child!),
                    initialRoute: '/splash',
                    onGenerateRoute: AppRouter.onGenerateRoute,
                    onUnknownRoute: AppRouter.onGenerateRoute,
                  )));
}
