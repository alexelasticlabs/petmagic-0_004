part of 'generation_status_page.dart';

class _ReadyActionsRow extends StatelessWidget {
  const _ReadyActionsRow({
    required this.onGenerateSimilar,
    required this.onUseAsInput,
    required this.onSave,
    required this.onShare,
    required this.hasWatermark,
    required this.isWatermarkRemoved,
    required this.canRemoveWatermark,
    required this.removeWatermarkCostCredits,
    required this.isRemovingWatermark,
    required this.isGeneratingSimilar,
    required this.onUpgrade,
    this.watermarkMessage,
    this.onRemoveWatermark,
  });

  final VoidCallback? onGenerateSimilar;
  final VoidCallback? onUseAsInput;
  final VoidCallback? onSave;
  final VoidCallback? onShare;
  final bool hasWatermark;
  final bool isWatermarkRemoved;
  final bool canRemoveWatermark;
  final int removeWatermarkCostCredits;
  final bool isRemovingWatermark;
  final bool isGeneratingSimilar;
  final String? watermarkMessage;
  final VoidCallback? onRemoveWatermark;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final message = watermarkMessage?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (message != null && message.isNotEmpty) ...[
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceStrong.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.border.withValues(alpha: 0.75)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    isWatermarkRemoved
                        ? Icons.verified_rounded
                        : Icons.auto_awesome_motion_rounded,
                    size: 18,
                    color: colors.accent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isWatermarkRemoved
                          ? text.generationStatusWatermarkRemoved
                          : hasWatermark
                          ? text.generationStatusWatermarkAddedFreePlan
                          : message,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textSoft,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: isGeneratingSimilar ? null : onGenerateSimilar,
                icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                label: Text(
                  isGeneratingSimilar
                      ? _similarLoadingLabel(text)
                      : _similarActionLabel(text),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onUseAsInput,
                icon: const Icon(Icons.add_photo_alternate_rounded, size: 18),
                label: Text(_useAsInputLabel(text)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: onShare,
                icon: const Icon(Icons.share_rounded, size: 18),
                label: Text(
                  hasWatermark
                      ? text.generationStatusShareWithWatermark
                      : text.supportChatShareAction,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onSave,
                icon: const Icon(Icons.download_rounded, size: 18),
                label: Text(
                  isWatermarkRemoved
                      ? text.generationStatusDownloadWithoutWatermark
                      : hasWatermark
                      ? text.generationStatusSaveWithWatermark
                      : text.generationStatusDownloadAction,
                ),
              ),
            ),
          ],
        ),
        if (canRemoveWatermark) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isRemovingWatermark ? null : onRemoveWatermark,
                  icon: const Icon(Icons.cleaning_services_rounded, size: 18),
                  label: Text(
                    isRemovingWatermark
                        ? text.generationStatusRemovingWatermark
                        : text.generationStatusRemoveWatermark,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onUpgrade,
                  icon: const Icon(Icons.workspace_premium_rounded, size: 18),
                  label: Text(text.generationStatusUpgradePremium),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ResultInputActions extends StatelessWidget {
  const _ResultInputActions({
    required this.onCreateVideo,
    required this.onUseAsInput,
    required this.hasWatermark,
    required this.isWatermarkRemoved,
    this.watermarkMessage,
  });

  final VoidCallback? onCreateVideo;
  final VoidCallback? onUseAsInput;
  final bool hasWatermark;
  final bool isWatermarkRemoved;
  final String? watermarkMessage;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final message = watermarkMessage?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (message != null && message.isNotEmpty) ...[
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceStrong.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.border.withValues(alpha: 0.75)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    isWatermarkRemoved
                        ? Icons.verified_rounded
                        : Icons.auto_awesome_motion_rounded,
                    size: 18,
                    color: colors.accent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isWatermarkRemoved
                          ? text.generationStatusWatermarkRemoved
                          : hasWatermark
                          ? text.generationStatusWatermarkAddedFreePlan
                          : message,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textSoft,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        FilledButton.icon(
          onPressed: onCreateVideo,
          icon: const Icon(Icons.movie_creation_rounded, size: 18),
          label: Text(text.generationStatusCreateVideoFromResultAction),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onUseAsInput,
          icon: const Icon(Icons.add_photo_alternate_rounded, size: 18),
          label: Text(_useAsInputLabel(text)),
        ),
      ],
    );
  }
}

String _similarActionLabel(AppLocalizations text) =>
    text.generationStatusGenerateSimilarAction;

String _similarLoadingLabel(AppLocalizations text) =>
    text.generationStatusGenerateSimilarLoading;

String _useAsInputLabel(AppLocalizations text) =>
    text.generationStatusUseAsInputAction;

class _FailedActions extends StatelessWidget {
  const _FailedActions({
    required this.isPhotoFailure,
    required this.onPickAnotherPhoto,
    required this.onRetry,
    required this.onSupport,
  });

  final VoidCallback onPickAnotherPhoto;
  final VoidCallback onRetry;
  final VoidCallback onSupport;
  final bool isPhotoFailure;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 58,
          child: FilledButton.icon(
            onPressed: isPhotoFailure ? onPickAnotherPhoto : onRetry,
            icon: Icon(
              isPhotoFailure
                  ? Icons.photo_library_outlined
                  : Icons.refresh_rounded,
            ),
            label: Text(
              isPhotoFailure
                  ? text.generationStatusPickAnotherPhotoAction
                  : text.generationStatusRetryAction,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 58,
          child: OutlinedButton.icon(
            onPressed: isPhotoFailure ? onRetry : onPickAnotherPhoto,
            icon: Icon(
              isPhotoFailure
                  ? Icons.refresh_rounded
                  : Icons.photo_library_outlined,
            ),
            label: Text(
              isPhotoFailure
                  ? text.generationStatusRetryAction
                  : text.generationStatusPickAnotherPhotoAction,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Divider(color: context.petMagicColors.border.withValues(alpha: 0.7)),
        const SizedBox(height: 14),
        Center(
          child: Column(
            children: [
              Text(
                text.generationStatusSupportPrompt,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.petMagicColors.textMuted,
                ),
              ),
              TextButton.icon(
                onPressed: onSupport,
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: Text(text.generationStatusContactSupportAction),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActiveActions extends StatelessWidget {
  const _ActiveActions({required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          onPressed: onContinue,
          child: Text(text.generationStatusContinueInAppAction),
        ),
      ],
    );
  }
}
