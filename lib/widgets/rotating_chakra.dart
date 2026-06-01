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

    // Bolder, more visible colors
    final rim = Paint()
      ..color = SacredTheme.primary        // rich #9C3F00 saffron
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.055
      ..strokeCap = StrokeCap.round;

    final spoke = Paint()
      ..color = SacredTheme.deepSaffron    // vivid #CC5500 orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.030
      ..strokeCap = StrokeCap.round;

    final accent = Paint()
      ..color = SacredTheme.templeGold     // gold for inner ring + beads
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.022
      ..strokeCap = StrokeCap.round;

    // Outer rim + inner ring
    canvas.drawCircle(center, r * 0.90, rim);
    canvas.drawCircle(center, r * 0.60, accent);

    // Spokes
    for (int i = 0; i < spokes; i++) {
      final angle = (i * 2 * math.pi) / spokes;
      final inner = Offset(
        center.dx + r * 0.18 * math.cos(angle),
        center.dy + r * 0.18 * math.sin(angle),
      );
      final outer = Offset(
        center.dx + r * 0.60 * math.cos(angle),
        center.dy + r * 0.60 * math.sin(angle),
      );
      canvas.drawLine(inner, outer, spoke);
      // Bead between inner ring and outer rim
      canvas.drawCircle(
        Offset(
          center.dx + r * 0.76 * math.cos(angle),
          center.dy + r * 0.76 * math.sin(angle),
        ),
        size.width * 0.026,
        Paint()..color = SacredTheme.primary,
      );
    }

    // Hub (filled + outlined)
    canvas.drawCircle(center, r * 0.17,
        Paint()..color = SacredTheme.primary);
    canvas.drawCircle(center, r * 0.17, accent);
  }

  @override
  bool shouldRepaint(covariant _ChakraPainter oldDelegate) =>
      oldDelegate.spokes != spokes;
}
