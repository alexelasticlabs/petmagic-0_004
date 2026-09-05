import 'package:flutter/material.dart';
import 'package:petmagic_mobile/shared/widgets/motion.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_haptics.dart';

class PressableScale extends StatefulWidget {
  const PressableScale({
    required this.child,
    required this.onTap,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.scaleDown = PetMotion.pressScale,
    this.haptic = PressableScaleHaptic.none,
    this.enabled = true,
    this.excludeFromSemantics = false,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;
  final double scaleDown;
  final PressableScaleHaptic haptic;
  final bool enabled;
  final bool excludeFromSemantics;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.enabled && widget.onTap != null;
    final reduceMotion = PetMotion.reduceMotion(context);
    final duration = PetMotion.effectiveDuration(context, PetMotion.fast);
    final pressScale = reduceMotion ? 1.0 : widget.scaleDown;

    return AnimatedScale(
      scale: _pressed && isEnabled ? pressScale : 1,
      duration: duration,
      curve: PetMotion.emphasized,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: widget.borderRadius,
          excludeFromSemantics: widget.excludeFromSemantics,
          onTap: isEnabled
              ? () {
                  _triggerHaptic(widget.haptic);
                  widget.onTap?.call();
                }
              : null,
          onHighlightChanged: (value) {
            if (_pressed == value) {
              return;
            }

            setState(() {
              _pressed = value;
            });
          },
          child: widget.child,
        ),
      ),
    );
  }

  void _triggerHaptic(PressableScaleHaptic haptic) {
    switch (haptic) {
      case PressableScaleHaptic.none:
        return;
      case PressableScaleHaptic.selection:
        PetMagicHaptics.selection();
        break;
      case PressableScaleHaptic.light:
        PetMagicHaptics.light();
        break;
      case PressableScaleHaptic.medium:
        PetMagicHaptics.medium();
        break;
    }
  }
}

enum PressableScaleHaptic { none, selection, light, medium }
