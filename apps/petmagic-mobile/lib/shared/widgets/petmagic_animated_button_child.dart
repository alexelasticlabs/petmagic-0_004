import 'package:flutter/material.dart';
import 'package:petmagic_mobile/shared/widgets/motion.dart';

class PetMagicAnimatedButtonChild extends StatelessWidget {
  const PetMagicAnimatedButtonChild({
    required this.label,
    this.loadingLabel,
    this.isLoading = false,
    this.icon,
    this.loadingIndicatorColor,
    super.key,
  });

  final String label;
  final String? loadingLabel;
  final bool isLoading;
  final Widget? icon;
  final Color? loadingIndicatorColor;

  @override
  Widget build(BuildContext context) {
    final duration = PetMotion.effectiveDuration(context, PetMotion.fast);

    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: PetMotion.emphasized,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        final offset = Tween<Offset>(
          begin: const Offset(0, 0.16),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offset, child: child),
        );
      },
      child: isLoading
          ? Row(
              key: const ValueKey('petmagic-button-loading'),
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      loadingIndicatorColor ??
                          DefaultTextStyle.of(context).style.color ??
                          Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(child: Text(loadingLabel ?? label)),
              ],
            )
          : Row(
              key: const ValueKey('petmagic-button-label'),
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[icon!, const SizedBox(width: 8)],
                Flexible(child: Text(label)),
              ],
            ),
    );
  }
}
