export 'package:petmagic_mobile/features/profile/application/notification_preferences_port.dart'
    show
        NotificationPreferencesStoragePort,
        notificationPreferencesStorageProvider;
export 'package:petmagic_mobile/features/profile/domain/notification_preferences.dart';

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/features/profile/application/notification_preferences_port.dart';
import 'package:petmagic_mobile/features/profile/domain/notification_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesNotificationPreferencesStorageProvider =
    Provider<NotificationPreferencesStoragePort>(
      (ref) => NotificationPreferencesStorage(),
    );

class NotificationPreferencesStorage
    implements NotificationPreferencesStoragePort {
  static const _keyPrefix = 'petmagic_mobile_notification_preferences_v1_';
  static const _hashedKeyPrefix =
      'petmagic_mobile_notification_preferences_v2_';
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  @override
  Future<NotificationPreferences> read({
    required String scope,
    required bool fallbackMarketingEmails,
  }) async {
    final storageKey = _keyForScope(scope);
    final legacyStorageKey = _legacyKeyForScope(scope);
    var rawValue = await _preferences.getString(storageKey);
    final shouldMigrateLegacy = rawValue == null || rawValue.isEmpty;
    if (shouldMigrateLegacy) {
      rawValue = await _preferences.getString(legacyStorageKey);
    }

    if (rawValue == null || rawValue.isEmpty) {
      return NotificationPreferences.defaults().copyWith(
        emailOffersAndDiscounts: fallbackMarketingEmails,
      );
    }

    try {
      final decoded = jsonDecode(rawValue);
      if (decoded is! Map<String, dynamic>) {
        await _clearStoredPreferences(
          storageKey: storageKey,
          legacyStorageKey: legacyStorageKey,
        );
        return NotificationPreferences.defaults().copyWith(
          emailOffersAndDiscounts: fallbackMarketingEmails,
        );
      }

      final preferences = _mapNotificationPreferences(
        decoded,
        fallbackMarketingEmails: fallbackMarketingEmails,
      );
      if (shouldMigrateLegacy) {
        await save(scope: scope, preferences: preferences);
      } else {
        await _preferences.remove(legacyStorageKey);
      }

      return preferences;
    } catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'Profile.Notifications',
        operation: 'read_preferences',
        message: 'Notification preferences read failed',
        context: {'hasScope': scope.trim().isNotEmpty},
        error: error,
        stackTrace: stackTrace,
      );
      await _clearStoredPreferences(
        storageKey: storageKey,
        legacyStorageKey: legacyStorageKey,
      );
      return NotificationPreferences.defaults().copyWith(
        emailOffersAndDiscounts: fallbackMarketingEmails,
      );
    }
  }

  @override
  Future<void> save({
    required String scope,
    required NotificationPreferences preferences,
  }) async {
    await _preferences.setString(
      _keyForScope(scope),
      jsonEncode(_mapNotificationPreferencesToJson(preferences)),
    );
    await _preferences.remove(_legacyKeyForScope(scope));
  }

  Future<void> _clearStoredPreferences({
    required String storageKey,
    required String legacyStorageKey,
  }) async {
    await Future.wait<void>([
      _preferences.remove(storageKey),
      _preferences.remove(legacyStorageKey),
    ]);
  }

  static String _keyForScope(String scope) {
    final normalizedScope = scope.trim().toLowerCase();
    final digest = sha256.convert(utf8.encode(normalizedScope));
    return '$_hashedKeyPrefix$digest';
  }

  static String _legacyKeyForScope(String scope) {
    return '$_keyPrefix$scope';
  }
}

NotificationPreferences _mapNotificationPreferences(
  Map<String, dynamic> json, {
  required bool fallbackMarketingEmails,
}) {
  return NotificationPreferences(
    pushPhotoReady: json['pushPhotoReady'] as bool? ?? true,
    pushVideoReady: json['pushVideoReady'] as bool? ?? true,
    pushGenerationErrors: json['pushGenerationErrors'] as bool? ?? true,
    pushReminders: json['pushReminders'] as bool? ?? true,
    pushNewTemplates: json['pushNewTemplates'] as bool? ?? true,
    pushPurchasesAndSubscriptions:
        json['pushPurchasesAndSubscriptions'] as bool? ?? true,
    emailOffersAndDiscounts:
        json['emailOffersAndDiscounts'] as bool? ?? fallbackMarketingEmails,
    emailNews: json['emailNews'] as bool? ?? false,
    emailAccountAlerts: json['emailAccountAlerts'] as bool? ?? true,
  );
}

Map<String, dynamic> _mapNotificationPreferencesToJson(
  NotificationPreferences preferences,
) => {
  'pushPhotoReady': preferences.pushPhotoReady,
  'pushVideoReady': preferences.pushVideoReady,
  'pushGenerationErrors': preferences.pushGenerationErrors,
  'pushReminders': preferences.pushReminders,
  'pushNewTemplates': preferences.pushNewTemplates,
  'pushPurchasesAndSubscriptions': preferences.pushPurchasesAndSubscriptions,
  'emailOffersAndDiscounts': preferences.emailOffersAndDiscounts,
  'emailNews': preferences.emailNews,
  'emailAccountAlerts': preferences.emailAccountAlerts,
};
