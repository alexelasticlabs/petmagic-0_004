import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/app/preferences/app_preferences_controller.dart';
import 'package:petmagic_mobile/core/config/app_config.dart';
import 'package:petmagic_mobile/core/network/authenticated_request_options.dart';
import 'package:petmagic_mobile/core/network/api_base_url_failover_interceptor.dart';
import 'package:petmagic_mobile/core/network/api_logging_interceptor.dart';
import 'package:petmagic_mobile/core/network/api_base_url_resolver.dart';

const _supportedLanguageCodes = <String>{
  'ru',
  'en',
  'de',
  'es',
  'fr',
  'it',
  'pl',
};

final dioProvider = Provider<Dio>((ref) {
  final resolver = ref.watch(apiBaseUrlResolverProvider);

  final headers = <String, String>{
    'Accept': 'application/json',
    'X-PetMagic-Client': 'mobile-flutter',
  };

  if (kDebugMode) {
    headers['ngrok-skip-browser-warning'] = 'true';
    headers['Bypass-Tunnel-Reminder'] = 'true';
  }

  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 8),
      headers: headers,
    ),
  );

  dio.interceptors.add(
    ApiBaseUrlFailoverInterceptor(dio: dio, baseUrlResolver: resolver),
  );
  dio.interceptors.add(ApiLoggingInterceptor());
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        removeAuthorizationHeaderForAnonymousRequest(options);
        options.headers['Accept-Language'] = _resolvePreferredLocaleTag(ref);
        handler.next(options);
      },
    ),
  );

  return dio;
});

String _resolvePreferredLocaleTag(Ref ref) {
  final preferred = ref.read(appPreferencesControllerProvider).locale;
  if (preferred != null) {
    return _normalizeLocaleTag(preferred);
  }

  return _normalizeLocaleTag(PlatformDispatcher.instance.locale);
}

String _normalizeLocaleTag(Locale locale) {
  final languageCode = locale.languageCode.toLowerCase();
  if (!_supportedLanguageCodes.contains(languageCode)) {
    return 'en';
  }

  final countryCode = locale.countryCode?.toUpperCase();
  if (countryCode == null || countryCode.isEmpty) {
    return languageCode;
  }

  return '$languageCode-$countryCode';
}
