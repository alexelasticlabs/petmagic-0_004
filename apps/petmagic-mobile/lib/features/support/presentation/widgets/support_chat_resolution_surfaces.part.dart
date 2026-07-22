part of 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';

class _SupportResolutionPrompt extends StatelessWidget {
  const _SupportResolutionPrompt({
    required this.title,
    required this.resolveLabel,
    required this.keepOpenLabel,
    required this.isBusy,
    required this.onResolve,
    required this.onKeepOpen,
  });

  final String title;
  final String resolveLabel;
  final String keepOpenLabel;
  final bool isBusy;
  final Future<void> Function() onResolve;
  final VoidCallback onKeepOpen;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border.withValues(alpha: 0.72)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: colors.textSoft,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _SupportPromptButton(
                  icon: Icons.check_rounded,
                  label: resolveLabel,
                  isBusy: isBusy,
                  onPressed: onResolve,
                ),
                _SupportPromptButton(
                  icon: Icons.edit_outlined,
                  label: keepOpenLabel,
                  isBusy: isBusy,
                  onPressed: () async {
                    onKeepOpen();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportPromptButton extends StatelessWidget {
  const _SupportPromptButton({
    required this.icon,
    required this.label,
    required this.isBusy,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool isBusy;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final actionTone = _supportSecondaryGreen(context);
    final textTheme = Theme.of(context).textTheme;

    return TextButton.icon(
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        foregroundColor: actionTone,
        textStyle: textTheme.labelLarge?.copyWith(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        backgroundColor: colors.surfaceStrong.withValues(alpha: 0.72),
      ),
      onPressed: isBusy ? null : onPressed,
      icon: Icon(icon, size: 14),
      label: Text(label, overflow: TextOverflow.ellipsis),
    );
  }
}

class _SupportClosedConversationBanner extends StatelessWidget {
  const _SupportClosedConversationBanner({
    required this.feedbackRating,
    required this.isBusy,
    required this.onReopen,
    required this.onSubmitFeedback,
  });

  final int? feedbackRating;
  final bool isBusy;
  final Future<void> Function() onReopen;
  final Future<void> Function(int rating, String? comment) onSubmitFeedback;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final actionTone = _supportComposerSendGreen(context);
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border.withValues(alpha: 0.72)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 15,
                  color: colors.textMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    text.supportChatConversationClosedLabel,
                    style: TextStyle(
                      color: colors.textSoft,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    foregroundColor: actionTone,
                    textStyle: textTheme.labelLarge?.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    backgroundColor: actionTone.withValues(alpha: 0.1),
                  ),
                  onPressed: isBusy ? null : onReopen,
                  child: Text(text.supportChatReopenAction),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              feedbackRating == null
                  ? text.supportChatRateTitle
                  : text.supportChatRatedLabel(feedbackRating!),
              style: TextStyle(
                color: colors.textSoft,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Wrap(
              spacing: 2,
              children: [
                for (var rating = 1; rating <= 5; rating++)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: text.supportChatRatedLabel(rating),
                    onPressed: feedbackRating == null && !isBusy
                        ? () async {
                            final comment =
                                await _showSupportFeedbackCommentDialog(
                                  context,
                                );
                            if (comment == null || !context.mounted) {
                              return;
                            }
                            await onSubmitFeedback(rating, comment);
                          }
                        : null,
                    icon: Icon(
                      rating <= (feedbackRating ?? 0)
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: rating <= (feedbackRating ?? 0)
                          ? actionTone
                          : colors.textMuted,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<String?> _showSupportFeedbackCommentDialog(BuildContext context) async {
  final controller = TextEditingController();
  final text = AppLocalizations.of(context);
  try {
    return await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(text.supportChatRateTitle),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 4,
          maxLength: 1000,
          decoration: InputDecoration(
            labelText: text.profileSettingsFeedbackMessageLabel,
            hintText: text.profileSettingsFeedbackMessageHint,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              MaterialLocalizations.of(dialogContext).cancelButtonLabel,
            ),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(text.profileSettingsFeedbackSubmitAction),
          ),
        ],
      ),
    );
  } finally {
    controller.dispose();
  }
}
