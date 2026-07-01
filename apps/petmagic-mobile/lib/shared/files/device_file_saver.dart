import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:petmagic_mobile/shared/files/file_name_sanitizer.dart';
import 'package:share_plus/share_plus.dart';

import 'temp_media_cleanup.dart';

const defaultRemoteFileDownloadMaxBytes = 128 * 1024 * 1024;

Future<List<int>> downloadFileBytes(
  String fileUrl, {
  Dio? client,
  Duration timeout = const Duration(seconds: 20),
  CancelToken? cancelToken,
  int maxBytes = defaultRemoteFileDownloadMaxBytes,
}) async {
  if (maxBytes <= 0) {
    throw ArgumentError.value(maxBytes, 'maxBytes', 'Must be positive.');
  }

  final ownsClient = client == null;
  final httpClient =
      client ??
      Dio(
        BaseOptions(
          connectTimeout: timeout,
          receiveTimeout: timeout,
          sendTimeout: timeout,
        ),
      );

  try {
    _throwIfDownloadCancelled(cancelToken);
    final response = await httpClient.get<ResponseBody>(
      fileUrl,
      cancelToken: cancelToken,
      options: Options(
        responseType: ResponseType.stream,
        receiveTimeout: timeout,
        sendTimeout: timeout,
      ),
    );
    final body = response.data;
    if (body == null) {
      throw StateError('Empty download payload.');
    }
    _throwIfDownloadCancelled(cancelToken);

    final contentLength = _contentLengthFromHeaders(response.headers);
    if (contentLength != null && contentLength > maxBytes) {
      throw StateError('Remote file exceeds maximum allowed size.');
    }

    final chunks = <Uint8List>[];
    var receivedBytes = 0;
    await for (final chunk in body.stream) {
      _throwIfDownloadCancelled(cancelToken);
      if (chunk.isEmpty) {
        continue;
      }
      receivedBytes += chunk.length;
      if (receivedBytes > maxBytes) {
        throw StateError('Remote file exceeds maximum allowed size.');
      }
      chunks.add(chunk);
    }

    if (receivedBytes == 0) {
      throw StateError('Empty download payload.');
    }

    final bytes = Uint8List(receivedBytes);
    var offset = 0;
    for (final chunk in chunks) {
      bytes.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    return bytes;
  } on DioException catch (error) {
    if (CancelToken.isCancel(error)) {
      throw _downloadCancelledException();
    }

    throw _sanitizeDownloadException(error, fileUrl);
  } finally {
    if (ownsClient) {
      httpClient.close(force: true);
    }
  }
}

void _throwIfDownloadCancelled(CancelToken? cancelToken) {
  if (cancelToken?.isCancelled != true) {
    return;
  }

  throw _downloadCancelledException();
}

DioException _downloadCancelledException() {
  return DioException.requestCancelled(
    requestOptions: RequestOptions(path: ''),
    reason: 'download_cancelled',
  );
}

DioException _sanitizeDownloadException(DioException error, String fileUrl) {
  final safeRequestOptions = RequestOptions(
    path: _safeDownloadPath(fileUrl),
    method: error.requestOptions.method,
  );
  final response = error.response == null
      ? null
      : Response<dynamic>(
          requestOptions: safeRequestOptions,
          statusCode: error.response?.statusCode,
          statusMessage: error.response?.statusMessage,
        );

  return DioException(
    requestOptions: safeRequestOptions,
    response: response,
    type: error.type,
    message: 'download_failed',
  );
}

String _safeDownloadPath(String fileUrl) {
  final uri = Uri.tryParse(fileUrl);
  if (uri == null) {
    return '';
  }

  return uri.replace(query: '', fragment: '').toString();
}

int? _contentLengthFromHeaders(Headers headers) {
  final raw = headers.value(Headers.contentLengthHeader);
  if (raw == null || raw.trim().isEmpty) {
    return null;
  }

  final parsed = int.tryParse(raw.trim());
  return parsed != null && parsed >= 0 ? parsed : null;
}

Future<bool> saveBytesToDevice({
  required List<int> bytes,
  required String dialogTitle,
  required String fileName,
  List<String>? allowedExtensions,
}) async {
  final normalizedExtensions = _normalizeAllowedExtensions(allowedExtensions);
  final safeFileName = sanitizeFileName(
    fileName,
    fallback: 'petmagic_${DateTime.now().millisecondsSinceEpoch}',
  );
  final extension = extractFileExtension(safeFileName);
  if (normalizedExtensions != null &&
      extension != null &&
      !normalizedExtensions.contains(extension)) {
    return false;
  }

  if (kIsWeb) {
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(Uint8List.fromList(bytes), name: safeFileName)],
        title: dialogTitle,
      ),
    );
    return result.status == ShareResultStatus.success;
  }

  final tempFile = TempMediaCleanup.createScopedTempFile(safeFileName);
  await tempFile.writeAsBytes(bytes, flush: true);
  try {
    final result = await SharePlus.instance.share(
      ShareParams(files: [XFile(tempFile.path, name: safeFileName)]),
    );
    return result.status == ShareResultStatus.success;
  } finally {
    await TempMediaCleanup.deleteIfExists(tempFile);
  }
}

String extensionFromUrl(String value) {
  final uri = Uri.tryParse(value);
  final rawSegment = uri != null && uri.pathSegments.isNotEmpty
      ? uri.pathSegments.last
      : value;
  final segment = rawSegment.split('?').first;
  final dotIndex = segment.lastIndexOf('.');
  if (dotIndex <= 0 || dotIndex >= segment.length - 1) {
    return '';
  }

  return segment.substring(dotIndex + 1).toLowerCase();
}

String? extractFileExtension(String fileName) {
  final dotIndex = fileName.lastIndexOf('.');
  if (dotIndex <= 0 || dotIndex >= fileName.length - 1) {
    return null;
  }

  final extension = fileName.substring(dotIndex + 1).toLowerCase();
  return extension.isEmpty ? null : extension;
}

List<String>? _normalizeAllowedExtensions(List<String>? values) {
  if (values == null || values.isEmpty) {
    return null;
  }

  final normalized = values
      .map(
        (value) => value.trim().toLowerCase().replaceFirst(RegExp(r'^\.'), ''),
      )
      .where((value) => value.isNotEmpty)
      .toSet()
      .toList(growable: false);

  return normalized.isEmpty ? null : normalized;
}
