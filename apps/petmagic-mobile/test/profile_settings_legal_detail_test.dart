import 'package:dio/dio.dart';
import 'package:petmagic_mobile/core/operations/request_cancellation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/profile/domain/profile_models.dart';
import 'package:petmagic_mobile/features/profile/data/profile_repository.dart';
import 'package:petmagic_mobile/features/profile/application/profile_controller.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_settings_detail_page.dart';

void main() {
  testWidgets(
    'legal detail stays offline without loading and retries on reconnect',
    (tester) async {
      final repository = _LegalDetailRepository();
      final networkController = _TestLegalDetailNetworkStatusController(
        initialHasInternet: false,
      );
      final container = ProviderContainer(
        retry: (attempt, error) => null,
        overrides: [
          profileControllerProvider.overrideWith(
            _FakeLegalDetailProfileController.new,
          ),
          profileRepositoryProvider.overrideWithValue(repository),
          networkStatusControllerProvider.overrideWith(() => networkController),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            routerConfig: GoRouter(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (context, state) => const ProfileSettingsDetailPage(
                    kind: ProfileSettingsDetailKind.terms,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump();

      expect(repository.fetchCurrentLegalDocumentsCalls, 0);
      expect(find.text("You're offline"), findsOneWidget);

      networkController.setHasInternet(true);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(repository.fetchCurrentLegalDocumentsCalls, 1);
      expect(find.text('Terms of Use'), findsOneWidget);
      expect(find.text("You're offline"), findsNothing);
    },
  );
}

class _FakeLegalDetailProfileController extends ProfileController {
  @override
  ProfileState build() {
    return const ProfileState(
      isLoading: false,
      isSaving: false,
      displayName: 'Pet User',
      email: 'pet@example.com',
      password: '',
      confirmPassword: '',
      profile: MobileUserProfile(
        userId: 'user-1',
        email: 'pet@example.com',
        displayName: 'Pet User',
        isPremium: false,
        emailConfirmed: true,
        termsOfUseAccepted: false,
        privacyPolicyAccepted: false,
        marketingEmailsEnabled: true,
        legalAcceptance: MobileLegalAcceptanceStatus(
          termsOfUseAccepted: false,
          termsOfUseAcceptedVersion: null,
          termsOfUseAcceptedAtUtc: null,
          privacyPolicyAccepted: false,
          privacyPolicyAcceptedVersion: null,
          privacyPolicyAcceptedAtUtc: null,
          currentTermsOfUseVersion: '2026-07-01',
          currentPrivacyPolicyVersion: '2026-07-01',
          requiresAcceptance: true,
        ),
        roles: ['user'],
        avatar: null,
      ),
    );
  }

  @override
  Future<void> initialize({String initialEmail = ''}) async {}

  @override
  Future<void> logout() async {}
}

class _LegalDetailRepository extends ProfileRepository {
  _LegalDetailRepository()
    : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  int fetchCurrentLegalDocumentsCalls = 0;

  @override
  Future<MobileLegalDocuments> fetchCurrentLegalDocuments({
    required String locale,
    RequestCancellation? cancelToken,
  }) async {
    fetchCurrentLegalDocumentsCalls++;
    return const MobileLegalDocuments(
      termsOfUse: MobileLegalDocument(
        kind: 'terms',
        title: 'Terms of Use',
        version: '2026-07-01',
        publishedAtUtc: null,
        summary: 'Terms summary',
        sections: [
          MobileLegalDocumentSection(
            heading: 'Terms heading',
            paragraphs: ['Terms paragraph'],
          ),
        ],
      ),
      privacyPolicy: MobileLegalDocument(
        kind: 'privacy',
        title: 'Privacy Policy',
        version: '2026-07-01',
        publishedAtUtc: null,
        summary: 'Privacy summary',
        sections: [
          MobileLegalDocumentSection(
            heading: 'Privacy heading',
            paragraphs: ['Privacy paragraph'],
          ),
        ],
      ),
    );
  }
}

class _TestLegalDetailNetworkStatusController extends NetworkStatusController {
  _TestLegalDetailNetworkStatusController({required this.initialHasInternet});

  final bool initialHasInternet;

  @override
  NetworkStatusState build() {
    return NetworkStatusState(hasInternet: initialHasInternet);
  }

  void setHasInternet(bool value) {
    state = state.copyWith(hasInternet: value);
  }
}
