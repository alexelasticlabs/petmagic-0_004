part of 'generation_gallery_store.dart';

const Object _copyWithUnset = Object();

class GenerationGalleryMediaRecord {
  const GenerationGalleryMediaRecord({
    required this.generationId,
    required this.accountScope,
    required this.userId,
    required this.status,
    required this.updatedAtUtc,
    required this.lastSyncedAtUtc,
    required this.version,
    this.templateTitle,
    this.templateType,
    this.previewRemoteUrl,
    this.outputRemoteUrl,
    this.previewLocalPath,
    this.outputLocalPath,
    this.isDeletedLocally = false,
    this.isDownloadComplete = false,
    this.pendingServerDelete = false,
    this.materializationFailureCount = 0,
    this.materializationBackoffUntilUtc,
    this.materializationFailureCode,
    this.localBytes = 0,
  });

  final String generationId;
  final String accountScope;
  final String userId;
  final String status;
  final String? templateTitle;
  final String? templateType;
  final DateTime updatedAtUtc;
  final String? previewRemoteUrl;
  final String? outputRemoteUrl;
  final String? previewLocalPath;
  final String? outputLocalPath;
  final bool isDeletedLocally;
  final bool isDownloadComplete;
  final DateTime lastSyncedAtUtc;
  final int version;
  final bool pendingServerDelete;
  final int materializationFailureCount;
  final DateTime? materializationBackoffUntilUtc;
  final String? materializationFailureCode;
  final int localBytes;

  GenerationGalleryMediaRecord copyWith({
    Object? previewLocalPath = _copyWithUnset,
    Object? outputLocalPath = _copyWithUnset,
    bool? isDeletedLocally,
    bool? isDownloadComplete,
    DateTime? lastSyncedAtUtc,
    int? version,
    bool? pendingServerDelete,
    int? materializationFailureCount,
    Object? materializationBackoffUntilUtc = _copyWithUnset,
    Object? materializationFailureCode = _copyWithUnset,
    int? localBytes,
  }) {
    return GenerationGalleryMediaRecord(
      generationId: generationId,
      accountScope: accountScope,
      userId: userId,
      status: status,
      updatedAtUtc: updatedAtUtc,
      lastSyncedAtUtc: lastSyncedAtUtc ?? this.lastSyncedAtUtc,
      version: version ?? this.version,
      templateTitle: templateTitle,
      templateType: templateType,
      previewRemoteUrl: previewRemoteUrl,
      outputRemoteUrl: outputRemoteUrl,
      previewLocalPath: identical(previewLocalPath, _copyWithUnset)
          ? this.previewLocalPath
          : previewLocalPath as String?,
      outputLocalPath: identical(outputLocalPath, _copyWithUnset)
          ? this.outputLocalPath
          : outputLocalPath as String?,
      isDeletedLocally: isDeletedLocally ?? this.isDeletedLocally,
      isDownloadComplete: isDownloadComplete ?? this.isDownloadComplete,
      pendingServerDelete: pendingServerDelete ?? this.pendingServerDelete,
      materializationFailureCount:
          materializationFailureCount ?? this.materializationFailureCount,
      materializationBackoffUntilUtc:
          identical(materializationBackoffUntilUtc, _copyWithUnset)
          ? this.materializationBackoffUntilUtc
          : materializationBackoffUntilUtc as DateTime?,
      materializationFailureCode:
          identical(materializationFailureCode, _copyWithUnset)
          ? this.materializationFailureCode
          : materializationFailureCode as String?,
      localBytes: localBytes ?? this.localBytes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'generationId': generationId,
      'status': status,
      'templateTitle': templateTitle,
      'templateType': templateType,
      'updatedAtUtc': updatedAtUtc.toIso8601String(),
      'previewRemoteUrl': persistentSafeGenerationMediaUrl(previewRemoteUrl),
      'outputRemoteUrl': persistentSafeGenerationMediaUrl(outputRemoteUrl),
      'previewLocalPath': previewLocalPath,
      'outputLocalPath': outputLocalPath,
      'isDeletedLocally': isDeletedLocally,
      'isDownloadComplete': isDownloadComplete,
      'lastSyncedAtUtc': lastSyncedAtUtc.toIso8601String(),
      'version': version,
      'pendingServerDelete': pendingServerDelete,
      'materializationFailureCount': materializationFailureCount,
      'materializationBackoffUntilUtc': materializationBackoffUntilUtc
          ?.toIso8601String(),
      'materializationFailureCode': materializationFailureCode,
      'localBytes': localBytes,
    };
  }

  factory GenerationGalleryMediaRecord.fromJson(
    Map<String, dynamic> json, {
    String? accountScope,
  }) {
    final resolvedAccountScope =
        accountScope ?? json['accountScope'] as String? ?? '';
    return GenerationGalleryMediaRecord(
      generationId: json['generationId'] as String? ?? '',
      accountScope: resolvedAccountScope,
      userId: json['userId'] as String? ?? resolvedAccountScope,
      status: json['status'] as String? ?? '',
      templateTitle: json['templateTitle'] as String?,
      templateType: json['templateType'] as String?,
      updatedAtUtc:
          DateTime.tryParse(json['updatedAtUtc'] as String? ?? '')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      previewRemoteUrl: persistentSafeGenerationMediaUrl(
        json['previewRemoteUrl'] as String?,
      ),
      outputRemoteUrl: persistentSafeGenerationMediaUrl(
        json['outputRemoteUrl'] as String?,
      ),
      previewLocalPath: json['previewLocalPath'] as String?,
      outputLocalPath: json['outputLocalPath'] as String?,
      isDeletedLocally: json['isDeletedLocally'] as bool? ?? false,
      isDownloadComplete: json['isDownloadComplete'] as bool? ?? false,
      lastSyncedAtUtc:
          DateTime.tryParse(
            json['lastSyncedAtUtc'] as String? ?? '',
          )?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      version: (json['version'] as num?)?.toInt() ?? 0,
      pendingServerDelete: json['pendingServerDelete'] as bool? ?? false,
      materializationFailureCount:
          (json['materializationFailureCount'] as num?)?.toInt() ?? 0,
      materializationBackoffUntilUtc: DateTime.tryParse(
        json['materializationBackoffUntilUtc'] as String? ?? '',
      )?.toUtc(),
      materializationFailureCode: json['materializationFailureCode'] as String?,
      localBytes: (json['localBytes'] as num?)?.toInt() ?? 0,
    );
  }
}

String? _previewUrl(TemplateGenerationResult generation) {
  final resultPreview = _safeMediaUrl(generation.resultPreviewUrl);
  final output = _safeMediaUrl(generation.outputUrl);
  final source = _safeMediaUrl(generation.sourceImageAsset?.url);
  final normalized = _safeMediaUrl(generation.normalizedImageUrl);
  final generationIsVideo = isVideoGenerationResult(generation);

  if (resultPreview != null && !isLikelyGenerationVideoUrl(resultPreview)) {
    return resultPreview;
  }

  if (generationIsVideo) {
    if (source != null) {
      return source;
    }
    if (normalized != null) {
      return normalized;
    }
    return output != null && isLikelyGenerationImageUrl(output) ? output : null;
  }

  if (output != null && !isLikelyGenerationVideoUrl(output)) {
    return output;
  }
  if (source != null) {
    return source;
  }
  if (normalized != null) {
    return normalized;
  }
  return null;
}

String? _safeMediaUrl(String? raw) {
  return parseSafeGenerationMediaUri(raw)?.toString();
}

String _stableUrlStamp(String value) {
  var hash = 0x811c9dc5;
  for (final codeUnit in value.codeUnits) {
    hash = (hash ^ codeUnit) & 0xffffffff;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

String _safePathSegment(String value, {required String fallback}) {
  final trimmed = value.trim();
  final sanitized = sanitizeFileName(trimmed, fallback: fallback);
  final isSpecialDirectory = sanitized == '.' || sanitized == '..';
  if (!isSpecialDirectory && sanitized == trimmed && sanitized.length <= 80) {
    return sanitized;
  }

  final base = isSpecialDirectory ? fallback : sanitized;
  final boundedBase = base.length <= 80 ? base : base.substring(0, 80);
  return '${boundedBase}_${_stableUrlStamp(trimmed)}';
}

String _downloadKey(String accountScope, String generationId) {
  return '$accountScope\u{1F}$generationId';
}

String _basename(String path) {
  final parts = path.split(Platform.pathSeparator);
  return parts.isEmpty ? path : parts.last;
}
