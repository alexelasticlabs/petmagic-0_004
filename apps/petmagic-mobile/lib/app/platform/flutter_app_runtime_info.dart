import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/platform/app_runtime_info.dart';

final flutterAppRuntimeInfoProvider = Provider<AppRuntimeInfo>((ref) {
  return const FlutterAppRuntimeInfo();
});

final class FlutterAppRuntimeInfo implements AppRuntimeInfo {
  const FlutterAppRuntimeInfo();

  @override
  AppLocale get locale {
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
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
