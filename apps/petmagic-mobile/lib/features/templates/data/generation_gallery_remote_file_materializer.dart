import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:petmagic_mobile/features/templates/data/generation_gallery_file_storage.dart';
import 'package:petmagic_mobile/shared/files/device_file_saver.dart';
import 'package:petmagic_mobile/shared/files/file_name_sanitizer.dart';
import 'package:petmagic_mobile/shared/navigation/external_url_policy.dart';

class GenerationGalleryMaterializeFileResult {
  const GenerationGalleryMaterializeFileResult({
    this.file,
    this.downloadedBytes = 0,
    this.failureCode,
    this.shouldBackoff = false,
  });

  final File? file;
  final int downloadedBytes;
  final String? failureCode;
  final bool shouldBackoff;
}

/// Downloads one gallery media file under explicit background byte budgets.
class GenerationGalleryRemoteFileMaterializer {
  const GenerationGalleryRemoteFileMaterializer({
    required Dio dio,
    required int maxBackgroundFileBytes,
  }) : _dio = dio,
       _maxBackgroundFileBytes = maxBackgroundFileBytes;

  final Dio _dio;
  final int _maxBackgroundFileBytes;

  Future<GenerationGalleryMaterializeFileResult> materialize({
    required String remoteUrl,
    required Directory targetDirectory,
    required String prefix,
    required String fallbackExtension,
    required CancelToken cancelToken,
    required bool background,
    required int remainingBackgroundBytes,
  }) async {
    final safeUri = parseSafeGenerationMediaUri(remoteUrl);
    if (safeUri == null) {
      return const GenerationGalleryMaterializeFileResult(
        failureCode: 'unsafe_url',
      );
    }
    if (background && remainingBackgroundBytes <= 0) {
      return const GenerationGalleryMaterializeFileResult(
        failureCode: 'background_byte_budget_exceeded',
      );
    }

    final resolvedExtension = extensionFromUrl(safeUri.toString());
    final extension = resolvedExtension.trim().isEmpty
        ? fallbackExtension
        : resolvedExtension;
    final urlStamp = _stableUrlStamp(safeUri.toString());
    final fileName = sanitizeFileName(
      '${prefix}_$urlStamp.$extension',
      fallback: '${prefix}_$urlStamp.$fallbackExtension',
    );
    final targetFile = File(
      '${targetDirectory.path}${Platform.pathSeparator}$fileName',
    );
    if (await GenerationGalleryFileStorage.hasUsableFile(targetFile)) {
      await GenerationGalleryFileStorage.deleteStaleFilesForPrefix(
        targetDirectory,
        prefix,
        targetFile,
      );
      return GenerationGalleryMaterializeFileResult(file: targetFile);
    }

    final tempFile = File('${targetFile.path}.part');
    if (await tempFile.exists()) {
      await tempFile.delete();
    }
    final limit = background
        ? math.min(_maxBackgroundFileBytes, remainingBackgroundBytes)
        : null;
    final limitedResult = await _download(
      safeUri: safeUri,
      tempFile: tempFile,
      cancelToken: cancelToken,
      byteLimit: limit,
    );
    if (limitedResult != null) {
      return limitedResult;
    }

    final downloadedBytes = await GenerationGalleryFileStorage.fileSize(
      tempFile,
    );
    final budgetFailure = _backgroundBudgetFailure(
      background: background,
      downloadedBytes: downloadedBytes,
      remainingBackgroundBytes: remainingBackgroundBytes,
    );
    if (budgetFailure != null) {
      await _deleteIfExists(tempFile);
      return GenerationGalleryMaterializeFileResult(
        downloadedBytes: downloadedBytes,
        failureCode: budgetFailure,
      );
    }
    if (!await GenerationGalleryFileStorage.hasUsableFile(tempFile)) {
      await _deleteIfExists(tempFile);
      return GenerationGalleryMaterializeFileResult(
        downloadedBytes: downloadedBytes,
        failureCode: downloadedBytes <= 0 ? 'empty_download' : 'invalid_media',
        shouldBackoff: true,
      );
    }

    await _deleteIfExists(targetFile);
    await tempFile.rename(targetFile.path);
    await GenerationGalleryFileStorage.deleteStaleFilesForPrefix(
      targetDirectory,
      prefix,
      targetFile,
    );
    return GenerationGalleryMaterializeFileResult(
      file: targetFile,
      downloadedBytes: downloadedBytes,
    );
  }

  Future<GenerationGalleryMaterializeFileResult?> _download({
    required Uri safeUri,
    required File tempFile,
    required CancelToken cancelToken,
    required int? byteLimit,
  }) async {
    var receivedBytes = 0;
    String? limitFailureCode;
    try {
      await _dio.downloadUri(
        safeUri,
        tempFile.path,
        cancelToken: cancelToken,
        deleteOnError: true,
        options: Options(responseType: ResponseType.bytes),
        onReceiveProgress: byteLimit == null
            ? null
            : (received, total) {
                receivedBytes = math.max(receivedBytes, received);
                final exceedsDeclaredLimit = total > 0 && total > byteLimit;
                if ((!exceedsDeclaredLimit && received <= byteLimit) ||
                    cancelToken.isCancelled) {
                  return;
                }
                limitFailureCode = byteLimit == _maxBackgroundFileBytes
                    ? 'background_file_too_large'
                    : 'background_byte_budget_exceeded';
                cancelToken.cancel(limitFailureCode);
              },
      );
      return null;
    } on Object {
      if (limitFailureCode == null) {
        rethrow;
      }
      await _deleteIfExists(tempFile);
      return GenerationGalleryMaterializeFileResult(
        downloadedBytes: receivedBytes,
        failureCode: limitFailureCode,
      );
    }
  }

  String? _backgroundBudgetFailure({
    required bool background,
    required int downloadedBytes,
    required int remainingBackgroundBytes,
  }) {
    if (!background) {
      return null;
    }
    if (downloadedBytes > _maxBackgroundFileBytes) {
      return 'background_file_too_large';
    }
    if (downloadedBytes > remainingBackgroundBytes) {
      return 'background_byte_budget_exceeded';
    }
    return null;
  }

  static Future<void> _deleteIfExists(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } on Object {
      // Dio may already have removed a partial file after cancellation.
    }
  }

  static String _stableUrlStamp(String value) {
    var hash = 0x811c9dc5;
    for (final codeUnit in value.codeUnits) {
      hash = (hash ^ codeUnit) & 0xffffffff;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}
