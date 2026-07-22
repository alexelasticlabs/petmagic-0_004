import 'package:petmagic_mobile/features/templates/domain/template_generation_results.dart';

RemoveGenerationWatermarkResult mapRemoveGenerationWatermarkResultDto(
  Map<String, dynamic> json,
) {
  return RemoveGenerationWatermarkResult(
    watermarkRemoved: json['watermarkRemoved'] as bool? ?? false,
    creditsSpent: (json['creditsSpent'] as num?)?.toInt() ?? 0,
    remainingCredits: (json['remainingCredits'] as num?)?.toInt(),
    mediaUrl: json['mediaUrl'] as String?,
  );
}

GenerationMediaAccessResult mapGenerationMediaAccessResultDto(
  Map<String, dynamic> json,
) {
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
