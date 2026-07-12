import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:petmagic_mobile/core/auth/auth_session.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';

abstract interface class AuthSessionStore {
  Future<AuthSession?> read();
  Future<void> save(AuthSession session);
  Future<void> clear();
}

final authSessionStorageProvider = Provider<AuthSessionStorage>((ref) {
  return AuthSessionStorage();
});

class AuthSessionStorage implements AuthSessionStore {
  AuthSessionStorage({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const sessionKey = 'petmagic_mobile_auth_session';
  static const _readTimeout = Duration(seconds: 5);
  static const _slowReadThreshold = Duration(milliseconds: 1200);

  final FlutterSecureStorage _secureStorage;

  @override
  Future<AuthSession?> read() async {
    final stopwatch = Stopwatch()..start();
    String? raw;
    try {
      raw = await _secureStorage.read(key: sessionKey).timeout(_readTimeout);
    } on TimeoutException catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'Startup',
        operation: 'auth_session_read_timeout',
        message: 'Secure storage read timed out during app startup',
        context: {'timeout_ms': _readTimeout.inMilliseconds},
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    } catch (error, stackTrace) {
      AppLogger.error(
        feature: 'Startup',
        operation: 'auth_session_read_failed',
        message: 'Secure storage read failed during app startup',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    } finally {
      stopwatch.stop();
      if (stopwatch.elapsed >= _slowReadThreshold) {
        AppLogger.warn(
          feature: 'Startup',
          operation: 'auth_session_read_slow',
          message: 'Secure storage read is slower than expected',
          context: {'elapsed_ms': stopwatch.elapsedMilliseconds},
        );
      }
    }

    if (raw == null || raw.isEmpty) return null;

    try {
      final session = AuthSession.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      if (!session.hasUsableTokens) {
        AppLogger.warn(
          feature: 'Auth.Session',
          operation: 'deserialize_invalid_tokens',
          message: 'Stored auth session is missing required tokens',
          context: {'raw_length': raw.length},
        );
        await _clearInvalidSession('deserialize_invalid_tokens_cleanup');
        return null;
      }
      return session;
    } catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'Auth.Session',
        operation: 'deserialize',
        message: 'Stored auth session could not be decoded',
        context: {'raw_length': raw.length},
        error: error,
        stackTrace: stackTrace,
      );
      await _clearInvalidSession('deserialize_cleanup');
      return null;
    }
  }

  @override
  Future<void> save(AuthSession session) async {
    if (!session.hasUsableTokens) {
      AppLogger.warn(
        feature: 'Auth.Session',
        operation: 'save_invalid_tokens',
        message: 'Refused to persist auth session without required tokens',
      );
      throw StateError('Auth session is missing required tokens.');
    }
    await _secureStorage.write(
      key: sessionKey,
      value: jsonEncode(session.toJson()),
    );
  }

  @override
  Future<void> clear() => _secureStorage.delete(key: sessionKey);

  Future<void> _clearInvalidSession(String operation) async {
    try {
      await clear();
    } catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'Auth.Session',
        operation: operation,
        message: 'Stored auth session cleanup failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
