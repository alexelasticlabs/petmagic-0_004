import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/features/profile/data/notification_preferences_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationPreferencesStorage', () {
    setUp(() {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
    });

    test(
      'returns defaults with marketing fallback when no saved value',
      () async {
        final storage = NotificationPreferencesStorage();

        final result = await storage.read(
          scope: 'user-1',
          fallbackMarketingEmails: true,
        );

        expect(result.pushPhotoReady, isTrue);
        expect(result.pushVideoReady, isTrue);
        expect(result.pushGenerationErrors, isTrue);
        expect(result.pushReminders, isTrue);
        expect(result.pushNewTemplates, isTrue);
        expect(result.pushPurchasesAndSubscriptions, isTrue);
        expect(result.emailOffersAndDiscounts, isTrue);
        expect(result.emailNews, isFalse);
        expect(result.emailAccountAlerts, isTrue);
      },
    );

    test('persists and restores all notification options', () async {
      final storage = NotificationPreferencesStorage();
      const saved = NotificationPreferences(
        pushPhotoReady: false,
        pushVideoReady: true,
        pushGenerationErrors: false,
        pushReminders: false,
        pushNewTemplates: true,
        pushPurchasesAndSubscriptions: false,
        emailOffersAndDiscounts: true,
        emailNews: true,
        emailAccountAlerts: false,
      );

      await storage.save(scope: 'user-2', preferences: saved);

      final restored = await storage.read(
        scope: 'user-2',
        fallbackMarketingEmails: false,
      );

      expect(restored.pushPhotoReady, saved.pushPhotoReady);
      expect(restored.pushVideoReady, saved.pushVideoReady);
      expect(restored.pushGenerationErrors, saved.pushGenerationErrors);
      expect(restored.pushReminders, saved.pushReminders);
      expect(restored.pushNewTemplates, saved.pushNewTemplates);
      expect(
        restored.pushPurchasesAndSubscriptions,
        saved.pushPurchasesAndSubscriptions,
      );
      expect(restored.emailOffersAndDiscounts, saved.emailOffersAndDiscounts);
      expect(restored.emailNews, saved.emailNews);
      expect(restored.emailAccountAlerts, saved.emailAccountAlerts);
    });

    test('does not store raw user scope in preferences key', () async {
      final preferences = SharedPreferencesAsync();
      final storage = NotificationPreferencesStorage();
      const userScope = 'user-sensitive-id@example.com';
      const saved = NotificationPreferences(
        pushPhotoReady: false,
        pushVideoReady: false,
        pushGenerationErrors: false,
        pushReminders: false,
        pushNewTemplates: false,
        pushPurchasesAndSubscriptions: false,
        emailOffersAndDiscounts: true,
        emailNews: true,
        emailAccountAlerts: false,
      );

      await storage.save(scope: userScope, preferences: saved);

      expect(
        await preferences.getString(
          'petmagic_mobile_notification_preferences_v1_$userScope',
        ),
        isNull,
      );
      final keys = await preferences.getKeys();
      expect(keys.any((key) => key.contains(userScope)), isFalse);

      final restored = await storage.read(
        scope: userScope,
        fallbackMarketingEmails: false,
      );
      expect(restored.pushPhotoReady, isFalse);
      expect(restored.emailOffersAndDiscounts, isTrue);
    });

    test('migrates legacy raw user scope key and removes it', () async {
      final preferences = SharedPreferencesAsync();
      final storage = NotificationPreferencesStorage();
      const userScope = 'legacy-user-id';
      await preferences.setString(
        'petmagic_mobile_notification_preferences_v1_$userScope',
        '{"pushPhotoReady":false,"emailNews":true}',
      );

      final migrated = await storage.read(
        scope: userScope,
        fallbackMarketingEmails: false,
      );

      expect(migrated.pushPhotoReady, isFalse);
      expect(migrated.emailNews, isTrue);
      expect(
        await preferences.getString(
          'petmagic_mobile_notification_preferences_v1_$userScope',
        ),
        isNull,
      );
      expect(await preferences.getKeys(), isNotEmpty);
    });

    test('removes corrupted legacy raw user scope key', () async {
      final preferences = SharedPreferencesAsync();
      final storage = NotificationPreferencesStorage();
      const userScope = 'corrupted-legacy-user-id';
      await preferences.setString(
        'petmagic_mobile_notification_preferences_v1_$userScope',
        '{not-json',
      );

      final fallback = await storage.read(
        scope: userScope,
        fallbackMarketingEmails: true,
      );

      expect(fallback.emailOffersAndDiscounts, isTrue);
      expect(
        await preferences.getString(
          'petmagic_mobile_notification_preferences_v1_$userScope',
        ),
        isNull,
      );
    });

    test(
      'does not log raw user scope when saved preferences are corrupted',
      () {
        final source = File(
          'lib/features/profile/data/notification_preferences_storage.dart',
        ).readAsStringSync();

        expect(source, contains("'hasScope': scope.trim().isNotEmpty"));
        expect(source, isNot(contains("'scope': scope")));
      },
    );
  });
}
