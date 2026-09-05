part of 'templates_remote_data_source.dart';

extension TemplatesRemoteDataSourceDetail on TemplatesRemoteDataSource {
  Future<TemplateItemDto> fetchTemplate(
    String templateId, {
    String? analyticsSource,
  }) async {
    try {
      final source = analyticsSource?.trim();
      final response = await _dio.get<Map<String, Object?>>(
        '/api/templates/${encodeTemplatePathSegment(templateId)}',
        queryParameters: _runtimeInfo.localizedQueryParameters(
          <String, Object?>{if (source?.isNotEmpty ?? false) 'source': source},
        ),
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
}
