import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_page.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_page.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_shell.dart';
import 'package:petmagic_mobile/shared/placeholders/coming_soon_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: TemplatesPage.routePath,
    routes: [
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
