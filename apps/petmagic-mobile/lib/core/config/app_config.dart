import 'dart:io';

import 'package:flutter/foundation.dart';

class AppConfig {
  const AppConfig._();

  static const configuredApiBaseUrl = String.fromEnvironment('API_BASE_URL');

  static List<String> get apiBaseUrls {
    if (configuredApiBaseUrl.isNotEmpty) {
      return [configuredApiBaseUrl];
    }

    if (!kIsWeb && Platform.isAndroid) {
      return const [
        'http://10.0.2.2:5000',
        'http://host.docker.internal:5000',
        'http://10.0.3.2:5000',
        'http://127.0.0.1:5000',
        'http://localhost:5000',
      ];
    }

    return const ['http://localhost:5000', 'http://127.0.0.1:5000'];
  }

  static String get apiBaseUrl {
    return apiBaseUrls.first;
  }
}
