import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Rejects oversized media both from Content-Length and while streaming when
/// a server omits or misreports that header.
final class BoundedHttpFileService extends FileService {
  BoundedHttpFileService({required this.maxBytes, required this.mediaKind}) {
    concurrentFetches = _delegate.concurrentFetches;
  }

  final int maxBytes;
  final String mediaKind;
  final HttpFileService _delegate = HttpFileService();

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    final response = await _delegate.get(url, headers: headers);
    final contentLength = response.contentLength;
    if (contentLength != null && contentLength > maxBytes) {
      throw StateError('template_${mediaKind}_download_too_large');
    }

    return _BoundedFileServiceResponse(
      response,
      maxBytes: maxBytes,
      mediaKind: mediaKind,
    );
  }
}

final class _BoundedFileServiceResponse implements FileServiceResponse {
  const _BoundedFileServiceResponse(
    this._inner, {
    required this.maxBytes,
    required this.mediaKind,
  });

  final FileServiceResponse _inner;
  final int maxBytes;
  final String mediaKind;

  @override
  Stream<List<int>> get content async* {
    var receivedBytes = 0;
    await for (final chunk in _inner.content) {
      receivedBytes += chunk.length;
      if (receivedBytes > maxBytes) {
        throw StateError('template_${mediaKind}_download_too_large');
      }
      yield chunk;
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
