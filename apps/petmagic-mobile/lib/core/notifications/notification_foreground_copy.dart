import 'dart:ui';

import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';

class NotificationForegroundCopy {
  const NotificationForegroundCopy._();

  static String openActionForLocale(Locale locale) {
    return _text(locale).notificationOpenAction;
  }

  static String titleForType(Locale locale, String? type) {
    final text = _text(locale);
    return switch (type) {
      'support_chat' => text.notificationSupportTitle,
      'template_generation' => text.notificationGenerationTitle,
      'wallet' => text.notificationWalletTitle,
      'premium' => text.notificationPremiumTitle,
      _ => text.notificationDefaultTitle,
    };
  }

  static String bodyForType(Locale locale, String? type) {
    final text = _text(locale);
    return switch (type) {
      'support_chat' => text.notificationSupportBody,
      'template_generation' => text.notificationGenerationBody,
      'wallet' => text.notificationWalletBody,
      'premium' => text.notificationPremiumBody,
      _ => '',
    };
  }

  static AppLocalizations _text(Locale locale) {
    final supportedLocale =
        AppLocalizations.supportedLocales.any(
          (supported) => supported.languageCode == locale.languageCode,
        )
        ? locale
        : const Locale('en');

    return lookupAppLocalizations(supportedLocale);
  }
}
