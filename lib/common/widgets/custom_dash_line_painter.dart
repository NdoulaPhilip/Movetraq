import 'package:flutter/material.dart';

class CustomDashLinePainter extends CustomPainter {
  final double dashWidth;
  final double dashSpace;
  final Color color;

  CustomDashLinePainter({this.dashWidth = 5.0, this.dashSpace = 3.0, this.color = Colors.black});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 1.0;

    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
