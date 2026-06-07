import 'dart:io';

import 'package:dio/dio.dart';

const defaultMultipartSendTimeout = Duration(seconds: 60);
const defaultMultipartReceiveTimeout = Duration(seconds: 60);

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
