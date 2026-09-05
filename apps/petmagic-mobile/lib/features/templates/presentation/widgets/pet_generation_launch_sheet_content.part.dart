part of 'pet_generation_launch_sheet.dart';

class _PetLaunchHeader extends StatelessWidget {
  const _PetLaunchHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return Column(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors.accent.withValues(alpha: 0.96),
                colors.accent.withValues(alpha: 0.52),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: colors.accent.withValues(alpha: 0.24),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            Icons.auto_awesome_rounded,
            color: colors.on(colors.accent),
            size: 25,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: colors.textStrong,
            fontWeight: FontWeight.w900,
            height: 1.08,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: colors.textSoft,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _PetLaunchTemplateCard extends StatelessWidget {
  const _PetLaunchTemplateCard({
    required this.template,
    required this.tokenCost,
  });

  final TemplateItem template;
  final int tokenCost;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceGlass.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border.withValues(alpha: 0.62)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: SizedBox(
                width: 82,
                height: 98,
                child: _PetLaunchTemplatePreview(template: template),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text.templateFlowTemplateLabel,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    template.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: colors.textStrong,
                      fontWeight: FontWeight.w800,
                      height: 1.18,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _PetLaunchChip(
                        icon: Icons.movie_creation_rounded,
                        label: template.isVideo
                            ? text.videoLabel
                            : text.imageLabel,
                      ),
                      _PetLaunchPawSparkChip(
                        label: '$tokenCost ${text.walletBalanceUnit}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PetLaunchPetCard extends StatelessWidget {
  const _PetLaunchPetCard({
    required this.petName,
    required this.balance,
    this.avatarUrl,
  });

  final String? petName;
  final String? avatarUrl;
  final int balance;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final name = petName?.trim();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.accent.withValues(alpha: 0.24)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            PetShortcutAvatar(avatarUrl: avatarUrl, size: 42),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name == null || name.isEmpty
                    ? text.petsGenerateWithPet
                    : text.petsGenerateWithName(name),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colors.textStrong,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            _PetLaunchPawSparkChip(label: '$balance'),
          ],
        ),
      ),
    );
  }
}

class _PetLaunchInlineError extends StatelessWidget {
  const _PetLaunchInlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.danger.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.danger.withValues(alpha: 0.24)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: colors.danger, size: 18),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.textStrong,
                  height: 1.28,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PetLaunchBottomBar extends StatelessWidget {
  const _PetLaunchBottomBar({
    required this.bottomInset,
    required this.showChangeAction,
    required this.isStarting,
    required this.startLabel,
    required this.changeLabel,
    required this.onStart,
    required this.onChangePet,
  });

  final double bottomInset;
  final bool showChangeAction;
  final bool isStarting;
  final String startLabel;
  final String changeLabel;
  final VoidCallback? onStart;
  final VoidCallback? onChangePet;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colors.backgroundBottom.withValues(alpha: 0.0),
            colors.backgroundBottom,
            colors.backgroundBottom,
          ],
          stops: const [0, 0.34, 1],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(18, 18, 18, bottomInset + 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PetLaunchStartButton(
              label: startLabel,
              isLoading: isStarting,
              onPressed: onStart,
            ),
            if (showChangeAction) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onChangePet,
                icon: const Icon(Icons.pets_rounded, size: 18),
                label: Text(changeLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PetLaunchStartButton extends StatelessWidget {
  const _PetLaunchStartButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return SizedBox(
      height: 54,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: isLoading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: colors.textStrong,
                ),
              )
            : const Icon(Icons.auto_awesome_rounded, size: 20),
        label: Text(label),
        style: FilledButton.styleFrom(
          textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class _PetLaunchChip extends StatelessWidget {
  const _PetLaunchChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceStrong.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border.withValues(alpha: 0.58)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: colors.accent, size: 14),
            const SizedBox(width: 5),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.textSoft,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PetLaunchPawSparkChip extends StatelessWidget {
  const _PetLaunchPawSparkChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.accent.withValues(alpha: 0.32)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PawSparkIcon(size: 14),
            const SizedBox(width: 5),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.textStrong,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
