import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/features/profile/data/profile_models.dart';

final authSessionStorageProvider = Provider<AuthSessionStorage>((ref) {
  return AuthSessionStorage();
});

class AuthSessionStorage {
  AuthSessionStorage({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const sessionKey = 'petmagic_mobile_auth_session';
  static const _readTimeout = Duration(seconds: 5);
  static const _slowReadThreshold = Duration(milliseconds: 1200);

  final FlutterSecureStorage _secureStorage;

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

    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final session = AuthSession.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      if (!session.hasUsableTokens) {
        AppLogger.warn(
          feature: 'Profile.AuthSession',
          operation: 'deserialize_invalid_tokens',
          message: 'Stored auth session is missing required tokens',
          context: {'raw_length': raw.length},
        );
        await clear();
        return null;
      }

      return session;
    } catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'Profile.AuthSession',
        operation: 'deserialize',
        message: 'Stored auth session could not be decoded',
        context: {'raw_length': raw.length},
        error: error,
        stackTrace: stackTrace,
      );
      await clear();
      return null;
    }
  }

  Future<void> save(AuthSession session) async {
    if (!session.hasUsableTokens) {
      AppLogger.warn(
        feature: 'Profile.AuthSession',
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

  Future<void> clear() async {
    await _secureStorage.delete(key: sessionKey);
  }
}
