import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/auth_social_buttons.dart';
import '../../widgets/movetraq_brand.dart';
import '../../widgets/primary_button.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.authBg,
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 54, 24, 32),
                  child: Column(children: [
                    const MoveTraqMark(size: 58),
                    const SizedBox(height: 50),
                    Text('Your world.\nDelivered.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .displayLarge
                            ?.copyWith(fontSize: 38, height: 1.02)),
                    const SizedBox(height: 24),
                    const Text(
                        'From little surprises to everyday essentials.\nSend it with care. Move it with Movetraq.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12, height: 1.7, color: AppColors.muted)),
                    const SizedBox(height: 24),
                    const Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 16,
                        runSpacing: 10,
                        children: [
                          _Benefit(
                              icon: Icons.shield_outlined, label: 'Protected'),
                          _Benefit(
                              icon: Icons.near_me_outlined, label: 'Trackable'),
                          _Benefit(
                              icon: Icons.inventory_2_outlined,
                              label: 'Door to door'),
                        ]),
                    const SizedBox(height: 28),
                    const Spacer(),
                    PrimaryButton(
                        label: 'Create account',
                        onPressed: () =>
                            Navigator.pushNamed(context, '/create')),
                    const SizedBox(height: 12),
                    SecondaryButton(
                        label: 'I already have an account',
                        onPressed: () =>
                            Navigator.pushNamed(context, '/signin')),
                    const AuthSocialButtons(),
                    const SizedBox(height: 24),
                  ]),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: AppColors.inkSoft),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: AppColors.inkSoft)),
      ]);
}

typedef WelcomeScreen = OnboardingScreen;
