import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/network/dio_provider.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/profile/data/profile_models.dart';

typedef DioExceptionToAppException =
    AppException Function(
      DioException error, {
      required String fallbackMessage,
    });

final authSessionCoordinatorProvider = Provider<AuthSessionCoordinator>((ref) {
  return AuthSessionCoordinator(
    dio: ref.watch(dioProvider),
    sessionStorage: ref.watch(authSessionStorageProvider),
  );
});

class AuthSessionCoordinator {
  static const int _requestTransientRetryAttempts = 2;
  static const int _refreshTransientRetryAttempts = 3;

  AuthSessionCoordinator({
    required Dio dio,
    required AuthSessionStorage sessionStorage,
  }) : _dio = dio,
       _sessionStorage = sessionStorage;

  final Dio _dio;
  final AuthSessionStorage _sessionStorage;

  Completer<AuthSession>? _refreshInFlight;

  Future<Response<T>> authorizedRequest<T>({
    required Future<Response<T>> Function(AuthSession session) request,
    required DioExceptionToAppException mapError,
    required String requestFailedMessage,
    String unauthorizedMessage = 'auth.sign_in_required',
    String sessionExpiredMessage = 'auth.session_expired',
  }) async {
    final initialSession = await _sessionStorage.read();
    if (initialSession == null) {
      throw AppException(unauthorizedMessage, statusCode: 401);
    }

    try {
      return await _executeWithTransientRetry(
        operation: () => request(initialSession),
        maxAttempts: _requestTransientRetryAttempts,
      );
    } on DioException catch (error) {
      if (error.response?.statusCode != 401) {
        throw mapError(error, fallbackMessage: requestFailedMessage);
      }
    }

    final refreshedSession = await _refreshSessionWithLock(
      refreshToken: initialSession.refreshToken,
      mapError: mapError,
      sessionExpiredMessage: sessionExpiredMessage,
    );

    try {
      return await _executeWithTransientRetry(
        operation: () => request(refreshedSession),
        maxAttempts: _requestTransientRetryAttempts,
      );
    } on DioException catch (error) {
      throw mapError(error, fallbackMessage: requestFailedMessage);
    }
  }

  Future<AuthSession> requireValidSession({
    required DioExceptionToAppException mapError,
    String unauthorizedMessage = 'auth.sign_in_required',
    String sessionExpiredMessage = 'auth.session_expired',
  }) async {
    final session = await _sessionStorage.read();
    if (session == null) {
      throw AppException(unauthorizedMessage, statusCode: 401);
    }

    if (session.expiresAtUtc.isAfter(DateTime.now().toUtc())) {
      return session;
    }

    return _refreshSessionWithLock(
      refreshToken: session.refreshToken,
      mapError: mapError,
      sessionExpiredMessage: sessionExpiredMessage,
    );
  }

  Future<AuthSession> _refreshSessionWithLock({
    required String refreshToken,
    required DioExceptionToAppException mapError,
    required String sessionExpiredMessage,
  }) async {
    final inFlight = _refreshInFlight;
    if (inFlight != null) {
      return inFlight.future;
    }

    final completer = Completer<AuthSession>();
    _refreshInFlight = completer;

    try {
      final response = await _executeWithTransientRetry(
        operation: () => _dio.post<Map<String, dynamic>>(
          '/api/auth/refresh',
          data: {'refreshToken': refreshToken},
        ),
        maxAttempts: _refreshTransientRetryAttempts,
      );

      final refreshed = AuthSession.fromJson(response.data ?? const {});
      await _sessionStorage.save(refreshed);
      completer.complete(refreshed);
      return refreshed;
    } on DioException catch (error, stackTrace) {
      if (_shouldInvalidateSessionForRefreshError(error)) {
        await _sessionStorage.clear();
      }
      final mapped = mapError(error, fallbackMessage: sessionExpiredMessage);
      completer.completeError(mapped, stackTrace);
      throw mapped;
    } catch (error, stackTrace) {
      final mapped = AppException(sessionExpiredMessage, cause: error);
      completer.completeError(mapped, stackTrace);
      throw mapped;
    } finally {
      if (identical(_refreshInFlight, completer)) {
        _refreshInFlight = null;
      }
    }
  }

  bool _shouldInvalidateSessionForRefreshError(DioException error) {
    final statusCode = error.response?.statusCode;
    if (statusCode == null) {
      return false;
    }

    return statusCode == 400 || statusCode == 401 || statusCode == 403;
  }

  Future<T> _executeWithTransientRetry<T>({
    required Future<T> Function() operation,
    required int maxAttempts,
  }) async {
    var attempt = 0;
    DioException? lastError;

    while (attempt < maxAttempts) {
      try {
        return await operation();
      } on DioException catch (error) {
        lastError = error;
        attempt += 1;

        if (!_isTransientDioFailure(error) || attempt >= maxAttempts) {
          rethrow;
        }

        await Future<void>.delayed(_retryDelayForAttempt(attempt));
      }
    }

    throw lastError ?? DioException(requestOptions: RequestOptions(path: ''));
  }

  bool _isTransientDioFailure(DioException error) {
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return true;
    }

    final statusCode = error.response?.statusCode;
    return statusCode == 429 ||
        statusCode == 500 ||
        statusCode == 502 ||
        statusCode == 503 ||
        statusCode == 504;
  }

  Duration _retryDelayForAttempt(int attempt) {
    final clampedAttempt = attempt.clamp(1, 4);
    return Duration(milliseconds: 250 * (1 << (clampedAttempt - 1)));
  }
}
