import 'package:flutter/material.dart';
import 'package:petmagic_mobile/shared/widgets/motion.dart';
import 'package:petmagic_mobile/shared/widgets/pressable_scale.dart';

class PetMagicInteractiveSurface extends StatelessWidget {
  const PetMagicInteractiveSurface({
    required this.child,
    this.onTap,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.enabled = true,
    this.haptic = PressableScaleHaptic.none,
    this.scaleDown = PetMotion.pressScale,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;
  final bool enabled;
  final PressableScaleHaptic haptic;
  final double scaleDown;

  @override
  Widget build(BuildContext context) {
    final isEnabled = enabled && onTap != null;
    final duration = PetMotion.effectiveDuration(context, PetMotion.fast);

    return AnimatedOpacity(
      opacity: enabled ? 1 : 0.58,
      duration: duration,
      curve: PetMotion.standard,
      child: PressableScale(
        onTap: onTap,
        enabled: isEnabled,
        borderRadius: borderRadius,
        haptic: haptic,
        scaleDown: scaleDown,
        child: child,
      ),
    );
  }
}
