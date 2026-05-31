import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/features/profile/data/profile_models.dart';

final authSessionStorageProvider = Provider<AuthSessionStorage>((ref) {
  return AuthSessionStorage();
});

class AuthSessionStorage {
  AuthSessionStorage({FlutterSecureStorage? secureStorage})
    : _secureStorage =
          secureStorage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  static const sessionKey = 'petmagic_mobile_auth_session';
  static const _readTimeout = Duration(seconds: 5);
  static const _slowReadThreshold = Duration(milliseconds: 1200);

  final FlutterSecureStorage _secureStorage;

  Future<AuthSession?> read() async {
    final stopwatch = Stopwatch()..start();
    String? raw;
    try {
      raw = await _secureStorage
          .read(key: sessionKey)
          .timeout(_readTimeout);
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
      return AuthSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (error, stackTrace) {
      developer.Timeline.instantSync(
        'petmagic.profile.auth_session.error',
        arguments: {'stage': 'deserialize', 'raw_length': raw.length},
      );
      developer.log(
        'AuthSessionStorage::deserialize failed',
        name: 'PetMagic.Profile.AuthSession',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<void> save(AuthSession session) async {
    await _secureStorage.write(key: sessionKey, value: jsonEncode(session.toJson()));
  }

  Future<void> clear() async {
    await _secureStorage.delete(key: sessionKey);
  }
}
