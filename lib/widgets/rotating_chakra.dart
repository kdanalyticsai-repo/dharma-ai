import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:dharma_ai/theme/theme.dart';

/// A slowly rotating Dharmachakra (dharma wheel) — used as a serene
/// brand accent on the login screen.
class RotatingChakra extends StatefulWidget {
  final double size;
  final int spokes;
  final Duration period;

  const RotatingChakra({
    Key? key,
    this.size = 96,
    this.spokes = 8,
    this.period = const Duration(seconds: 24),
  }) : super(key: key);

  @override
  State<RotatingChakra> createState() => _RotatingChakraState();
}

class _RotatingChakraState extends State<RotatingChakra>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.period)..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: CustomPaint(
        size: Size(widget.size, widget.size),
        painter: _ChakraPainter(spokes: widget.spokes),
      ),
    );
  }
}

class _ChakraPainter extends CustomPainter {
  final int spokes;
  _ChakraPainter({required this.spokes});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    final rim = Paint()
      ..color = SacredTheme.deepSaffron
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.04
      ..strokeCap = StrokeCap.round;

    final thin = Paint()
      ..color = SacredTheme.templeGold
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.02
      ..strokeCap = StrokeCap.round;

    // Outer + inner rims
    canvas.drawCircle(center, r * 0.92, rim);
    canvas.drawCircle(center, r * 0.62, thin);

    // Spokes radiating from the hub to the inner rim
    for (int i = 0; i < spokes; i++) {
      final angle = (i * 2 * math.pi) / spokes;
      final inner = Offset(
        center.dx + r * 0.18 * math.cos(angle),
        center.dy + r * 0.18 * math.sin(angle),
      );
      final outer = Offset(
        center.dx + r * 0.62 * math.cos(angle),
        center.dy + r * 0.62 * math.sin(angle),
      );
      canvas.drawLine(inner, outer, thin);
      // Small bead near the rim at each spoke tip
      canvas.drawCircle(
        Offset(
          center.dx + r * 0.77 * math.cos(angle),
          center.dy + r * 0.77 * math.sin(angle),
        ),
        size.width * 0.018,
        Paint()..color = SacredTheme.deepSaffron,
      );
    }

    // Hub
    canvas.drawCircle(
      center,
      r * 0.16,
      Paint()..color = SacredTheme.deepSaffron,
    );
    canvas.drawCircle(center, r * 0.16, thin);
  }

  @override
  bool shouldRepaint(covariant _ChakraPainter oldDelegate) =>
      oldDelegate.spokes != spokes;
}
