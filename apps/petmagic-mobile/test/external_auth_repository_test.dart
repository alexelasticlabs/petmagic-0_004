import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:app_links/app_links.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/profile/data/external_auth_repository.dart';
import 'package:petmagic_mobile/features/profile/data/profile_models.dart';
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
    'browser callback error is allowlisted before reaching app state',
    () async {
      final callbacks = StreamController<Uri>();
      addTearDown(callbacks.close);

      final dio = Dio(BaseOptions(baseUrl: 'https://api.petmagic.test'))
        ..httpClientAdapter = _FakeHttpClientAdapter((options) async {
          throw StateError('Unexpected path: ${options.path}');
        });

      final repository = MobileExternalAuthRepository(
        dio: dio,
        sessionStorage: _InMemoryAuthSessionStorage(),
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
        repository.authenticate(ExternalAuthProvider.apple),
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
