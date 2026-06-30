import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
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

part 'petmagic_shell_active_generation.part.dart';
part 'petmagic_shell_backdrop.part.dart';
part 'petmagic_shell_navigation.part.dart';
part 'petmagic_shell_transition.part.dart';

const _bottomNavHeight = 42.0;
const _bottomNavOuterGap = 10.0;
const _bottomNavContentInsetExtra = 18.0;
const _bottomNavBackdropExtra = 64.0;
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
