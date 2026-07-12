export 'package:petmagic_mobile/core/auth/auth_session.dart';

class MobileLegalDocumentSection {
  const MobileLegalDocumentSection({
    required this.heading,
    required this.paragraphs,
  });

  final String heading;
  final List<String> paragraphs;

  factory MobileLegalDocumentSection.fromJson(Map<String, dynamic> json) {
    return MobileLegalDocumentSection(
      heading: json['heading'] as String? ?? '',
      paragraphs: (json['paragraphs'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
    );
  }
}

class MobileLegalDocument {
  const MobileLegalDocument({
    required this.kind,
    required this.title,
    required this.version,
    required this.publishedAtUtc,
    required this.summary,
    required this.sections,
  });

  final String kind;
  final String title;
  final String version;
  final DateTime? publishedAtUtc;
  final String summary;
  final List<MobileLegalDocumentSection> sections;

  factory MobileLegalDocument.fromJson(Map<String, dynamic> json) {
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
          .map(MobileLegalDocumentSection.fromJson)
          .toList(growable: false),
    );
  }
}

class MobileLegalDocuments {
  const MobileLegalDocuments({
    required this.termsOfUse,
    required this.privacyPolicy,
  });

  final MobileLegalDocument termsOfUse;
  final MobileLegalDocument privacyPolicy;

  factory MobileLegalDocuments.fromJson(Map<String, dynamic> json) {
    return MobileLegalDocuments(
      termsOfUse: MobileLegalDocument.fromJson(
        json['termsOfUse'] as Map<String, dynamic>? ?? const {},
      ),
      privacyPolicy: MobileLegalDocument.fromJson(
        json['privacyPolicy'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}

class MobileLinkedAccount {
  const MobileLinkedAccount({
    required this.provider,
    required this.displayName,
    required this.canDisconnect,
  });

  final String provider;
  final String displayName;
  final bool canDisconnect;

  factory MobileLinkedAccount.fromJson(Map<String, dynamic> json) {
    return MobileLinkedAccount(
      provider: json['provider'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      canDisconnect: json['canDisconnect'] as bool? ?? false,
    );
  }
}

// Profile domain read models.
