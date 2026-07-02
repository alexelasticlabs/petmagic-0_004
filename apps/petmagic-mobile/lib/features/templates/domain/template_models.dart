enum TemplateType { image, video }

enum TemplateRandomMode { any, image, video }

enum TemplateRandomAccess { available, free, premium }

class TemplateOfTheDayItem {
  const TemplateOfTheDayItem({
    required this.templateId,
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.templateType,
    required this.isPremium,
    required this.requiredPlan,
    required this.date,
    required this.source,
    this.category = '',
    this.tags = const [],
    this.tokenCost = 0,
    this.thumbnailUrl,
    this.previewMediaUrl,
    this.previewAsset,
    this.isNew = false,
    this.popularityCount,
    this.expiresAtUtc,
  });

  final String templateId;
  final String title;
  final String subtitle;
  final String badgeText;
  final TemplateType templateType;
  final String? thumbnailUrl;
  final String? previewMediaUrl;
  final bool isPremium;
  final String requiredPlan;
  final DateTime date;
  final String source;
  final String category;
  final List<String> tags;
  final int tokenCost;
  final TemplateAsset? previewAsset;
  final bool isNew;
  final int? popularityCount;
  final DateTime? expiresAtUtc;

  bool get isVideo => templateType == TemplateType.video;

  TemplateItem toFallbackTemplateItem() {
    final previewUrl = previewMediaUrl?.trim();
    final resolvedPreviewAsset =
        previewAsset ??
        (previewUrl == null || previewUrl.isEmpty
            ? null
            : TemplateAsset(
                url: previewUrl,
                fileName: previewUrl.split('/').last,
                contentType: isVideo ? 'video/mp4' : 'image/jpeg',
              ));
    return TemplateItem(
      templateId: templateId,
      templateType: templateType,
      title: title,
      shortDescription: subtitle,
      petPhotoRequirements: const [],
      category: category,
      tags: tags,
      isPremium: isPremium,
      tokenCost: tokenCost,
      effectivePromoBadge: badgeText,
      thumbnailUrl: thumbnailUrl,
      previewAsset: resolvedPreviewAsset,
      supportsGenerateSimilar: false,
    );
  }
}

extension TemplateTypeApi on TemplateType {
  String get apiValue => switch (this) {
    TemplateType.image => 'Image',
    TemplateType.video => 'Video',
  };
}

TemplateType templateTypeFromApi(String value) =>
    value.toLowerCase() == 'video' ? TemplateType.video : TemplateType.image;

class TemplateAsset {
  const TemplateAsset({
    required this.url,
    required this.fileName,
    required this.contentType,
    this.fileSizeBytes,
    this.durationSeconds,
  });

  final String url;
  final String fileName;
  final String contentType;
  final int? fileSizeBytes;
  final double? durationSeconds;
}

class TemplateItem {
  const TemplateItem({
    required this.templateId,
    required this.templateType,
    required this.title,
    required this.shortDescription,
    required this.petPhotoRequirements,
    required this.category,
    required this.tags,
    required this.isPremium,
    required this.tokenCost,
    this.effectivePromoBadge,
    this.thumbnailUrl,
    this.animatedPreviewUrl,
    this.feedLoopLowUrl,
    this.feedLoopMediumUrl,
    this.detailPreviewUrl,
    this.mediaKind,
    this.durationMs,
    this.sizeBytes,
    this.mediaVersion,
    this.previewAsset,
    this.musicDescription,
    this.referenceVideoDurationSeconds,
    this.supportsGenerationResultInput = false,
    this.requiredInputMediaType,
    this.recommendedAfterImageGeneration = false,
    this.supportsGenerateSimilar = true,
    this.defaultVariationStrength = 'medium',
    this.version = 0,
    this.updatedAtUtc,
  });

  final String templateId;
  final TemplateType templateType;
  final String title;
  final String shortDescription;
  final List<String> petPhotoRequirements;
  final String category;
  final List<String> tags;
  final bool isPremium;
  final int tokenCost;
  final String? effectivePromoBadge;
  final String? thumbnailUrl;
  final String? animatedPreviewUrl;
  final String? feedLoopLowUrl;
  final String? feedLoopMediumUrl;
  final String? detailPreviewUrl;
  final String? mediaKind;
  final int? durationMs;
  final int? sizeBytes;
  final int? mediaVersion;
  final TemplateAsset? previewAsset;
  final String? musicDescription;
  final double? referenceVideoDurationSeconds;
  final bool supportsGenerationResultInput;
  final TemplateType? requiredInputMediaType;
  final bool recommendedAfterImageGeneration;
  final bool supportsGenerateSimilar;
  final String defaultVariationStrength;
  final int version;
  final DateTime? updatedAtUtc;

  bool get isVideo => templateType == TemplateType.video;

  String get mediaIdentity {
    final thumbnail = thumbnailUrl?.trim() ?? '';
    final animated = animatedPreviewUrl?.trim() ?? '';
    final feedLow = feedLoopLowUrl?.trim() ?? '';
    final feedMedium = feedLoopMediumUrl?.trim() ?? '';
    final detail = detailPreviewUrl?.trim() ?? '';
    final previewUrl = previewAsset?.url.trim() ?? '';
    final previewContentType = previewAsset?.contentType.trim() ?? '';
    return '$thumbnail|$animated|$feedLow|$feedMedium|$detail|$previewUrl|$previewContentType|${mediaVersion ?? 0}';
  }

  List<String> get effectivePetPhotoRequirements {
    final normalized = petPhotoRequirements
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (normalized.isNotEmpty) {
      return normalized;
    }

    return isVideo
        ? const [
            'Full body visible',
            'Pet facing camera',
            'No cropped head or legs',
          ]
        : const ['One pet in the photo', 'Clear face', 'Good lighting'];
  }
}

class TemplatesFeedPage {
  const TemplatesFeedPage({
    required this.items,
    required this.hasMore,
    this.nextCursor,
    this.page = 1,
  });

  final List<TemplateItem> items;
  final bool hasMore;
  final String? nextCursor;
  final int page;
}

class TemplatesCatalogChanges {
  const TemplatesCatalogChanges({
    required this.fromVersion,
    required this.toVersion,
    required this.upserts,
    required this.deletedIds,
    required this.needsFullResync,
  });

  final int fromVersion;
  final int toVersion;
  final List<TemplateItem> upserts;
  final List<String> deletedIds;
  final bool needsFullResync;
}

bool isVideoPreview(TemplateAsset? asset) {
  if (asset == null) return false;
  final contentType = asset.contentType.toLowerCase();
  return contentType.startsWith('video/') ||
      isVideoUrl(asset.url) ||
      isVideoUrl(asset.fileName);
}

bool isVideoUrl(String? rawUrl) {
  if (rawUrl == null || rawUrl.trim().isEmpty) {
    return false;
  }

  final normalized = rawUrl.trim().toLowerCase();
  final uri = Uri.tryParse(normalized);
  final path = (uri?.path ?? normalized).toLowerCase();
  final query = (uri?.query ?? '').toLowerCase();

  return path.endsWith('.mp4') ||
      path.endsWith('.webm') ||
      path.endsWith('.mov') ||
      path.endsWith('.m4v') ||
      normalized.contains('.mp4?') ||
      normalized.contains('.webm?') ||
      normalized.contains('.mov?') ||
      normalized.contains('.m4v?') ||
      query.contains('format=mp4') ||
      query.contains('ext=mp4') ||
      query.contains('contenttype=video');
}

String formatDuration(double? durationSeconds) {
  if (durationSeconds == null || durationSeconds <= 0) return '0:00';
  final totalSeconds = durationSeconds.round();
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
