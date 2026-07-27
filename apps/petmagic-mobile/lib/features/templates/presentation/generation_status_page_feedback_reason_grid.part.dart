part of 'generation_status_page.dart';

class _FeedbackReasonGrid extends StatelessWidget {
  const _FeedbackReasonGrid({
    required this.reasons,
    required this.selectedReasons,
    required this.onChanged,
  });

  final List<(String, String)> reasons;
  final Set<String> selectedReasons;
  final void Function(String reason, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnCount = constraints.maxWidth >= 360 ? 2 : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columnCount,
            mainAxisExtent: 64,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
          ),
          itemCount: reasons.length,
          itemBuilder: (context, index) {
            final reason = reasons[index];
            return _FeedbackReasonOptionButton(
              reason: reason,
              selected: selectedReasons.contains(reason.$1),
              onPressed: () {
                onChanged(reason.$1, !selectedReasons.contains(reason.$1));
              },
            );
          },
        );
      },
    );
  }
}

class _FeedbackReasonOptionButton extends StatelessWidget {
  const _FeedbackReasonOptionButton({
    required this.reason,
    required this.selected,
    required this.onPressed,
  });

  final (String, String) reason;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final icon = switch (reason.$1) {
      'payment' || 'credits_charged' => Icons.receipt_long_outlined,
      'too_long' || 'stuck' => Icons.schedule_outlined,
      'wrong_pet' || 'pet_not_similar' => Icons.pets_outlined,
      'distortion' || 'face_distorted' => Icons.face_retouching_off_outlined,
      'inappropriate' => Icons.report_outlined,
      'watermark' => Icons.branding_watermark_outlined,
      'wrong_template' || 'preview_mismatch' => Icons.compare_outlined,
      'low_quality' => Icons.high_quality_outlined,
      'style_disliked' => Icons.palette_outlined,
      _ => Icons.chat_bubble_outline_rounded,
    };

    return Semantics(
      button: true,
      selected: selected,
      label: reason.$2,
      child: Material(
        color: selected ? colors.accentSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? colors.accent : colors.border,
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(
                    selected ? Icons.check_circle_rounded : icon,
                    color: selected ? colors.accent : colors.textMuted,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      reason.$2,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: colors.textStrong,
                        fontWeight: FontWeight.w700,
                      ),
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
