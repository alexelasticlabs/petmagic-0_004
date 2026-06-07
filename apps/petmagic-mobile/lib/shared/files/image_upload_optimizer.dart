import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:petmagic_mobile/shared/files/file_name_sanitizer.dart';

class OptimizedUploadFile {
  const OptimizedUploadFile._(this.file, this._temporaryPath);

  factory OptimizedUploadFile.original(XFile file) =>
      OptimizedUploadFile._(file, null);

  factory OptimizedUploadFile.temporary(XFile file) =>
      OptimizedUploadFile._(file, file.path);

  final XFile file;
  final String? _temporaryPath;

  bool get isTemporary => _temporaryPath != null;

  Future<void> dispose() async {
    final temporaryPath = _temporaryPath;
    if (temporaryPath == null) {
      return;
    }

    try {
      final file = File(temporaryPath);
      if (await file.exists()) {
        await file.delete();
      }
    } on FileSystemException {
      // Temp-file cleanup should never mask the user-facing upload result.
    }
  }
}

class ImageUploadOptimizer {
  const ImageUploadOptimizer({
    this.minInputBytes = 768 * 1024,
    this.maxDimension = 1600,
    this.jpegQuality = 88,
  });

  final int minInputBytes;
  final int maxDimension;
  final int jpegQuality;

  Future<OptimizedUploadFile> optimizeGenerationSource(
    XFile source, {
    CancelToken? cancelToken,
  }) async {
    if (minInputBytes <= 0 || maxDimension <= 0 || jpegQuality <= 0) {
      return OptimizedUploadFile.original(source);
    }

    _throwIfCancelled(cancelToken);

    late final int sourceBytesLength;
    late final Uint8List sourceBytes;
    try {
      final sourceFile = File(source.path);
      sourceBytesLength = await sourceFile.length();
      if (sourceBytesLength < minInputBytes) {
        return OptimizedUploadFile.original(source);
      }
      sourceBytes = await sourceFile.readAsBytes();
    } on FileSystemException {
      return OptimizedUploadFile.original(source);
    }
    _throwIfCancelled(cancelToken);

    final optimizedBytes = await compute(_optimizeImageBytes, <String, Object>{
      'bytes': sourceBytes,
      'maxDimension': maxDimension,
      'jpegQuality': jpegQuality.clamp(1, 100),
    });
    _throwIfCancelled(cancelToken);

    if (optimizedBytes == null || optimizedBytes.length >= sourceBytesLength) {
      return OptimizedUploadFile.original(source);
    }

    final outputPath =
        '${Directory.systemTemp.path}${Platform.pathSeparator}'
        'petmagic_generation_${DateTime.now().microsecondsSinceEpoch}.jpg';
    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(optimizedBytes, flush: true);

    final outputName = _optimizedFileName(source);
    return OptimizedUploadFile.temporary(
      XFile(outputPath, name: outputName, mimeType: 'image/jpeg'),
    );
  }

  String _optimizedFileName(XFile source) {
    final rawName = source.name.trim().isNotEmpty
        ? source.name
        : source.path.split(Platform.pathSeparator).last;
    final basename = rawName
        .replaceAll(r'\', '/')
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .lastOrNull;
    final sanitized = sanitizeFileName(
      basename,
      fallback: 'petmagic_source_image',
    );
    final withoutExtension = sanitized.replaceFirst(RegExp(r'\.[^.]*$'), '');
    return '${withoutExtension.isEmpty ? 'petmagic_source_image' : withoutExtension}.jpg';
  }
}

Uint8List? _optimizeImageBytes(Map<String, Object> payload) {
  final bytes = payload['bytes']! as Uint8List;
  final maxDimension = payload['maxDimension']! as int;
  final jpegQuality = payload['jpegQuality']! as int;

  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    return null;
  }

  final longestSide = math.max(decoded.width, decoded.height);
  final shouldResize = longestSide > maxDimension;
  final prepared = shouldResize
      ? img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? maxDimension : null,
          height: decoded.height > decoded.width ? maxDimension : null,
          interpolation: img.Interpolation.average,
        )
      : decoded;

  return Uint8List.fromList(img.encodeJpg(prepared, quality: jpegQuality));
}

void _throwIfCancelled(CancelToken? cancelToken) {
  if (cancelToken?.isCancelled ?? false) {
    throw DioException(
      requestOptions: RequestOptions(path: ''),
      type: DioExceptionType.cancel,
      error: 'request_cancelled',
    );
  }
}
