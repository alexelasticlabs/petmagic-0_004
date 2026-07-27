import 'package:flutter/material.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';

class PawSparkIcon extends StatelessWidget {
  const PawSparkIcon({super.key, this.size = 24, this.showGlow = false});

  final double size;
  final bool showGlow;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.accent,
        border: Border.all(
          color: colors.accent.withValues(alpha: isLight ? 0.52 : 0.7),
          width: size * 0.06,
        ),
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: colors.accent.withValues(alpha: isLight ? 0.16 : 0.26),
                  blurRadius: size * 0.38,
                  offset: Offset(0, size * 0.1),
                ),
              ]
            : null,
      ),
      child: Center(
        child: Icon(
          Icons.pets_rounded,
          size: size * 0.58,
          color: colors.on(colors.accent),
        ),
      ),
    );
  }
}
