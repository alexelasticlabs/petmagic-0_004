import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/profile/domain/profile_models.dart';
import 'package:petmagic_mobile/features/profile/data/profile_repository.dart';
import 'package:petmagic_mobile/features/profile/presentation/legal_acceptance_gate_page.dart';
import 'package:petmagic_mobile/features/profile/application/profile_controller.dart';

void main() {
  testWidgets(
    'legal acceptance gate stays offline without loading and retries on reconnect',
    (tester) async {
      final repository = _LegalDocumentsRepository();
      final networkController = _TestLegalGateNetworkStatusController(false);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileControllerProvider.overrideWith(
              _AuthenticatedLegalGateProfileController.new,
            ),
            profileRepositoryProvider.overrideWithValue(repository),
            networkStatusControllerProvider.overrideWith(
              () => networkController,
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const LegalAcceptanceGatePage(),
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
      expect(find.text('Privacy Policy'), findsOneWidget);
    },
  );
}

class _AuthenticatedLegalGateProfileController extends ProfileController {
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
        marketingEmailsEnabled: false,
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
        roles: ['User'],
        avatar: null,
      ),
    );
  }

  @override
  Future<void> logout() async {}
}

class _LegalDocumentsRepository extends ProfileRepository {
  _LegalDocumentsRepository()
    : super(dio: Dio(), sessionStorage: AuthSessionStorage());

  int fetchCurrentLegalDocumentsCalls = 0;

  @override
  Future<MobileLegalDocuments> fetchCurrentLegalDocuments({
    required String locale,
    CancelToken? cancelToken,
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

class _TestLegalGateNetworkStatusController extends NetworkStatusController {
  _TestLegalGateNetworkStatusController(this.initialHasInternet);

  final bool initialHasInternet;

  @override
  NetworkStatusState build() {
    return NetworkStatusState(hasInternet: initialHasInternet);
  }

  void setHasInternet(bool value) {
    state = state.copyWith(hasInternet: value);
  }
}
