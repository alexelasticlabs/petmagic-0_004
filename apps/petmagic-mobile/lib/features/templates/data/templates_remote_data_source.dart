import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/network/dio_provider.dart';
import 'package:petmagic_mobile/features/templates/data/templates_dto.dart';
import 'package:petmagic_mobile/features/templates/data/templates_query.dart';

final templatesRemoteDataSourceProvider = Provider<TemplatesRemoteDataSource>((
  ref,
) {
  final dataSource = TemplatesRemoteDataSource(ref.watch(dioProvider));
  ref.onDispose(dataSource.cancelPendingFeedRequest);
  return dataSource;
});

class TemplatesRemoteDataSource {
  TemplatesRemoteDataSource(this._dio);

  final Dio _dio;
  CancelToken? _feedCancelToken;

  Future<TemplatesFeedDto> fetchFeed(TemplatesQuery query) async {
    cancelPendingFeedRequest();
    final cancelToken = CancelToken();
    _feedCancelToken = cancelToken;

    try {
      final response = await _dio.get<Map<String, Object?>>(
        '/api/templates',
        queryParameters: query.toQueryParameters(),
        cancelToken: cancelToken,
      );

      if (identical(_feedCancelToken, cancelToken)) {
        _feedCancelToken = null;
      }

      final data = response.data;
      if (data == null) {
        throw const AppException('templates.catalog_page_response_empty');
      }

      return TemplatesFeedDto.fromJson(data);
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        throw const RequestCancelledException();
      }

      throw AppException(
        _mapMessage(error),
        statusCode: error.response?.statusCode,
        cause: error,
      );
    }
  }

  Future<List<String>> fetchCategories() async {
    try {
      final response = await _dio.get<List<dynamic>>(
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
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        throw const RequestCancelledException();
      }

      throw AppException(
        _mapMessage(error),
        statusCode: error.response?.statusCode,
        cause: error,
      );
    }
  }

  Future<TemplatesCatalogVersionDto> fetchCatalogVersion() async {
    try {
      final response = await _dio.get<Map<String, Object?>>(
        '/api/templates/catalog-version',
      );
      final data = response.data;
      if (data == null) {
        throw const AppException('templates.catalog_version_response_empty');
      }

      return TemplatesCatalogVersionDto.fromJson(data);
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        throw const RequestCancelledException();
      }

      throw AppException(
        _mapMessage(error),
        statusCode: error.response?.statusCode,
        cause: error,
      );
    }
  }

  Future<TemplatesCatalogChangesDto> fetchCatalogChanges(int sinceVersion) async {
    try {
      final response = await _dio.get<Map<String, Object?>>(
        '/api/templates/changes',
        queryParameters: {'sinceVersion': sinceVersion},
      );
      final data = response.data;
      if (data == null) {
        throw const AppException('templates.catalog_changes_response_empty');
      }

      return TemplatesCatalogChangesDto.fromJson(data);
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        throw const RequestCancelledException();
      }

      throw AppException(
        _mapMessage(error),
        statusCode: error.response?.statusCode,
        cause: error,
      );
    }
  }

  void cancelPendingFeedRequest() {
    final cancelToken = _feedCancelToken;
    if (cancelToken == null || cancelToken.isCancelled) {
      return;
    }

    cancelToken.cancel('Superseded by a newer templates feed request.');
    _feedCancelToken = null;
  }

  String _mapMessage(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.connectionError) {
      return 'templates.connection_timeout';
    }

    if (error.type == DioExceptionType.receiveTimeout) {
      return 'templates.server_timeout';
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

    return error.message ?? 'templates.request_failed';
  }
}
