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

  factory RemoveGenerationWatermarkResult.fromJson(Map<String, dynamic> json) {
    return RemoveGenerationWatermarkResult(
      watermarkRemoved: json['watermarkRemoved'] as bool? ?? false,
      creditsSpent: (json['creditsSpent'] as num?)?.toInt() ?? 0,
      remainingCredits: (json['remainingCredits'] as num?)?.toInt(),
      mediaUrl: json['mediaUrl'] as String?,
    );
  }
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

  factory GenerationMediaAccessResult.fromJson(Map<String, dynamic> json) {
    final signedMediaUrl =
        (json['signedMediaUrl'] as String?) ??
        (json['mediaUrl'] as String?) ??
        '';
    return GenerationMediaAccessResult(
      mediaUrl: signedMediaUrl,
      signedMediaUrl: signedMediaUrl,
      hasWatermark: json['hasWatermark'] as bool? ?? false,
      fileName: json['fileName'] as String? ?? 'petmagic-result',
      shareUrl: json['shareUrl'] as String? ?? '',
      shareToken: json['shareToken'] as String? ?? '',
      expiresAtUtc: DateTime.tryParse(
        json['expiresAtUtc'] as String? ?? '',
      )?.toUtc(),
      contentType: json['contentType'] as String?,
    );
  }
}
