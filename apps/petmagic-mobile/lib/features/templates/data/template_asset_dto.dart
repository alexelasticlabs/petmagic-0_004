import 'package:petmagic_mobile/features/templates/domain/template_models.dart';

class TemplateAssetDto {
  const TemplateAssetDto({
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

  factory TemplateAssetDto.fromJson(Map<String, Object?> json) {
    return TemplateAssetDto(
      url: json['url'] as String? ?? '',
      fileName: json['fileName'] as String? ?? '',
      contentType: json['contentType'] as String? ?? '',
      fileSizeBytes: (json['fileSizeBytes'] as num?)?.toInt(),
      durationSeconds: (json['durationSeconds'] as num?)?.toDouble(),
    );
  }

  Map<String, Object?> toJson() => {
    'url': url,
    'fileName': fileName,
    'contentType': contentType,
    'fileSizeBytes': fileSizeBytes,
    'durationSeconds': durationSeconds,
  };

  TemplateAsset toDomain() => TemplateAsset(
    url: url,
    fileName: fileName,
    contentType: contentType,
    fileSizeBytes: fileSizeBytes,
    durationSeconds: durationSeconds,
  );
}
