import 'package:flutter/material.dart';
import 'package:petmagic_mobile/shared/widgets/motion.dart';

/// Animates between confirmed text values without displaying intermediate
/// values that could be mistaken for real application state.
class PetMagicAnimatedValueText extends StatelessWidget {
  const PetMagicAnimatedValueText({
    required this.value,
    this.style,
    this.textAlign,
    this.maxLines = 1,
    this.overflow = TextOverflow.clip,
    this.semanticsLabel,
    this.alignment = Alignment.centerLeft,
    this.duration = PetMotion.medium,
    this.curve = PetMotion.emphasized,
    super.key,
  });

  final String value;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final String? semanticsLabel;
  final AlignmentGeometry alignment;
  final Duration duration;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    final valueText = Text(
      value,
      key: ValueKey<String>(value),
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
    final Widget visual;
    if (PetMotion.reduceMotion(context)) {
      visual = valueText;
    } else {
      visual = AnimatedSwitcher(
        duration: duration,
        switchInCurve: curve,
        switchOutCurve: curve,
        layoutBuilder: (currentChild, previousChildren) {
          return Stack(
            alignment: alignment,
            clipBehavior: Clip.none,
            children: [...previousChildren, ?currentChild],
          );
        },
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.16),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: valueText,
      );
    }

    return Semantics(
      label: semanticsLabel ?? value,
      child: ExcludeSemantics(child: visual),
    );
  }
}
