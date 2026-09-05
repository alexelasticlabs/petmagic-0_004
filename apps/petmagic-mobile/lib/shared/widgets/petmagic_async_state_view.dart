import 'package:flutter/material.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/shared/widgets/motion.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_animated_button_child.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_state_illustration.dart';

class PetMagicAsyncStateView extends StatelessWidget {
  const PetMagicAsyncStateView({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.footer,
    this.padding,
    this.iconColor,
    this.actionIcon,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? footer;
  final EdgeInsetsGeometry? padding;
  final Color? iconColor;
  final IconData? actionIcon;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final duration = PetMotion.effectiveDuration(context, PetMotion.medium);

    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: PetMotion.emphasized,
      switchOutCurve: Curves.easeIn,
      child: Center(
        key: ValueKey('$title|$message|$actionLabel'),
        child: SingleChildScrollView(
          primary: false,
          padding: padding ?? const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: PetMagicStateIllustration(
                    icon: icon,
                    color: iconColor,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: colors.textStrong,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
                if (message.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.textSoft,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: onAction,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    icon: actionIcon == null
                        ? null
                        : Icon(actionIcon, size: 19),
                    label: PetMagicAnimatedButtonChild(label: actionLabel!),
                  ),
                ],
                if (footer != null) ...[const SizedBox(height: 14), footer!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
