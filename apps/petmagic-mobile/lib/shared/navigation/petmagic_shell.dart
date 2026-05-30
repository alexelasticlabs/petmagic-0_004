import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/rewards/presentation/rewards_page.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_history_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_status_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/generations_gallery_page.dart';
import 'package:petmagic_mobile/shared/widgets/pressable_scale.dart';

const _bottomNavHeight = 42.0;
const _bottomNavOuterGap = 10.0;
const _bottomNavContentInsetExtra = 18.0;
const _bottomNavBackdropExtra = 28.0;
const _bottomSheetBottomGap = 14.0;

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
    final navigationShell = widget.navigationShell;
    final showBottomNav = !hasKeyboard && isCurrentRoute;
    final activeGeneration = ref.watch(
      generationHistoryControllerProvider.select(
        (state) => state.activeGeneration,
      ),
    );
    final showActiveBanner =
        showBottomNav &&
        activeGeneration != null &&
        !activeGeneration.isTerminal &&
        _dismissedGenerationId != activeGeneration.generationId &&
        !location.startsWith(GenerationStatusPage.routePrefix);
    final currentIndex =
        navigationShell?.currentIndex ??
        _resolveCurrentIndexFromLocation(location);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          _ShellTabFadeTransition(
            tabIndex: currentIndex,
            child: navigationShell ?? widget.child!,
          ),
          if (showBottomNav) const _BottomNavBackdrop(),
          if (showActiveBanner)
            _ActiveGenerationBanner(
              generation: activeGeneration,
              onDismiss: () {
                setState(() {
                  _dismissedGenerationId = activeGeneration.generationId;
                });
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
  static const _duration = Duration(milliseconds: 120);
  static const _curve = Curves.easeOut;

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
        final opacity = 0.9 + (_animation.value * 0.1);
        return Opacity(opacity: opacity, child: child);
      },
    );
  }

  bool _disableAnimations(BuildContext context) {
    final media = MediaQuery.maybeOf(context);
    if (media == null) {
      return false;
    }

    return media.disableAnimations || media.accessibleNavigation;
  }
}

class _BottomNavBackdrop extends StatelessWidget {
  const _BottomNavBackdrop();

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;

    return RepaintBoundary(
      child: IgnorePointer(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height:
                bottomPadding +
                _bottomNavHeight +
                _bottomNavOuterGap +
                _bottomNavBackdropExtra,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colors.backgroundBottom.withValues(alpha: 0),
                  colors.backgroundBottom.withValues(
                    alpha: isLight ? 0.3 : 0.18,
                  ),
                  colors.backgroundBottom.withValues(
                    alpha: isLight ? 0.62 : 0.42,
                  ),
                  colors.backgroundBottom.withValues(
                    alpha: isLight ? 0.9 : 0.74,
                  ),
                ],
                stops: const [0, 0.34, 0.68, 1],
              ),
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
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: colors.shadow.withValues(alpha: 0.3),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                      BoxShadow(
                        color: colors.backgroundBottom.withValues(
                          alpha: isLight ? 0.28 : 0.18,
                        ),
                        blurRadius: isLight ? 22 : 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surfaceGlass.withValues(
                        alpha: isLight ? 0.92 : 0.68,
                      ),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: colors.border.withValues(
                          alpha: isLight ? 0.6 : 0.22,
                        ),
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
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
    final previewUrl = generation.sourceImageAsset?.url;
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
          borderRadius: BorderRadius.circular(18),
          haptic: PressableScaleHaptic.selection,
          onTap: () => context.push(
            '${GenerationStatusPage.routePrefix}/${generation.generationId}',
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceGlass.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(18),
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
              padding: const EdgeInsets.fromLTRB(10, 9, 8, 9),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: SizedBox(
                          width: 34,
                          height: 34,
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
                        child: Text(
                          text.shellActiveGenerationLabel(
                            generation.templateTitle ??
                                text.shellActiveGenerationFallback,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: colors.textStrong,
                                fontWeight: FontWeight.w900,
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
                        onPressed: onDismiss,
                        icon: Icon(
                          Icons.keyboard_arrow_up_rounded,
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 4,
                      value: progress / 100,
                      color: colors.accent,
                      backgroundColor: colors.border.withValues(alpha: 0.55),
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
    final inactiveColor = Color.lerp(colors.textMuted, colors.textSoft, 0.34)!;

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
                ? colors.accent.withValues(alpha: isLight ? 0.14 : 0.1)
                : Colors.transparent,
            border: selected
                ? Border.all(
                    color: colors.accent.withValues(
                      alpha: isLight ? 0.22 : 0.08,
                    ),
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
