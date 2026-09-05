import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/templates/domain/template_discovery_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_discovery_media.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_interactive_surface.dart';
import 'package:petmagic_mobile/shared/widgets/pressable_scale.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'discovery_collection_style.dart';

part 'template_category_carousel_progress.part.dart';
part 'template_category_spotlight_card.part.dart';

class TemplateCategoryCarousel extends StatefulWidget {
  const TemplateCategoryCarousel({
    required this.sections,
    required this.eyebrowLabel,
    required this.openLabel,
    required this.onCategoryPressed,
    this.onActiveCategoryChanged,
    this.autoplayEnabled = true,
    this.autoAdvanceInterval = const Duration(seconds: 7),
    super.key,
  });

  final List<TemplateDiscoverySection> sections;
  final String eyebrowLabel;
  final String openLabel;
  final ValueChanged<String> onCategoryPressed;
  final ValueChanged<int>? onActiveCategoryChanged;
  final bool autoplayEnabled;
  final Duration autoAdvanceInterval;

  @override
  State<TemplateCategoryCarousel> createState() =>
      _TemplateCategoryCarouselState();
}

class _TemplateCategoryCarouselState extends State<TemplateCategoryCarousel>
    with WidgetsBindingObserver {
  static const _viewportFraction = 0.58;
  static const _interactionResumeDelay = Duration(seconds: 4);

  late PageController _pageController;
  Timer? _autoAdvanceTimer;
  Timer? _interactionResumeTimer;
  final _visibilityKey = UniqueKey();
  int _rawPage = 1;
  int _logicalPage = 0;
  int? _reportedLogicalPage;
  bool _isUserInteracting = false;
  bool _isAppResumed = true;
  bool _tickerEnabled = true;
  bool _reduceMotion = false;
  bool _isVisible = false;
  bool _hasKeyboardFocus = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _rawPage = widget.sections.length > 1 ? 1 : 0;
    _pageController = _createController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifyActiveCategory();
    });
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
      _reportedLogicalPage = null;
      _logicalPage = 0;
      _rawPage = widget.sections.length > 1 ? 1 : 0;
      _pageController = _createController();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _logicalPage == 0) {
          _notifyActiveCategory();
        }
      });
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
    VisibilityDetectorController.instance.forget(_visibilityKey);
    _pageController.dispose();
    super.dispose();
  }

  PageController _createController() => PageController(
    initialPage: widget.sections.length > 1 ? 1 : 0,
    viewportFraction: _viewportFraction,
  );

  void _notifyActiveCategory() {
    final onChanged = widget.onActiveCategoryChanged;
    if (!mounted || onChanged == null || _reportedLogicalPage == _logicalPage) {
      return;
    }
    _reportedLogicalPage = _logicalPage;
    onChanged(_logicalPage);
  }

  bool get _canAutoAdvance =>
      widget.autoplayEnabled &&
      widget.sections.length > 1 &&
      _isAppResumed &&
      _tickerEnabled &&
      _isVisible &&
      !_reduceMotion &&
      !_hasKeyboardFocus &&
      !_isUserInteracting;

  void _handleVisibilityChanged(VisibilityInfo info) {
    final visible = info.visibleFraction >= 0.5;
    if (!mounted || visible == _isVisible) return;
    _isVisible = visible;
    _scheduleAutoAdvance();
  }

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
    if (notification is ScrollEndNotification) {
      _normalizeLoopPosition();
    }
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
      final activeCategoryChanged = logicalPage != _logicalPage;
      setState(() {
        _rawPage = rawPage;
        _logicalPage = logicalPage;
      });
      if (activeCategoryChanged) {
        _notifyActiveCategory();
      }
    }
  }

  void _normalizeLoopPosition() {
    final count = widget.sections.length;
    if (count <= 1 || (_rawPage != 0 && _rawPage != count + 1)) return;
    // A page change fires halfway through a drag. Jump only once the mirrored
    // card is fully settled, otherwise the remaining gesture visibly jerks.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_pageController.hasClients ||
          _pageController.position.isScrollingNotifier.value) {
        return;
      }
      final target = _rawPage == 0 ? count : (_rawPage == count + 1 ? 1 : null);
      if (target != null) _pageController.jumpToPage(target);
    });
  }

  void _handleCardPressed(int rawIndex, String category) {
    if (widget.sections.length <= 1 || rawIndex == _rawPage) {
      widget.onCategoryPressed(category);
      return;
    }
    _pauseAfterInteraction();
    if (_reduceMotion) {
      _pageController.jumpToPage(rawIndex);
      return;
    }
    _pageController.animateToPage(
      rawIndex,
      duration: PetMagicMotion.medium,
      curve: PetMagicMotion.emphasized,
    );
  }

  void _stepCategory(int direction) {
    if (widget.sections.length <= 1 || !_pageController.hasClients) return;
    _pauseAfterInteraction();
    final target = (_rawPage + direction).clamp(0, widget.sections.length + 1);
    if (_reduceMotion) {
      _pageController.jumpToPage(target);
    } else {
      _pageController.animateToPage(
        target,
        duration: PetMagicMotion.medium,
        curve: PetMagicMotion.emphasized,
      );
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || widget.sections.isEmpty) {
      return KeyEventResult.ignored;
    }
    final direction = Directionality.of(context) == TextDirection.rtl ? -1 : 1;
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (widget.sections.length <= 1) return KeyEventResult.ignored;
      _stepCategory(direction);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (widget.sections.length <= 1) return KeyEventResult.ignored;
      _stepCategory(-direction);
    } else if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.space) {
      widget.onCategoryPressed(widget.sections[_logicalPage].category);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
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
    return VisibilityDetector(
      key: _visibilityKey,
      onVisibilityChanged: _handleVisibilityChanged,
      child: Focus(
        key: const ValueKey('discovery-carousel-focus'),
        onKeyEvent: _handleKeyEvent,
        onFocusChange: (focused) {
          if (!mounted) return;
          setState(() => _hasKeyboardFocus = focused);
          _scheduleAutoAdvance();
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = math.min(
              240.0,
              constraints.maxWidth * _viewportFraction - 10,
            );
            final height = cardWidth * 1.5 + 14;
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
                        final logicalIndex = _logicalIndex(
                          rawIndex,
                          sections.length,
                        );
                        return AnimatedBuilder(
                          animation: _pageController,
                          builder: (context, child) {
                            final page =
                                _pageController.hasClients &&
                                    _pageController.position.haveDimensions
                                ? _pageController.page ?? _rawPage.toDouble()
                                : _rawPage.toDouble();
                            final distance = (page - rawIndex).abs().clamp(
                              0.0,
                              1.0,
                            );
                            final emphasis = Curves.easeOut.transform(
                              1 - distance,
                            );
                            final scale = _reduceMotion
                                ? 1.0
                                : 0.9 + emphasis * 0.1;
                            final opacity = 0.72 + emphasis * 0.28;
                            return Transform.scale(
                              scale: scale,
                              child: Opacity(opacity: opacity, child: child),
                            );
                          },
                          child: Center(
                            child: SizedBox(
                              width: cardWidth,
                              height: cardWidth * 1.5,
                              child: _CategorySpotlightCard(
                                section: section,
                                logicalIndex: logicalIndex,
                                total: sections.length,
                                eyebrowLabel: widget.eyebrowLabel,
                                openLabel: widget.openLabel,
                                isSelected: logicalIndex == _logicalPage,
                                showFocus:
                                    _hasKeyboardFocus &&
                                    logicalIndex == _logicalPage,
                                pageController: _pageController,
                                rawIndex: rawIndex,
                                reduceMotion: _reduceMotion,
                                onSemanticPressed: () =>
                                    widget.onCategoryPressed(section.category),
                                onPressed: () => _handleCardPressed(
                                  rawIndex,
                                  section.category,
                                ),
                              ),
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
                  categories: sections
                      .map((section) => section.category)
                      .toList(),
                  label: widget.eyebrowLabel,
                  reduceMotion: _reduceMotion,
                  onPrevious: () => _stepCategory(-1),
                  onNext: () => _stepCategory(1),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
