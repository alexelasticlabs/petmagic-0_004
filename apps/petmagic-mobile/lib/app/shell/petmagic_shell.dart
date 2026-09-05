import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/performance/app_performance_monitor.dart';
import 'package:petmagic_mobile/core/performance/performance_guard.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/core/navigation/app_navigator.dart';
import 'package:petmagic_mobile/features/rewards/presentation/rewards_page.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/application/generation_history_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_status_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/generations_gallery_page.dart';
import 'package:petmagic_mobile/shared/files/persistent_media_url.dart';
import 'package:petmagic_mobile/shared/auth/auth_required_sheet.dart';
import 'package:petmagic_mobile/shared/navigation/app_navigation_context.dart';
import 'package:petmagic_mobile/shared/navigation/external_url_policy.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_navigation_layout.dart';
import 'package:petmagic_mobile/shared/widgets/pressable_scale.dart';

part 'petmagic_shell_active_generation.part.dart';
part 'petmagic_shell_backdrop.part.dart';
part 'petmagic_shell_navigation.part.dart';
part 'petmagic_shell_transition.part.dart';

const _activeGenerationThumbnailCacheWidth = 96;

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
  @override
  Widget build(BuildContext context) {
    final hasKeyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? true;
    final location = widget.location;
    final colors = context.petMagicColors;
    AppPerformanceTrace.setRouteLabel(location);
    final navigationShell = widget.navigationShell;
    final showBottomNav = !hasKeyboard && isCurrentRoute;
    final isAuthenticated = ref.watch(
      appLaunchControllerProvider.select((state) => state.isAuthenticated),
    );
    final currentIndex =
        navigationShell?.currentIndex ??
        _resolveCurrentIndexFromLocation(location);

    return PetMagicShellScope(
      child: Scaffold(
        backgroundColor: colors.backgroundBottom,
        body: Stack(
          fit: StackFit.expand,
          children: [
            _ShellTabFadeTransition(
              tabIndex: currentIndex,
              child: navigationShell ?? widget.child!,
            ),
            if (showBottomNav) const _BottomNavBackdrop(),
            if (showBottomNav && isAuthenticated)
              _ActiveGenerationBannerSlot(location: location),
            if (showBottomNav)
              _FloatingBottomNav(
                currentIndex: currentIndex,
                isAuthenticated: isAuthenticated,
                onItemSelected: (index) {
                  if (!isAuthenticated && index != 0) {
                    _openGuestDestination(index);
                    return;
                  }
                  if (navigationShell != null) {
                    navigationShell.goBranch(
                      index,
                      initialLocation: index == currentIndex,
                    );
                    return;
                  }

                  if (index == currentIndex) {
                    return;
                  }

                  switch (index) {
                    case 0:
                      context.go('/discover');
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
      ),
    );
  }

  void _openGuestDestination(int index) {
    if (index == 3) {
      unawaited(
        context.appNavigator.push<void>(
          const AuthDestination(redirectPath: '/profile'),
        ),
      );
      return;
    }
    final text = AppLocalizations.of(context);
    unawaited(
      showAuthRequiredSheet(
        context,
        redirectPath: index == 1
            ? GenerationsGalleryPage.routePath
            : RewardsPage.routePath,
        title: index == 1 ? text.navCreations : text.navRewards,
        showSignUp: true,
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
