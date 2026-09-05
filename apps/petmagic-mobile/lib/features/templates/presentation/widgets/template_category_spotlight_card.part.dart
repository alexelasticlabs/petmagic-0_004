part of 'template_category_carousel.dart';

class _CategorySpotlightCard extends StatelessWidget {
  const _CategorySpotlightCard({
    required this.section,
    required this.logicalIndex,
    required this.total,
    required this.eyebrowLabel,
    required this.openLabel,
    required this.isSelected,
    required this.showFocus,
    required this.pageController,
    required this.rawIndex,
    required this.reduceMotion,
    required this.onSemanticPressed,
    required this.onPressed,
  });

  final TemplateDiscoverySection section;
  final int logicalIndex;
  final int total;
  final String eyebrowLabel;
  final String openLabel;
  final bool isSelected;
  final bool showFocus;
  final PageController pageController;
  final int rawIndex;
  final bool reduceMotion;
  final VoidCallback onSemanticPressed;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final collection = DiscoveryCollectionStyle.of(context, section.category);
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = (260 * pixelRatio).clamp(480, 900).round();

    return Semantics(
      container: true,
      button: true,
      selected: isSelected,
      label: '${section.category}, ${logicalIndex + 1} / $total',
      onTap: onSemanticPressed,
      child: ExcludeSemantics(
        child: PetMagicInteractiveSurface(
          key: ValueKey('discovery-category-${section.category}'),
          onTap: onPressed,
          haptic: PressableScaleHaptic.selection,
          borderRadius: BorderRadius.circular(PetMagicRadii.lg),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(PetMagicRadii.lg),
            child: Container(
              foregroundDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(PetMagicRadii.lg),
                border: Border.all(
                  color: showFocus
                      ? colors.accent
                      : collection.accent.withValues(
                          alpha: isSelected ? 0.72 : 0.3,
                        ),
                  width: showFocus ? 2 : 0.8,
                ),
              ),
              decoration: BoxDecoration(
                color: colors.surfaceStrong,
                border: Border.all(
                  color: collection.accent.withValues(alpha: 0.28),
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) => AnimatedBuilder(
                      animation: pageController,
                      child: RepaintBoundary(
                        child: TemplateDiscoveryMedia(
                          category: section.category,
                          paletteIndex: logicalIndex,
                          template: section.representative,
                          cacheWidth: cacheWidth,
                        ),
                      ),
                      builder: (context, child) {
                        final page =
                            pageController.hasClients &&
                                pageController.position.haveDimensions
                            ? pageController.page ?? rawIndex.toDouble()
                            : rawIndex.toDouble();
                        final displacement = (rawIndex - page).clamp(-1.0, 1.0);
                        // A small overscan keeps the image edge outside the
                        // portrait mask. Only transforms change while dragging;
                        // the media subtree and preview controller stay intact.
                        return Transform.translate(
                          key: ValueKey('discovery-parallax-$rawIndex'),
                          offset: Offset(
                            reduceMotion
                                ? 0
                                : displacement * constraints.maxWidth * 0.035,
                            0,
                          ),
                          child: Transform.scale(
                            scale: reduceMotion ? 1 : 1.08,
                            child: child,
                          ),
                        );
                      },
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.08),
                          Colors.black.withValues(alpha: 0.16),
                          Colors.black.withValues(alpha: 0.84),
                        ],
                        stops: const [0, 0.48, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    left: PetMagicSpacing.md,
                    top: PetMagicSpacing.md,
                    right: PetMagicSpacing.md,
                    child: Align(
                      alignment: AlignmentDirectional.topStart,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.64),
                          borderRadius: BorderRadius.circular(
                            PetMagicRadii.pill,
                          ),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.auto_awesome_rounded,
                                size: 12,
                                color: Color.lerp(
                                  collection.accent,
                                  Colors.white,
                                  0.35,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  eyebrowLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.6,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: PetMagicSpacing.md,
                    right: PetMagicSpacing.md,
                    bottom: PetMagicSpacing.md,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          section.category,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontSize: 20,
                                height: 1.02,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.55,
                              ),
                        ),
                        const SizedBox(height: 9),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.accent,
                            borderRadius: BorderRadius.circular(
                              PetMagicRadii.pill,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 7,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    openLabel,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          color: colors.on(colors.accent),
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 14,
                                  color: colors.on(colors.accent),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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
