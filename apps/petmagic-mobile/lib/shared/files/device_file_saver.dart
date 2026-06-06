import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

Future<List<int>> downloadFileBytes(
  String fileUrl, {
  Dio? client,
  Duration timeout = const Duration(seconds: 20),
  CancelToken? cancelToken,
}) async {
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
    final response = await httpClient.get<List<int>>(
      fileUrl,
      cancelToken: cancelToken,
      options: Options(
        responseType: ResponseType.bytes,
        receiveTimeout: timeout,
        sendTimeout: timeout,
      ),
    );
    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Empty download payload.');
    }

    return bytes;
  } finally {
    if (ownsClient) {
      httpClient.close(force: true);
    }
  }
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

  final tempFile = File(
    '${Directory.systemTemp.path}${Platform.pathSeparator}petmagic_$safeFileName',
  );
  await tempFile.writeAsBytes(bytes, flush: true);
  try {
    final result = await SharePlus.instance.share(
      ShareParams(files: [XFile(tempFile.path, name: safeFileName)]),
    );
    return result.status == ShareResultStatus.success;
  } finally {
    if (await tempFile.exists()) {
      await tempFile.delete();
    }
  }
}

String sanitizeFileName(String? value, {required String fallback}) {
  final candidate = value?.trim();
  if (candidate == null || candidate.isEmpty) {
    return fallback;
  }

  final normalized = candidate
      .replaceAll(RegExp(r'\s+'), '_')
      .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');

  return normalized.isEmpty ? fallback : normalized;
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
