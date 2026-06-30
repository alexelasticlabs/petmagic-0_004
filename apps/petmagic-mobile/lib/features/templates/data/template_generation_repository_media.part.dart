part of 'template_generation_repository.dart';

Future<GenerationMediaAccessResult> _fetchDownloadUrl(
  TemplateGenerationRepository repository,
  String generationId, {
  CancelToken? cancelToken,
}) {
  final encodedGenerationId = repository._apiPathSegment(generationId);
  return _fetchMediaAccess(
    repository,
    generationId,
    '/api/templates/generations/$encodedGenerationId/download',
    method: 'GET',
    cancelToken: cancelToken,
  );
}

Future<GenerationMediaAccessResult> _fetchShareUrl(
  TemplateGenerationRepository repository,
  String generationId, {
  CancelToken? cancelToken,
}) {
  final encodedGenerationId = repository._apiPathSegment(generationId);
  return _fetchMediaAccess(
    repository,
    generationId,
    '/api/templates/generations/$encodedGenerationId/share',
    method: 'POST',
    cancelToken: cancelToken,
  );
}

Future<GenerationMediaAccessResult> _fetchMediaAccess(
  TemplateGenerationRepository repository,
  String generationId,
  String path, {
  required String method,
  CancelToken? cancelToken,
}) async {
  final response = await repository._authorizedRequest<Map<String, dynamic>>(
    (session) => repository._dio.request<Map<String, dynamic>>(
      path,
      options: authenticatedRequestOptions(
        session.accessToken,
      ).copyWith(method: method),
      cancelToken: cancelToken,
    ),
    retryTransientFailures: false,
  );

  return GenerationMediaAccessResult.fromJson(response.data ?? const {});
}
