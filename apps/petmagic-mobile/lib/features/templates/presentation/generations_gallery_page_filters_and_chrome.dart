part of 'generations_gallery_page.dart';

class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.selected});

  final GenerationHistoryFilter selected;

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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: StadiumBorder(
                side: BorderSide(
                  color: selected == filter.$1
                      ? colors.accent.withValues(alpha: 0.5)
                      : colors.border.withValues(alpha: 0.7),
                ),
              ),
              selectedColor: colors.accent.withValues(alpha: 0.2),
              backgroundColor: colors.surfaceGlass,
              label: Text(
                filter.$2,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected == filter.$1
                      ? colors.accent
                      : colors.textSoft,
                  fontWeight: FontWeight.w700,
                ),
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

class _GalleryAtmosphere extends StatelessWidget {
  const _GalleryAtmosphere();

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -120,
            left: -80,
            child: _GlowBlob(
              size: 260,
              color: colors.accent.withValues(alpha: 0.16),
            ),
          ),
          Positioned(
            top: 170,
            right: -110,
            child: _GlowBlob(
              size: 300,
              color: colors.blue.withValues(alpha: 0.14),
            ),
          ),
          Positioned(
            bottom: 40,
            left: -60,
            child: _GlowBlob(
              size: 220,
              color: colors.purple.withValues(alpha: 0.11),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
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
        borderRadius: BorderRadius.circular(14),
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
    final isRu = Localizations.localeOf(context).languageCode.toLowerCase() ==
        'ru';
    final isLight = Theme.of(context).brightness == Brightness.light;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFF2C14E).withValues(alpha: 0.92),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: PremiumBannerStyle.gradient(isLight),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFC342).withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const PremiumCrownIcon(size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isRu ? 'Экспорт без водяного знака' : 'Watermark-free export',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: isLight
                          ? const Color(0xFF735018)
                          : const Color(0xFFFFD776),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              isRu
                  ? 'Premium уберет логотип PetMagic'
                  : 'Premium removes the PetMagic logo',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isLight
                    ? const Color(0xFF2D3B54)
                    : Colors.white.withValues(alpha: 0.82),
                height: 1.2,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            PremiumShimmerButton(
              label: text.profilePremiumOpenAction,
              onTap: onOpenPremium,
              height: 40,
              borderRadius: 11,
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
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final shimmerStart = -1.6 + (t * 2.8);
        return ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Stack(
            children: [
              FilledButton(
                onPressed: widget.onPressed,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: const Color(0xFFF5BD3E),
                  foregroundColor: const Color(0xFF241403),
                  textStyle: const TextStyle(
                    fontSize: 12.8,
                    fontWeight: FontWeight.w900,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
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
              ),
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
    );
  }
}
