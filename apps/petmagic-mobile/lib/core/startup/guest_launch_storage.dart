import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final guestLaunchStorageProvider = Provider<GuestLaunchStorage>((ref) {
  return GuestLaunchStorage();
});

class GuestLaunchStorage {
  static const _onboardingSeenKey = 'petmagic_mobile_guest_onboarding_seen';
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  Future<bool> readOnboardingSeen() async {
    return await _preferences.getBool(_onboardingSeenKey) ?? false;
  }

  Future<void> saveOnboardingSeen(bool value) async {
    await _preferences.setBool(_onboardingSeenKey, value);
  }
}
