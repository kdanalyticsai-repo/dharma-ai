import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:dharma_ai/theme/theme.dart';

class LotusLoadingIndicator extends StatefulWidget {
  final double size;
  final Color? color;

  const LotusLoadingIndicator({
    Key? key,
    this.size = 50.0,
    this.color,
  }) : super(key: key);

  @override
  State<LotusLoadingIndicator> createState() => _LotusLoadingIndicatorState();
}

class _LotusLoadingIndicatorState extends State<LotusLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = widget.color ?? SacredTheme.deepSaffron;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: _controller.value * 2 * math.pi,
          child: CustomPaint(
            size: Size(widget.size, widget.size),
            painter: LotusPainter(
              color: themeColor,
              animationValue: _controller.value,
            ),
          ),
        );
      },
    );
  }
}

class LotusPainter extends CustomPainter {
  final Color color;
  final double animationValue;

  LotusPainter({
    required this.color,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final double centerX = size.width / 2;
    final double centerY = size.height / 2;
    final double radius = size.width / 4;

    // Draw 8 symmetric petals
    for (int i = 0; i < 8; i++) {
      final double angle = (i * 2 * math.pi) / 8;
      canvas.save();
      
      // Translate to center and rotate for this petal
      canvas.translate(centerX, centerY);
      canvas.rotate(angle);

      // Draw petal using two bezier curves
      final Path path = Path();
      path.moveTo(0, 0);
      
      // Left side of petal
      path.quadraticBezierTo(
        -radius * 0.8, -radius * 1.2,
        0, -radius * 2.0,
      );
      
      // Right side of petal
      path.quadraticBezierTo(
        radius * 0.8, -radius * 1.2,
        0, 0,
      );

      // Add a subtle inner detail line
      canvas.drawPath(path, paint);
      
      // Petal center vein
      canvas.drawLine(
        Offset(0, -radius * 0.3),
        Offset(0, -radius * 1.5),
        paint..strokeWidth = 1.0,
      );

      canvas.restore();
    }

    // Draw central seed head/circle
    final Paint centerPaint = Paint()
      ..color = SacredTheme.templeGold.withOpacity(0.8)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(Offset(centerX, centerY), radius * 0.4, centerPaint);
    
    // Core highlight circle
    final Paint ringPaint = Paint()
      ..color = color.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(Offset(centerX, centerY), radius * 0.4, ringPaint);
  }

  @override
  bool shouldRepaint(covariant LotusPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.animationValue != animationValue;
  }
}
