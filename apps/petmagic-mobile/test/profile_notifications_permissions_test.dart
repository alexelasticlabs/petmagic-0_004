import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile notification setting subtitles use localizations', () async {
    final source = await File(
      'lib/features/profile/presentation/widgets/profile_notifications_settings_section.dart',
    ).readAsString();

    const expectedGetters = <String>[
      'profileNotificationsPushPhotoReadySubtitle',
      'profileNotificationsPushVideoReadySubtitle',
      'profileNotificationsPushGenerationErrorsSubtitle',
      'profileNotificationsPushRemindersSubtitle',
      'profileNotificationsPushNewTemplatesSubtitle',
      'profileNotificationsPushPurchasesAndSubscriptionsSubtitle',
      'profileNotificationsEmailOffersSubtitle',
      'profileNotificationsEmailNewsSubtitle',
      'profileNotificationsEmailAccountAlertsSubtitle',
    ];
    const removedLiterals = <String>[
      'Когда AI-фото готово к просмотру',
      'Когда AI-видео завершило обработку',
      'Если генерация завершилась с ошибкой',
      'Напоминания об использовании приложения',
      'Новые стили и шаблоны генерации',
      'Подтверждения оплат и статус подписки',
      'Скидки, акции и промо-предложения',
      'Обновления приложения и новые функции',
      'Уведомления безопасности и о смене данных',
    ];

    for (final getter in expectedGetters) {
      expect(source, contains(getter));
    }
    for (final literal in removedLiterals) {
      expect(source, isNot(contains(literal)));
    }
  });

  test(
    'profile notification subtitle keys exist in every supported locale',
    () async {
      const arbFiles = <String>[
        'lib/l10n/app_en.arb',
        'lib/l10n/app_ru.arb',
        'lib/l10n/app_de.arb',
        'lib/l10n/app_es.arb',
        'lib/l10n/app_fr.arb',
        'lib/l10n/app_it.arb',
        'lib/l10n/app_pl.arb',
      ];
      const requiredKeys = <String>[
        'profileNotificationsPushPhotoReadySubtitle',
        'profileNotificationsPushVideoReadySubtitle',
        'profileNotificationsPushGenerationErrorsSubtitle',
        'profileNotificationsPushRemindersSubtitle',
        'profileNotificationsPushNewTemplatesSubtitle',
        'profileNotificationsPushPurchasesAndSubscriptionsSubtitle',
        'profileNotificationsEmailOffersSubtitle',
        'profileNotificationsEmailNewsSubtitle',
        'profileNotificationsEmailAccountAlertsSubtitle',
      ];

      for (final path in arbFiles) {
        final source = await File(path).readAsString();
        for (final key in requiredKeys) {
          expect(source, contains('"$key"'), reason: '$path is missing $key');
        }
      }
    },
  );

  test(
    'profile notification settings does not read or request media permissions',
    () async {
      final source = await File(
        'lib/features/profile/presentation/widgets/profile_notifications_settings_section.dart',
      ).readAsString();

      final refreshDeviceBody = _methodBody(
        source,
        '_refreshDevicePermissions',
      );

      expect(
        refreshDeviceBody,
        contains('types: const [AppPermissionType.notifications]'),
      );
      expect(refreshDeviceBody, isNot(contains('AppPermissionType.camera')));
      expect(refreshDeviceBody, isNot(contains('AppPermissionType.photos')));
      expect(refreshDeviceBody, isNot(contains('AppPermissionType.videos')));
      expect(
        refreshDeviceBody,
        isNot(contains('AppPermissionType.microphone')),
      );
      expect(
        source,
        isNot(contains('requestOnDemand(AppPermissionType.camera)')),
      );
      expect(
        source,
        isNot(contains('requestOnDemand(AppPermissionType.photos)')),
      );
      expect(
        source,
        isNot(contains('requestOnDemand(AppPermissionType.files)')),
      );
    },
  );

  test('profile notification settings async actions are guarded', () async {
    final source = await File(
      'lib/features/profile/presentation/widgets/profile_notifications_settings_section.dart',
    ).readAsString();

    final updateBody = _methodBody(source, '_update');
    final refreshDeviceBody = _methodBody(source, '_refreshDevicePermissions');
    final requestPushBody = _methodBody(source, '_requestPushPermission');
    final openSettingsBody = _methodBody(source, '_openDeviceSettings');

    expect(updateBody, contains('if (_isSaving)'));
    expect(requestPushBody, contains('if (_isRequestingPermission)'));
    expect(refreshDeviceBody, contains("try {"));
    expect(refreshDeviceBody, contains("'refresh_device_permissions'"));
    expect(openSettingsBody, contains('if (_isOpeningSettings)'));
    expect(openSettingsBody, contains("try {"));
    expect(openSettingsBody, contains("'open_device_settings'"));
    expect(
      source,
      isNot(contains('() => _permissionCoordinator.openSettings()')),
    );
  });

  test('profile notification permission grant registers push token', () async {
    final source = await File(
      'lib/features/profile/presentation/widgets/profile_notifications_settings_section.dart',
    ).readAsString();

    final requestPushBody = _methodBody(source, '_requestPushPermission');
    final refreshPushBody = _methodBody(source, '_refreshPushPermissionStatus');
    final registerBody = _methodBody(source, '_registerPushTokenIfAllowed');

    expect(requestPushBody, contains('_registerPushTokenIfAllowed'));
    expect(refreshPushBody, contains('_registerPushTokenIfAllowed'));
    expect(registerBody, contains('FirebaseMessaging.instance.getToken()'));
    expect(source, contains('PushTokenRegistrar'));
    expect(source, contains('templateGenerationRepositoryProvider'));
    expect(source, contains('supportChatRepositoryProvider'));
    expect(source, contains('walletRepositoryProvider'));
    expect(registerBody, contains('_pushTokenRegistrar.registerToken'));
    expect(registerBody, contains('defaultTargetPlatform.name'));
    expect(
      registerBody,
      contains('Localizations.localeOf(context).toLanguageTag()'),
    );
    expect(registerBody, contains('canContinue: () => mounted'));
    expect(registerBody, contains('register_push_token_after_permission'));
  });
}

String _methodBody(String source, String methodName) {
  final methodMatch = RegExp(
    r'(?:void|bool|Future<[^>]+>)\s+' + methodName + r'\s*\(',
  ).firstMatch(source);
  if (methodMatch == null) {
    fail('Method $methodName was not found.');
  }

  final openBraceIndex = _methodOpenBraceIndex(source, methodMatch);
  if (openBraceIndex < 0) {
    fail('Method $methodName has no body.');
  }

  var depth = 0;
  for (var index = openBraceIndex; index < source.length; index++) {
    final char = source[index];
    if (char == '{') {
      depth++;
      continue;
    }
    if (char != '}') {
      continue;
    }

    depth--;
    if (depth == 0) {
      return source.substring(openBraceIndex, index + 1);
    }
  }

  fail('Method $methodName body did not close.');
}

int _methodOpenBraceIndex(String source, RegExpMatch methodMatch) {
  var parenDepth = 0;
  for (var index = methodMatch.end - 1; index < source.length; index++) {
    final char = source[index];
    if (char == '(') {
      parenDepth++;
      continue;
    }
    if (char == ')') {
      parenDepth--;
      continue;
    }
    if (char == '{' && parenDepth == 0) {
      return index;
    }
  }

  return -1;
}
