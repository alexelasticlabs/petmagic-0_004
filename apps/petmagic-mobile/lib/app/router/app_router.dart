import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/core/performance/app_performance_monitor.dart';
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
import 'package:petmagic_mobile/features/rewards/presentation/rewards_page.dart';
import 'package:petmagic_mobile/features/startup/presentation/guest_welcome_page.dart';
import 'package:petmagic_mobile/features/startup/presentation/startup_loading_page.dart';
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
import 'package:petmagic_mobile/features/wallet/presentation/all_transactions_page.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_page.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_page_transitions.dart';
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
    routes: [
      GoRoute(
        path: StartupLoadingPage.routePath,
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: StartupLoadingPage()),
      ),
      GoRoute(
        path: GuestWelcomePage.routePath,
        pageBuilder: (context, state) =>
            _buildFadeSlidePage(state: state, child: const GuestWelcomePage()),
      ),
      GoRoute(
        path: AuthEntryPage.routePath,
        pageBuilder: (context, state) => _buildFadeSlidePage(
          state: state,
          child: AuthEntryPage(
            initialEmail: state.uri.queryParameters['email'],
            redirectPath: state.uri.queryParameters['redirect'],
          ),
        ),
      ),
      GoRoute(
        path: RegisterEntryPage.routePath,
        pageBuilder: (context, state) =>
            _buildFadeSlidePage(state: state, child: const RegisterEntryPage()),
      ),
      GoRoute(
        path: PasswordResetPage.routePath,
        pageBuilder: (context, state) => _buildFadeSlidePage(
          state: state,
          child: PasswordResetPage(
            initialEmail: state.uri.queryParameters['email'],
          ),
        ),
      ),
      GoRoute(
        path: EmailVerificationPage.routePath,
        pageBuilder: (context, state) => _buildFadeSlidePage(
          state: state,
          child: EmailVerificationPage(
            email: state.uri.queryParameters['email'] ?? '',
            startResendCooldown: state.uri.queryParameters['cooldown'] == '1',
          ),
        ),
      ),
      GoRoute(
        path: LegalAcceptanceGatePage.routePath,
        pageBuilder: (context, state) => _buildFadeSlidePage(
          state: state,
          child: const LegalAcceptanceGatePage(),
        ),
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
        path: MyPetsPage.routePath,
        pageBuilder: (context, state) =>
            _buildFadeSlidePage(state: state, child: const MyPetsPage()),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: PetDetailsPage.routePath,
        pageBuilder: (context, state) => _buildFadeSlidePage(
          state: state,
          child: PetDetailsPage(petId: state.pathParameters['petId'] ?? ''),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '${TemplatePreviewPage.routePath}/:templateId',
        redirect: (context, state) {
          if (state.extra is TemplateItem || state.extra is TemplatePreviewRouteArgs) {
            return null;
          }
          final templateId = state.pathParameters['templateId'];
          if (templateId != null && templateId.isNotEmpty) {
            return null;
          }
          return TemplatesPage.routePath;
        },
        pageBuilder: (context, state) {
          final extra = state.extra;
          final TemplatePreviewRouteArgs args;
          if (extra is TemplatePreviewRouteArgs) {
            args = extra;
          } else if (extra is TemplateItem) {
            args = TemplatePreviewRouteArgs(
              template: extra,
              hasPremiumAccess: false,
              isAuthenticated: false,
            );
          } else {
            final templateId = state.pathParameters['templateId'] ?? '';
            return _buildFadeSlidePage(
              state: state,
              child: TemplatePreviewLoaderPage(templateId: templateId),
            );
          }

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
            templateOfTheDay: state.extra is TemplateOfTheDayItem
                ? state.extra! as TemplateOfTheDayItem
                : null,
          ),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path:
            '${GenerationResultInputPage.routePrefix}/:generationId/use-input',
        pageBuilder: (context, state) => _buildFadeSlidePage(
          state: state,
          child: GenerationResultInputPage(
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
        pageBuilder: (context, state) => _buildFadeSlidePage(
          state: state,
          child: SupportChatPage(
            initialMessage: state
                .uri
                .queryParameters[SupportChatPage.initialMessageQueryParam],
            relatedGenerationId: state
                .uri
                .queryParameters[SupportChatPage.relatedGenerationIdQueryParam],
          ),
        ),
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
  return buildPetMagicFadeSlidePage(state: state, child: child);
}
