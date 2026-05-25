import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/rewards/presentation/rewards_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_history_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_status_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/generations_gallery_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_generation_controller.dart';

const _bottomNavHeight = 42.0;
const _bottomNavOuterGap = 10.0;
const _bottomNavContentInsetExtra = 18.0;
const _bottomNavBackdropExtra = 28.0;
const _bottomSheetBottomGap = 14.0;

double petMagicBottomNavInset(BuildContext context) {
  final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;
  return bottomPadding +
      _bottomNavHeight +
      _bottomNavOuterGap +
      _bottomNavContentInsetExtra;
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

class PetMagicShell extends ConsumerWidget {
  const PetMagicShell({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasKeyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? true;
    final showBottomNav = !hasKeyboard && isCurrentRoute;
    final activeGeneration = ref.watch(
      templateGenerationControllerProvider.select((state) => state.generation),
    );
    final showActiveBanner =
        showBottomNav &&
        activeGeneration != null &&
        !activeGeneration.isTerminal &&
        !location.startsWith(GenerationStatusPage.routePrefix);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          child,
          if (showBottomNav) const _BottomNavBackdrop(),
          if (showActiveBanner)
            _ActiveGenerationBanner(
              generationId: activeGeneration.generationId,
            ),
          if (showBottomNav) _FloatingBottomNav(location: location),
        ],
      ),
    );
  }
}

class _BottomNavBackdrop extends StatelessWidget {
  const _BottomNavBackdrop();

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
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
                  colors.backgroundBottom.withValues(alpha: 0.18),
                  colors.backgroundBottom.withValues(alpha: 0.42),
                  colors.backgroundBottom.withValues(alpha: 0.74),
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
  const _FloatingBottomNav({required this.location});

  final String location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;
    final unreadCount = ref.watch(
      generationHistoryControllerProvider.select((state) => state.unreadCount),
    );
    final items = [
      _NavItem('/templates', Icons.play_arrow_rounded, text.navTemplates),
      _NavItem(
        GenerationsGalleryPage.routePath,
        Icons.photo_library_outlined,
        text.navCreations,
        badgeCount: unreadCount,
      ),
      _NavItem(
        RewardsPage.routePath,
        Icons.card_giftcard_rounded,
        text.navRewards,
      ),
      _NavItem('/profile', Icons.person_outline_rounded, text.navProfile),
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
                        color: colors.backgroundBottom.withValues(alpha: 0.18),
                        blurRadius: 18,
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
                      color: colors.surfaceGlass.withValues(alpha: 0.68),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: colors.border.withValues(alpha: 0.22),
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
                                    selected: _isSelected(item.path, location),
                                    onTap: _isSelected(item.path, location)
                                        ? null
                                        : () => context.go(item.path),
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

  bool _isSelected(String path, String location) {
    return switch (path) {
      '/profile' => location.startsWith('/profile'),
      RewardsPage.routePath => location.startsWith(RewardsPage.routePath),
      GenerationsGalleryPage.routePath =>
        location == GenerationsGalleryPage.routePath ||
            location.startsWith(GenerationStatusPage.routePrefix),
      _ => location == path,
    };
  }
}

class _ActiveGenerationBanner extends StatelessWidget {
  const _ActiveGenerationBanner({required this.generationId});

  final String generationId;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          bottomPadding + _bottomNavOuterGap + _bottomNavHeight + 10,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () =>
              context.go('${GenerationStatusPage.routePrefix}/$generationId'),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceGlass.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.accent.withValues(alpha: 0.22)),
              boxShadow: [
                BoxShadow(
                  color: colors.shadow.withValues(alpha: 0.18),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
              child: Row(
                children: [
                  SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.3,
                      color: colors.accent,
                      backgroundColor: colors.border.withValues(alpha: 0.55),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Генерация продолжается',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textStrong,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: colors.textMuted),
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
    final inactiveColor = Color.lerp(colors.textMuted, colors.textSoft, 0.34)!;

    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: selected
                ? colors.accent.withValues(alpha: 0.1)
                : Colors.transparent,
            border: selected
                ? Border.all(color: colors.accent.withValues(alpha: 0.08))
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
  const _NavItem(this.path, this.icon, this.label, {this.badgeCount = 0});

  final String path;
  final IconData icon;
  final String label;
  final int badgeCount;
}
