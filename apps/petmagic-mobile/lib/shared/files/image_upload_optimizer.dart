import 'dart:io';
import 'dart:math' as math;

import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/operations/request_cancellation.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
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
    this.generationSourceProfile = generationSourceDefaults,
    this.avatarProfile = avatarDefaults,
    this.petPhotoProfile = petPhotoDefaults,
    this.supportImageProfile = supportImageDefaults,
  });

  static const ImageUploadOptimizationProfile generationSourceDefaults =
      ImageUploadOptimizationProfile(
        logProfileName: 'generation_source',
        minInputBytes: 768 * 1024,
        maxDimension: 1600,
        jpegQuality: 88,
      );

  static const ImageUploadOptimizationProfile avatarDefaults =
      ImageUploadOptimizationProfile(
        logProfileName: 'avatar',
        minInputBytes: 1,
        maxDimension: 1200,
        jpegQuality: 92,
      );

  static const ImageUploadOptimizationProfile petPhotoDefaults =
      ImageUploadOptimizationProfile(
        logProfileName: 'pet_photo',
        minInputBytes: 768 * 1024,
        maxDimension: 2048,
        jpegQuality: 88,
      );

  static const ImageUploadOptimizationProfile supportImageDefaults =
      ImageUploadOptimizationProfile(
        logProfileName: 'support_image',
        minInputBytes: 512 * 1024,
        maxDimension: 1800,
        jpegQuality: 86,
      );

  final ImageUploadOptimizationProfile generationSourceProfile;
  final ImageUploadOptimizationProfile avatarProfile;
  final ImageUploadOptimizationProfile petPhotoProfile;
  final ImageUploadOptimizationProfile supportImageProfile;

  Future<OptimizedUploadFile> optimizeGenerationSource(
    XFile source, {
    RequestCancellation? cancelToken,
  }) async {
    return _optimizeImageFile(
      source,
      profile: generationSourceProfile,
      cancelToken: cancelToken,
    );
  }

  Future<OptimizedUploadFile> optimizeForAvatar(
    XFile source, {
    RequestCancellation? cancelToken,
  }) async {
    return _optimizeImageFile(
      source,
      profile: avatarProfile,
      cancelToken: cancelToken,
    );
  }

  Future<OptimizedUploadFile> optimizeForPetPhoto(
    XFile source, {
    RequestCancellation? cancelToken,
  }) async {
    return _optimizeImageFile(
      source,
      profile: petPhotoProfile,
      cancelToken: cancelToken,
    );
  }

  Future<OptimizedUploadFile> optimizeForSupportImage(
    XFile source, {
    RequestCancellation? cancelToken,
  }) async {
    return _optimizeImageFile(
      source,
      profile: supportImageProfile,
      cancelToken: cancelToken,
    );
  }

  Future<OptimizedUploadFile> _optimizeImageFile(
    XFile source, {
    required ImageUploadOptimizationProfile profile,
    RequestCancellation? cancelToken,
  }) async {
    if (!profile.isEnabled) {
      _logSkippedOptimization(profile: profile, reason: 'profile_disabled');
      return OptimizedUploadFile.original(source);
    }

    _throwIfCancelled(cancelToken);

    late final int sourceBytesLength;
    late final Uint8List sourceBytes;
    try {
      final sourceFile = File(source.path);
      sourceBytesLength = await sourceFile.length();
      if (sourceBytesLength < profile.minInputBytes) {
        _logSkippedOptimization(
          profile: profile,
          reason: 'below_threshold',
          originalBytes: sourceBytesLength,
        );
        return OptimizedUploadFile.original(source);
      }
      sourceBytes = await sourceFile.readAsBytes();
    } on FileSystemException {
      _logSkippedOptimization(profile: profile, reason: 'read_failed');
      return OptimizedUploadFile.original(source);
    }
    _throwIfCancelled(cancelToken);

    final optimizedBytes = await compute(_optimizeImageBytes, <String, Object>{
      'bytes': sourceBytes,
      'maxDimension': profile.maxDimension,
      'jpegQuality': profile.jpegQuality.clamp(1, 100),
    });
    _throwIfCancelled(cancelToken);

    if (optimizedBytes == null) {
      _logSkippedOptimization(
        profile: profile,
        reason: 'decode_failed',
        originalBytes: sourceBytesLength,
      );
      return OptimizedUploadFile.original(source);
    }

    if (optimizedBytes.length >= sourceBytesLength) {
      _logSkippedOptimization(
        profile: profile,
        reason: 'no_size_gain',
        originalBytes: sourceBytesLength,
        optimizedBytes: optimizedBytes.length,
      );
      return OptimizedUploadFile.original(source);
    }

    final outputPath =
        '${Directory.systemTemp.path}${Platform.pathSeparator}'
        'petmagic_${_safeTempProfileName(profile.logProfileName)}_${DateTime.now().microsecondsSinceEpoch}.jpg';
    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(optimizedBytes, flush: true);

    final outputName = _optimizedFileName(source);
    AppLogger.info(
      feature: 'Media.Upload',
      operation: 'optimize_image',
      message: 'Image upload optimized before transfer',
      context: {
        'profile': profile.logProfileName,
        'original_bytes': sourceBytesLength,
        'optimized_bytes': optimizedBytes.length,
      },
    );
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

  String _safeTempProfileName(String profileName) {
    final basename = profileName
        .replaceAll(r'\', '/')
        .split('/')
        .where((segment) => segment.trim().isNotEmpty)
        .lastOrNull;
    final sanitized = sanitizeFileName(basename, fallback: 'upload');
    final normalized = sanitized.replaceAll(RegExp(r'^\.+$'), '');
    return normalized.isEmpty ? 'upload' : normalized;
  }

  void _logSkippedOptimization({
    required ImageUploadOptimizationProfile profile,
    required String reason,
    int? originalBytes,
    int? optimizedBytes,
  }) {
    AppLogger.info(
      feature: 'Media.Upload',
      operation: 'skip_image_optimization',
      message: 'Image upload kept original payload',
      context: {
        'profile': profile.logProfileName,
        'reason': reason,
        'original_bytes': ?originalBytes,
        'optimized_bytes': ?optimizedBytes,
      },
    );
  }
}

class ImageUploadOptimizationProfile {
  const ImageUploadOptimizationProfile({
    required this.logProfileName,
    required this.minInputBytes,
    required this.maxDimension,
    required this.jpegQuality,
  });

  final String logProfileName;
  final int minInputBytes;
  final int maxDimension;
  final int jpegQuality;

  bool get isEnabled =>
      minInputBytes > 0 && maxDimension > 0 && jpegQuality > 0;
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

Uint8List? optimizeAvatarCropBytes(Map<String, Object> request) {
  final sourceBytes = request['bytes'];
  final x = request['x'];
  final y = request['y'];
  final size = request['size'];
  if (sourceBytes is! Uint8List || x is! int || y is! int || size is! int) {
    return null;
  }

  final decodedSource = img.decodeImage(sourceBytes);
  if (decodedSource == null) {
    return null;
  }

  final decoded = img.bakeOrientation(decodedSource);
  final clampedX = x.clamp(0, decoded.width - 1);
  final clampedY = y.clamp(0, decoded.height - 1);
  final maxWidth = decoded.width - clampedX;
  final maxHeight = decoded.height - clampedY;
  final cropSize = math.max(1, math.min(size, math.min(maxWidth, maxHeight)));
  final cropped = img.copyCrop(
    decoded,
    x: clampedX,
    y: clampedY,
    width: cropSize,
    height: cropSize,
  );
  final resized = img.copyResize(
    cropped,
    width: ImageUploadOptimizer.avatarDefaults.maxDimension,
    height: ImageUploadOptimizer.avatarDefaults.maxDimension,
    interpolation: img.Interpolation.cubic,
  );

  return Uint8List.fromList(
    img.encodeJpg(
      resized,
      quality: ImageUploadOptimizer.avatarDefaults.jpegQuality,
    ),
  );
}

void _throwIfCancelled(RequestCancellation? cancelToken) {
  if (cancelToken?.isCancelled ?? false) {
    throw const RequestCancelledException();
  }
}
