import 'dart:io';

import 'package:dio/dio.dart';

const defaultMultipartSendTimeout = Duration(seconds: 60);
const defaultMultipartReceiveTimeout = Duration(seconds: 60);
const anonymousRequestExtraKey = 'petmagic_anonymous_request';

Options anonymousRequestOptions({
  Map<String, String>? extraHeaders,
  String? correlationId,
}) {
  final trimmedCorrelationId = correlationId?.trim();
  return Options(
    headers: {
      if (trimmedCorrelationId != null && trimmedCorrelationId.isNotEmpty)
        'X-Correlation-ID': trimmedCorrelationId,
      ...?extraHeaders,
    },
    extra: const {anonymousRequestExtraKey: true},
  );
}

void removeAuthorizationHeaderForAnonymousRequest(RequestOptions options) {
  if (options.extra[anonymousRequestExtraKey] != true) {
    return;
  }

  options.headers.removeWhere(
    (key, _) => key.toLowerCase() == HttpHeaders.authorizationHeader,
  );
}

Options authenticatedRequestOptions(
  String accessToken, {
  Map<String, String>? extraHeaders,
  bool multipart = false,
  String? correlationId,
  Duration? sendTimeout,
  Duration? receiveTimeout,
}) {
  final trimmedCorrelationId = correlationId?.trim();
  return Options(
    headers: {
      HttpHeaders.authorizationHeader: 'Bearer $accessToken',
      if (trimmedCorrelationId != null && trimmedCorrelationId.isNotEmpty)
        'X-Correlation-ID': trimmedCorrelationId,
      ...?extraHeaders,
    },
    contentType: multipart ? 'multipart/form-data' : null,
    sendTimeout: sendTimeout,
    receiveTimeout: receiveTimeout,
  );
}

Options authenticatedMultipartRequestOptions(
  String accessToken, {
  Map<String, String>? extraHeaders,
  String? correlationId,
}) {
  return authenticatedRequestOptions(
    accessToken,
    extraHeaders: extraHeaders,
    multipart: true,
    correlationId: correlationId,
    sendTimeout: defaultMultipartSendTimeout,
    receiveTimeout: defaultMultipartReceiveTimeout,
  );
}
