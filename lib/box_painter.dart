import 'package:flutter/material.dart';

class BoxBreathingPainter extends CustomPainter {
  final double progress;
  final int currentStep;
  final Color stepColor;
  final double glowIntensity;

  BoxBreathingPainter({
    required this.progress,
    required this.currentStep,
    required this.stepColor,
    required this.glowIntensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final boxSize = size.width * 0.8;
    final halfBox = boxSize / 2;
    
    // Box corners
    final topLeft = Offset(center.dx - halfBox, center.dy - halfBox);
    final topRight = Offset(center.dx + halfBox, center.dy - halfBox);
    final bottomRight = Offset(center.dx + halfBox, center.dy + halfBox);
    final bottomLeft = Offset(center.dx - halfBox, center.dy + halfBox);
    
    // Paint for box outline
    final boxPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    
    // Paint for active edge
    final activePaint = Paint()
      ..color = stepColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;
    
    // Paint for glow effect
    final glowPaint = Paint()
      ..color = stepColor.withOpacity(glowIntensity * 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
    
    // Paint for indicator dot
    final dotPaint = Paint()
      ..color = stepColor
      ..style = PaintingStyle.fill;
    
    final dotGlowPaint = Paint()
      ..color = stepColor.withOpacity(glowIntensity)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
    
    // Draw box outline
    final boxPath = Path()
      ..moveTo(topLeft.dx, topLeft.dy)
      ..lineTo(topRight.dx, topRight.dy)
      ..lineTo(bottomRight.dx, bottomRight.dy)
      ..lineTo(bottomLeft.dx, bottomLeft.dy)
      ..lineTo(topLeft.dx, topLeft.dy);
    
    canvas.drawPath(boxPath, boxPaint);
    
    // Calculate current position based on step and progress
    Offset currentPosition;
    Path currentPath;
    
    switch (currentStep) {
      case 0: // Inhale - Left edge (bottom to top)
        currentPosition = Offset(
          bottomLeft.dx,
          bottomLeft.dy - (bottomLeft.dy - topLeft.dy) * progress,
        );
        currentPath = Path()
          ..moveTo(bottomLeft.dx, bottomLeft.dy)
          ..lineTo(currentPosition.dx, currentPosition.dy);
        break;
      case 1: // Hold - Top edge (left to right)
        currentPosition = Offset(
          topLeft.dx + (topRight.dx - topLeft.dx) * progress,
          topLeft.dy,
        );
        currentPath = Path()
          ..moveTo(topLeft.dx, topLeft.dy)
          ..lineTo(currentPosition.dx, currentPosition.dy);
        break;
      case 2: // Exhale - Right edge (top to bottom)
        currentPosition = Offset(
          topRight.dx,
          topRight.dy + (bottomRight.dy - topRight.dy) * progress,
        );
        currentPath = Path()
          ..moveTo(topRight.dx, topRight.dy)
          ..lineTo(currentPosition.dx, currentPosition.dy);
        break;
      case 3: // Hold - Bottom edge (right to left)
        currentPosition = Offset(
          bottomRight.dx - (bottomRight.dx - bottomLeft.dx) * progress,
          bottomRight.dy,
        );
        currentPath = Path()
          ..moveTo(bottomRight.dx, bottomRight.dy)
          ..lineTo(currentPosition.dx, currentPosition.dy);
        break;
      default:
        currentPosition = bottomLeft;
        currentPath = Path();
    }
    
    // Draw glow effect for active edge
    canvas.drawPath(currentPath, glowPaint);
    
    // Draw active edge
    canvas.drawPath(currentPath, activePaint);
    
    // Draw indicator dot with glow
    canvas.drawCircle(currentPosition, 12.0, dotGlowPaint);
    canvas.drawCircle(currentPosition, 6.0, dotPaint);
    
    // Draw corner dots
    final cornerPaint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(topLeft, 3.0, cornerPaint);
    canvas.drawCircle(topRight, 3.0, cornerPaint);
    canvas.drawCircle(bottomRight, 3.0, cornerPaint);
    canvas.drawCircle(bottomLeft, 3.0, cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}