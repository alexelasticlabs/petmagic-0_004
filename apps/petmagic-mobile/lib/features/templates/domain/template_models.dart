enum TemplateType { image, video }

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
    required this.category,
    required this.tags,
    required this.isPremium,
    required this.tokenCost,
    this.effectivePromoBadge,
    this.previewAsset,
    this.musicDescription,
    this.referenceVideoDurationSeconds,
  });

  final String templateId;
  final TemplateType templateType;
  final String title;
  final String shortDescription;
  final String category;
  final List<String> tags;
  final bool isPremium;
  final int tokenCost;
  final String? effectivePromoBadge;
  final TemplateAsset? previewAsset;
  final String? musicDescription;
  final double? referenceVideoDurationSeconds;

  bool get isVideo => templateType == TemplateType.video;
}

class TemplatesFeedPage {
  const TemplatesFeedPage({
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });

  final List<TemplateItem> items;
  final String? nextCursor;
  final bool hasMore;
}

bool isVideoPreview(TemplateAsset? asset) {
  if (asset == null) return false;
  final contentType = asset.contentType.toLowerCase();
  final url = asset.url.toLowerCase();
  return contentType.startsWith('video/') ||
      url.endsWith('.mp4') ||
      url.endsWith('.webm') ||
      url.endsWith('.mov');
}

String formatDuration(double? durationSeconds) {
  if (durationSeconds == null || durationSeconds <= 0) return '0:00';
  final totalSeconds = durationSeconds.round();
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
