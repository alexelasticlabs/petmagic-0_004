export 'package:petmagic_mobile/core/auth/auth_session.dart';

class MobileLegalDocumentSection {
  const MobileLegalDocumentSection({
    required this.heading,
    required this.paragraphs,
  });

  final String heading;
  final List<String> paragraphs;
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
}

class MobileLegalDocuments {
  const MobileLegalDocuments({
    required this.termsOfUse,
    required this.privacyPolicy,
  });

  final MobileLegalDocument termsOfUse;
  final MobileLegalDocument privacyPolicy;
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
}

// Profile domain read models.
