import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/features/profile/domain/notification_preferences.dart';

final notificationPreferencesStorageProvider =
    Provider<NotificationPreferencesStoragePort>((ref) {
      throw StateError(
        'NotificationPreferencesStoragePort is not bound. Add app overrides.',
      );
    });

abstract interface class NotificationPreferencesStoragePort {
  Future<NotificationPreferences> read({
    required String scope,
    required bool fallbackMarketingEmails,
  });
  Future<void> save({
    required String scope,
    required NotificationPreferences preferences,
  });
}
