import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

  final FlutterSecureStorage _secureStorage;

  Future<AuthSession?> read() async {
    final raw = await _secureStorage.read(key: sessionKey);
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
