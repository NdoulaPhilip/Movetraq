import 'package:flutter/material.dart';

import '../models/parcel_order.dart';
import '../theme/app_theme.dart';

/// A stylized stand-in "map" card (dark surface + route line + pulsing dot),
/// matching the original design's `{{ miniMap }}` slot. Swap this out for a
/// real `google_maps_flutter` / `flutter_map` widget once you add API keys —
/// everything else (courier location stream) is already wired for it.
class MiniMap extends StatefulWidget {
  /// Fixed height for the map card. Pass null to fill all available space
  /// (e.g. wrapped in `Positioned.fill` for a full-screen live map).
  final double? height;
  final bool showPulse;
  final LatLng? courierLocation;
  const MiniMap({
    super.key,
    this.height = 150,
    this.showPulse = true,
    this.courierLocation,
  });

  @override
  State<MiniMap> createState() => _MiniMapState();
}

class _MiniMapState extends State<MiniMap> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget? _buildPulse() {
    if (!widget.showPulse) return null;
    final alignment = _markerAlignment(widget.courierLocation);
    return Align(
      alignment: alignment,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: (1 - t).clamp(0, 1),
                child: Transform.scale(
                  scale: 1 + t * 1.6,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                  ),
                ),
              ),
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
              ),
            ],
          );
        },
      ),
    );
  }

  Alignment _markerAlignment(LatLng? location) {
    if (location == null) {
      return const Alignment(0.4, -0.1);
    }

    const minLat = 6.5000;
    const maxLat = 6.5500;
    const minLng = 3.3500;
    const maxLng = 3.4100;
    final x = ((location.longitude - minLng) / (maxLng - minLng))
        .clamp(0.08, 0.92)
        .toDouble();
    final y = 1 -
        ((location.latitude - minLat) / (maxLat - minLat))
            .clamp(0.08, 0.92)
            .toDouble();

    return Alignment(x * 2 - 1, y * 2 - 1);
  }

  @override
  Widget build(BuildContext context) {
    // CustomPaint.size is non-nullable, so build it with or without an
    // explicit `size:` argument rather than trying to pass a nullable Size.
    final content = widget.height == null
        ? CustomPaint(size: Size.infinite, painter: _RoutePainter(), child: _buildPulse())
        : CustomPaint(painter: _RoutePainter(), child: _buildPulse());
    if (widget.height == null) return SizedBox.expand(child: content);
    return SizedBox(height: widget.height, child: content);
  }
}

class _RoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = AppColors.darkSurface;
    canvas.drawRect(Offset.zero & size, bg);

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 26) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 26) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final route = Paint()
      ..color = AppColors.accent
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width * 0.12, size.height * 0.82)
      ..cubicTo(
        size.width * 0.4, size.height * 0.82,
        size.width * 0.35, size.height * 0.25,
        size.width * 0.68, size.height * 0.28,
      );
    canvas.drawPath(path, route);

    final startDot = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(size.width * 0.12, size.height * 0.82), 5, startDot);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Circular icon button used repeatedly for back / bell / etc.
class CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color background;
  final Color iconColor;
  final bool showDot;

  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.background = Colors.white,
    this.iconColor = AppColors.ink,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.borderSoft),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, size: 20, color: iconColor),
              if (showDot)
                Positioned(
                  top: 9,
                  right: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A simple header row: back button + title, used on detail-style screens.
class ScreenHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const ScreenHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleIconButton(icon: Icons.arrow_back, onTap: () => Navigator.of(context).maybePop()),
        Expanded(
          child: Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.ink)),
        ),
        trailing ?? const SizedBox(width: 44),
      ],
    );
  }
}
