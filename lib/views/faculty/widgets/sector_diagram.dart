import 'dart:math' as math;
import 'package:flutter/material.dart';

class SectorDiagramPainter extends CustomPainter {
  final double sectorDegrees;
  final double headingDeg;

  SectorDiagramPainter({
    required this.sectorDegrees,
    required this.headingDeg,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    // Background circle (back zone — red)
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = Colors.red.withOpacity(0.12),
    );

    // Front sector (green)
    if (sectorDegrees < 359) {
      final startAngle =
          (headingDeg - sectorDegrees / 2 - 90) * math.pi / 180;
      final sweepAngle = sectorDegrees * math.pi / 180;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        Paint()..color = Colors.green.withOpacity(0.25),
      );
    } else {
      // Full circle green
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = Colors.green.withOpacity(0.2),
      );
    }

    // Outer circle border
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.grey.shade400
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Faculty arrow (direction pointer)
    final arrowAngle = (headingDeg - 90) * math.pi / 180;
    final arrowEnd = Offset(
      center.dx + (radius * 0.7) * math.cos(arrowAngle),
      center.dy + (radius * 0.7) * math.sin(arrowAngle),
    );
    canvas.drawLine(
      center,
      arrowEnd,
      Paint()
        ..color = Colors.orange
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    // Faculty dot
    canvas.drawCircle(
      center,
      8,
      Paint()..color = Colors.orange,
    );

    // Compass cardinal labels
    final tp = TextPainter(textDirection: TextDirection.ltr);

    void drawLabel(String text, Offset offset, Color color) {
      tp.text = TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      );
      tp.layout();
      tp.paint(canvas, offset - Offset(tp.width / 2, tp.height / 2));
    }

    drawLabel('N', center + Offset(0, -radius + 12), Colors.grey.shade600);
    drawLabel('S', center + Offset(0, radius - 12), Colors.grey.shade600);
    drawLabel('E', center + Offset(radius - 12, 0), Colors.grey.shade600);
    drawLabel('W', center + Offset(-radius + 12, 0), Colors.grey.shade600);
  }

  @override
  bool shouldRepaint(SectorDiagramPainter old) =>
      old.sectorDegrees != sectorDegrees || old.headingDeg != headingDeg;
}
