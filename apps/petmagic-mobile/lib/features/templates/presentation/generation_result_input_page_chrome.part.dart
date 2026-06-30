part of 'generation_result_input_page.dart';

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.value,
    required this.onChanged,
    required this.copy,
  });

  final _ResultTemplateFilter value;
  final ValueChanged<_ResultTemplateFilter> onChanged;
  final _GenerationResultInputCopy copy;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<_ResultTemplateFilter>(
      segments: [
        ButtonSegment(value: _ResultTemplateFilter.all, label: Text(copy.all)),
        ButtonSegment(
          value: _ResultTemplateFilter.image,
          label: Text(copy.image),
        ),
        ButtonSegment(
          value: _ResultTemplateFilter.video,
          label: Text(copy.video),
        ),
      ],
      selected: {value},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceStrong,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colors.textSoft,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ConfirmStartSheet extends StatelessWidget {
  const _ConfirmStartSheet({
    required this.title,
    required this.cost,
    required this.copy,
  });

  final String title;
  final int cost;
  final _GenerationResultInputCopy copy;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        8,
        18,
        petMagicScrollableBottomInset(context),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colors.textStrong,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            copy.cost(cost),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.textSoft,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(copy.start),
          ),
        ],
      ),
    );
  }
}

class _ResultInputLoadingCard extends StatelessWidget {
  const _ResultInputLoadingCard();

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator.adaptive()),
      ),
    );
  }
}
