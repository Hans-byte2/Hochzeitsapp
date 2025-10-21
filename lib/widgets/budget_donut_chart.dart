import 'package:flutter/material.dart';

// ================================
// BUDGET DONUT CHART PAINTER (für Budget-Seite)
// ================================

class BudgetDonutChartPainter extends CustomPainter {
  final double totalPlanned;
  final double totalActual;
  final double remaining;

  BudgetDonutChartPainter({
    required this.totalPlanned,
    required this.totalActual,
    required this.remaining,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = 15.0;

    if (totalPlanned <= 0) return;

    double startAngle = -1.5708; // -90 degrees in radians

    // Ausgegeben (Orange/Red)
    if (totalActual > 0) {
      final sweepAngle = (totalActual / totalPlanned) * 6.2832; // 2 * PI
      final paint = Paint()
        ..color = totalActual > totalPlanned ? Colors.red : Colors.orange
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle > 6.2832 ? 6.2832 : sweepAngle,
        false,
        paint,
      );
      startAngle += sweepAngle > 6.2832 ? 6.2832 : sweepAngle;
    }

    // Übrig (Green)
    if (remaining > 0 && totalActual <= totalPlanned) {
      final sweepAngle = (remaining / totalPlanned) * 6.2832;
      final paint = Paint()
        ..color = Colors.green
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }

    // Hintergrund-Kreis
    final backgroundPaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius - strokeWidth / 2, backgroundPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ================================
// BUDGET PIE CHART PAINTER (für Dashboard)
// ================================

class BudgetPieChartPainter extends CustomPainter {
  final double actual;
  final double remaining;

  BudgetPieChartPainter({required this.actual, required this.remaining});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    final total = actual + remaining;

    if (total <= 0) return;

    final actualAngle = (actual / total) * 2 * 3.14159;
    const startAngle = -3.14159 / 2; // Start at top

    // Actual (spent) portion
    final actualPaint = Paint()
      ..color = Colors.red.shade400
      ..style = PaintingStyle.fill;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      actualAngle,
      true,
      actualPaint,
    );

    // Remaining portion
    final remainingPaint = Paint()
      ..color = Colors.red.shade100
      ..style = PaintingStyle.fill;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle + actualAngle,
      2 * 3.14159 - actualAngle,
      true,
      remainingPaint,
    );

    // Inner circle (donut hole)
    final innerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius * 0.4, innerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
