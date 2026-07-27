part of 'app_router.dart';

List<RouteBase> _buildAppRoutes(Ref ref) {
  return [
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
      pageBuilder: (context, state) {
        final args = state.extra is AuthEntryRouteArgs
            ? state.extra! as AuthEntryRouteArgs
            : null;
        return _buildFadeSlidePage(
          state: state,
          child: AuthEntryPage(
            initialEmail: args?.initialEmail,
            redirectPath: normalizeAuthRedirectPath(
              args?.redirectPath ?? state.uri.queryParameters['redirect'],
            ),
          ),
        );
      },
    ),
    GoRoute(
      path: RegisterEntryPage.routePath,
      pageBuilder: (context, state) => _buildFadeSlidePage(
        state: state,
        child: RegisterEntryPage(
          redirectPath: normalizeAuthRedirectPath(
            state.uri.queryParameters['redirect'],
          ),
        ),
      ),
    ),
    GoRoute(
      path: PasswordResetPage.routePath,
      pageBuilder: (context, state) {
        final args = state.extra is PasswordResetRouteArgs
            ? state.extra! as PasswordResetRouteArgs
            : null;
        return _buildFadeSlidePage(
          state: state,
          child: PasswordResetPage(initialEmail: args?.initialEmail),
        );
      },
    ),
    GoRoute(
      path: EmailVerificationPage.routePath,
      pageBuilder: (context, state) {
        final args = state.extra is EmailVerificationRouteArgs
            ? state.extra! as EmailVerificationRouteArgs
            : null;
        return _buildFadeSlidePage(
          state: state,
          child: EmailVerificationPage(
            email: args?.email ?? '',
            startResendCooldown:
                args?.startResendCooldown ??
                state.uri.queryParameters['cooldown'] == '1',
          ),
        );
      },
    ),
    GoRoute(
      path: LegalAcceptanceGatePage.routePath,
      pageBuilder: (context, state) => _buildFadeSlidePage(
        state: state,
        child: const LegalAcceptanceGatePage(),
      ),
    ),
    GoRoute(
      path: CreateHubPage.routePath,
      pageBuilder: (context, state) => NoTransitionPage(
        child: Scaffold(
          body: CreateHubPage(
            initialSource:
                state.uri.queryParameters[CreateHubPage.sourceQueryParameter],
          ),
        ),
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
              pageBuilder: (context, state) => NoTransitionPage(
                child: TemplatesPage(
                  initialPetId: state.uri.queryParameters['petId'],
                  initialPetPhotoId: state.uri.queryParameters['petPhotoId'],
                ),
              ),
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
      path: AchievementsPage.routePath,
      pageBuilder: (context, state) =>
          _buildFadeSlidePage(state: state, child: const AchievementsPage()),
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
      path: TemplatePreviewPage.routePath,
      redirect: (context, state) {
        final extra = state.extra;
        if (extra is TemplateItem || extra is TemplatePreviewRouteArgs) {
          return null;
        }
        return TemplatesPage.routePath;
      },
      pageBuilder: (context, state) {
        final previewPage = _buildTemplatePreviewPageFromState(state);
        if (previewPage != null) {
          return previewPage;
        }

        return _buildFadeSlidePage(state: state, child: const TemplatesPage());
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '${TemplatePreviewPage.routePath}/:templateId',
      redirect: (context, state) {
        if (state.extra is TemplateItem ||
            state.extra is TemplatePreviewRouteArgs) {
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

        return _buildTemplatePreviewPage(state: state, args: args);
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
      path: '${GenerationResultInputPage.routePrefix}/:generationId/use-input',
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
      path: WalletPage.routePath,
      pageBuilder: (context, state) =>
          _buildFadeSlidePage(state: state, child: const WalletPage()),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      name: AllTransactionsPage.routeName,
      path: AllTransactionsPage.routePath,
      pageBuilder: (context, state) =>
          _buildFadeSlidePage(state: state, child: const AllTransactionsPage()),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: ProfileSettingsPage.routePath,
      pageBuilder: (context, state) =>
          _buildFadeSlidePage(state: state, child: const ProfileSettingsPage()),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: StorageManagementPage.routePath,
      pageBuilder: (context, state) => _buildFadeSlidePage(
        state: state,
        child: const StorageManagementPage(),
      ),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: PasswordChangePage.routePath,
      pageBuilder: (context, state) {
        final args = state.extra is PasswordChangeRouteArgs
            ? state.extra! as PasswordChangeRouteArgs
            : null;
        return _buildFadeSlidePage(
          state: state,
          child: PasswordChangePage(email: args?.email ?? ''),
        );
      },
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
      redirect: (context, state) {
        final kind = ProfileSettingsDetailKind.fromSlug(
          state.pathParameters['kind'] ?? 'help-center',
        );
        if (kind == ProfileSettingsDetailKind.support) {
          return SupportHomePage.routePath;
        }

        return null;
      },
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
          initialMessage: SupportChatPage.normalizeInitialMessageQuery(
            state.uri.queryParameters[SupportChatPage.initialMessageQueryParam],
          ),
          relatedGenerationId:
              SupportChatPage.normalizeRelatedGenerationIdQuery(
                state.uri.queryParameters[SupportChatPage
                    .relatedGenerationIdQueryParam],
              ),
        ),
      ),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: SupportAssistantPage.routePath,
      pageBuilder: (context, state) => _buildFadeSlidePage(
        state: state,
        child: SupportAssistantPage(
          scenario:
              normalizeSupportScenarioQuery(
                state.uri.queryParameters['scenario'],
              ) ??
              'Other',
        ),
      ),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: SupportTicketFormPage.routePath,
      pageBuilder: (context, state) => _buildFadeSlidePage(
        state: state,
        child: SupportTicketFormPage(
          scenario:
              normalizeSupportScenarioQuery(
                state.uri.queryParameters['scenario'],
              ) ??
              'Other',
        ),
      ),
    ),
  ];
}
