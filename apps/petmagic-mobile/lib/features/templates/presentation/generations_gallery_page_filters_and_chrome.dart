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

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
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

class _GalleryPremiumUpsellCard extends StatelessWidget {
  const _GalleryPremiumUpsellCard({required this.onOpenPremium});

  final VoidCallback onOpenPremium;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFF2C14E).withValues(alpha: 0.74),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: PremiumBannerStyle.gradient(isLight),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFC342).withValues(alpha: 0.16),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const PremiumCrownIcon(size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text.galleryPremiumUpsellTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: isLight
                          ? const Color(0xFF735018)
                          : const Color(0xFFFFD776),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    text.galleryPremiumUpsellSubtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isLight
                          ? const Color(0xFF2D3B54)
                          : Colors.white.withValues(alpha: 0.82),
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 110),
              child: PremiumShimmerButton(
                label: text.profilePremiumOpenAction,
                onTap: onOpenPremium,
                height: 34,
                borderRadius: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GalleryGoldShimmerButton extends StatefulWidget {
  const _GalleryGoldShimmerButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  State<_GalleryGoldShimmerButton> createState() =>
      _GalleryGoldShimmerButtonState();
}

class _GalleryGoldShimmerButtonState extends State<_GalleryGoldShimmerButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimationState();
  }

  @override
  void deactivate() {
    _controller.stop();
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _syncAnimationState();
  }

  @override
  void dispose() {
    _controller.stop();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!PerformanceGuard.shouldAnimateRepeatingEffects(context)) {
      return _buildButton();
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final shimmerStart = -1.6 + (t * 2.8);
        return ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Stack(
            children: [
              child!,
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(shimmerStart, -1),
                        end: Alignment(shimmerStart + 0.9, 1),
                        colors: [
                          Colors.transparent,
                          const Color(0xFFFFF3C9).withValues(alpha: 0.0),
                          const Color(0xFFFFF3C9).withValues(alpha: 0.4),
                          const Color(0xFFFFF3C9).withValues(alpha: 0.0),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.30, 0.5, 0.70, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      child: _buildButton(),
    );
  }

  Widget _buildButton() {
    return FilledButton(
      onPressed: widget.onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: const Color(0xFFF5BD3E),
        foregroundColor: const Color(0xFF241403),
        textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.label),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_forward_rounded, size: 16),
          ],
        ),
      ),
    );
  }

  void _syncAnimationState() {
    if (!PerformanceGuard.shouldAnimateRepeatingEffects(context)) {
      if (_controller.isAnimating) {
        _controller.stop();
      }
      return;
    }

    if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }
}
