import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:dharma_ai/theme/theme.dart';

class MandalaBackground extends StatefulWidget {
  final Widget child;
  final double scale;
  final Alignment alignment;
  final bool rotate;
  final double opacity;

  const MandalaBackground({
    Key? key,
    required this.child,
    this.scale = 1.0,
    this.alignment = Alignment.center,
    this.rotate = false,
    this.opacity = 0.10, // visible mandala on every screen
  }) : super(key: key);

  @override
  State<MandalaBackground> createState() => _MandalaBackgroundState();
}

class _MandalaBackgroundState extends State<MandalaBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40), // slow, serene rotation
    );
    if (widget.rotate) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant MandalaBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rotate != oldWidget.rotate) {
      if (widget.rotate) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              color: SacredTheme.surface,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: widget.rotate ? _controller.value * 2 * math.pi : 0.0,
                    child: CustomPaint(
                      painter: MandalaPainter(
                        scale: widget.scale,
                        alignment: widget.alignment,
                        opacity: widget.opacity,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        // Faint paper texture effect
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.05),
                    SacredTheme.surfaceDim.withOpacity(0.03),
                    Colors.white.withOpacity(0.05),
                  ],
                ),
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class MandalaPainter extends CustomPainter {
  final double scale;
  final Alignment alignment;
  final double opacity;

  MandalaPainter({
    required this.scale,
    required this.alignment,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Calculate center based on alignment
    double centerX = w / 2;
    double centerY = h / 2;
    if (alignment == Alignment.topLeft) {
      centerX = 0;
      centerY = 0;
    } else if (alignment == Alignment.topRight) {
      centerX = w;
      centerY = 0;
    } else if (alignment == Alignment.bottomRight) {
      centerX = w;
      centerY = h;
    } else if (alignment == Alignment.bottomLeft) {
      centerX = 0;
      centerY = h;
    }

    final double maxDimension = math.max(w, h);
    final double baseRadius = (maxDimension / 3) * scale;

    final Paint paint = Paint()
      ..color = SacredTheme.meditativeIndigo.withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    final Paint fillPaint = Paint()
      ..color = SacredTheme.templeGold.withOpacity(opacity * 0.5)
      ..style = PaintingStyle.fill;

    // Draw concentric circle rings
    for (double r in [0.15, 0.3, 0.45, 0.6, 0.8, 1.0]) {
      final double currentRadius = baseRadius * r;
      canvas.drawCircle(Offset(centerX, centerY), currentRadius, paint);
      
      // Draw small dotted highlight marks on rings
      if (r == 0.45 || r == 0.8) {
        paint.strokeWidth = 1.5;
        _drawRingDots(canvas, centerX, centerY, currentRadius, 32, paint);
        paint.strokeWidth = 1.0;
      }
    }

    // Draw radiating petals and geometric symbols
    canvas.save();
    canvas.translate(centerX, centerY);

    // 1. Draw Inner Lotus Star
    final int innerSymmetry = 12;
    for (int i = 0; i < innerSymmetry; i++) {
      final double angle = (i * 2 * math.pi) / innerSymmetry;
      canvas.save();
      canvas.rotate(angle);
      
      // Draw tiny petal point
      final Path petalPath = Path();
      petalPath.moveTo(0, baseRadius * 0.15);
      petalPath.quadraticBezierTo(
        baseRadius * 0.04, baseRadius * 0.22,
        0, baseRadius * 0.3,
      );
      petalPath.quadraticBezierTo(
        -baseRadius * 0.04, baseRadius * 0.22,
        0, baseRadius * 0.15,
      );
      canvas.drawPath(petalPath, paint);
      canvas.restore();
    }

    // 2. Draw Middle Sacred Geometric Triangles/Lace
    final int middleSymmetry = 24;
    for (int i = 0; i < middleSymmetry; i++) {
      final double angle = (i * 2 * math.pi) / middleSymmetry;
      canvas.save();
      canvas.rotate(angle);

      // Draw middle arc loop
      final Path loopPath = Path();
      loopPath.moveTo(0, baseRadius * 0.3);
      loopPath.cubicTo(
        baseRadius * 0.08, baseRadius * 0.4,
        baseRadius * 0.08, baseRadius * 0.5,
        0, baseRadius * 0.6,
      );
      loopPath.cubicTo(
        -baseRadius * 0.08, baseRadius * 0.5,
        -baseRadius * 0.08, baseRadius * 0.4,
        0, baseRadius * 0.3,
      );
      canvas.drawPath(loopPath, paint);

      // Draw a gold accent circle at the peak of the middle loops
      canvas.drawCircle(Offset(0, baseRadius * 0.52), 2.5, fillPaint);
      
      canvas.restore();
    }

    // 3. Draw Outer Radiant Rays
    final int outerSymmetry = 48;
    for (int i = 0; i < outerSymmetry; i++) {
      final double angle = (i * 2 * math.pi) / outerSymmetry;
      canvas.save();
      canvas.rotate(angle);

      // Draw alternate long/short rays
      final double length = i % 2 == 0 ? baseRadius * 1.0 : baseRadius * 0.85;
      final double start = baseRadius * 0.6;
      
      canvas.drawLine(
        Offset(0, start),
        Offset(0, length),
        paint..strokeWidth = 0.5,
      );
      
      if (i % 4 == 0) {
        // Little diamond at the tip of quadrant lines
        final Path diamond = Path();
        diamond.moveTo(0, length - 4);
        diamond.lineTo(3, length);
        diamond.lineTo(0, length + 4);
        diamond.lineTo(-3, length);
        diamond.close();
        canvas.drawPath(diamond, paint..strokeWidth = 1.0);
      }
      
      canvas.restore();
    }

    canvas.restore();
  }

  void _drawRingDots(Canvas canvas, double cx, double cy, double r, int dotCount, Paint paint) {
    for (int i = 0; i < dotCount; i++) {
      final double angle = (i * 2 * math.pi) / dotCount;
      final double dx = cx + r * math.cos(angle);
      final double dy = cy + r * math.sin(angle);
      canvas.drawCircle(Offset(dx, dy), 1.0, paint);
    }
  }

  @override
  bool shouldRepaint(covariant MandalaPainter oldDelegate) {
    return oldDelegate.scale != scale ||
        oldDelegate.alignment != alignment ||
        oldDelegate.opacity != opacity;
  }
}
