import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final guestLaunchStorageProvider = Provider<GuestLaunchStorage>((ref) {
  return GuestLaunchStorage();
});

class GuestLaunchStorage {
  static const _onboardingSeenKey = 'petmagic_mobile_guest_onboarding_seen';

  Future<bool> readOnboardingSeen() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_onboardingSeenKey) ?? false;
  }

  Future<void> saveOnboardingSeen(bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_onboardingSeenKey, value);
  }
}