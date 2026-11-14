import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Seconds into the breath cycle for [step] at fractional [progress].
double breathElapsed(int step, double progress, List<double> durations) {
  var elapsed = 0.0;
  for (var i = 0; i < step; i++) {
    elapsed += durations[i];
  }
  return elapsed + progress * durations[step];
}

/// Height of the breath path at [seconds] into the cycle, from 0 (empty
/// lungs) to 1 (full). Inhale rises, the first hold stays at the top,
/// exhale falls and the second hold stays at the bottom.
double breathLevel(double seconds, List<double> durations) {
  final cycle = durations.fold<double>(0, (sum, d) => sum + d);
  var t = seconds % cycle;
  for (var i = 0; i < durations.length; i++) {
    final d = durations[i];
    if (t < d || i == durations.length - 1) {
      final f = d == 0 ? 1.0 : math.min(1.0, t / d);
      switch (i) {
        case 0:
          return f;
        case 1:
          return 1;
        case 2:
          return 1 - f;
        default:
          return 0;
      }
    }
    t -= d;
  }
  return 0;
}

/// A stepped breath line that scrolls right to left past a fixed ball.
class BreathPathPainter extends CustomPainter {
  final double elapsed;
  final List<double> durations;
  final Color lineColor;
  final Color ballColor;
  final String label;
  final String detail;
  final Color detailColor;
  final TextScaler textScaler;

  /// Horizontal position of the ball as a fraction of the width.
  static const ballFraction = 0.38;

  /// Seconds of breath visible across the full width.
  static const visibleSeconds = 10.0;

  BreathPathPainter({
    required this.elapsed,
    required this.durations,
    required this.lineColor,
    required this.ballColor,
    required this.label,
    required this.detail,
    required this.detailColor,
    this.textScaler = TextScaler.noScaling,
  });

  static double topFor(Size size) => size.height * 0.42;
  static double bottomFor(Size size) => size.height * 0.88;

  /// The y coordinate of the line for a breath [level] between 0 and 1.
  static double yFor(Size size, double level) =>
      bottomFor(size) - (bottomFor(size) - topFor(size)) * level;

  /// Where the ball sits for the current [elapsed] time.
  Offset ballOffset(Size size) => Offset(
        size.width * ballFraction,
        yFor(size, breathLevel(elapsed, durations)),
      );

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final pixelsPerSecond = size.width / visibleSeconds;
    final ballX = size.width * ballFraction;
    final start = elapsed - ballX / pixelsPerSecond;
    final end = elapsed + (size.width - ballX) / pixelsPerSecond;
    final cycle = durations.fold<double>(0, (sum, d) => sum + d);

    // Phase corners between start and end, plus the ball's own time.
    final times = <double>[start, elapsed, end];
    var base = (start / cycle).floorToDouble() * cycle;
    while (base <= end) {
      var corner = base;
      for (final d in durations) {
        corner += d;
        if (corner > start && corner < end) times.add(corner);
      }
      base += cycle;
    }
    times.sort();

    Offset point(double t) => Offset(
          ballX + (t - elapsed) * pixelsPerSecond,
          yFor(size, breathLevel(t, durations)),
        );
    final pastPoints = times.where((t) => t <= elapsed).map(point).toList();
    final aheadPoints = times.where((t) => t >= elapsed).map(point).toList();
    final past = Path()..addPolygon(pastPoints, false);
    final ahead = Path()..addPolygon(aheadPoints, false);

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(past, line..color = lineColor.withValues(alpha: 0.35));
    canvas.drawPath(ahead, line..color = lineColor);

    final ball = ballOffset(size);
    canvas.drawCircle(
      ball,
      20,
      Paint()
        ..color = lineColor.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(ball, 13, Paint()..color = ballColor);

    final text = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: ballColor,
          fontSize: 32,
          fontWeight: FontWeight.w700,
        ),
        children: [
          if (detail.isNotEmpty)
            TextSpan(
              text: '  $detail',
              style: TextStyle(
                color: detailColor,
                fontWeight: FontWeight.w300,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
        ],
      ),
      textDirection: TextDirection.ltr,
      textScaler: textScaler.clamp(maxScaleFactor: 1.6),
      maxLines: 1,
    );
    text.layout(maxWidth: size.width);
    final maxLeft = size.width - text.width;
    final left = math.max(0.0, math.min(ball.dx - text.width / 2, maxLeft));
    final top = math.max(0.0, ball.dy - 24 - text.height);
    text.paint(canvas, Offset(left, top));
    text.dispose();
  }

  @override
  bool shouldRepaint(covariant BreathPathPainter oldDelegate) =>
      oldDelegate.elapsed != elapsed ||
      oldDelegate.label != label ||
      oldDelegate.detail != detail ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.ballColor != ballColor ||
      oldDelegate.textScaler != textScaler ||
      oldDelegate.durations != durations;
}
