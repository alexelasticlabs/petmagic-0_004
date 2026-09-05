import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:petmagic_mobile/core/performance/media_prefetch_budget.dart';

/// Rejects oversized media both from Content-Length and while streaming when
/// a server omits or misreports that header.
final class BoundedHttpFileService extends FileService {
  BoundedHttpFileService({
    required this.maxBytes,
    required this.mediaKind,
    int maxConcurrentFetches = 4,
  }) : assert(maxConcurrentFetches > 0) {
    concurrentFetches = maxConcurrentFetches;
  }

  final int maxBytes;
  final String mediaKind;
  // Request abortion begins once the native socket connects. Bound that
  // preceding phase as well so an unreachable origin cannot pin the queue.
  final http.Client _client = IOClient(
    HttpClient()..connectionTimeout = const Duration(seconds: 15),
  );
  static const _constraintHeader = 'x-petmagic-local-download-constraint';
  final Map<String, MediaDownloadConstraint> _constraints = {};
  int _nextConstraint = 0;

  /// Cache manager preserves headers through its asynchronous download queue.
  /// This local marker is stripped before any HTTP request is made.
  Map<String, String> registerConstraint(MediaDownloadConstraint constraint) {
    final id = '${++_nextConstraint}';
    _constraints[id] = constraint;
    return {_constraintHeader: id};
  }

  void unregisterConstraint(Map<String, String> headers) =>
      _constraints.remove(headers[_constraintHeader]);

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    final outgoing = {...?headers};
    final constraint = _constraints[outgoing.remove(_constraintHeader)];
    constraint?.checkContentLength(null);
    final request = http.AbortableRequest(
      'GET',
      Uri.parse(url),
      abortTrigger: constraint?.abortTrigger,
    )..headers.addAll(outgoing);
    final FileServiceResponse response;
    try {
      response = HttpGetResponse(await _client.send(request));
    } on http.RequestAbortedException {
      throw const MediaPrefetchLimitException();
    }
    final contentLength = response.contentLength;
    try {
      if (contentLength != null && contentLength > maxBytes) {
        throw StateError('template_${mediaKind}_download_too_large');
      }
      constraint?.checkContentLength(contentLength);
    } catch (_) {
      await response.content.listen(null).cancel();
      rethrow;
    }

    return _BoundedFileServiceResponse(
      response,
      maxBytes: maxBytes,
      mediaKind: mediaKind,
      constraint: constraint,
    );
  }
}

final class _BoundedFileServiceResponse implements FileServiceResponse {
  const _BoundedFileServiceResponse(
    this._inner, {
    required this.maxBytes,
    required this.mediaKind,
    this.constraint,
  });

  final FileServiceResponse _inner;
  final int maxBytes;
  final String mediaKind;
  final MediaDownloadConstraint? constraint;

  @override
  Stream<List<int>> get content async* {
    var receivedBytes = 0;
    try {
      await for (final chunk in _inner.content) {
        constraint?.consume(chunk.length);
        receivedBytes += chunk.length;
        if (receivedBytes > maxBytes) {
          throw StateError('template_${mediaKind}_download_too_large');
        }
        yield chunk;
      }
    } on http.RequestAbortedException {
      throw const MediaPrefetchLimitException();
    }
  }

  @override
  int? get contentLength => _inner.contentLength;

  @override
  String? get eTag => _inner.eTag;

  @override
  String get fileExtension => _inner.fileExtension;

  @override
  int get statusCode => _inner.statusCode;

  @override
  DateTime get validTill => _inner.validTill;
}
