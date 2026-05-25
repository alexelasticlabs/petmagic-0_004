import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:petmagic_mobile/core/network/api_base_url_resolver.dart';

class ApiBaseUrlFailoverInterceptor extends Interceptor {
  ApiBaseUrlFailoverInterceptor({
    required Dio dio,
    required ApiBaseUrlResolver baseUrlResolver,
  }) : _dio = dio,
       _baseUrlResolver = baseUrlResolver;

  static const _attemptedBaseUrlsKey = 'petmagic_attempted_base_urls';
  static const _skipFailoverKey = 'petmagic_skip_base_url_failover';

  final Dio _dio;
  final ApiBaseUrlResolver _baseUrlResolver;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (_shouldSkipFailover(options)) {
      handler.next(options);
      return;
    }

    final resolvedBaseUrl = await _baseUrlResolver.resolveBaseUrl();
    options.baseUrl = resolvedBaseUrl;

    final attempted = _readAttemptedBaseUrls(options);
    attempted.add(resolvedBaseUrl);
    options.extra[_attemptedBaseUrlsKey] = attempted.toList(growable: false);

    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final requestBaseUrl = response.requestOptions.baseUrl;
    unawaited(_baseUrlResolver.markSuccessful(requestBaseUrl));

    response.data = _rewriteLocalhostUrls(response.data, requestBaseUrl);
    handler.next(response);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final requestOptions = err.requestOptions;
    if (_shouldSkipFailover(requestOptions) ||
        !_isConnectionFailure(err) ||
        CancelToken.isCancel(err)) {
      handler.next(err);
      return;
    }

    final attempted = _readAttemptedBaseUrls(requestOptions);
    if (requestOptions.baseUrl.isNotEmpty) {
      attempted.add(requestOptions.baseUrl);
      await _baseUrlResolver.invalidate(requestOptions.baseUrl);
    }

    final candidates = await _baseUrlResolver.prioritizedCandidates();
    DioException? lastError = err;

    for (final candidate in candidates) {
      if (attempted.contains(candidate)) {
        continue;
      }

      final retryOptions = requestOptions.copyWith(
        baseUrl: candidate,
        data: _cloneRequestData(requestOptions.data),
        extra: {
          ...requestOptions.extra,
          _skipFailoverKey: true,
          _attemptedBaseUrlsKey: [...attempted, candidate],
        },
      );

      try {
        final response = await _dio.fetch<dynamic>(retryOptions);
        await _baseUrlResolver.markSuccessful(candidate);
        response.data = _rewriteLocalhostUrls(response.data, candidate);
        handler.resolve(response);
        return;
      } on DioException catch (retryError) {
        lastError = retryError;
        if (_isConnectionFailure(retryError) &&
            !CancelToken.isCancel(retryError)) {
          attempted.add(candidate);
          await _baseUrlResolver.invalidate(candidate);
          continue;
        }

        handler.next(retryError);
        return;
      }
    }

    handler.next(lastError ?? err);
  }

  bool _shouldSkipFailover(RequestOptions options) {
    return options.extra[_skipFailoverKey] == true;
  }

  Set<String> _readAttemptedBaseUrls(RequestOptions options) {
    final raw = options.extra[_attemptedBaseUrlsKey];
    if (raw is List) {
      return raw.whereType<String>().toSet();
    }

    return <String>{};
  }

  bool _isConnectionFailure(DioException error) {
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout) {
      return true;
    }

    return error.type == DioExceptionType.unknown &&
        error.error is SocketException;
  }

  Object? _cloneRequestData(Object? data) {
    if (data is FormData) {
      return data.clone();
    }

    if (data is List) {
      return List<Object?>.from(data);
    }

    if (data is Map) {
      return Map<Object?, Object?>.from(data);
    }

    return data;
  }

  Object? _rewriteLocalhostUrls(Object? value, String activeBaseUrl) {
    final activeUri = Uri.tryParse(activeBaseUrl);
    if (activeUri == null || _isLoopbackHost(activeUri.host)) {
      return value;
    }

    if (value is String) {
      return _replaceLocalhostPrefix(value, activeUri);
    }

    if (value is List) {
      return value
          .map((item) => _rewriteLocalhostUrls(item, activeBaseUrl))
          .toList(growable: false);
    }

    if (value is Map) {
      return value.map(
        (key, item) =>
            MapEntry(key, _rewriteLocalhostUrls(item, activeBaseUrl)),
      );
    }

    return value;
  }

  String _replaceLocalhostPrefix(String raw, Uri activeUri) {
    final parsed = Uri.tryParse(raw);
    if (parsed == null || !_isLoopbackHost(parsed.host)) {
      return raw;
    }

    final replaced = parsed.replace(
      scheme: activeUri.scheme,
      host: activeUri.host,
      port: activeUri.hasPort ? activeUri.port : null,
    );

    return replaced.toString();
  }

  bool _isLoopbackHost(String host) {
    final normalized = host.toLowerCase();
    return normalized == 'localhost' || normalized == '127.0.0.1';
  }
}
