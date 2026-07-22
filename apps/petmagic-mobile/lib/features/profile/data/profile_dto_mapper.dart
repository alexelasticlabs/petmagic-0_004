import 'package:petmagic_mobile/features/profile/domain/profile_models.dart';

MobileLinkedAccount mapMobileLinkedAccountDto(Map<String, dynamic> json) {
  return MobileLinkedAccount(
    provider: json['provider'] as String? ?? '',
    displayName: json['displayName'] as String? ?? '',
    canDisconnect: json['canDisconnect'] as bool? ?? false,
  );
}

MobileLegalDocuments mapMobileLegalDocumentsDto(Map<String, dynamic> json) {
  return MobileLegalDocuments(
    termsOfUse: _mapMobileLegalDocumentDto(
      json['termsOfUse'] as Map<String, dynamic>? ?? const {},
    ),
    privacyPolicy: _mapMobileLegalDocumentDto(
      json['privacyPolicy'] as Map<String, dynamic>? ?? const {},
    ),
  );
}

MobileLegalDocument _mapMobileLegalDocumentDto(Map<String, dynamic> json) {
  return MobileLegalDocument(
    kind: json['kind'] as String? ?? '',
    title: json['title'] as String? ?? '',
    version: json['version'] as String? ?? '',
    publishedAtUtc: json['publishedAtUtc'] is String
        ? DateTime.tryParse(json['publishedAtUtc'] as String)
        : null,
    summary: json['summary'] as String? ?? '',
    sections: (json['sections'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(_mapMobileLegalDocumentSectionDto)
        .toList(growable: false),
  );
}

MobileLegalDocumentSection _mapMobileLegalDocumentSectionDto(
  Map<String, dynamic> json,
) {
  return MobileLegalDocumentSection(
    heading: json['heading'] as String? ?? '',
    paragraphs: (json['paragraphs'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList(growable: false),
  );
}
