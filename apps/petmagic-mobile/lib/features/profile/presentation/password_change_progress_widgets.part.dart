part of 'password_change_page.dart';

class _PasswordChangeStepIndicator extends StatelessWidget {
  const _PasswordChangeStepIndicator({required this.currentStep});

  final int currentStep;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final text = AppLocalizations.of(context);

    final steps = [
      (
        label: text.passwordChangeStepRequestCode,
        icon: Icons.mark_email_unread_outlined,
      ),
      (
        label: text.passwordChangeStepNewPassword,
        icon: Icons.lock_reset_rounded,
      ),
    ];

    return Row(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          Expanded(
            child: _StepPill(
              index: i,
              label: steps[i].label,
              icon: steps[i].icon,
              state: i < currentStep
                  ? _StepState.done
                  : i == currentStep
                  ? _StepState.active
                  : _StepState.upcoming,
            ),
          ),
          if (i < steps.length - 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 24,
                height: 2,
                decoration: BoxDecoration(
                  color: currentStep > 0
                      ? colors.accent
                      : colors.border.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

enum _StepState { done, active, upcoming }

class _StepPill extends StatelessWidget {
  const _StepPill({
    required this.index,
    required this.label,
    required this.icon,
    required this.state,
  });

  final int index;
  final String label;
  final IconData icon;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final isDone = state == _StepState.done;
    final isActive = state == _StepState.active;

    final iconColor = isDone || isActive ? colors.accent : colors.textMuted;
    final bgColor = isDone || isActive
        ? colors.accent.withValues(alpha: 0.13)
        : colors.border.withValues(alpha: 0.2);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive
              ? colors.accent.withValues(alpha: 0.4)
              : Colors.transparent,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(isDone ? Icons.check_rounded : icon, size: 15, color: iconColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isDone || isActive
                    ? colors.textStrong
                    : colors.textMuted,
                fontSize: 12.5,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
