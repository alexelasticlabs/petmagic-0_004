import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/performance/app_performance_monitor.dart';
import 'package:petmagic_mobile/core/performance/performance_guard.dart';
import 'package:petmagic_mobile/features/rewards/presentation/rewards_page.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_history_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_status_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/generations_gallery_page.dart';
import 'package:petmagic_mobile/shared/navigation/external_url_policy.dart';
import 'package:petmagic_mobile/shared/widgets/pressable_scale.dart';

const _bottomNavHeight = 42.0;
const _bottomNavOuterGap = 10.0;
const _bottomNavContentInsetExtra = 18.0;
const _bottomNavBackdropExtra = 28.0;
const _bottomSheetBottomGap = 14.0;
const _activeGenerationThumbnailCacheWidth = 96;

const kPetMagicBottomContentInsetRelaxed = _bottomNavContentInsetExtra;
const kPetMagicBottomContentInsetCompact = _bottomNavOuterGap;

double petMagicBottomNavInset(
  BuildContext context, {
  double extraSpacing = kPetMagicBottomContentInsetRelaxed,
}) {
  final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;
  return bottomPadding + _bottomNavHeight + _bottomNavOuterGap + extraSpacing;
}

double petMagicScrollableBottomInset(
  BuildContext context, {
  double extraSpacing = kPetMagicBottomContentInsetRelaxed,
}) {
  return petMagicBottomNavInset(context, extraSpacing: extraSpacing);
}

double petMagicBottomSheetOffset(BuildContext context) {
  final viewMediaQuery = MediaQueryData.fromView(View.of(context));
  final keyboardInset = viewMediaQuery.viewInsets.bottom;
  if (keyboardInset > 0) {
    return keyboardInset + _bottomSheetBottomGap;
  }

  final bottomPadding = viewMediaQuery.viewPadding.bottom;
  return bottomPadding +
      _bottomNavHeight +
      _bottomNavOuterGap +
      _bottomSheetBottomGap;
}

class PetMagicShell extends ConsumerStatefulWidget {
  const PetMagicShell({
    required this.location,
    this.navigationShell,
    this.child,
    super.key,
  }) : assert(
         navigationShell != null || child != null,
         'Either navigationShell or child must be provided.',
       );

  final String location;
  final StatefulNavigationShell? navigationShell;
  final Widget? child;

  @override
  ConsumerState<PetMagicShell> createState() => _PetMagicShellState();
}

class _PetMagicShellState extends ConsumerState<PetMagicShell> {
  String? _dismissedGenerationId;

  @override
  Widget build(BuildContext context) {
    final hasKeyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? true;
    final location = widget.location;
    final colors = context.petMagicColors;
    AppPerformanceTrace.setRouteLabel(location);
    final navigationShell = widget.navigationShell;
    final showBottomNav = !hasKeyboard && isCurrentRoute;
    final currentIndex =
        navigationShell?.currentIndex ??
        _resolveCurrentIndexFromLocation(location);

    return Scaffold(
      backgroundColor: colors.backgroundBottom,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _ShellTabFadeTransition(
            tabIndex: currentIndex,
            child: navigationShell ?? widget.child!,
          ),
          if (showBottomNav) const _BottomNavBackdrop(),
          if (showBottomNav)
            _ActiveGenerationBannerSlot(
              location: location,
              dismissedGenerationId: _dismissedGenerationId,
              onDismiss: (generationId) {
                setState(() => _dismissedGenerationId = generationId);
              },
            ),
          if (showBottomNav)
            _FloatingBottomNav(
              currentIndex: currentIndex,
              onItemSelected: (index) {
                if (index == currentIndex) {
                  return;
                }

                if (navigationShell != null) {
                  navigationShell.goBranch(index);
                  return;
                }

                switch (index) {
                  case 0:
                    context.go('/templates');
                  case 1:
                    context.go(GenerationsGalleryPage.routePath);
                  case 2:
                    context.go(RewardsPage.routePath);
                  case 3:
                    context.go('/profile');
                }
              },
            ),
        ],
      ),
    );
  }

  int _resolveCurrentIndexFromLocation(String location) {
    if (location.startsWith('/profile')) {
      return 3;
    }
    if (location.startsWith(RewardsPage.routePath)) {
      return 2;
    }
    if (location == GenerationsGalleryPage.routePath ||
        location.startsWith(GenerationStatusPage.routePrefix)) {
      return 1;
    }
    return 0;
  }
}

class _ShellTabFadeTransition extends StatefulWidget {
  const _ShellTabFadeTransition({required this.tabIndex, required this.child});

  final int tabIndex;
  final Widget child;

  @override
  State<_ShellTabFadeTransition> createState() =>
      _ShellTabFadeTransitionState();
}

class _ShellTabFadeTransitionState extends State<_ShellTabFadeTransition>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 220);
  static const _curve = Curves.easeOutCubic;

  late final AnimationController _controller;
  late final Animation<double> _animation;
  late int _lastTabIndex;

  @override
  void initState() {
    super.initState();
    _lastTabIndex = widget.tabIndex;
    _controller = AnimationController(
      vsync: this,
      duration: _duration,
      value: 1,
    );
    _animation = CurvedAnimation(parent: _controller, curve: _curve);
  }

  @override
  void didUpdateWidget(covariant _ShellTabFadeTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_lastTabIndex == widget.tabIndex) {
      return;
    }

    _lastTabIndex = widget.tabIndex;
    if (_disableAnimations(context)) {
      _controller.value = 1;
      return;
    }

    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_disableAnimations(context)) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _animation,
      child: widget.child,
      builder: (context, child) {
        final opacity = 0.82 + (_animation.value * 0.18);
        final translateY = (1 - _animation.value) * 10;
        final scale = 0.992 + (_animation.value * 0.008);
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, translateY),
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
    );
  }

  bool _disableAnimations(BuildContext context) {
    return PerformanceGuard.shouldReduceMotion(context);
  }
}

class _BottomNavBackdrop extends StatelessWidget {
  const _BottomNavBackdrop();

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final isDegraded = PerformanceGuard.isDegradedMode(context);
    final blurSigma = isDegraded ? 8.0 : 12.0;
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;
    final height =
        bottomPadding +
        _bottomNavHeight +
        _bottomNavOuterGap +
        _bottomNavBackdropExtra;
    final scrim = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colors.backgroundBottom.withValues(alpha: 0),
            colors.backgroundBottom.withValues(alpha: isLight ? 0.24 : 0.10),
            colors.backgroundBottom.withValues(alpha: isLight ? 0.46 : 0.18),
          ],
          stops: const [0, 0.48, 1],
        ),
      ),
      child: const SizedBox.expand(),
    );

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: height,
      child: RepaintBoundary(
        child: IgnorePointer(
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
              child: scrim,
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingBottomNav extends ConsumerWidget {
  const _FloatingBottomNav({
    required this.currentIndex,
    required this.onItemSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onItemSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final isDegraded = PerformanceGuard.isDegradedMode(context);
    final blurSigma = isDegraded ? 10.0 : 18.0;
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;
    final unreadCount = ref.watch(
      generationHistoryControllerProvider.select((state) => state.unreadCount),
    );
    final items = [
      _NavItem(0, Icons.play_arrow_rounded, text.navTemplates),
      _NavItem(
        1,
        Icons.photo_library_outlined,
        text.navCreations,
        badgeCount: unreadCount,
      ),
      _NavItem(2, Icons.card_giftcard_rounded, text.navRewards),
      _NavItem(3, Icons.person_outline_rounded, text.navProfile),
    ];
    final navSurface = DecoratedBox(
      decoration: BoxDecoration(
        color: isLight
            ? colors.surfaceGlass.withValues(alpha: isDegraded ? 0.94 : 0.78)
            : Color.alphaBlend(
                Colors.black.withValues(alpha: isDegraded ? 0.40 : 0.30),
                colors.surfaceGlass.withValues(alpha: isDegraded ? 0.78 : 0.56),
              ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isLight
              ? Colors.white.withValues(alpha: 0.74)
              : Colors.white.withValues(alpha: 0.11),
          width: isLight ? 1.1 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(3, 1, 3, 1),
        child: SizedBox(
          height: _bottomNavHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final item in items)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 2,
                    ),
                    child: _BottomNavButton(
                      item: item,
                      selected: currentIndex == item.index,
                      onTap: currentIndex == item.index
                          ? null
                          : () => onItemSelected(item.index),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    return RepaintBoundary(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            bottomPadding + _bottomNavOuterGap,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                top: 1,
                bottom: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: isDegraded
                        ? [
                            BoxShadow(
                              color: colors.shadow.withValues(
                                alpha: isLight ? 0.20 : 0.24,
                              ),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: colors.shadow.withValues(
                                alpha: isLight ? 0.30 : 0.38,
                              ),
                              blurRadius: isLight ? 24 : 22,
                              offset: const Offset(0, 8),
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: isLight ? 0.08 : 0.18,
                              ),
                              blurRadius: 34,
                              offset: const Offset(0, 14),
                            ),
                          ],
                  ),
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: blurSigma,
                    sigmaY: blurSigma,
                  ),
                  child: navSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveGenerationBannerSlot extends ConsumerWidget {
  const _ActiveGenerationBannerSlot({
    required this.location,
    required this.dismissedGenerationId,
    required this.onDismiss,
  });

  final String location;
  final String? dismissedGenerationId;
  final ValueChanged<String> onDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeGeneration = ref.watch(
      generationHistoryControllerProvider.select(
        (state) => state.activeGeneration,
      ),
    );

    if (activeGeneration == null ||
        activeGeneration.isTerminal ||
        dismissedGenerationId == activeGeneration.generationId ||
        location == GenerationsGalleryPage.routePath ||
        location.startsWith(GenerationStatusPage.routePrefix)) {
      return const SizedBox.shrink();
    }

    return _ActiveGenerationBanner(
      generation: activeGeneration,
      onDismiss: () => onDismiss(activeGeneration.generationId),
    );
  }
}

class _ActiveGenerationBanner extends StatelessWidget {
  const _ActiveGenerationBanner({
    required this.generation,
    required this.onDismiss,
  });

  final TemplateGenerationResult generation;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;
    final previewUrl = parseSafeGenerationMediaUri(
      generation.sourceImageAsset?.url,
    )?.toString();
    final progress = generation.effectiveProgressPercent;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          bottomPadding + _bottomNavOuterGap + _bottomNavHeight + 10,
        ),
        child: PressableScale(
          borderRadius: BorderRadius.circular(16),
          haptic: PressableScaleHaptic.selection,
          onTap: () => context.push(
            GenerationStatusPage.routeFor(generation.generationId),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceGlass.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colors.accent.withValues(alpha: isLight ? 0.36 : 0.22),
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.shadow.withValues(alpha: 0.18),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: SizedBox(
                          width: 30,
                          height: 30,
                          child: previewUrl == null || previewUrl.isEmpty
                              ? ColoredBox(
                                  color: colors.surfaceStrong,
                                  child: Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 18,
                                    color: colors.accent,
                                  ),
                                )
                              : CachedNetworkImage(
                                  imageUrl: previewUrl,
                                  fit: BoxFit.cover,
                                  memCacheWidth:
                                      _activeGenerationThumbnailCacheWidth,
                                  maxWidthDiskCache:
                                      _activeGenerationThumbnailCacheWidth,
                                  filterQuality: FilterQuality.medium,
                                  errorWidget: (context, url, error) =>
                                      ColoredBox(
                                        color: colors.surfaceStrong,
                                        child: Icon(
                                          Icons.auto_awesome_rounded,
                                          size: 18,
                                          color: colors.accent,
                                        ),
                                      ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              generation.templateTitle ??
                                  text.shellActiveGenerationFallback,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: colors.textStrong,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              text.templateFlowStepCreateMagic,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: colors.textMuted,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 42,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            minHeight: 4,
                            value: progress / 100,
                            color: colors.accent,
                            backgroundColor: colors.border.withValues(
                              alpha: 0.55,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$progress%',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: colors.accent,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        onPressed: onDismiss,
                        icon: Icon(
                          Icons.keyboard_arrow_up_rounded,
                          color: colors.textMuted,
                        ),
                      ),
                    ],
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

class _BottomNavButton extends StatelessWidget {
  const _BottomNavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final inactiveColor = Color.lerp(colors.textMuted, colors.textSoft, 0.62)!;

    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      child: PressableScale(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        haptic: PressableScaleHaptic.selection,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: selected
                ? colors.accent.withValues(alpha: isLight ? 0.26 : 0.1)
                : Colors.transparent,
            border: selected
                ? Border.all(
                    color: colors.accent.withValues(
                      alpha: isLight ? 0.48 : 0.08,
                    ),
                    width: isLight ? 1.05 : 1,
                  )
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 24,
                height: 18,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      item.icon,
                      color: selected ? colors.accent : inactiveColor,
                      size: 17,
                    ),
                    if (item.badgeCount > 0)
                      Positioned(
                        right: 1,
                        top: 0,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: colors.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 1),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? colors.accent : inactiveColor,
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  letterSpacing: 0.05,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.index, this.icon, this.label, {this.badgeCount = 0});

  final int index;
  final IconData icon;
  final String label;
  final int badgeCount;
}
