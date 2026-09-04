import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/templates/domain/template_discovery_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_discovery_media.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_interactive_surface.dart';
import 'package:petmagic_mobile/shared/widgets/pressable_scale.dart';

part 'template_category_carousel_progress.part.dart';

class TemplateCategoryCarousel extends StatefulWidget {
  const TemplateCategoryCarousel({
    required this.sections,
    required this.eyebrowLabel,
    required this.openLabel,
    required this.onCategoryPressed,
    this.autoplayEnabled = true,
    this.autoAdvanceInterval = const Duration(seconds: 7),
    super.key,
  });

  final List<TemplateDiscoverySection> sections;
  final String eyebrowLabel;
  final String openLabel;
  final ValueChanged<String> onCategoryPressed;
  final bool autoplayEnabled;
  final Duration autoAdvanceInterval;

  @override
  State<TemplateCategoryCarousel> createState() =>
      _TemplateCategoryCarouselState();
}

class _TemplateCategoryCarouselState extends State<TemplateCategoryCarousel>
    with WidgetsBindingObserver {
  static const _viewportFraction = 0.68;
  static const _interactionResumeDelay = Duration(seconds: 4);

  late PageController _pageController;
  Timer? _autoAdvanceTimer;
  Timer? _interactionResumeTimer;
  int _rawPage = 1;
  int _logicalPage = 0;
  bool _isUserInteracting = false;
  bool _isAppResumed = true;
  bool _tickerEnabled = true;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _rawPage = widget.sections.length > 1 ? 1 : 0;
    _pageController = _createController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    final mediaQuery = MediaQuery.of(context);
    _reduceMotion =
        mediaQuery.disableAnimations || mediaQuery.accessibleNavigation;
    _scheduleAutoAdvance();
  }

  @override
  void didUpdateWidget(covariant TemplateCategoryCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final categoriesChanged = !_sameCategories(
      oldWidget.sections,
      widget.sections,
    );
    if (categoriesChanged) {
      _pageController.dispose();
      _logicalPage = 0;
      _rawPage = widget.sections.length > 1 ? 1 : 0;
      _pageController = _createController();
    }
    _scheduleAutoAdvance();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppResumed = state == AppLifecycleState.resumed;
    _scheduleAutoAdvance();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoAdvanceTimer?.cancel();
    _interactionResumeTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  PageController _createController() => PageController(
    initialPage: widget.sections.length > 1 ? 1 : 0,
    viewportFraction: _viewportFraction,
  );

  bool get _canAutoAdvance =>
      widget.autoplayEnabled &&
      widget.sections.length > 1 &&
      _isAppResumed &&
      _tickerEnabled &&
      !_reduceMotion &&
      !_isUserInteracting;

  void _scheduleAutoAdvance() {
    _autoAdvanceTimer?.cancel();
    if (!_canAutoAdvance) {
      return;
    }
    _autoAdvanceTimer = Timer(widget.autoAdvanceInterval, _advance);
  }

  Future<void> _advance() async {
    if (!_canAutoAdvance || !_pageController.hasClients) {
      _scheduleAutoAdvance();
      return;
    }
    await _pageController.nextPage(
      duration: PetMagicMotion.slow,
      curve: PetMagicMotion.emphasized,
    );
    if (mounted) {
      _scheduleAutoAdvance();
    }
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _interactionResumeTimer?.cancel();
      _isUserInteracting = true;
      _scheduleAutoAdvance();
    } else if (notification is ScrollEndNotification && _isUserInteracting) {
      _interactionResumeTimer?.cancel();
      _interactionResumeTimer = Timer(_interactionResumeDelay, () {
        if (!mounted) {
          return;
        }
        _isUserInteracting = false;
        _scheduleAutoAdvance();
      });
    }
    return false;
  }

  void _handlePageChanged(int rawPage) {
    final count = widget.sections.length;
    if (count <= 1) {
      return;
    }
    final logicalPage = _logicalIndex(rawPage, count);
    if (mounted) {
      setState(() {
        _rawPage = rawPage;
        _logicalPage = logicalPage;
      });
    }

    if (rawPage == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pageController.hasClients) {
          _pageController.jumpToPage(count);
        }
      });
    } else if (rawPage == count + 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pageController.hasClients) {
          _pageController.jumpToPage(1);
        }
      });
    }
  }

  void _handleCardPressed(int rawIndex, String category) {
    if (widget.sections.length <= 1 || rawIndex == _rawPage) {
      widget.onCategoryPressed(category);
      return;
    }
    _pauseAfterInteraction();
    _pageController.animateToPage(
      rawIndex,
      duration: PetMagicMotion.medium,
      curve: PetMagicMotion.emphasized,
    );
  }

  void _pauseAfterInteraction() {
    _interactionResumeTimer?.cancel();
    _isUserInteracting = true;
    _scheduleAutoAdvance();
    _interactionResumeTimer = Timer(_interactionResumeDelay, () {
      if (!mounted) {
        return;
      }
      _isUserInteracting = false;
      _scheduleAutoAdvance();
    });
  }

  @override
  Widget build(BuildContext context) {
    final sections = widget.sections;
    if (sections.isEmpty) {
      return const SizedBox.shrink();
    }

    final loopedSections = sections.length == 1
        ? sections
        : <TemplateDiscoverySection>[
            sections.last,
            ...sections,
            sections.first,
          ];
    final compact = MediaQuery.sizeOf(context).width <= 360;
    final baseHeight = compact ? 232.0 : 254.0;
    final scaledTitleGrowth = math.max(
      0,
      MediaQuery.textScalerOf(context).scale(22) - 22,
    );
    final height = baseHeight + scaledTitleGrowth * 1.5;

    return Column(
      children: [
        SizedBox(
          height: height,
          child: NotificationListener<ScrollNotification>(
            onNotification: _handleScrollNotification,
            child: PageView.builder(
              key: const ValueKey('template-category-carousel'),
              controller: _pageController,
              physics: const BouncingScrollPhysics(),
              itemCount: loopedSections.length,
              onPageChanged: _handlePageChanged,
              itemBuilder: (context, rawIndex) {
                final section = loopedSections[rawIndex];
                final logicalIndex = _logicalIndex(rawIndex, sections.length);
                return AnimatedBuilder(
                  animation: _pageController,
                  builder: (context, child) {
                    final page =
                        _pageController.hasClients &&
                            _pageController.position.haveDimensions
                        ? _pageController.page ?? _rawPage.toDouble()
                        : _rawPage.toDouble();
                    final distance = (page - rawIndex).abs().clamp(0.0, 1.0);
                    final scale = 1 - distance * 0.12;
                    final opacity = 1 - distance * 0.42;
                    return Transform.scale(
                      scale: scale,
                      child: Opacity(opacity: opacity, child: child),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 7,
                    ),
                    child: _CategorySpotlightCard(
                      section: section,
                      logicalIndex: logicalIndex,
                      total: sections.length,
                      eyebrowLabel: widget.eyebrowLabel,
                      openLabel: widget.openLabel,
                      onSemanticPressed: () =>
                          widget.onCategoryPressed(section.category),
                      onPressed: () =>
                          _handleCardPressed(rawIndex, section.category),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: PetMagicSpacing.xs),
        _CarouselProgress(
          currentIndex: _logicalPage,
          itemCount: sections.length,
        ),
      ],
    );
  }
}

class _CategorySpotlightCard extends StatelessWidget {
  const _CategorySpotlightCard({
    required this.section,
    required this.logicalIndex,
    required this.total,
    required this.eyebrowLabel,
    required this.openLabel,
    required this.onSemanticPressed,
    required this.onPressed,
  });

  final TemplateDiscoverySection section;
  final int logicalIndex;
  final int total;
  final String eyebrowLabel;
  final String openLabel;
  final VoidCallback onSemanticPressed;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = (260 * pixelRatio).clamp(480, 900).round();

    return Semantics(
      container: true,
      button: true,
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
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surfaceStrong,
                border: Border.all(
                  color: colors.accent.withValues(alpha: 0.28),
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  TemplateDiscoveryMedia(
                    category: section.category,
                    paletteIndex: logicalIndex,
                    template: section.representative,
                    cacheWidth: cacheWidth,
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
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.48),
                        borderRadius: BorderRadius.circular(PetMagicRadii.pill),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        child: Text(
                          eyebrowLabel,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.92),
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
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
                                fontSize: 22,
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
