import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/premium/presentation/premium_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/auth_entry_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/password_reset_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_settings_detail_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_settings_page.dart';
import 'package:petmagic_mobile/features/rewards/presentation/rewards_page.dart';
import 'package:petmagic_mobile/features/startup/presentation/guest_welcome_page.dart';
import 'package:petmagic_mobile/features/startup/presentation/onboarding_page.dart';
import 'package:petmagic_mobile/features/startup/presentation/startup_loading_page.dart';
import 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';
import 'package:petmagic_mobile/features/support/presentation/support_home_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_status_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/generations_gallery_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_page.dart';
import 'package:petmagic_mobile/features/wallet/presentation/all_transactions_page.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_page.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final launchState = ref.watch(appLaunchControllerProvider);

  return GoRouter(
    initialLocation: StartupLoadingPage.routePath,
    redirect: (context, state) {
      final location = state.uri.path;
      final isStartupRoute = location == StartupLoadingPage.routePath;
      final isOnboardingRoute = location == OnboardingPage.routePath;
      final isWelcomeRoute = location == GuestWelcomePage.routePath;
      final isAuthRoute = location == AuthEntryPage.routePath;
      final isRegisterRoute = location == RegisterEntryPage.routePath;
      final isPasswordResetRoute = location == PasswordResetPage.routePath;
      final isPublicAuthRoute =
          isAuthRoute || isRegisterRoute || isPasswordResetRoute;

      if (launchState.isLoading) {
        return isStartupRoute ? null : StartupLoadingPage.routePath;
      }

      if (launchState.isAuthenticated) {
        if (isStartupRoute ||
            isOnboardingRoute ||
            isWelcomeRoute ||
            isPublicAuthRoute) {
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
        path: PremiumPage.routePath,
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: PremiumPage()),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            PetMagicShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: TemplatesPage.routePath,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: TemplatesPage()),
          ),
          GoRoute(
            path: GenerationsGalleryPage.routePath,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: GenerationsGalleryPage()),
          ),
          GoRoute(
            path: '${GenerationStatusPage.routePrefix}/:generationId',
            pageBuilder: (context, state) => NoTransitionPage(
              child: GenerationStatusPage(
                generationId: state.pathParameters['generationId'] ?? '',
              ),
            ),
          ),
          GoRoute(
            path: ProfilePage.routePath,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ProfilePage()),
          ),
          GoRoute(
            path: WalletPage.legacyRoutePath,
            redirect: (context, state) => WalletPage.routePath,
          ),
          GoRoute(
            path: WalletPage.routePath,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: WalletPage()),
          ),
          GoRoute(
            name: AllTransactionsPage.routeName,
            path: AllTransactionsPage.routePath,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: AllTransactionsPage()),
          ),
          GoRoute(
            path: RewardsPage.routePath,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: RewardsPage()),
          ),
          GoRoute(
            path: ProfileSettingsPage.routePath,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ProfileSettingsPage()),
          ),
          GoRoute(
            path: ProfileAccountInfoPage.routePath,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ProfileAccountInfoPage()),
          ),
          GoRoute(
            path: ProfileSettingsDetailPage.routePath,
            pageBuilder: (context, state) => NoTransitionPage(
              child: ProfileSettingsDetailPage(
                kind: ProfileSettingsDetailKind.fromSlug(
                  state.pathParameters['kind'] ?? 'help-center',
                ),
              ),
            ),
          ),
          GoRoute(
            path: SupportHomePage.routePath,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: SupportHomePage()),
          ),
          GoRoute(
            path: SupportChatPage.routePath,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: SupportChatPage()),
          ),
        ],
      ),
    ],
  );
});
