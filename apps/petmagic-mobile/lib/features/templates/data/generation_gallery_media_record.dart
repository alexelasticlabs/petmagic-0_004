import 'package:petmagic_mobile/features/templates/application/generation_gallery_cache.dart';
import 'package:petmagic_mobile/features/templates/domain/generation_media_kind.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/shared/files/persistent_media_url.dart';
import 'package:petmagic_mobile/shared/navigation/external_url_policy.dart';

const Object _copyWithUnset = Object();

class GenerationGalleryMediaRecord implements GenerationGalleryMediaRecordView {
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

  @override
  final String generationId;
  @override
  final String accountScope;
  @override
  final String userId;
  @override
  final String status;
  @override
  final String? templateTitle;
  @override
  final String? templateType;
  @override
  final DateTime updatedAtUtc;
  @override
  final String? previewRemoteUrl;
  @override
  final String? outputRemoteUrl;
  @override
  final String? previewLocalPath;
  @override
  final String? outputLocalPath;
  @override
  final bool isDeletedLocally;
  @override
  final bool isDownloadComplete;
  @override
  final DateTime lastSyncedAtUtc;
  @override
  final int version;
  @override
  final bool pendingServerDelete;
  final int materializationFailureCount;
  final DateTime? materializationBackoffUntilUtc;
  final String? materializationFailureCode;
  @override
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

  Map<String, dynamic> toJson({
    String? Function(String? path)? localPathMapper,
  }) {
    final mapLocalPath = localPathMapper ?? (String? path) => path;
    return {
      'generationId': generationId,
      'status': status,
      'templateTitle': templateTitle,
      'templateType': templateType,
      'updatedAtUtc': updatedAtUtc.toIso8601String(),
      'previewRemoteUrl': persistentSafeGenerationMediaUrl(previewRemoteUrl),
      'outputRemoteUrl': persistentSafeGenerationMediaUrl(outputRemoteUrl),
      'previewLocalPath': mapLocalPath(previewLocalPath),
      'outputLocalPath': mapLocalPath(outputLocalPath),
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

String? galleryPreviewUrl(TemplateGenerationResult generation) {
  final resultPreview = gallerySafeMediaUrl(generation.resultPreviewUrl);
  final output = gallerySafeMediaUrl(generation.outputUrl);
  final source = gallerySafeMediaUrl(generation.sourceImageAsset?.url);
  final normalized = gallerySafeMediaUrl(generation.normalizedImageUrl);
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

String? gallerySafeMediaUrl(String? raw) {
  return parseSafeGenerationMediaUri(raw)?.toString();
}

String galleryDownloadKey(String accountScope, String generationId) {
  return '$accountScope\u{1F}$generationId';
}
