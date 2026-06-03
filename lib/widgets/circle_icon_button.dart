import 'package:flutter/material.dart';
import 'package:dharma_ai/theme/theme.dart';

/// A friendly, consistent circular icon action: a rounded glyph on a soft
/// saffron-tinted circle, with a tooltip and a comfortable touch target.
/// Used for top-bar / app-bar actions across the app.
class CircleIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const CircleIconButton({
    Key? key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Material(
        color: SacredTheme.primary.withOpacity(0.08),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Tooltip(
            message: tooltip,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Center(child: Icon(icon, size: 20, color: SacredTheme.primary)),
            ),
          ),
        ),
      ),
    );
  }
}
