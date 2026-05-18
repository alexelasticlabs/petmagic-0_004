import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/config/app_config.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/network/dio_provider.dart';
import 'package:petmagic_mobile/features/templates/data/templates_dto.dart';
import 'package:petmagic_mobile/features/templates/data/templates_query.dart';

final templatesRemoteDataSourceProvider = Provider<TemplatesRemoteDataSource>((
  ref,
) {
  return TemplatesRemoteDataSource(ref.watch(dioProvider));
});

class TemplatesRemoteDataSource {
  const TemplatesRemoteDataSource(this._dio);

  final Dio _dio;

  Future<TemplatesFeedDto> fetchFeed(TemplatesQuery query) async {
    final response = await _getWithFallback<Map<String, Object?>>(
      '/api/templates/feed',
      queryParameters: query.toQueryParameters(),
      options: Options(listFormat: ListFormat.multi),
    );

    final data = response.data;
    if (data == null) {
      throw const AppException('Templates feed response was empty.');
    }

    return TemplatesFeedDto.fromJson(data);
  }

  Future<List<String>> fetchCategories() async {
    final response = await _getWithFallback<List<dynamic>>(
      '/api/templates/categories',
    );
    final data = response.data;
    if (data == null) {
      return const [];
    }

    final categories =
        data
            .whereType<Map>()
            .map((item) => item['name'])
            .whereType<String>()
            .map((name) => name.trim())
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList(growable: false)
          ..sort();

    return categories;
  }

  Future<Response<T>> _getWithFallback<T>(
    String path, {
    Map<String, Object?>? queryParameters,
    Options? options,
  }) async {
    DioException? lastConnectionError;

    for (final baseUrl in AppConfig.apiBaseUrls) {
      try {
        return await _dio.get<T>(
          '$baseUrl$path',
          queryParameters: queryParameters,
          options: options,
        );
      } on DioException catch (error) {
        final isConnectionFailure =
            error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.connectionError;

        if (isConnectionFailure) {
          lastConnectionError = error;
          continue;
        }

        throw AppException(
          _mapMessage(error),
          statusCode: error.response?.statusCode,
          cause: error,
        );
      }
    }

    if (lastConnectionError != null) {
      throw AppException(
        'Connection timeout. Checked: ${AppConfig.apiBaseUrls.join(', ')}. If you are on a physical Android device over USB, run `adb reverse tcp:5000 tcp:5000` and use API_BASE_URL=http://127.0.0.1:5000.',
        cause: lastConnectionError,
      );
    }

    throw const AppException('Templates feed request failed.');
  }

  String _mapMessage(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.connectionError) {
      return 'Connection timeout. Check API availability and API_BASE_URL.';
    }

    if (error.type == DioExceptionType.receiveTimeout) {
      return 'Server response timeout. Try again.';
    }

    try {
      final detail =
          (error.response?.data as Map<String, dynamic>?)?['detail'] as String?;
      if (detail != null && detail.isNotEmpty) {
        return detail;
      }
    } catch (_) {
      // Keep a safe fallback below.
    }

    return error.message ?? 'Templates feed request failed.';
  }
}
