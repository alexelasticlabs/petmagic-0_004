import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppRuntimePlatform { android, ios, other }

final class AppLocale {
  const AppLocale({required this.languageTag, this.countryCode});

  final String languageTag;
  final String? countryCode;
}

final appRuntimeInfoProvider = Provider<AppRuntimeInfo>((ref) {
  return const DefaultAppRuntimeInfo();
});

abstract interface class AppRuntimeInfo {
  AppLocale get locale;

  AppRuntimePlatform get platform;
}

final class DefaultAppRuntimeInfo implements AppRuntimeInfo {
  const DefaultAppRuntimeInfo({
    this.locale = const AppLocale(languageTag: 'en'),
    this.platform = AppRuntimePlatform.other,
  });

  @override
  final AppLocale locale;

  @override
  final AppRuntimePlatform platform;
}
