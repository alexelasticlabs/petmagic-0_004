import 'dart:convert';

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
    } catch (_) {
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
