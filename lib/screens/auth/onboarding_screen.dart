import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/mini_map.dart';
import '../../widgets/primary_button.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 20, 26, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(12)),
                    child: const Center(
                      child: Icon(Icons.route_rounded, color: AppColors.accent, size: 22),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('MoveTraq',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 22)),
                ],
              ),
              const SizedBox(height: 40),
              Text('Everything,\ndelivered.',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 38, height: 1.04)),
              const SizedBox(height: 14),
              const Text(
                'Send, receive and track parcels across the city — live, to the doorstep.',
                style: TextStyle(fontSize: 15.5, height: 1.5, color: AppColors.inkSoft),
              ),
              const SizedBox(height: 26),
              ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: Container(
                  color: AppColors.darkSurface,
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          const MiniMap(height: 190),
                          Positioned(
                            left: 16,
                            top: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                              ),
                              child: const Text('Live · arriving 12 min',
                                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        color: AppColors.darkSurface2,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 20,
                              backgroundColor: Color(0xFF3A4250),
                              child: Text('DO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Daniel is on the way',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                                  SizedBox(height: 2),
                                  Text('MT-4821 · Wireless Headphones',
                                      style: TextStyle(color: Color(0xFF8A93A2), fontSize: 12)),
                                ],
                              ),
                            ),
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(12)),
                              child: const Icon(Icons.chat_bubble_outline, color: AppColors.ink, size: 18),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              PrimaryButton(
                label: 'Get started',
                trailingIcon: Icons.arrow_forward,
                onPressed: () => Navigator.pushNamed(context, '/create'),
              ),
              const SizedBox(height: 12),
              SecondaryButton(
                label: 'I already have an account',
                onPressed: () => Navigator.pushNamed(context, '/signin'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 22),
                child: Row(children: const [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('or continue with', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                  ),
                  Expanded(child: Divider()),
                ]),
              ),
              Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      label: 'Google',
                      height: 50,
                      fontSize: 14,
                      radius: 14,
                      onPressed: () => Navigator.pushNamed(context, '/create'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SecondaryButton(
                      label: 'Apple',
                      height: 50,
                      fontSize: 14,
                      radius: 14,
                      onPressed: () => Navigator.pushNamed(context, '/create'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SecondaryButton(
                      label: 'Email',
                      height: 50,
                      fontSize: 14,
                      radius: 14,
                      onPressed: () => Navigator.pushNamed(context, '/create'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
