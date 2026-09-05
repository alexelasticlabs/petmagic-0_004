import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/network/dio_provider.dart';
import 'package:petmagic_mobile/core/platform/app_runtime_info.dart';
import 'package:petmagic_mobile/features/templates/data/template_discovery_dto.dart';
import 'package:petmagic_mobile/features/templates/data/templates_remote_error_policy.dart';

final templateDiscoveryRemoteDataSourceProvider =
    Provider<TemplateDiscoveryRemoteDataSource>((ref) {
      final dataSource = TemplateDiscoveryRemoteDataSource(
        ref.watch(dioProvider),
        runtimeInfo: ref.watch(appRuntimeInfoProvider),
      );
      ref.onDispose(dataSource.cancelPendingRequest);
      return dataSource;
    });

final class TemplateDiscoveryRemoteDataSource {
  TemplateDiscoveryRemoteDataSource(this._dio, {AppRuntimeInfo? runtimeInfo})
    : _runtimeInfo = runtimeInfo ?? const DefaultAppRuntimeInfo();

  final Dio _dio;
  final AppRuntimeInfo _runtimeInfo;
  CancelToken? _cancelToken;

  Future<TemplateDiscoveryDto> fetch() async {
    cancelPendingRequest();
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;

    try {
      final response = await _dio.get<Map<String, Object?>>(
        '/api/templates/discovery',
        queryParameters: _localizedQueryParameters(),
        cancelToken: cancelToken,
      );
      final data = response.data;
      if (data == null) {
        throw const AppException('templates.discovery_response_empty');
      }
      return TemplateDiscoveryDto.fromJson(data);
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
      if (identical(_cancelToken, cancelToken)) {
        _cancelToken = null;
      }
    }
  }

  Map<String, Object?> _localizedQueryParameters() {
    final languageTag = _runtimeInfo.locale.languageTag.trim();
    return <String, Object?>{
      'sectionLimit': 24,
      'itemsPerSection': 12,
      if (languageTag.isNotEmpty && !languageTag.toLowerCase().startsWith('en'))
        'locale': languageTag,
    };
  }

  void cancelPendingRequest() {
    final cancelToken = _cancelToken;
    if (cancelToken == null || cancelToken.isCancelled) {
      return;
    }
    cancelToken.cancel('Superseded by template discovery lifecycle.');
    _cancelToken = null;
  }
}
