import 'package:flutter/material.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/shared/widgets/motion.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_animated_button_child.dart';

class PetMagicAsyncStateView extends StatelessWidget {
  const PetMagicAsyncStateView({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.padding,
    this.iconColor,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry? padding;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final duration = PetMotion.effectiveDuration(context, PetMotion.medium);

    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: PetMotion.emphasized,
      switchOutCurve: Curves.easeIn,
      child: Padding(
        key: ValueKey('$title|$message|$actionLabel'),
        padding: padding ?? const EdgeInsets.fromLTRB(28, 36, 28, 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor ?? colors.accent, size: 46),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: colors.textStrong,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.textMuted,
                fontSize: 13,
                height: 1.35,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onAction,
                child: PetMagicAnimatedButtonChild(label: actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
