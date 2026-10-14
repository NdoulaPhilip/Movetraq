import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_theme.dart';

class AuthSocialButtons extends StatelessWidget {
  const AuthSocialButtons({super.key});

  void _unavailable(BuildContext context, String provider) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$provider sign-in is not configured.')));
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Row(children: [
              Expanded(child: Divider(color: AppColors.borderSoft)),
              Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('or continue with',
                      style: TextStyle(fontSize: 10, color: AppColors.muted))),
              Expanded(child: Divider(color: AppColors.borderSoft)),
            ])),
        Row(children: [
          Expanded(
              child: OutlinedButton.icon(
            onPressed: () => _unavailable(context, 'Google'),
            icon: SvgPicture.asset('assets/brand/google.svg',
                width: 18, height: 18),
            label: const Text('Google'),
            style: _style,
          )),
          const SizedBox(width: 10),
          Expanded(
              child: OutlinedButton.icon(
            onPressed: () => _unavailable(context, 'Apple'),
            icon: const Icon(Icons.apple, size: 19),
            label: const Text('Apple'),
            style: _style,
          )),
        ]),
      ]);

  static final _style = OutlinedButton.styleFrom(
    minimumSize: const Size.fromHeight(42),
    foregroundColor: AppColors.ink,
    textStyle: const TextStyle(
        fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600),
    side: const BorderSide(color: AppColors.borderSoft),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );
}
