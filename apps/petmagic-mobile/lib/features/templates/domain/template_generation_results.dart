import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';

class TemplateGenerationGalleryPage {
  const TemplateGenerationGalleryPage({
    required this.items,
    required this.hasMore,
    required this.unreadCount,
    required this.appliedFilter,
    this.nextCursor,
    this.serverTimeUtc,
  });

  final List<TemplateGenerationResult> items;
  final String? nextCursor;
  final bool hasMore;
  final DateTime? serverTimeUtc;
  final int unreadCount;
  final String appliedFilter;
}

class RemoveGenerationWatermarkResult {
  const RemoveGenerationWatermarkResult({
    required this.watermarkRemoved,
    required this.creditsSpent,
    this.remainingCredits,
    this.mediaUrl,
  });

  final bool watermarkRemoved;
  final int creditsSpent;
  final int? remainingCredits;
  final String? mediaUrl;
}

class GenerationMediaAccessResult {
  const GenerationMediaAccessResult({
    required this.mediaUrl,
    required this.hasWatermark,
    required this.fileName,
    String? signedMediaUrl,
    this.shareUrl = '',
    this.shareToken = '',
    this.expiresAtUtc,
    this.contentType,
  }) : signedMediaUrl = signedMediaUrl ?? mediaUrl;

  final String mediaUrl;
  final String signedMediaUrl;
  final bool hasWatermark;
  final String fileName;
  final String shareUrl;
  final String shareToken;
  final DateTime? expiresAtUtc;
  final String? contentType;
}
