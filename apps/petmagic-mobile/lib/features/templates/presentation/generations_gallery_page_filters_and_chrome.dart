part of 'generations_gallery_page.dart';

class _GalleryFilterCounts {
  const _GalleryFilterCounts({
    required this.all,
    required this.active,
    required this.ready,
    required this.failed,
  });

  factory _GalleryFilterCounts.fromState(_GalleryPageViewState state) {
    final allItems =
        state.cachedItemsByFilter[GenerationHistoryFilter.all] ??
        (state.filter == GenerationHistoryFilter.all ? state.items : null);
    final source = allItems ?? state.items;

    int countFor(GenerationHistoryFilter filter) {
      return switch (filter) {
        GenerationHistoryFilter.all => source.length,
        GenerationHistoryFilter.active =>
          source.where((item) => !item.isTerminal).length,
        GenerationHistoryFilter.ready =>
          source.where((item) => item.isCompleted).length,
        GenerationHistoryFilter.failed =>
          source.where((item) => item.isFailed).length,
      };
    }

    return _GalleryFilterCounts(
      all: countFor(GenerationHistoryFilter.all),
      active: countFor(GenerationHistoryFilter.active),
      ready: countFor(GenerationHistoryFilter.ready),
      failed: countFor(GenerationHistoryFilter.failed),
    );
  }

  final int all;
  final int active;
  final int ready;
  final int failed;

  int forFilter(GenerationHistoryFilter filter) {
    return switch (filter) {
      GenerationHistoryFilter.all => all,
      GenerationHistoryFilter.active => active,
      GenerationHistoryFilter.ready => ready,
      GenerationHistoryFilter.failed => failed,
    };
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.selected, required this.counts});

  final GenerationHistoryFilter selected;
  final _GalleryFilterCounts counts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final filters = <(GenerationHistoryFilter, String)>[
      (GenerationHistoryFilter.all, text.allFilter),
      (GenerationHistoryFilter.active, text.generationStatusFilterActive),
      (GenerationHistoryFilter.ready, text.generationStatusFilterReady),
      (GenerationHistoryFilter.failed, text.generationStatusFilterFailed),
    ];

    return HorizontalFilterStrip(
      child: Row(
        children: [
          for (final filter in filters) ...[
            ChoiceChip(
              selected: selected == filter.$1,
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              shape: StadiumBorder(
                side: BorderSide(
                  color: selected == filter.$1
                      ? colors.accent.withValues(alpha: 0.5)
                      : colors.border.withValues(alpha: 0.7),
                ),
              ),
              selectedColor: colors.accent.withValues(alpha: 0.2),
              backgroundColor: colors.surfaceGlass,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    filter.$2,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: selected == filter.$1
                          ? colors.accent
                          : colors.textSoft,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 6),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: selected == filter.$1
                          ? colors.accent.withValues(alpha: 0.16)
                          : colors.surfaceStrong.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      child: Text(
                        '${counts.forFilter(filter.$1)}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: selected == filter.$1
                              ? colors.accent
                              : colors.textMuted,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              onSelected: (_) => ref
                  .read(generationHistoryControllerProvider.notifier)
                  .load(filter: filter.$1),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: colors.textStrong,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.accent.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Text(
              '$count',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colors.accent,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ShowMoreButton extends StatelessWidget {
  const _ShowMoreButton({
    required this.expanded,
    required this.hiddenCount,
    required this.onPressed,
  });

  final bool expanded;
  final int hiddenCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onPressed,
      child: Ink(
        height: 38,
        decoration: BoxDecoration(
          color: colors.surfaceGlass,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border.withValues(alpha: 0.7)),
        ),
        child: Center(
          child: Text(
            expanded
                ? text.generationStatusCollapseAction
                : text.generationStatusShowMoreAction(hiddenCount),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: colors.textSoft,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _GalleryLoadMoreFooter extends ConsumerWidget {
  const _GalleryLoadMoreFooter({
    required this.isLoading,
    required this.hasError,
  });

  final bool isLoading;
  final bool hasError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    if (isLoading) {
      return SizedBox(
        height: 48,
        child: Center(
          child: SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator.adaptive(
              strokeWidth: 2.4,
              valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
            ),
          ),
        ),
      );
    }

    final button = OutlinedButton.icon(
      onPressed: () =>
          ref.read(generationHistoryControllerProvider.notifier).loadMore(),
      icon: Icon(hasError ? Icons.refresh_rounded : Icons.expand_more_rounded),
      label: Text(
        hasError ? text.retryAction : text.generationStatusLoadMoreAction,
      ),
    );
    if (!hasError) {
      return button;
    }

    return Column(
      children: [
        Text(
          text.generationStatusLoadMoreFailed,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: colors.textSoft,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        button,
      ],
    );
  }
}

class _ActiveInfoCard extends StatelessWidget {
  const _ActiveInfoCard();

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceGlass,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border.withValues(alpha: 0.7)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, size: 16, color: colors.gold),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text.generationStatusActiveInfoHint,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.textSoft,
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
