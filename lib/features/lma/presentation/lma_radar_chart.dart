import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/models/lma_config_models.dart';

class LmaRadarChart extends StatelessWidget {
  const LmaRadarChart({
    super.key,
    required this.categoryScores,
  });

  final List<LeanMaturityCategoryScore> categoryScores;

  @override
  Widget build(BuildContext context) {
    if (categoryScores.isEmpty) {
      return const SizedBox(height: 220, child: Center(child: Text('No score data')));
    }

    return SizedBox(
      height: 320,
      child: CustomPaint(
        painter: _RadarPainter(categoryScores),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter(this.categoryScores);

  final List<LeanMaturityCategoryScore> categoryScores;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 12);
    final radius = math.min(size.width, size.height) * 0.28;
    final axisCount = categoryScores.length;
    final angleStep = (2 * math.pi) / axisCount;

    final gridPaint = Paint()
      ..color = AppColors.divider
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final axisPaint = Paint()
      ..color = AppColors.textSecondary.withOpacity(0.45)
      ..strokeWidth = 1;
    final areaPaint = Paint()
      ..color = AppColors.primary.withOpacity(0.18)
      ..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final dotPaint = Paint()..color = AppColors.primary;

    for (var ring = 1; ring <= 5; ring++) {
      final path = Path();
      final ringRadius = radius * (ring / 5);
      for (var i = 0; i < axisCount; i++) {
        final point = _pointFor(i, center, ringRadius, angleStep);
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    for (var i = 0; i < axisCount; i++) {
      final point = _pointFor(i, center, radius, angleStep);
      canvas.drawLine(center, point, axisPaint);
      _drawLabel(
        canvas,
        size,
        categoryScores[i].category,
        point,
      );
    }

    final polygon = Path();
    for (var i = 0; i < axisCount; i++) {
      final valueRadius = radius * (categoryScores[i].percentage.clamp(0, 100) / 100);
      final point = _pointFor(i, center, valueRadius, angleStep);
      if (i == 0) {
        polygon.moveTo(point.dx, point.dy);
      } else {
        polygon.lineTo(point.dx, point.dy);
      }
    }
    polygon.close();

    canvas.drawPath(polygon, areaPaint);
    canvas.drawPath(polygon, linePaint);

    for (var i = 0; i < axisCount; i++) {
      final valueRadius = radius * (categoryScores[i].percentage.clamp(0, 100) / 100);
      final point = _pointFor(i, center, valueRadius, angleStep);
      canvas.drawCircle(point, 4, dotPaint);
    }
  }

  Offset _pointFor(int index, Offset center, double radius, double angleStep) {
    final angle = (-math.pi / 2) + (angleStep * index);
    return Offset(
      center.dx + (radius * math.cos(angle)),
      center.dy + (radius * math.sin(angle)),
    );
  }

  void _drawLabel(Canvas canvas, Size size, String text, Offset anchor) {
    final label = text.length > 22 ? '${text.substring(0, 22)}...' : text;
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
      maxLines: 2,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: 92);

    double dx = anchor.dx - (painter.width / 2);
    double dy = anchor.dy - (painter.height / 2);

    if (anchor.dx < size.width / 2) dx -= 12;
    if (anchor.dx > size.width / 2) dx += 12;
    if (anchor.dy < size.height / 2) dy -= 12;
    if (anchor.dy > size.height / 2) dy += 12;

    painter.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) {
    return oldDelegate.categoryScores != categoryScores;
  }
}
