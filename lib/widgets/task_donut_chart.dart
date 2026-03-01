import 'package:flutter/material.dart';

// ================================
// TASK DONUT CHART PAINTER
// ================================

class TaskDonutChartPainter extends CustomPainter {
  final int completed;
  final int pending;
  final int overdue;

  TaskDonutChartPainter({
    required this.completed,
    required this.pending,
    required this.overdue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = 8.0;

    final total = completed + pending + overdue;
    if (total == 0) return;

    double startAngle = -1.5708; // -90 degrees

    // Completed (Green)
    if (completed > 0) {
      final sweepAngle = (completed / total) * 6.2832; // 2 * PI
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
      startAngle += sweepAngle;
    }

    // Overdue (Red)
    if (overdue > 0) {
      final sweepAngle = (overdue / total) * 6.2832;
      final paint = Paint()
        ..color = Colors.red
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
      startAngle += sweepAngle;
    }

    // Pending (Orange)
    if (pending > 0) {
      final sweepAngle = (pending / total) * 6.2832;
      final paint = Paint()
        ..color = Colors.orange
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

    // Background circle
    final backgroundPaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius - strokeWidth / 2, backgroundPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
