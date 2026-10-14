import 'package:flutter/material.dart';
import '../../screens/auth/sign_in_screen.dart';
import '../../screens/auth/create_account_screen.dart';
import '../../screens/additional_screens.dart';
import '../../widgets/app_page.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key, required this.mode, this.email});
  final String mode;
  final String? email;
  @override
  Widget build(BuildContext context) => switch (mode) {
        'login' => const SignInScreen(),
        'signup' => const CreateAccountScreen(),
        'verify' => additionalScreen('/verify-email', {'email': email ?? ''})!,
        'reset' => additionalScreen('/password-recovery', null)!,
        'recovery' => additionalScreen('/change-password', null)!,
        _ => const AppPage(title: 'Authentication unavailable', children: [
            InfoBand(title: 'This authentication page could not be found.')
          ]),
      };
}
