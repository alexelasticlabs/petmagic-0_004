import 'package:flutter/material.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';

/// Small, local artwork for empty and guest states. It carries no state or
/// animation, so feedback remains readable while offline or in reduced motion.
class PetMagicStateIllustration extends StatelessWidget {
  const PetMagicStateIllustration({
    required this.icon,
    this.color,
    this.size = 104,
    super.key,
  });

  final IconData icon;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final ink = color ?? colors.accentInk;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      colors.accent.withValues(alpha: 0.12),
                      colors.accent.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            Transform.rotate(
              angle: -0.13,
              child: Container(
                width: size * 0.64,
                height: size * 0.64,
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(size * 0.2),
                  border: Border.all(
                    color: colors.accent.withValues(alpha: 0.15),
                  ),
                ),
              ),
            ),
            Container(
              width: size * 0.64,
              height: size * 0.64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size * 0.2),
                color: colors.surface,
                border: Border.all(color: colors.border),
                boxShadow: [
                  BoxShadow(
                    color: colors.shadow.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: ink, size: size * 0.32),
            ),
            PositionedDirectional(
              end: size * 0.04,
              top: size * 0.04,
              child: Icon(
                Icons.auto_awesome_rounded,
                color: colors.goldInk,
                size: size * 0.23,
              ),
            ),
            PositionedDirectional(
              start: size * 0.06,
              bottom: size * 0.12,
              child: Icon(
                icon == Icons.pets_rounded
                    ? Icons.auto_awesome_rounded
                    : Icons.pets_rounded,
                color: colors.accentInk,
                size: size * 0.17,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
