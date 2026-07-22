import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:app_links/app_links.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:petmagic_mobile/core/auth/google_sign_in_adapter.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/profile/data/external_auth_repository.dart';
import 'package:petmagic_mobile/features/profile/data/profile_models.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'google auth keeps native failure and does not trigger browser fallback',
    () async {
      var launchCalls = 0;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
        ..httpClientAdapter = _FakeHttpClientAdapter((options) async {
          if (options.path == '/api/auth/external/google/mobile-config') {
            return ResponseBody.fromString(
              jsonEncode(const {
                'title': 'auth.external_not_configured',
                'detail': 'Google sign-in is not configured.',
              }),
              404,
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
              },
            );
          }

          throw StateError('Unexpected path: ${options.path}');
        });

      final repository = MobileExternalAuthRepository(
        dio: dio,
        sessionStorage: _InMemoryAuthSessionStorage(),
        appLinks: AppLinks(),
        launchUrlDelegate: (Uri uri, LaunchMode mode) async {
          launchCalls++;
          return false;
        },
      );

      await expectLater(
        repository.authenticate(ExternalAuthProvider.google),
        throwsA(
          isA<AppException>().having(
            (error) => error.message,
            'message',
            'auth.external_not_configured',
          ),
        ),
      );

      expect(launchCalls, 0);
    },
  );

  test(
    'native google auth maps connectivity failures to retryable copy',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
        ..httpClientAdapter = _FakeHttpClientAdapter((options) async {
          throw DioException.connectionError(
            requestOptions: options,
            reason: 'offline',
          );
        });

      final repository = MobileExternalAuthRepository(
        dio: dio,
        sessionStorage: _InMemoryAuthSessionStorage(),
        appLinks: AppLinks(),
      );

      await expectLater(
        repository.authenticate(ExternalAuthProvider.google),
        throwsA(
          isA<AppException>().having(
            (error) => error.message,
            'message',
            'network.unavailable',
          ),
        ),
      );
    },
  );

  test(
    'google auth continues to native picker when mobile config is forbidden',
    () async {
      var googleSignInCalls = 0;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
        ..httpClientAdapter = _FakeHttpClientAdapter((options) async {
          if (options.path == '/api/auth/external/google/mobile-config') {
            return ResponseBody.fromString(
              jsonEncode(const {
                'title': 'auth.forbidden',
                'detail': 'Forbidden',
              }),
              403,
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
              },
            );
          }

          throw StateError('Unexpected path: ${options.path}');
        });

      final repository = MobileExternalAuthRepository(
        dio: dio,
        sessionStorage: _InMemoryAuthSessionStorage(),
        appLinks: AppLinks(),
        googleSignInAdapter: _FakeGoogleSignInAdapter((_) async {
          googleSignInCalls++;
          throw const GoogleSignInException(
            code: GoogleSignInExceptionCode.canceled,
          );
        }),
      );

      await expectLater(
        repository.authenticate(ExternalAuthProvider.google),
        throwsA(
          isA<AppException>().having(
            (error) => error.message,
            'message',
            'auth.external_cancelled',
          ),
        ),
      );

      expect(googleSignInCalls, 1);
    },
  );

  test(
    'native google auth keeps google sign-in cancellation in native flow',
    () async {
      var nativeExchangeCalls = 0;
      var launchCalls = 0;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
        ..httpClientAdapter = _FakeHttpClientAdapter((options) async {
          if (options.path == '/api/auth/external/google/mobile-config') {
            return ResponseBody.fromString(
              jsonEncode(const {'serverClientId': 'server-client-id'}),
              200,
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
              },
            );
          }

          if (options.path == '/api/auth/external/google/native') {
            nativeExchangeCalls++;
          }

          throw StateError('Unexpected path: ${options.path}');
        });

      final repository = MobileExternalAuthRepository(
        dio: dio,
        sessionStorage: _InMemoryAuthSessionStorage(),
        appLinks: AppLinks(),
        launchUrlDelegate: (Uri uri, LaunchMode mode) async {
          launchCalls++;
          return false;
        },
        googleSignInAdapter: _FakeGoogleSignInAdapter(
          (_) async => throw const GoogleSignInException(
            code: GoogleSignInExceptionCode.canceled,
          ),
        ),
      );

      await expectLater(
        repository.authenticate(ExternalAuthProvider.google),
        throwsA(
          isA<AppException>().having(
            (error) => error.message,
            'message',
            'auth.external_cancelled',
          ),
        ),
      );

      expect(nativeExchangeCalls, 0);
      expect(launchCalls, 0);
    },
  );

  test(
    'native google auth does not exchange when google sign-in fails',
    () async {
      var nativeExchangeCalls = 0;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
        ..httpClientAdapter = _FakeHttpClientAdapter((options) async {
          if (options.path == '/api/auth/external/google/mobile-config') {
            return ResponseBody.fromString(
              jsonEncode(const {'serverClientId': 'server-client-id'}),
              200,
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
              },
            );
          }

          if (options.path == '/api/auth/external/google/native') {
            nativeExchangeCalls++;
          }

          throw StateError('Unexpected path: ${options.path}');
        });

      final repository = MobileExternalAuthRepository(
        dio: dio,
        sessionStorage: _InMemoryAuthSessionStorage(),
        appLinks: AppLinks(),
        googleSignInAdapter: _FakeGoogleSignInAdapter(
          (_) async => throw const GoogleSignInException(
            code: GoogleSignInExceptionCode.providerConfigurationError,
            description: 'sign-in failed',
          ),
        ),
      );

      await expectLater(
        repository.authenticate(ExternalAuthProvider.google),
        throwsA(
          isA<AppException>().having(
            (error) => error.message,
            'message',
            'auth.external_invalid',
          ),
        ),
      );

      expect(nativeExchangeCalls, 0);
    },
  );

  test(
    'google auth treats server client id changes as configuration errors',
    () async {
      final adapter = _ConfigurationLockedGoogleSignInAdapter();

      Dio createDio(String serverClientId) {
        return Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
          ..httpClientAdapter = _FakeHttpClientAdapter((options) async {
            if (options.path == '/api/auth/external/google/mobile-config') {
              return ResponseBody.fromString(
                jsonEncode({'serverClientId': serverClientId}),
                200,
                headers: {
                  Headers.contentTypeHeader: [Headers.jsonContentType],
                },
              );
            }

            throw StateError('Unexpected path: ${options.path}');
          });
      }

      final firstRepository = MobileExternalAuthRepository(
        dio: createDio('server-client-a'),
        sessionStorage: _InMemoryAuthSessionStorage(),
        appLinks: AppLinks(),
        googleSignInAdapter: adapter,
      );
      await firstRepository.clearSession(ExternalAuthProvider.google);

      await expectLater(
        firstRepository.authenticate(ExternalAuthProvider.google),
        throwsA(
          isA<AppException>().having(
            (error) => error.message,
            'message',
            'auth.external_cancelled',
          ),
        ),
      );

      final secondRepository = MobileExternalAuthRepository(
        dio: createDio('server-client-b'),
        sessionStorage: _InMemoryAuthSessionStorage(),
        appLinks: AppLinks(),
        googleSignInAdapter: adapter,
      );

      await expectLater(
        secondRepository.authenticate(ExternalAuthProvider.google),
        throwsA(
          isA<AppException>().having(
            (error) => error.message,
            'message',
            'auth.external_invalid',
          ),
        ),
      );

      expect(adapter.initializeCalls, ['server-client-a']);
    },
  );

  test(
    'external auth logs google sdk failures instead of swallowing them',
    () async {
      final source = await File(
        'lib/features/profile/data/external_auth_repository.dart',
      ).readAsString();

      expect(source, contains('AppLogger.warn('));
      expect(
        source,
        contains("operation: 'authenticate_native_google_sign_in'"),
      );
      expect(source, contains('has_description'));
      expect(source, contains('error.code.name'));
      expect(source, isNot(contains('} catch (_) {')));
    },
  );

  test(
    'browser callback error is allowlisted before reaching app state',
    () async {
      final callbacks = StreamController<Uri>();
      addTearDown(callbacks.close);
      final storage = _InMemoryAuthSessionStorage();
      await storage.save(_authSession());

      final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
        ..httpClientAdapter = _FakeHttpClientAdapter((options) async {
          if (options.path == '/api/auth/me/linked-accounts/Apple/prepare') {
            return ResponseBody.fromString(
              jsonEncode(const {'ticket': 'link-ticket'}),
              200,
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
              },
            );
          }

          throw StateError('Unexpected path: ${options.path}');
        });

      final repository = MobileExternalAuthRepository(
        dio: dio,
        sessionStorage: storage,
        appLinks: AppLinks(),
        uriLinkStream: callbacks.stream,
        launchUrlDelegate: (Uri uri, LaunchMode mode) async {
          scheduleMicrotask(() {
            callbacks.add(
              Uri.parse(
                'petmagic://auth/external?error='
                'Authorization%3A%20Bearer%20raw-token%20'
                'https%3A%2F%2Fcdn.petmagic.ai%2Ffile.jpg%3Fsignature%3Dsecret',
              ),
            );
          });
          return true;
        },
      );

      await expectLater(
        repository.link(ExternalAuthProvider.apple),
        throwsA(
          isA<AppException>()
              .having(
                (error) => error.message,
                'message',
                'auth.external_invalid',
              )
              .having(
                (error) => error.message,
                'raw token',
                isNot(contains('raw-token')),
              )
              .having(
                (error) => error.message,
                'signed url',
                isNot(contains('signature=secret')),
              ),
        ),
      );
    },
  );

  test(
    'browser link flow maps launcher exceptions to launch failure copy',
    () async {
      final storage = _InMemoryAuthSessionStorage();
      await storage.save(_authSession());

      final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
        ..httpClientAdapter = _FakeHttpClientAdapter((options) async {
          if (options.path == '/api/auth/me/linked-accounts/Apple/prepare') {
            return ResponseBody.fromString(
              jsonEncode(const {'ticket': 'link-ticket'}),
              200,
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
              },
            );
          }

          throw StateError('Unexpected path: ${options.path}');
        });

      final repository = MobileExternalAuthRepository(
        dio: dio,
        sessionStorage: storage,
        appLinks: AppLinks(),
        launchUrlDelegate: (Uri uri, LaunchMode mode) async {
          throw StateError('launcher unavailable');
        },
      );

      await expectLater(
        repository.link(ExternalAuthProvider.apple),
        throwsA(
          isA<AppException>().having(
            (error) => error.message,
            'message',
            'auth.external_launch_failed',
          ),
        ),
      );
    },
  );

  test(
    'native apple auth posts identity token and authorization code',
    () async {
      final storage = _InMemoryAuthSessionStorage();
      final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
        ..httpClientAdapter = _FakeHttpClientAdapter((options) async {
          expect(options.path, '/api/auth/apple');
          expect(options.data, {
            'identityToken': 'apple-identity-token',
            'authorizationCode': 'apple-auth-code',
          });

          return ResponseBody.fromString(
            jsonEncode(_authSessionJson()),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        });

      final repository = MobileExternalAuthRepository(
        dio: dio,
        sessionStorage: storage,
        appLinks: AppLinks(),
        appleSignInDelegate: () async {
          return const AuthorizationCredentialAppleID(
            userIdentifier: 'apple-user-1',
            givenName: null,
            familyName: null,
            authorizationCode: 'apple-auth-code',
            email: 'relay@privaterelay.appleid.com',
            identityToken: 'apple-identity-token',
            state: null,
          );
        },
      );

      final session = await repository.authenticate(ExternalAuthProvider.apple);

      expect(session.accessToken, 'access-token');
      expect((await storage.read())?.refreshToken, 'refresh-token');
    },
  );
}

class _InMemoryAuthSessionStorage extends AuthSessionStorage {
  _InMemoryAuthSessionStorage();

  AuthSession? _session;

  @override
  Future<AuthSession?> read() async => _session;

  @override
  Future<void> save(AuthSession session) async {
    _session = session;
  }

  @override
  Future<void> clear() async {
    _session = null;
  }
}

AuthSession _authSession() => AuthSession.fromJson(_authSessionJson());

Map<String, dynamic> _authSessionJson() {
  return {
    'accessToken': 'access-token',
    'refreshToken': 'refresh-token',
    'expiresAtUtc': DateTime.now()
        .add(const Duration(hours: 1))
        .toIso8601String(),
    'user': {
      'userId': 'user-1',
      'email': 'pet@example.com',
      'displayName': 'Pet Parent',
      'isPremium': false,
      'emailConfirmed': true,
      'termsOfUseAccepted': true,
      'privacyPolicyAccepted': true,
      'marketingEmailsEnabled': false,
      'roles': ['user'],
      'legalAcceptance': {
        'termsOfUseAccepted': true,
        'termsOfUseVersion': '2026-05-20',
        'termsOfUseAcceptedAtUtc': DateTime.now().toIso8601String(),
        'privacyPolicyAccepted': true,
        'privacyPolicyVersion': '2026-05-20',
        'privacyPolicyAcceptedAtUtc': DateTime.now().toIso8601String(),
        'currentTermsOfUseVersion': '2026-05-20',
        'currentPrivacyPolicyVersion': '2026-05-20',
        'requiresAcceptance': false,
      },
    },
  };
}

class _FakeHttpClientAdapter implements HttpClientAdapter {
  _FakeHttpClientAdapter(this._handler);

  final Future<ResponseBody> Function(RequestOptions options) _handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) {
    return _handler(options);
  }

  @override
  void close({bool force = false}) {}
}

class _FakeGoogleSignInAdapter implements GoogleSignInAdapter {
  _FakeGoogleSignInAdapter(this._authenticate);

  final Future<GoogleSignInCredential> Function(String? serverClientId)
  _authenticate;

  @override
  Future<GoogleSignInCredential> authenticate({String? serverClientId}) {
    return _authenticate(serverClientId);
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> signOut() async {}
}

class _ConfigurationLockedGoogleSignInAdapter implements GoogleSignInAdapter {
  final List<String?> initializeCalls = [];
  String? _serverClientId;
  bool _initialized = false;

  @override
  Future<GoogleSignInCredential> authenticate({String? serverClientId}) async {
    if (_initialized && _serverClientId != serverClientId) {
      throw const GoogleSignInConfigurationException();
    }
    if (!_initialized) {
      _initialized = true;
      _serverClientId = serverClientId;
      initializeCalls.add(serverClientId);
    }
    throw const GoogleSignInException(code: GoogleSignInExceptionCode.canceled);
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> signOut() async {}
}
