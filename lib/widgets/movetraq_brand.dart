import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_theme.dart';

class MoveTraqMark extends StatelessWidget {
  const MoveTraqMark({
    super.key,
    this.size = 46,
    this.dark = false,
    this.showWordmark = false,
  });

  final double size;
  final bool dark;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    final logo = SizedBox(
      width: size,
      height: size,
      child: SvgPicture.asset(
        'assets/brand/movetraq-mark.svg',
        fit: BoxFit.contain,
        semanticsLabel: 'MoveTraq',
      ),
    );

    if (!showWordmark) return logo;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        logo,
      ],
    );
  }
}

class DelivererAvatar extends StatelessWidget {
  const DelivererAvatar({
    super.key,
    this.radius = 24,
  });

  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF9D7B61),
      backgroundImage: const AssetImage('assets/images/deliverer.png'),
    );
  }
}

class PremiumCard extends StatelessWidget {
  const PremiumCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color = Colors.white,
    this.radius = AppRadius.card,
    this.borderColor = AppColors.cardBorder,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final double radius;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class PremiumScreenTitle extends StatelessWidget {
  const PremiumScreenTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.w700,
                  fontSize: 24,
                  height: 1.2,
                  color: AppColors.ink,
                  letterSpacing: 0,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    height: 1.5,
                    color: AppColors.muted,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 14),
          trailing!,
        ],
      ],
    );
  }
}
