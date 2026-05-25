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

const kPetMagicBottomNavHeight = 42.0;
const kPetMagicBottomNavOuterGap = 10.0;
const kPetMagicBottomContentInsetCompact = 16.0;
const kPetMagicBottomContentInsetRelaxed = 24.0;
const kPetMagicBottomNavBackdropExtra = 28.0;
const kPetMagicBottomSheetBottomGap = 14.0;

double petMagicBottomNavInset(
  BuildContext context, {
  double extraSpacing = kPetMagicBottomContentInsetCompact,
}) {
  final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;
  return bottomPadding +
      kPetMagicBottomNavHeight +
      kPetMagicBottomNavOuterGap +
      extraSpacing;
}

double petMagicScrollableBottomInset(
  BuildContext context, {
  double extraSpacing = kPetMagicBottomContentInsetCompact,
  double keyboardExtra = kPetMagicBottomContentInsetCompact,
}) {
  final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
  final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
  if (keyboardInset > 0) {
    return safeBottom + keyboardExtra;
  }

  return safeBottom +
      kPetMagicBottomNavHeight +
      kPetMagicBottomNavOuterGap +
      extraSpacing;
}

double petMagicBottomSheetOffset(BuildContext context) {
  final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
  if (keyboardInset > 0) {
    return keyboardInset + kPetMagicBottomSheetBottomGap;
  }

  final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;
  return bottomPadding + kPetMagicBottomSheetBottomGap;
}

class PetMagicShell extends ConsumerStatefulWidget {
  const PetMagicShell({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  @override
  ConsumerState<PetMagicShell> createState() => _PetMagicShellState();
}

class _PetMagicShellState extends ConsumerState<PetMagicShell> {
  String? _dismissedGenerationId;

  @override
  Widget build(BuildContext context) {
    final hasKeyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? true;
    final showBottomNav = !hasKeyboard && isCurrentRoute;
    final location = widget.location;
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

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
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
                kPetMagicBottomNavHeight +
                kPetMagicBottomNavOuterGap +
                kPetMagicBottomNavBackdropExtra,
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
            bottomPadding + kPetMagicBottomNavOuterGap,
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
                        height: kPetMagicBottomNavHeight,
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
  const _ActiveGenerationBanner({
    required this.generation,
    required this.onDismiss,
  });

  final TemplateGenerationResult generation;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
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
          bottomPadding +
              kPetMagicBottomNavOuterGap +
              kPetMagicBottomNavHeight +
              10,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => context.go(
            '${GenerationStatusPage.routePrefix}/${generation.generationId}',
          ),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Создаем ваш результат...',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: colors.textMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            Text(
                              generation.templateTitle ?? 'Новая генерация',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: colors.textStrong,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                          ],
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
