import 'dart:math' as math;

import 'package:flutter/material.dart';

class BarChartPainter extends CustomPainter {
  BarChartPainter({
    required this.values,
    required this.labels,
    required this.progress,
    required this.color,
  });

  final List<double> values;
  final List<String> labels;
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    const left = 8.0;
    const right = 8.0;
    const top = 12.0;
    const labelHeight = 22.0;
    final chartHeight = math.max(0.0, size.height - top - labelHeight);
    final maxValue = values.fold<double>(
      0,
      (maximum, value) => math.max(maximum, value).toDouble(),
    );
    final slotWidth = (size.width - left - right) / values.length;
    final barWidth = math.min(22.0, slotWidth * 0.48);
    final baseline = top + chartHeight;

    final baselinePaint = Paint()
      ..color = const Color(0xFFE9EFEC)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(left, baseline),
      Offset(size.width - right, baseline),
      baselinePaint,
    );

    for (var index = 0; index < values.length; index++) {
      final centerX = left + slotWidth * (index + 0.5);
      final barHeight = maxValue == 0
          ? 3.0
          : math.max(3.0, chartHeight * values[index] / maxValue * progress);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          centerX - barWidth / 2,
          baseline - barHeight,
          barWidth,
          barHeight,
        ),
        const Radius.circular(8),
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..color = values[index] == 0
              ? const Color(0xFFE0E8E4)
              : color.withValues(alpha: 0.48 + 0.52 * progress),
      );

      final text = TextPainter(
        text: TextSpan(
          text: labels[index],
          style: TextStyle(
            color: const Color(0xFF7B8983),
            fontSize: 10,
            fontWeight: index == values.length - 1
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, Offset(centerX - text.width / 2, baseline + 7));
    }
  }

  @override
  bool shouldRepaint(covariant BarChartPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.values != values ||
        oldDelegate.labels != labels ||
        oldDelegate.color != color;
  }
}
