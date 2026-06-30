import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/auth/auth_session_coordinator.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/profile/data/profile_models.dart';

void main() {
  test('authorizedRequest retries once after successful refresh', () async {
    var refreshCalls = 0;
    final dio = Dio()
      ..httpClientAdapter = _FakeHttpClientAdapter((options) async {
        if (options.path == '/api/auth/refresh') {
          refreshCalls++;
          return ResponseBody.fromString(
            jsonEncode(_sessionJson(accessToken: 'new-access')),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }

        throw StateError('Unexpected path: ${options.path}');
      });

    final storage = _InMemoryAuthSessionStorage(
      session: _session(
        accessToken: 'old-access',
        expiresAtUtc: DateTime.now().toUtc().add(const Duration(hours: 1)),
      ),
    );
    final coordinator = AuthSessionCoordinator(
      dio: dio,
      sessionStorage: storage,
    );

    var attempt = 0;
    final response = await coordinator.authorizedRequest<String>(
      request: (session) async {
        attempt++;
        if (attempt == 1) {
          throw _unauthorizedDioException();
        }

        return Response<String>(
          requestOptions: RequestOptions(path: '/api/protected'),
          statusCode: 200,
          data: session.accessToken,
        );
      },
      mapError: _mapDioException,
      requestFailedMessage: 'request.failed',
      sessionExpiredMessage: 'session.expired',
    );

    expect(response.data, 'new-access');
    expect(refreshCalls, 1);
    expect(storage.savedSessions, hasLength(1));
    expect(storage.savedSessions.single.accessToken, 'new-access');
  });

  test(
    'authorizedRequest retries once after forbidden stale session',
    () async {
      var refreshCalls = 0;
      final dio = Dio()
        ..httpClientAdapter = _FakeHttpClientAdapter((options) async {
          if (options.path == '/api/auth/refresh') {
            refreshCalls++;
            return ResponseBody.fromString(
              jsonEncode(_sessionJson(accessToken: 'refreshed-access')),
              200,
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
              },
            );
          }

          throw StateError('Unexpected path: ${options.path}');
        });

      final storage = _InMemoryAuthSessionStorage(
        session: _session(
          accessToken: 'stale-access',
          expiresAtUtc: DateTime.now().toUtc().add(const Duration(hours: 1)),
        ),
      );
      final coordinator = AuthSessionCoordinator(
        dio: dio,
        sessionStorage: storage,
      );

      var attempt = 0;
      final response = await coordinator.authorizedRequest<String>(
        request: (session) async {
          attempt++;
          if (attempt == 1) {
            throw _forbiddenDioException();
          }

          return Response<String>(
            requestOptions: RequestOptions(path: '/api/protected'),
            statusCode: 200,
            data: session.accessToken,
          );
        },
        mapError: _mapDioException,
        requestFailedMessage: 'request.failed',
        sessionExpiredMessage: 'session.expired',
      );

      expect(response.data, 'refreshed-access');
      expect(refreshCalls, 1);
      expect(storage.savedSessions, hasLength(1));
      expect(storage.savedSessions.single.accessToken, 'refreshed-access');
    },
  );

  test('requireValidSession coalesces concurrent refresh requests', () async {
    var refreshCalls = 0;
    final unblockRefresh = Completer<void>();

    final dio = Dio()
      ..httpClientAdapter = _FakeHttpClientAdapter((options) async {
        if (options.path == '/api/auth/refresh') {
          refreshCalls++;
          await unblockRefresh.future;
          return ResponseBody.fromString(
            jsonEncode(_sessionJson(accessToken: 'new-access')),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }

        throw StateError('Unexpected path: ${options.path}');
      });

    final storage = _InMemoryAuthSessionStorage(
      session: _session(
        accessToken: 'expired-access',
        expiresAtUtc: DateTime.now().toUtc().subtract(
          const Duration(minutes: 1),
        ),
      ),
    );
    final coordinator = AuthSessionCoordinator(
      dio: dio,
      sessionStorage: storage,
    );

    final firstFuture = coordinator.requireValidSession(
      mapError: _mapDioException,
      sessionExpiredMessage: 'session.expired',
    );
    final secondFuture = coordinator.requireValidSession(
      mapError: _mapDioException,
      sessionExpiredMessage: 'session.expired',
    );

    unblockRefresh.complete();

    final first = await firstFuture;
    final second = await secondFuture;

    expect(first.accessToken, 'new-access');
    expect(second.accessToken, 'new-access');
    expect(refreshCalls, 1);
    expect(storage.clearCalls, 0);
  });

  test(
    'authorizedRequest can disable transient retry for non-idempotent calls',
    () async {
      final storage = _InMemoryAuthSessionStorage(
        session: _session(
          accessToken: 'access',
          expiresAtUtc: DateTime.now().toUtc().add(const Duration(hours: 1)),
        ),
      );
      final coordinator = AuthSessionCoordinator(
        dio: Dio(),
        sessionStorage: storage,
      );

      var attempts = 0;
      await expectLater(
        coordinator.authorizedRequest<String>(
          request: (_) async {
            attempts++;
            throw _serverUnavailableDioException();
          },
          mapError: _mapDioException,
          requestFailedMessage: 'request.failed',
          transientRetryAttempts: 1,
        ),
        throwsA(isA<AppException>()),
      );

      expect(attempts, 1);
    },
  );

  test('authorizedRequest preserves request cancellation', () async {
    final storage = _InMemoryAuthSessionStorage(
      session: _session(
        accessToken: 'access',
        expiresAtUtc: DateTime.now().toUtc().add(const Duration(hours: 1)),
      ),
    );
    final coordinator = AuthSessionCoordinator(
      dio: Dio(),
      sessionStorage: storage,
    );

    await expectLater(
      coordinator.authorizedRequest<String>(
        request: (_) async {
          throw DioException.requestCancelled(
            requestOptions: RequestOptions(path: '/api/protected'),
            reason: 'test_cancelled',
          );
        },
        mapError: _mapDioException,
        requestFailedMessage: 'request.failed',
      ),
      throwsA(isA<RequestCancelledException>()),
    );
  });

  test('authorizedRequest clears stored session with empty tokens', () async {
    final storage = _InMemoryAuthSessionStorage(
      session: _session(
        accessToken: '',
        refreshToken: '',
        expiresAtUtc: DateTime.now().toUtc().add(const Duration(hours: 1)),
      ),
    );
    final coordinator = AuthSessionCoordinator(
      dio: Dio(),
      sessionStorage: storage,
    );

    await expectLater(
      coordinator.authorizedRequest<String>(
        request: (_) async => Response<String>(
          requestOptions: RequestOptions(path: '/api/protected'),
          statusCode: 200,
        ),
        mapError: _mapDioException,
        requestFailedMessage: 'request.failed',
      ),
      throwsA(
        isA<AppException>().having(
          (error) => error.statusCode,
          'statusCode',
          401,
        ),
      ),
    );

    expect(storage.clearCalls, 1);
  });

  test(
    'refresh response with empty tokens clears session and is not saved',
    () async {
      var refreshCalls = 0;
      final dio = Dio()
        ..httpClientAdapter = _FakeHttpClientAdapter((options) async {
          if (options.path == '/api/auth/refresh') {
            refreshCalls++;
            return ResponseBody.fromString(
              jsonEncode(_sessionJson(accessToken: '', refreshToken: '')),
              200,
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
              },
            );
          }

          throw StateError('Unexpected path: ${options.path}');
        });

      final storage = _InMemoryAuthSessionStorage(
        session: _session(
          accessToken: 'expired-access',
          refreshToken: 'refresh-token',
          expiresAtUtc: DateTime.now().toUtc().subtract(
            const Duration(minutes: 1),
          ),
        ),
      );
      final coordinator = AuthSessionCoordinator(
        dio: dio,
        sessionStorage: storage,
      );

      await expectLater(
        coordinator.requireValidSession(
          mapError: _mapDioException,
          sessionExpiredMessage: 'session.expired',
        ),
        throwsA(isA<AppException>()),
      );

      expect(refreshCalls, 1);
      expect(storage.savedSessions, isEmpty);
      expect(storage.clearCalls, 1);
    },
  );

  test('refresh cancellation is preserved without clearing session', () async {
    var refreshCalls = 0;
    final dio = Dio()
      ..httpClientAdapter = _FakeHttpClientAdapter((options) async {
        if (options.path == '/api/auth/refresh') {
          refreshCalls++;
          throw DioException.requestCancelled(
            requestOptions: options,
            reason: 'refresh_cancelled',
          );
        }

        throw StateError('Unexpected path: ${options.path}');
      });

    final storage = _InMemoryAuthSessionStorage(
      session: _session(
        accessToken: 'expired-access',
        refreshToken: 'refresh-token',
        expiresAtUtc: DateTime.now().toUtc().subtract(
          const Duration(minutes: 1),
        ),
      ),
    );
    final coordinator = AuthSessionCoordinator(
      dio: dio,
      sessionStorage: storage,
    );

    await expectLater(
      coordinator.requireValidSession(
        mapError: _mapDioException,
        sessionExpiredMessage: 'session.expired',
      ),
      throwsA(isA<RequestCancelledException>()),
    );

    expect(refreshCalls, 1);
    expect(storage.clearCalls, 0);
    expect(storage.savedSessions, isEmpty);
  });
}

AppException _mapDioException(
  DioException error, {
  required String fallbackMessage,
}) {
  return AppException(
    fallbackMessage,
    statusCode: error.response?.statusCode,
    cause: error,
  );
}

DioException _unauthorizedDioException() {
  final requestOptions = RequestOptions(path: '/api/protected');
  return DioException.badResponse(
    statusCode: 401,
    requestOptions: requestOptions,
    response: Response<Map<String, Object?>>(
      requestOptions: requestOptions,
      statusCode: 401,
      data: const {'title': 'Unauthorized'},
    ),
  );
}

DioException _serverUnavailableDioException() {
  final requestOptions = RequestOptions(path: '/api/protected');
  return DioException.badResponse(
    statusCode: 503,
    requestOptions: requestOptions,
    response: Response<Map<String, Object?>>(
      requestOptions: requestOptions,
      statusCode: 503,
      data: const {'title': 'ServiceUnavailable'},
    ),
  );
}

DioException _forbiddenDioException() {
  final requestOptions = RequestOptions(path: '/api/protected');
  return DioException.badResponse(
    statusCode: 403,
    requestOptions: requestOptions,
    response: Response<Map<String, Object?>>(
      requestOptions: requestOptions,
      statusCode: 403,
      data: const {'title': 'Forbidden'},
    ),
  );
}

Map<String, Object?> _sessionJson({
  required String accessToken,
  String refreshToken = 'refresh-token',
}) {
  return {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'expiresAtUtc': DateTime.now()
        .toUtc()
        .add(const Duration(hours: 6))
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
      'legalAcceptance': {
        'termsOfUseAccepted': true,
        'termsOfUseAcceptedVersion': '2026-05-22',
        'termsOfUseAcceptedAtUtc': null,
        'privacyPolicyAccepted': true,
        'privacyPolicyAcceptedVersion': '2026-05-22',
        'privacyPolicyAcceptedAtUtc': null,
        'currentTermsOfUseVersion': '2026-05-22',
        'currentPrivacyPolicyVersion': '2026-05-22',
        'requiresAcceptance': false,
      },
      'roles': ['user'],
      'avatar': null,
    },
  };
}

AuthSession _session({
  required String accessToken,
  String refreshToken = 'refresh-token',
  required DateTime expiresAtUtc,
}) {
  return AuthSession(
    accessToken: accessToken,
    refreshToken: refreshToken,
    expiresAtUtc: expiresAtUtc,
    user: const MobileUserProfile(
      userId: 'user-1',
      email: 'pet@example.com',
      displayName: 'Pet Parent',
      isPremium: false,
      emailConfirmed: true,
      termsOfUseAccepted: true,
      privacyPolicyAccepted: true,
      marketingEmailsEnabled: false,
      legalAcceptance: MobileLegalAcceptanceStatus(
        termsOfUseAccepted: true,
        termsOfUseAcceptedVersion: '2026-05-22',
        termsOfUseAcceptedAtUtc: null,
        privacyPolicyAccepted: true,
        privacyPolicyAcceptedVersion: '2026-05-22',
        privacyPolicyAcceptedAtUtc: null,
        currentTermsOfUseVersion: '2026-05-22',
        currentPrivacyPolicyVersion: '2026-05-22',
        requiresAcceptance: false,
      ),
      roles: ['user'],
      avatar: null,
    ),
  );
}

class _InMemoryAuthSessionStorage extends AuthSessionStorage {
  _InMemoryAuthSessionStorage({AuthSession? session}) : _session = session;

  AuthSession? _session;
  final List<AuthSession> savedSessions = <AuthSession>[];
  int clearCalls = 0;

  @override
  Future<AuthSession?> read() async => _session;

  @override
  Future<void> save(AuthSession session) async {
    _session = session;
    savedSessions.add(session);
  }

  @override
  Future<void> clear() async {
    _session = null;
    clearCalls++;
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
