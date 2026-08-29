part of 'generation_status_page.dart';

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({
    required this.title,
    required this.excellentLabel,
    required this.okayLabel,
    required this.badLabel,
    required this.isSubmitting,
    required this.onRatingSelected,
  });

  final String title;
  final String excellentLabel;
  final String okayLabel;
  final String badLabel;
  final bool isSubmitting;
  final ValueChanged<int> onRatingSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: colors.textStrong,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _RatingButton(
                label: excellentLabel,
                icon: Icons.favorite_rounded,
                onTap: isSubmitting ? null : () => onRatingSelected(3),
              ),
              const SizedBox(width: 8),
              _RatingButton(
                label: okayLabel,
                icon: Icons.thumb_up_alt_rounded,
                onTap: isSubmitting ? null : () => onRatingSelected(2),
              ),
              const SizedBox(width: 8),
              _RatingButton(
                label: badLabel,
                icon: Icons.sentiment_dissatisfied_rounded,
                onTap: isSubmitting ? null : () => onRatingSelected(1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeedbackSubmittedCard extends StatelessWidget {
  const _FeedbackSubmittedCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return _Panel(
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: colors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.textStrong,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingButton extends StatelessWidget {
  const _RatingButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceGlass,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            child: Column(
              children: [
                Icon(icon, color: colors.accent, size: 20),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.textStrong,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FailedFeedbackCard extends StatelessWidget {
  const _FailedFeedbackCard({
    required this.isSubmitting,
    required this.onSubmit,
  });

  final bool isSubmitting;
  final ValueChanged<String> onSubmit;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final text = _feedbackText(context);
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                text.failedTitle,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: colors.textStrong,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                text.optionalLabel,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final reason in text.failedReasons)
                ActionChip(
                  label: Text(reason.$2),
                  onPressed: isSubmitting ? null : () => onSubmit(reason.$1),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProblemFeedbackSheet extends StatefulWidget {
  const _ProblemFeedbackSheet({required this.title, required this.reasons});

  final String title;
  final List<(String, String)> reasons;

  @override
  State<_ProblemFeedbackSheet> createState() => _ProblemFeedbackSheetState();
}

class _ProblemFeedbackSheetState extends State<_ProblemFeedbackSheet> {
  final _commentController = TextEditingController();
  String? _selectedReason;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final text = _feedbackText(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.backgroundBottom,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: colors.border.withValues(alpha: 0.7)),
        ),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.82,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colors.textStrong,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _FeedbackReasonGrid(
                    reasons: widget.reasons,
                    selectedReasons: _selectedReason == null
                        ? const <String>{}
                        : {_selectedReason!},
                    onChanged: (reason, selected) => setState(
                      () => _selectedReason = selected ? reason : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _commentController,
                    minLines: 2,
                    maxLines: 4,
                    maxLength: 2000,
                    decoration: InputDecoration(
                      labelText: text.commentLabel,
                      hintText: text.commentHint,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: _selectedReason == null
                          ? null
                          : () => Navigator.of(context).pop(
                              _FeedbackResult(
                                [_selectedReason!],
                                _commentController.text.trim().isEmpty
                                    ? null
                                    : _commentController.text.trim(),
                              ),
                            ),
                      icon: const Icon(Icons.send_rounded),
                      label: Text(text.submit),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeedbackText {
  const _FeedbackText({
    required this.failedTitle,
    required this.failedReasons,
    required this.optionalLabel,
    required this.reportTitle,
    required this.reportReasons,
    required this.commentLabel,
    required this.commentHint,
    required this.submit,
  });

  final String failedTitle;
  final List<(String, String)> failedReasons;
  final String optionalLabel;
  final String reportTitle;
  final List<(String, String)> reportReasons;
  final String commentLabel;
  final String commentHint;
  final String submit;
}

_FeedbackText _feedbackText(BuildContext context) {
  final text = AppLocalizations.of(context);
  return _FeedbackText(
    failedTitle: text.generationStatusFailedFeedbackTitle,
    failedReasons: [
      ('stuck', text.generationStatusFailedFeedbackStuck),
      ('too_long', text.generationStatusFailedFeedbackTooLong),
      ('not_completed', text.generationStatusFailedFeedbackNotCompleted),
      ('other', text.generationStatusFailedFeedbackOther),
    ],
    optionalLabel: text.generationStatusOptionalLabel,
    reportTitle: text.generationStatusReportFeedbackTitle,
    reportReasons: [
      ('low_quality', text.generationStatusReportFeedbackLowQuality),
      ('wrong_pet', text.generationStatusReportFeedbackWrongPet),
      ('distortion', text.generationStatusReportFeedbackDistortion),
      ('inappropriate', text.generationStatusReportFeedbackInappropriate),
      ('wrong_template', text.generationStatusReportFeedbackWrongTemplate),
      ('watermark', text.generationStatusReportFeedbackWatermark),
      ('payment', text.generationStatusReportFeedbackPayment),
      ('other', text.generationStatusReportFeedbackOther),
    ],
    commentLabel: text.generationStatusFeedbackCommentLabel,
    commentHint: text.generationStatusFeedbackCommentHint,
    submit: text.generationStatusFeedbackSubmitAction,
  );
}

class _NegativeFeedbackSheet extends StatefulWidget {
  const _NegativeFeedbackSheet();

  @override
  State<_NegativeFeedbackSheet> createState() => _NegativeFeedbackSheetState();
}

class _NegativeFeedbackSheetState extends State<_NegativeFeedbackSheet> {
  final _commentController = TextEditingController();
  final _selectedReasons = <String>{};

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final reasons = <(String, String)>[
      ('pet_not_similar', text.generationStatusFeedbackReasonPetNotSimilar),
      ('face_distorted', text.generationStatusFeedbackReasonFaceDistorted),
      ('strange_motion', text.generationStatusFeedbackReasonStrangeMotion),
      ('preview_mismatch', text.generationStatusFeedbackReasonPreviewMismatch),
      ('low_quality', text.generationStatusFeedbackReasonLowQuality),
      ('style_disliked', text.generationStatusFeedbackReasonStyleDisliked),
      ('other', text.generationStatusFeedbackReasonOther),
    ];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.backgroundBottom,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: colors.border.withValues(alpha: 0.7)),
        ),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.82,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    text.generationStatusFeedbackImproveTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colors.textStrong,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _FeedbackReasonGrid(
                    reasons: reasons,
                    selectedReasons: _selectedReasons,
                    onChanged: (reason, selected) {
                      setState(() {
                        if (selected) {
                          _selectedReasons.add(reason);
                        } else {
                          _selectedReasons.remove(reason);
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _commentController,
                    minLines: 2,
                    maxLines: 4,
                    maxLength: 2000,
                    decoration: InputDecoration(
                      labelText: text.generationStatusFeedbackCommentLabel,
                      hintText: text.generationStatusFeedbackCommentHint,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop(
                        _FeedbackResult(
                          _selectedReasons.toList(growable: false),
                          _commentController.text.trim().isEmpty
                              ? null
                              : _commentController.text.trim(),
                        ),
                      ),
                      icon: const Icon(Icons.send_rounded),
                      label: Text(text.generationStatusFeedbackSubmitAction),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
