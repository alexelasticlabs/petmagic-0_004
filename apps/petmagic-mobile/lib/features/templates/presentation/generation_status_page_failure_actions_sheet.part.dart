part of 'generation_status_page.dart';

class _GenerationFailureActionsSheet extends StatelessWidget {
  const _GenerationFailureActionsSheet({
    required this.bottomInset,
    required this.onRetry,
    required this.onPickPhoto,
    required this.onSupport,
  });

  final double bottomInset;
  final VoidCallback onRetry;
  final VoidCallback onPickPhoto;
  final VoidCallback onSupport;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final text = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      bottom: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          child: DecoratedBox(
            decoration: BoxDecoration(color: colors.surface),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.border.withValues(alpha: .56),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 44),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                text.generationStatusActionsTitle,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(
                                      color: colors.textStrong,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                text.generationStatusActionsSubtitle,
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(color: colors.textMuted),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: -8,
                          child: IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                            color: colors.textSoft,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    _FailureActionRow(
                      icon: Icons.refresh_rounded,
                      title: text.generationStatusRetryAction,
                      subtitle: text.generationStatusRetryActionSubtitle,
                      onTap: onRetry,
                      primary: true,
                    ),
                    const SizedBox(height: 10),
                    _FailureActionRow(
                      icon: Icons.image_outlined,
                      title: text.generationStatusPickAnotherPhotoAction,
                      subtitle: text.generationStatusPickAnotherPhotoSubtitle,
                      onTap: onPickPhoto,
                    ),
                    const SizedBox(height: 10),
                    _FailureActionRow(
                      icon: Icons.headset_mic_outlined,
                      title: text.generationStatusContactSupportAction,
                      subtitle: text.generationStatusContactSupportSubtitle,
                      onTap: onSupport,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FailureActionRow extends StatelessWidget {
  const _FailureActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final tint = primary
        ? colors.accent.withValues(alpha: .13)
        : colors.surfaceStrong.withValues(alpha: .42);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: tint,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border.withValues(alpha: .10)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: primary
                      ? colors.accent.withValues(alpha: .18)
                      : colors.surfaceStrong,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  size: 21,
                  color: primary ? colors.accent : colors.textSoft,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colors.textStrong,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textMuted,
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: colors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
