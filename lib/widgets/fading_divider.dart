import 'package:flutter/material.dart';

class FadingDivider extends StatelessWidget {
  final double height;
  final double thickness;
  final Color? color;
  final double indent;
  final double endIndent;

  const FadingDivider({
    Key? key,
    this.height = 16.0,
    this.thickness = 0.5,
    this.color,
    this.indent = 0.0,
    this.endIndent = 0.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dividerColor = color ?? Theme.of(context).colorScheme.outlineVariant;
    return Container(
      height: height,
      margin: EdgeInsets.only(left: indent, right: endIndent),
      child: Center(
        child: Container(
          height: thickness,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                dividerColor.withOpacity(0.0),
                dividerColor.withOpacity(1.0),
                dividerColor.withOpacity(0.0),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}
