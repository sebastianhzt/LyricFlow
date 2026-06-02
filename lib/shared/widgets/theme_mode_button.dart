import 'package:flutter/material.dart';

import '../../app.dart';

class ThemeModeButton extends StatelessWidget {
  const ThemeModeButton({
    this.style,
    super.key,
  });

  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    final controller = LyricFlowTheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return IconButton.filledTonal(
      tooltip: isDark ? 'Modo claro' : 'Modo oscuro',
      onPressed: controller.toggle,
      style: style,
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) {
          return RotationTransition(
            turns: Tween<double>(begin: -0.08, end: 0).animate(animation),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        child: Icon(
          isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          key: ValueKey(isDark),
        ),
      ),
    );
  }
}
