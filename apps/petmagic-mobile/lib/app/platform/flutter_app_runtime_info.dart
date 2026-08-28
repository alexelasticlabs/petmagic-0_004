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
  const FlutterAppRuntimeInfo({this.localeOverride});

  final Locale? localeOverride;

  @override
  AppLocale get locale {
    final locale =
        localeOverride ?? WidgetsBinding.instance.platformDispatcher.locale;
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
