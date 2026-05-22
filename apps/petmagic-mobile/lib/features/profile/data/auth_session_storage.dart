import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:petmagic_mobile/features/profile/data/profile_models.dart';

final authSessionStorageProvider = Provider<AuthSessionStorage>((ref) {
  return AuthSessionStorage();
});

class AuthSessionStorage {
  static const _sessionKey = 'petmagic_mobile_auth_session';

  Future<AuthSession?> read() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_sessionKey);
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
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_sessionKey, jsonEncode(session.toJson()));
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_sessionKey);
  }
}
