import 'dart:convert';
import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';

class NotificationPreferences {
  const NotificationPreferences({
    required this.pushPhotoReady,
    required this.pushVideoReady,
    required this.pushGenerationErrors,
    required this.pushReminders,
    required this.pushNewTemplates,
    required this.pushPurchasesAndSubscriptions,
    required this.emailOffersAndDiscounts,
    required this.emailNews,
    required this.emailAccountAlerts,
  });

  const NotificationPreferences.defaults()
    : this(
        pushPhotoReady: true,
        pushVideoReady: true,
        pushGenerationErrors: true,
        pushReminders: true,
        pushNewTemplates: true,
        pushPurchasesAndSubscriptions: true,
        emailOffersAndDiscounts: false,
        emailNews: false,
        emailAccountAlerts: true,
      );

  final bool pushPhotoReady;
  final bool pushVideoReady;
  final bool pushGenerationErrors;
  final bool pushReminders;
  final bool pushNewTemplates;
  final bool pushPurchasesAndSubscriptions;
  final bool emailOffersAndDiscounts;
  final bool emailNews;
  final bool emailAccountAlerts;

  NotificationPreferences copyWith({
    bool? pushPhotoReady,
    bool? pushVideoReady,
    bool? pushGenerationErrors,
    bool? pushReminders,
    bool? pushNewTemplates,
    bool? pushPurchasesAndSubscriptions,
    bool? emailOffersAndDiscounts,
    bool? emailNews,
    bool? emailAccountAlerts,
  }) {
    return NotificationPreferences(
      pushPhotoReady: pushPhotoReady ?? this.pushPhotoReady,
      pushVideoReady: pushVideoReady ?? this.pushVideoReady,
      pushGenerationErrors: pushGenerationErrors ?? this.pushGenerationErrors,
      pushReminders: pushReminders ?? this.pushReminders,
      pushNewTemplates: pushNewTemplates ?? this.pushNewTemplates,
      pushPurchasesAndSubscriptions:
          pushPurchasesAndSubscriptions ?? this.pushPurchasesAndSubscriptions,
      emailOffersAndDiscounts:
          emailOffersAndDiscounts ?? this.emailOffersAndDiscounts,
      emailNews: emailNews ?? this.emailNews,
      emailAccountAlerts: emailAccountAlerts ?? this.emailAccountAlerts,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pushPhotoReady': pushPhotoReady,
      'pushVideoReady': pushVideoReady,
      'pushGenerationErrors': pushGenerationErrors,
      'pushReminders': pushReminders,
      'pushNewTemplates': pushNewTemplates,
      'pushPurchasesAndSubscriptions': pushPurchasesAndSubscriptions,
      'emailOffersAndDiscounts': emailOffersAndDiscounts,
      'emailNews': emailNews,
      'emailAccountAlerts': emailAccountAlerts,
    };
  }

  static NotificationPreferences fromJson(
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
}

class NotificationPreferencesStorage {
  static const _keyPrefix = 'petmagic_mobile_notification_preferences_v1_';

  Future<NotificationPreferences> read({
    required String scope,
    required bool fallbackMarketingEmails,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final rawValue = preferences.getString('$_keyPrefix$scope');

    if (rawValue == null || rawValue.isEmpty) {
      return NotificationPreferences.defaults().copyWith(
        emailOffersAndDiscounts: fallbackMarketingEmails,
      );
    }

    try {
      final decoded = jsonDecode(rawValue);
      if (decoded is! Map<String, dynamic>) {
        return NotificationPreferences.defaults().copyWith(
          emailOffersAndDiscounts: fallbackMarketingEmails,
        );
      }

      return NotificationPreferences.fromJson(
        decoded,
        fallbackMarketingEmails: fallbackMarketingEmails,
      );
    } catch (error, stackTrace) {
      developer.Timeline.instantSync(
        'petmagic.profile.notifications.error',
        arguments: {'stage': 'read_preferences', 'scope': scope},
      );
      developer.log(
        'NotificationPreferencesStorage::read failed',
        name: 'PetMagic.Profile.Notifications',
        error: error,
        stackTrace: stackTrace,
      );
      return NotificationPreferences.defaults().copyWith(
        emailOffersAndDiscounts: fallbackMarketingEmails,
      );
    }
  }

  Future<void> save({
    required String scope,
    required NotificationPreferences preferences,
  }) async {
    final sharedPreferences = await SharedPreferences.getInstance();
    await sharedPreferences.setString(
      '$_keyPrefix$scope',
      jsonEncode(preferences.toJson()),
    );
  }
}
