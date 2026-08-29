part of 'generation_status_page.dart';

String _similarActionLabel(AppLocalizations text) =>
    text.generationStatusGenerateSimilarAction;

String _similarLoadingLabel(AppLocalizations text) =>
    text.generationStatusGenerateSimilarLoading;

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
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(17),
            ),
          ),
          child: Text(text.generationStatusContinueInAppAction),
        ),
      ],
    );
  }
}

class _ActiveSecondaryActions extends StatelessWidget {
  const _ActiveSecondaryActions({
    required this.onDetails,
    required this.onSupport,
  });

  final VoidCallback onDetails;
  final VoidCallback onSupport;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        TextButton(
          onPressed: onDetails,
          style: TextButton.styleFrom(foregroundColor: colors.textMuted),
          child: Text(text.generationStatusTechnicalDetailsAction),
        ),
        Container(
          height: 22,
          width: 1,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          color: colors.border.withValues(alpha: 0.72),
        ),
        TextButton.icon(
          onPressed: onSupport,
          style: TextButton.styleFrom(foregroundColor: colors.textMuted),
          icon: const Icon(Icons.headset_mic_outlined, size: 17),
          label: Text(text.generationStatusSupportShortAction),
        ),
      ],
    );
  }
}
