import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/features/premium/presentation/paywall_feedback_scope.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/profile/data/profile_models.dart';

void main() {
  test(
    'paywall feedback scope resolver uses guest scope for signed-out flow',
    () async {
      final resolver = PaywallFeedbackScopeResolver(
        sessionStorage: _FakeAuthSessionStorage(),
      );

      final scope = await resolver.resolve(isAuthenticated: false);

      expect(scope, 'guest');
    },
  );

  test(
    'paywall feedback scope resolver prefers loaded profile user id',
    () async {
      final storage = _FakeAuthSessionStorage(
        session: _sessionWithUserId('session-user'),
      );
      final resolver = PaywallFeedbackScopeResolver(sessionStorage: storage);

      final scope = await resolver.resolve(
        isAuthenticated: true,
        profileUserId: 'profile-user',
      );

      expect(scope, 'profile-user');
      expect(storage.readCalls, 0);
    },
  );

  test(
    'paywall feedback scope resolver falls back to auth session user id',
    () async {
      final storage = _FakeAuthSessionStorage(
        session: _sessionWithUserId('session-user'),
      );
      final resolver = PaywallFeedbackScopeResolver(sessionStorage: storage);

      final scope = await resolver.resolve(isAuthenticated: true);

      expect(scope, 'session-user');
      expect(storage.readCalls, 1);
    },
  );

  test(
    'paywall feedback scope resolver skips prompt when auth scope is unavailable',
    () async {
      final resolver = PaywallFeedbackScopeResolver(
        sessionStorage: _FakeAuthSessionStorage(),
      );

      final scope = await resolver.resolve(isAuthenticated: true);

      expect(scope, isNull);
    },
  );

  test('paywall feedback storage keys stay isolated by scope', () {
    expect(
      buildPaywallFeedbackLastShownStorageKey('user-a'),
      isNot(buildPaywallFeedbackLastShownStorageKey('user-b')),
    );
  });
}

class _FakeAuthSessionStorage extends AuthSessionStorage {
  _FakeAuthSessionStorage({this.session});

  final AuthSession? session;
  int readCalls = 0;

  @override
  Future<AuthSession?> read() async {
    readCalls++;
    return session;
  }
}

AuthSession _sessionWithUserId(String userId) {
  return AuthSession(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    expiresAtUtc: DateTime.utc(2030, 1, 1),
    user: MobileUserProfile(
      userId: userId,
      email: '$userId@example.com',
      displayName: 'User',
      isPremium: false,
      emailConfirmed: true,
      termsOfUseAccepted: true,
      privacyPolicyAccepted: true,
      marketingEmailsEnabled: false,
      legalAcceptance: const MobileLegalAcceptanceStatus(
        termsOfUseAccepted: true,
        termsOfUseAcceptedVersion: '2026-05-20',
        termsOfUseAcceptedAtUtc: null,
        privacyPolicyAccepted: true,
        privacyPolicyAcceptedVersion: '2026-05-20',
        privacyPolicyAcceptedAtUtc: null,
        currentTermsOfUseVersion: '2026-05-20',
        currentPrivacyPolicyVersion: '2026-05-20',
        requiresAcceptance: false,
      ),
      roles: const ['user'],
      avatar: null,
    ),
  );
}
