import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/profile/data/profile_repository.dart';

void main() {
  test(
    'verifyEmailCode saves returned auth session in secure storage',
    () async {
      final storage = _MemoryAuthSessionStorage();
      final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              expect(options.path, '/api/auth/verify-email-code');
              expect(options.data, {
                'email': 'pet@example.com',
                'code': '123456',
              });
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: const {
                    'accessToken': 'access-token',
                    'refreshToken': 'refresh-token',
                    'expiresAtUtc': '2030-01-01T00:00:00Z',
                    'user': {
                      'userId': 'user-1',
                      'email': 'pet@example.com',
                      'displayName': 'Pet Parent',
                      'isPremium': false,
                      'emailConfirmed': true,
                      'termsOfUseAccepted': true,
                      'privacyPolicyAccepted': true,
                      'marketingEmailsEnabled': true,
                      'legalAcceptance': {
                        'termsOfUseAccepted': true,
                        'termsOfUseAcceptedVersion': '2026-05-20',
                        'privacyPolicyAccepted': true,
                        'privacyPolicyAcceptedVersion': '2026-05-20',
                        'currentTermsOfUseVersion': '2026-05-20',
                        'currentPrivacyPolicyVersion': '2026-05-20',
                        'requiresAcceptance': false,
                      },
                      'roles': ['User'],
                    },
                  },
                ),
              );
            },
          ),
        );
      final repository = ProfileRepository(dio: dio, sessionStorage: storage);

      final session = await repository.verifyEmailCode(
        email: ' pet@example.com ',
        code: ' 123456 ',
      );

      expect(session.accessToken, 'access-token');
      expect(session.user.emailConfirmed, isTrue);
      expect(storage.savedSession?.refreshToken, 'refresh-token');
      expect(storage.savedSession?.user.marketingEmailsEnabled, isTrue);
    },
  );
}

class _MemoryAuthSessionStorage extends AuthSessionStorage {
  AuthSession? savedSession;

  @override
  Future<AuthSession?> read() async => savedSession;

  @override
  Future<void> save(AuthSession session) async {
    savedSession = session;
  }

  @override
  Future<void> clear() async {
    savedSession = null;
  }
}
