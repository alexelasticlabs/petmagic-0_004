import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/app/preferences/app_preferences_controller.dart';
import 'package:petmagic_mobile/core/platform/app_runtime_info.dart';

final flutterAppRuntimeInfoProvider = Provider<AppRuntimeInfo>((ref) {
  final selectedLocale = ref.watch(
    appPreferencesControllerProvider.select((state) => state.locale),
  );
  return FlutterAppRuntimeInfo(localeOverride: selectedLocale);
});

final class FlutterAppRuntimeInfo implements AppRuntimeInfo {
  const FlutterAppRuntimeInfo({
    this.localeOverride,
    this.platformLocaleOverride,
  });

  final Locale? localeOverride;
  final Locale? platformLocaleOverride;

  @override
  AppLocale get locale {
    final selectedLocale = localeOverride;
    if (selectedLocale?.countryCode case final selectedCountryCode?) {
      return AppLocale(
        languageTag: selectedLocale!.toLanguageTag(),
        countryCode: selectedCountryCode,
      );
    }

    final platformLocale =
        platformLocaleOverride ??
        WidgetsBinding.instance.platformDispatcher.locale;
    final locale = selectedLocale == null
        ? platformLocale
        : Locale(selectedLocale.languageCode, platformLocale.countryCode);
    return AppLocale(
      languageTag: locale.toLanguageTag(),
      countryCode: locale.countryCode,
    );
  }

  @override
  AppRuntimePlatform get platform {
    if (Platform.isAndroid) {
      return AppRuntimePlatform.android;
    }
    if (Platform.isIOS) {
      return AppRuntimePlatform.ios;
    }
    return AppRuntimePlatform.other;
  }
}
