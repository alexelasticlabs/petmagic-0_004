import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/premium/presentation/premium_page.dart';
import 'package:petmagic_mobile/features/premium/presentation/stripe_paymentsheet_smoke_test_page.dart';
import 'package:petmagic_mobile/features/premium/presentation/subscription_management_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/auth_entry_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/email_verification_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/legal_acceptance_gate_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/password_change_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/password_reset_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_settings_detail_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_settings_page.dart';
import 'package:petmagic_mobile/features/rewards/presentation/rewards_page.dart';
import 'package:petmagic_mobile/features/startup/presentation/guest_welcome_page.dart';
import 'package:petmagic_mobile/features/startup/presentation/onboarding_page.dart';
import 'package:petmagic_mobile/features/startup/presentation/startup_loading_page.dart';
import 'package:petmagic_mobile/features/support/presentation/support_assistant_page.dart';
import 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';
import 'package:petmagic_mobile/features/support/presentation/support_home_page.dart';
import 'package:petmagic_mobile/features/support/presentation/support_ticket_form_page.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_status_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/generations_gallery_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_preview_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_page.dart';
import 'package:petmagic_mobile/features/wallet/presentation/all_transactions_page.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_page.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_shell.dart';

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
    redirect: (context, state) {
      final launchState = ref.read(appLaunchControllerProvider);
      final location = state.uri.path;
      final isStartupRoute = location == StartupLoadingPage.routePath;
      final isOnboardingRoute = location == OnboardingPage.routePath;
      final isWelcomeRoute = location == GuestWelcomePage.routePath;
      final isAuthRoute = location == AuthEntryPage.routePath;
      final isRegisterRoute = location == RegisterEntryPage.routePath;
      final isPasswordResetRoute = location == PasswordResetPage.routePath;
      final isVerifyEmailRoute = location == EmailVerificationPage.routePath;
      final isLegalGateRoute = location == LegalAcceptanceGatePage.routePath;
      final isPublicAuthRoute =
          isAuthRoute ||
          isRegisterRoute ||
          isPasswordResetRoute ||
          isVerifyEmailRoute;

      if (launchState.isLoading) {
        return isStartupRoute ? null : StartupLoadingPage.routePath;
      }

      if (launchState.isAuthenticated) {
        if (launchState.requiresLegalAcceptance) {
          return isLegalGateRoute ? null : LegalAcceptanceGatePage.routePath;
        }

        if (isStartupRoute ||
            isOnboardingRoute ||
            isWelcomeRoute ||
            isPublicAuthRoute ||
            isLegalGateRoute) {
          return TemplatesPage.routePath;
        }
        return null;
      }

      if (!launchState.hasSeenOnboarding) {
        return isOnboardingRoute || isPublicAuthRoute
            ? null
            : OnboardingPage.routePath;
      }

      if (!launchState.guestSessionReady) {
        return isWelcomeRoute || isPublicAuthRoute
            ? null
            : GuestWelcomePage.routePath;
      }

      if (isStartupRoute || isOnboardingRoute || isWelcomeRoute) {
        return TemplatesPage.routePath;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: StartupLoadingPage.routePath,
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: StartupLoadingPage()),
      ),
      GoRoute(
        path: OnboardingPage.routePath,
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: OnboardingPage()),
      ),
      GoRoute(
        path: GuestWelcomePage.routePath,
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: GuestWelcomePage()),
      ),
      GoRoute(
        path: AuthEntryPage.routePath,
        pageBuilder: (context, state) => NoTransitionPage(
          child: AuthEntryPage(
            initialEmail: state.uri.queryParameters['email'],
            redirectPath: state.uri.queryParameters['redirect'],
          ),
        ),
      ),
      GoRoute(
        path: RegisterEntryPage.routePath,
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: RegisterEntryPage()),
      ),
      GoRoute(
        path: PasswordResetPage.routePath,
        pageBuilder: (context, state) => NoTransitionPage(
          child: PasswordResetPage(
            initialEmail: state.uri.queryParameters['email'],
          ),
        ),
      ),
      GoRoute(
        path: EmailVerificationPage.routePath,
        pageBuilder: (context, state) {
          final extra = state.extra is Map<String, dynamic>
              ? state.extra! as Map<String, dynamic>
              : null;
          final initialPassword = extra == null
              ? null
              : extra['initialPassword'] as String?;

          return NoTransitionPage(
            child: EmailVerificationPage(
              email: state.uri.queryParameters['email'] ?? '',
              initialPassword: initialPassword,
            ),
          );
        },
      ),
      GoRoute(
        path: LegalAcceptanceGatePage.routePath,
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: LegalAcceptanceGatePage()),
      ),
      GoRoute(
        path: StripePaymentSheetSmokeTestPage.routePath,
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: StripePaymentSheetSmokeTestPage()),
      ),
      StatefulShellRoute.indexedStack(
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state, navigationShell) => PetMagicShell(
          location: state.uri.path,
          navigationShell: navigationShell,
        ),
        branches: [
          StatefulShellBranch(
            navigatorKey: _templatesNavigatorKey,
            routes: [
              GoRoute(
                path: TemplatesPage.routePath,
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: TemplatesPage()),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _creationsNavigatorKey,
            routes: [
              GoRoute(
                path: GenerationsGalleryPage.routePath,
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: GenerationsGalleryPage()),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _rewardsNavigatorKey,
            routes: [
              GoRoute(
                path: RewardsPage.routePath,
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: RewardsPage()),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _profileNavigatorKey,
            routes: [
              GoRoute(
                path: ProfilePage.routePath,
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: ProfilePage()),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: PremiumPage.routePath,
        pageBuilder: (context, state) =>
            _buildFadeSlidePage(state: state, child: const PremiumPage()),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: TemplatePreviewPage.routePath,
        redirect: (context, state) =>
            state.extra is TemplateItem ||
                state.extra is TemplatePreviewRouteArgs
            ? null
            : TemplatesPage.routePath,
        pageBuilder: (context, state) {
          final extra = state.extra!;
          final args = switch (extra) {
            final TemplatePreviewRouteArgs value => value,
            final TemplateItem value => TemplatePreviewRouteArgs(
              template: value,
              hasPremiumAccess: false,
              isAuthenticated: false,
            ),
            _ => throw StateError(
              'Unexpected template preview route args type.',
            ),
          };

          return _buildFadeSlidePage(
            state: state,
            child: TemplatePreviewPage(
              template: args.template,
              hasPremiumAccess: args.hasPremiumAccess,
              isAuthenticated: args.isAuthenticated,
            ),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '${GenerationStatusPage.routePrefix}/:generationId',
        pageBuilder: (context, state) => _buildFadeSlidePage(
          state: state,
          child: GenerationStatusPage(
            generationId: state.pathParameters['generationId'] ?? '',
          ),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: SubscriptionManagementPage.routePath,
        pageBuilder: (context, state) => _buildFadeSlidePage(
          state: state,
          child: const SubscriptionManagementPage(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: WalletPage.legacyRoutePath,
        redirect: (context, state) => WalletPage.routePath,
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: WalletPage.routePath,
        pageBuilder: (context, state) =>
            _buildFadeSlidePage(state: state, child: const WalletPage()),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AllTransactionsPage.legacyRoutePath,
        redirect: (context, state) => AllTransactionsPage.routePath,
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        name: AllTransactionsPage.routeName,
        path: AllTransactionsPage.routePath,
        pageBuilder: (context, state) => _buildFadeSlidePage(
          state: state,
          child: const AllTransactionsPage(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: ProfileSettingsPage.routePath,
        pageBuilder: (context, state) => _buildFadeSlidePage(
          state: state,
          child: const ProfileSettingsPage(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: PasswordChangePage.routePath,
        pageBuilder: (context, state) => _buildFadeSlidePage(
          state: state,
          child: PasswordChangePage(
            email: state.uri.queryParameters['email'] ?? '',
          ),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: ProfileAccountInfoPage.routePath,
        pageBuilder: (context, state) => _buildFadeSlidePage(
          state: state,
          child: const ProfileAccountInfoPage(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: ProfileSettingsDetailPage.routePath,
        pageBuilder: (context, state) => _buildFadeSlidePage(
          state: state,
          child: ProfileSettingsDetailPage(
            kind: ProfileSettingsDetailKind.fromSlug(
              state.pathParameters['kind'] ?? 'help-center',
            ),
          ),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: SupportHomePage.routePath,
        pageBuilder: (context, state) =>
            _buildFadeSlidePage(state: state, child: const SupportHomePage()),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: SupportChatPage.routePath,
        pageBuilder: (context, state) =>
            _buildFadeSlidePage(state: state, child: const SupportChatPage()),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: SupportAssistantPage.routePath,
        pageBuilder: (context, state) => _buildFadeSlidePage(
          state: state,
          child: SupportAssistantPage(
            scenario: state.uri.queryParameters['scenario'] ?? 'Other',
          ),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: SupportTicketFormPage.routePath,
        pageBuilder: (context, state) => _buildFadeSlidePage(
          state: state,
          child: SupportTicketFormPage(
            scenario: state.uri.queryParameters['scenario'] ?? 'Other',
          ),
        ),
      ),
    ],
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
    transitionDuration: const Duration(milliseconds: 260),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final fade = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      final offset = Tween<Offset>(
        begin: const Offset(0, 0.025),
        end: Offset.zero,
      ).animate(fade);
      return FadeTransition(
        opacity: fade,
        child: SlideTransition(position: offset, child: child),
      );
    },
  );
}
