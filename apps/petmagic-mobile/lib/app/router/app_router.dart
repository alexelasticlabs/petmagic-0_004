import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_page.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/profile/presentation/auth_entry_page.dart';
import 'package:petmagic_mobile/features/startup/presentation/guest_welcome_page.dart';
import 'package:petmagic_mobile/features/startup/presentation/onboarding_page.dart';
import 'package:petmagic_mobile/features/startup/presentation/startup_loading_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_page.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_shell.dart';
import 'package:petmagic_mobile/shared/placeholders/coming_soon_page.dart';

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
      final isPublicAuthRoute = isAuthRoute || isRegisterRoute;

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
        builder: (context, state) => const StartupLoadingPage(),
      ),
      GoRoute(
        path: OnboardingPage.routePath,
        builder: (context, state) => const OnboardingPage(),
      ),
      GoRoute(
        path: GuestWelcomePage.routePath,
        builder: (context, state) => const GuestWelcomePage(),
      ),
      GoRoute(
        path: AuthEntryPage.routePath,
        builder: (context, state) => const AuthEntryPage(),
      ),
      GoRoute(
        path: RegisterEntryPage.routePath,
        builder: (context, state) => const RegisterEntryPage(),
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
            path: '/creations',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ComingSoonPage(kind: ComingSoonKind.creations),
            ),
          ),
          GoRoute(
            path: ProfilePage.routePath,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ProfilePage()),
          ),
        ],
      ),
    ],
  );
});
