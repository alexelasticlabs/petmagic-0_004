import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/core/performance/app_performance_monitor.dart';
import 'package:petmagic_mobile/core/navigation/app_navigator.dart';
import 'package:petmagic_mobile/features/create/presentation/create_hub_page.dart';
import 'package:petmagic_mobile/features/pets/presentation/my_pets_page.dart';
import 'package:petmagic_mobile/features/premium/presentation/premium_page.dart';
import 'package:petmagic_mobile/features/premium/presentation/subscription_management_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/auth_entry_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/email_verification_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/legal_acceptance_gate_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/password_change_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/password_reset_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_settings_detail_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_settings_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/storage_management_page.dart';
import 'package:petmagic_mobile/features/rewards/presentation/rewards_page.dart';
import 'package:petmagic_mobile/features/startup/presentation/guest_welcome_page.dart';
import 'package:petmagic_mobile/features/startup/presentation/startup_loading_page.dart';
import 'package:petmagic_mobile/features/support/presentation/support_assistant_scenarios.dart';
import 'package:petmagic_mobile/features/support/presentation/support_assistant_page.dart';
import 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';
import 'package:petmagic_mobile/features/support/presentation/support_home_page.dart';
import 'package:petmagic_mobile/features/support/presentation/support_ticket_form_page.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_result_input_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_status_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/generations_gallery_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_preview_loader_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_preview_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_page.dart';
import 'package:petmagic_mobile/features/gamification/presentation/achievements_page.dart';
import 'package:petmagic_mobile/features/wallet/presentation/all_transactions_page.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_page.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_page_transitions.dart';
import 'package:petmagic_mobile/shared/widgets/motion.dart';
import 'package:petmagic_mobile/app/shell/petmagic_shell.dart';

part 'app_routes.part.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'rootNavigator',
);
final _templatesNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'templatesNavigator',
);
final _creationsNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'creationsNavigator',
);
final _rewardsNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'rewardsNavigator',
);
final _profileNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'profileNavigator',
);

final _routerRefreshListenableProvider = Provider<RouterRefreshListenable>((
  ref,
) {
  final listenable = RouterRefreshListenable();
  ref.listen<AppLaunchState>(appLaunchControllerProvider, (previous, next) {
    listenable.notify();
  });
  ref.onDispose(listenable.dispose);
  return listenable;
});

class RouterRefreshListenable extends ChangeNotifier {
  void notify() {
    notifyListeners();
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshListenable = ref.watch(_routerRefreshListenableProvider);

  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    refreshListenable: refreshListenable,
    initialLocation: StartupLoadingPage.routePath,
    observers: [AppPerformanceRouteObserver.instance],
    redirect: (context, state) {
      final launchState = ref.read(appLaunchControllerProvider);
      final location = state.uri.path;
      final isStartupRoute = location == StartupLoadingPage.routePath;
      final isWelcomeRoute = location == GuestWelcomePage.routePath;
      final isAuthRoute = location == AuthEntryPage.routePath;
      final isRegisterRoute = location == RegisterEntryPage.routePath;
      final isPasswordResetRoute = location == PasswordResetPage.routePath;
      final isVerifyEmailRoute = location == EmailVerificationPage.routePath;
      final isLegalGateRoute = location == LegalAcceptanceGatePage.routePath;
      final isLegalDocumentRoute =
          location ==
              ProfileSettingsDetailPage.location(
                ProfileSettingsDetailKind.terms,
              ) ||
          location ==
              ProfileSettingsDetailPage.location(
                ProfileSettingsDetailKind.privacy,
              );
      final isAuthFlowRoute =
          isAuthRoute ||
          isRegisterRoute ||
          isPasswordResetRoute ||
          isVerifyEmailRoute;
      final isPublicAuthRoute = isAuthFlowRoute || isLegalDocumentRoute;

      if (launchState.isLoading) {
        return isStartupRoute ? null : StartupLoadingPage.routePath;
      }

      if (launchState.isAuthenticated) {
        if (launchState.requiresLegalAcceptance) {
          return isLegalGateRoute || isLegalDocumentRoute
              ? null
              : LegalAcceptanceGatePage.routePath;
        }

        if (isStartupRoute ||
            isWelcomeRoute ||
            isAuthFlowRoute ||
            isLegalGateRoute) {
          return TemplatesPage.routePath;
        }
        return null;
      }

      if (!launchState.hasSeenOnboarding) {
        return isWelcomeRoute || isPublicAuthRoute
            ? null
            : GuestWelcomePage.routePath;
      }

      if (!launchState.guestSessionReady) {
        return isWelcomeRoute || isPublicAuthRoute
            ? null
            : GuestWelcomePage.routePath;
      }

      if (isStartupRoute || isWelcomeRoute) {
        return TemplatesPage.routePath;
      }

      return null;
    },
    routes: _buildAppRoutes(ref),
  );

  ref.onDispose(router.dispose);
  return router;
});

CustomTransitionPage<T> _buildFadeSlidePage<T>({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: PetMotion.medium,
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: petMagicFadeSlideTransition,
  );
}

CustomTransitionPage<dynamic>? _buildTemplatePreviewPageFromState(
  GoRouterState state,
) {
  final extra = state.extra;
  final TemplatePreviewRouteArgs? args;
  if (extra is TemplatePreviewRouteArgs) {
    args = extra;
  } else if (extra is TemplateItem) {
    args = TemplatePreviewRouteArgs(
      template: extra,
      hasPremiumAccess: false,
      isAuthenticated: false,
    );
  } else {
    args = null;
  }

  if (args == null) {
    return null;
  }

  return _buildTemplatePreviewPage(state: state, args: args);
}

CustomTransitionPage<dynamic> _buildTemplatePreviewPage({
  required GoRouterState state,
  required TemplatePreviewRouteArgs args,
}) {
  return _buildFadeSlidePage(
    state: state,
    child: TemplatePreviewPage(
      template: args.template,
      hasPremiumAccess: args.hasPremiumAccess,
      isAuthenticated: args.isAuthenticated,
    ),
  );
}
