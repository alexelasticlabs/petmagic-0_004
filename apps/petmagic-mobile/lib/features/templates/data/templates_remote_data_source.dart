import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/network/dio_provider.dart';
import 'package:petmagic_mobile/features/templates/data/templates_dto.dart';
import 'package:petmagic_mobile/features/templates/data/templates_remote_error_policy.dart';
import 'package:petmagic_mobile/features/templates/domain/templates_query.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';

final templatesRemoteDataSourceProvider = Provider<TemplatesRemoteDataSource>((
  ref,
) {
  final dataSource = TemplatesRemoteDataSource(ref.watch(dioProvider));
  ref.onDispose(() {
    dataSource.cancelPendingFeedRequest();
    dataSource.cancelPendingRandomTemplateRequest();
    dataSource.cancelPendingMetadataRequests();
  });
  return dataSource;
});

class TemplatesRemoteDataSource {
  TemplatesRemoteDataSource(this._dio);

  final Dio _dio;
  CancelToken? _feedCancelToken;
  CancelToken? _randomCancelToken;
  CancelToken? _categoriesCancelToken;
  CancelToken? _templateOfTheDayCancelToken;

  Future<TemplatesFeedDto> fetchFeed(TemplatesQuery query) async {
    cancelPendingFeedRequest();
    final cancelToken = CancelToken();
    _feedCancelToken = cancelToken;

    try {
      final response = await _dio.get<Map<String, Object?>>(
        '/api/templates/feed',
        queryParameters: query.toQueryParameters(),
        cancelToken: cancelToken,
      );

      final data = response.data;
      if (data == null) {
        throw const AppException('templates.catalog_page_response_empty');
      }

      return TemplatesFeedDto.fromJson(data);
    } on DioException catch (error) {
      if (TemplatesRemoteErrorPolicy.isCancelledRequest(error)) {
        throw const RequestCancelledException();
      }

      throw AppException(
        TemplatesRemoteErrorPolicy.mapMessage(error),
        statusCode: error.response?.statusCode,
        cause: error,
      );
    } finally {
      if (identical(_feedCancelToken, cancelToken)) {
        _feedCancelToken = null;
      }
    }
  }

  Future<TemplatesFeedDto> fetchCatalogPage({
    required int page,
    required int pageSize,
  }) async {
    try {
      final response = await _dio.get<Map<String, Object?>>(
        '/api/templates',
        queryParameters: <String, Object?>{'page': page, 'pageSize': pageSize},
      );

      final data = response.data;
      if (data == null) {
        throw const AppException('templates.catalog_page_response_empty');
      }

      return TemplatesFeedDto.fromJson(data);
    } on DioException catch (error) {
      if (TemplatesRemoteErrorPolicy.isCancelledRequest(error)) {
        throw const RequestCancelledException();
      }

      throw AppException(
        TemplatesRemoteErrorPolicy.mapMessage(error),
        statusCode: error.response?.statusCode,
        cause: error,
      );
    }
  }

  Future<TemplateItemDto> fetchTemplate(String templateId) async {
    try {
      final response = await _dio.get<Map<String, Object?>>(
        '/api/templates/${encodeTemplatePathSegment(templateId)}',
      );
      final data = response.data;
      if (data == null) {
        throw const AppException('templates.template_response_empty');
      }

      return TemplateItemDto.fromJson(data);
    } on DioException catch (error) {
      if (TemplatesRemoteErrorPolicy.isCancelledRequest(error)) {
        throw const RequestCancelledException();
      }

      throw AppException(
        TemplatesRemoteErrorPolicy.mapMessage(error),
        statusCode: error.response?.statusCode,
        cause: error,
      );
    }
  }

  Future<PublicRandomTemplateDto> fetchRandomTemplate({
    required TemplateRandomMode mode,
    required String? category,
    required bool includePremium,
    TemplateRandomAccess access = TemplateRandomAccess.available,
  }) async {
    cancelPendingRandomTemplateRequest();
    final cancelToken = CancelToken();
    _randomCancelToken = cancelToken;

    try {
      final response = await _dio.get<Map<String, Object?>>(
        '/api/templates/random',
        queryParameters: <String, Object?>{
          if (mode != TemplateRandomMode.any)
            'type': mode == TemplateRandomMode.video
                ? TemplateType.video.apiValue
                : TemplateType.image.apiValue,
          if (category != null && category.trim().isNotEmpty)
            'category': category.trim(),
          'includePremium': includePremium,
          if (access != TemplateRandomAccess.available)
            'access': access == TemplateRandomAccess.premium
                ? 'premium'
                : 'free',
        },
        cancelToken: cancelToken,
      );
      final data = response.data;
      if (data == null) {
        throw const AppException('templates.random_response_empty');
      }

      return PublicRandomTemplateDto.fromJson(data);
    } on DioException catch (error) {
      if (TemplatesRemoteErrorPolicy.isCancelledRequest(error)) {
        throw const RequestCancelledException();
      }

      throw AppException(
        TemplatesRemoteErrorPolicy.mapMessage(error),
        statusCode: error.response?.statusCode,
        cause: error,
      );
    } finally {
      if (identical(_randomCancelToken, cancelToken)) {
        _randomCancelToken = null;
      }
    }
  }

  Future<List<String>> fetchCategories() async {
    cancelPendingCategoriesRequest();
    final cancelToken = CancelToken();
    _categoriesCancelToken = cancelToken;

    try {
      final response = await _dio.get<List<dynamic>>(
        '/api/templates/categories',
        cancelToken: cancelToken,
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
      if (TemplatesRemoteErrorPolicy.isCancelledRequest(error)) {
        throw const RequestCancelledException();
      }

      throw AppException(
        TemplatesRemoteErrorPolicy.mapMessage(error),
        statusCode: error.response?.statusCode,
        cause: error,
      );
    } finally {
      if (identical(_categoriesCancelToken, cancelToken)) {
        _categoriesCancelToken = null;
      }
    }
  }

  Future<PublicTemplateOfTheDayDto> fetchTemplateOfTheDay() async {
    cancelPendingTemplateOfTheDayRequest();
    final cancelToken = CancelToken();
    _templateOfTheDayCancelToken = cancelToken;

    try {
      final response = await _dio.get<Map<String, Object?>>(
        '/api/templates/template-of-the-day',
        cancelToken: cancelToken,
      );
      final data = response.data;
      if (data == null) {
        throw const AppException(
          'templates.template_of_the_day_response_empty',
        );
      }

      return PublicTemplateOfTheDayDto.fromJson(data);
    } on DioException catch (error) {
      if (TemplatesRemoteErrorPolicy.isCancelledRequest(error)) {
        throw const RequestCancelledException();
      }

      throw AppException(
        TemplatesRemoteErrorPolicy.mapMessage(error),
        statusCode: error.response?.statusCode,
        cause: error,
      );
    } finally {
      if (identical(_templateOfTheDayCancelToken, cancelToken)) {
        _templateOfTheDayCancelToken = null;
      }
    }
  }

  Future<void> recordAnalyticsEvent({
    required String templateId,
    required String eventType,
    String? source,
    String? generationId,
    Map<String, Object?>? metadata,
  }) async {
    try {
      await _dio.post<void>(
        '/api/templates/${encodeTemplatePathSegment(templateId)}/analytics/events',
        data: <String, Object?>{
          'eventType': eventType,
          if (source != null && source.trim().isNotEmpty)
            'source': source.trim(),
          if (generationId != null && generationId.trim().isNotEmpty)
            'generationId': generationId.trim(),
          if (metadata != null && metadata.isNotEmpty) 'metadata': metadata,
        },
      );
    } on DioException catch (error) {
      if (TemplatesRemoteErrorPolicy.isCancelledRequest(error)) {
        throw const RequestCancelledException();
      }

      throw AppException(
        TemplatesRemoteErrorPolicy.mapMessage(error),
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
      if (TemplatesRemoteErrorPolicy.isCancelledRequest(error)) {
        throw const RequestCancelledException();
      }

      throw AppException(
        TemplatesRemoteErrorPolicy.mapMessage(error),
        statusCode: error.response?.statusCode,
        cause: error,
      );
    }
  }

  Future<TemplatesCatalogChangesDto> fetchCatalogChanges(
    int sinceVersion,
  ) async {
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
      if (TemplatesRemoteErrorPolicy.isCancelledRequest(error)) {
        throw const RequestCancelledException();
      }

      throw AppException(
        TemplatesRemoteErrorPolicy.mapMessage(error),
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

  void cancelPendingRandomTemplateRequest() {
    final cancelToken = _randomCancelToken;
    if (cancelToken == null || cancelToken.isCancelled) {
      return;
    }

    cancelToken.cancel('Superseded by a newer random template request.');
    _randomCancelToken = null;
  }

  void cancelPendingMetadataRequests() {
    cancelPendingCategoriesRequest();
    cancelPendingTemplateOfTheDayRequest();
  }

  void cancelPendingCategoriesRequest() {
    final cancelToken = _categoriesCancelToken;
    if (cancelToken == null || cancelToken.isCancelled) {
      return;
    }

    cancelToken.cancel('Superseded by hidden templates metadata lifecycle.');
    _categoriesCancelToken = null;
  }

  void cancelPendingTemplateOfTheDayRequest() {
    final cancelToken = _templateOfTheDayCancelToken;
    if (cancelToken == null || cancelToken.isCancelled) {
      return;
    }

    cancelToken.cancel('Superseded by hidden templates metadata lifecycle.');
    _templateOfTheDayCancelToken = null;
  }
}
