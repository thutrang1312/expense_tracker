import 'dart:math' as math;

import 'package:flutter/material.dart';

class DonutChartPainter extends CustomPainter {
  DonutChartPainter({
    required this.values,
    required this.colors,
    required this.progress,
  });

  final List<double> values;
  final List<Color> colors;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (sum, value) => sum + value);
    final center = Offset(size.width / 2, size.height / 2);
    final strokeWidth = math.min(size.width, size.height) * 0.17;
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final background = Paint()
      ..color = const Color(0xFFE9EFEC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawArc(rect, 0, math.pi * 2, false, background);

    if (total <= 0) return;
    var startAngle = -math.pi / 2;
    final visibleSweep = math.pi * 2 * progress.clamp(0, 1);
    for (var index = 0; index < values.length; index++) {
      final sweep = values[index] / total * math.pi * 2;
      if (sweep > 0) {
        final paint = Paint()
          ..color = colors[index % colors.length]
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.butt;
        final drawnSweep = math.min(sweep, visibleSweep);
        if (drawnSweep > 0) {
          canvas.drawArc(rect, startAngle, drawnSweep, false, paint);
        }
        startAngle += sweep;
      }
    }
  }

  @override
  bool shouldRepaint(covariant DonutChartPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.values != values ||
        oldDelegate.colors != colors;
  }
}
