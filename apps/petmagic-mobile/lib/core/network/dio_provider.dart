import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/config/app_config.dart';
import 'package:petmagic_mobile/core/network/api_base_url_failover_interceptor.dart';
import 'package:petmagic_mobile/core/network/api_base_url_resolver.dart';

final dioProvider = Provider<Dio>((ref) {
  final resolver = ref.watch(apiBaseUrlResolverProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 25),
      sendTimeout: const Duration(seconds: 20),
      headers: const {
        'Accept': 'application/json',
        'X-PetMagic-Client': 'mobile-flutter',
      },
    ),
  );

  dio.interceptors.add(
    ApiBaseUrlFailoverInterceptor(dio: dio, baseUrlResolver: resolver),
  );

  return dio;
});
