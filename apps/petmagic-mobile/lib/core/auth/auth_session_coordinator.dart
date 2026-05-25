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
    var session = await _sessionStorage.read();
    if (session == null) {
      throw AppException(unauthorizedMessage, statusCode: 401);
    }

    try {
      return await request(session);
    } on DioException catch (error) {
      if (error.response?.statusCode != 401) {
        throw mapError(error, fallbackMessage: requestFailedMessage);
      }
    }

    session = await _refreshSessionWithLock(
      refreshToken: session.refreshToken,
      mapError: mapError,
      sessionExpiredMessage: sessionExpiredMessage,
    );

    try {
      return await request(session);
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
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/auth/refresh',
        data: {'refreshToken': refreshToken},
      );

      final refreshed = AuthSession.fromJson(response.data ?? const {});
      await _sessionStorage.save(refreshed);
      completer.complete(refreshed);
      return refreshed;
    } on DioException catch (error, stackTrace) {
      await _sessionStorage.clear();
      final mapped = mapError(error, fallbackMessage: sessionExpiredMessage);
      completer.completeError(mapped, stackTrace);
      throw mapped;
    } catch (error, stackTrace) {
      await _sessionStorage.clear();
      final mapped = AppException(sessionExpiredMessage, cause: error);
      completer.completeError(mapped, stackTrace);
      throw mapped;
    } finally {
      if (identical(_refreshInFlight, completer)) {
        _refreshInFlight = null;
      }
    }
  }
}
