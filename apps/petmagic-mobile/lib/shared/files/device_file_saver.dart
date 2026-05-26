import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

Future<List<int>> downloadFileBytes(String fileUrl, {Dio? client}) async {
  final httpClient = client ?? Dio();
  final response = await httpClient.get<List<int>>(
    fileUrl,
    options: Options(responseType: ResponseType.bytes),
  );
  final bytes = response.data;
  if (bytes == null || bytes.isEmpty) {
    throw StateError('Empty download payload.');
  }

  return bytes;
}

Future<bool> saveBytesToDevice({
  required List<int> bytes,
  required String dialogTitle,
  required String fileName,
  List<String>? allowedExtensions,
}) async {
  final normalizedExtensions = _normalizeAllowedExtensions(allowedExtensions);
  final targetPath = await FilePicker.platform.saveFile(
    dialogTitle: dialogTitle,
    fileName: fileName,
    type: normalizedExtensions == null ? FileType.any : FileType.custom,
    allowedExtensions: normalizedExtensions,
    bytes: Uint8List.fromList(bytes),
  );

  if (kIsWeb) {
    return true;
  }

  return targetPath != null && targetPath.trim().isNotEmpty;
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
