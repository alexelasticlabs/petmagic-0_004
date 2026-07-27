import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/features/premium/presentation/paywall_feedback_scope.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';

void main() {
  test(
    'paywall feedback scope resolver skips the signed-out flow',
    () async {
      final storage = _FakeAuthSessionStorage();
      final resolver = PaywallFeedbackScopeResolver(sessionStorage: storage);

      final scope = await resolver.resolve(isAuthenticated: false);

      expect(scope, isNull);
      expect(storage.readCalls, 0);
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

  test(
    'paywall feedback scope resolver rejects unsafe storage scopes',
    () async {
      final resolver = PaywallFeedbackScopeResolver(
        sessionStorage: _FakeAuthSessionStorage(
          session: _sessionWithUserId('${'user' * 50}\nleak'),
        ),
      );

      final scope = await resolver.resolve(isAuthenticated: true);

      expect(scope, isNull);
    },
  );

  test('paywall feedback scope normalization bounds storage key input', () {
    expect(normalizePaywallFeedbackScope(' user-a '), 'user-a');
    expect(normalizePaywallFeedbackScope('user\nraw'), isNull);
    expect(normalizePaywallFeedbackScope('x' * 129), isNull);
  });

  test('paywall feedback storage keys stay isolated by scope', () {
    final userAKey = buildPaywallFeedbackLastShownStorageKey('user-a');
    final userBKey = buildPaywallFeedbackLastShownStorageKey('user-b');

    expect(userAKey, isNot(userBKey));
    expect(userAKey, isNot(contains('user-a')));
    expect(userBKey, isNot(contains('user-b')));
    expect(userAKey, startsWith('$paywallFeedbackLastShownStorageKeyPrefix:'));
  });

  test(
    'paywall feedback legacy storage key remains available for migration',
    () {
      expect(
        buildLegacyPaywallFeedbackLastShownStorageKey('user-a'),
        '$paywallFeedbackLastShownStorageKeyPrefix:user-a',
      );
    },
  );
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
