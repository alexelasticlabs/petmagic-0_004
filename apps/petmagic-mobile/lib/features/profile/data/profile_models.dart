class MobileUserAvatar {
  const MobileUserAvatar({
    required this.url,
    required this.fileName,
    required this.contentType,
    this.fileSizeBytes,
    this.updatedAtUtc,
  });

  final String url;
  final String fileName;
  final String contentType;
  final int? fileSizeBytes;
  final DateTime? updatedAtUtc;

  factory MobileUserAvatar.fromJson(Map<String, dynamic> json) {
    return MobileUserAvatar(
      url: json['url'] as String? ?? '',
      fileName: json['fileName'] as String? ?? '',
      contentType: json['contentType'] as String? ?? '',
      fileSizeBytes: (json['fileSizeBytes'] as num?)?.toInt(),
      updatedAtUtc: json['updatedAtUtc'] is String
          ? DateTime.tryParse(json['updatedAtUtc'] as String)
          : null,
    );
  }
}

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

class MobileLegalAcceptanceStatus {
  const MobileLegalAcceptanceStatus({
    required this.termsOfUseAccepted,
    required this.termsOfUseAcceptedVersion,
    required this.termsOfUseAcceptedAtUtc,
    required this.privacyPolicyAccepted,
    required this.privacyPolicyAcceptedVersion,
    required this.privacyPolicyAcceptedAtUtc,
    required this.currentTermsOfUseVersion,
    required this.currentPrivacyPolicyVersion,
    required this.requiresAcceptance,
  });

  final bool termsOfUseAccepted;
  final String? termsOfUseAcceptedVersion;
  final DateTime? termsOfUseAcceptedAtUtc;
  final bool privacyPolicyAccepted;
  final String? privacyPolicyAcceptedVersion;
  final DateTime? privacyPolicyAcceptedAtUtc;
  final String currentTermsOfUseVersion;
  final String currentPrivacyPolicyVersion;
  final bool requiresAcceptance;

  bool get isCurrentAccepted => !requiresAcceptance;

  factory MobileLegalAcceptanceStatus.fromJson(Map<String, dynamic> json) {
    return MobileLegalAcceptanceStatus(
      termsOfUseAccepted: json['termsOfUseAccepted'] as bool? ?? false,
      termsOfUseAcceptedVersion: json['termsOfUseAcceptedVersion'] as String?,
      termsOfUseAcceptedAtUtc: json['termsOfUseAcceptedAtUtc'] is String
          ? DateTime.tryParse(json['termsOfUseAcceptedAtUtc'] as String)
          : null,
      privacyPolicyAccepted: json['privacyPolicyAccepted'] as bool? ?? false,
      privacyPolicyAcceptedVersion:
          json['privacyPolicyAcceptedVersion'] as String?,
      privacyPolicyAcceptedAtUtc: json['privacyPolicyAcceptedAtUtc'] is String
          ? DateTime.tryParse(json['privacyPolicyAcceptedAtUtc'] as String)
          : null,
      currentTermsOfUseVersion:
          json['currentTermsOfUseVersion'] as String? ?? '',
      currentPrivacyPolicyVersion:
          json['currentPrivacyPolicyVersion'] as String? ?? '',
      requiresAcceptance: json['requiresAcceptance'] as bool? ?? false,
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

class MobileUserProfile {
  const MobileUserProfile({
    required this.userId,
    required this.email,
    required this.displayName,
    required this.isPremium,
    required this.emailConfirmed,
    required this.termsOfUseAccepted,
    required this.privacyPolicyAccepted,
    required this.marketingEmailsEnabled,
    required this.legalAcceptance,
    required this.roles,
    required this.avatar,
  });

  final String userId;
  final String email;
  final String? displayName;
  final bool isPremium;
  final bool emailConfirmed;
  final bool termsOfUseAccepted;
  final bool privacyPolicyAccepted;
  final bool marketingEmailsEnabled;
  final MobileLegalAcceptanceStatus legalAcceptance;
  final List<String> roles;
  final MobileUserAvatar? avatar;

  factory MobileUserProfile.fromJson(Map<String, dynamic> json) {
    return MobileUserProfile(
      userId: json['userId'] as String? ?? '',
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String?,
      isPremium: json['isPremium'] as bool? ?? false,
      emailConfirmed: json['emailConfirmed'] as bool? ?? false,
      termsOfUseAccepted: json['termsOfUseAccepted'] as bool? ?? false,
      privacyPolicyAccepted: json['privacyPolicyAccepted'] as bool? ?? false,
      marketingEmailsEnabled: json['marketingEmailsEnabled'] as bool? ?? false,
      legalAcceptance: MobileLegalAcceptanceStatus.fromJson(
        json['legalAcceptance'] as Map<String, dynamic>? ?? const {},
      ),
      roles: (json['roles'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      avatar: json['avatar'] is Map<String, dynamic>
          ? MobileUserAvatar.fromJson(json['avatar'] as Map<String, dynamic>)
          : null,
    );
  }
}

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAtUtc,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAtUtc;
  final MobileUserProfile user;

  bool get hasUsableTokens =>
      accessToken.trim().isNotEmpty && refreshToken.trim().isNotEmpty;

  Map<String, dynamic> toJson() {
    return {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'expiresAtUtc': expiresAtUtc.toIso8601String(),
      'user': {
        'userId': user.userId,
        'email': user.email,
        'displayName': user.displayName,
        'isPremium': user.isPremium,
        'emailConfirmed': user.emailConfirmed,
        'termsOfUseAccepted': user.termsOfUseAccepted,
        'privacyPolicyAccepted': user.privacyPolicyAccepted,
        'marketingEmailsEnabled': user.marketingEmailsEnabled,
        'legalAcceptance': {
          'termsOfUseAccepted': user.legalAcceptance.termsOfUseAccepted,
          'termsOfUseAcceptedVersion':
              user.legalAcceptance.termsOfUseAcceptedVersion,
          'termsOfUseAcceptedAtUtc': user
              .legalAcceptance
              .termsOfUseAcceptedAtUtc
              ?.toIso8601String(),
          'privacyPolicyAccepted': user.legalAcceptance.privacyPolicyAccepted,
          'privacyPolicyAcceptedVersion':
              user.legalAcceptance.privacyPolicyAcceptedVersion,
          'privacyPolicyAcceptedAtUtc': user
              .legalAcceptance
              .privacyPolicyAcceptedAtUtc
              ?.toIso8601String(),
          'currentTermsOfUseVersion':
              user.legalAcceptance.currentTermsOfUseVersion,
          'currentPrivacyPolicyVersion':
              user.legalAcceptance.currentPrivacyPolicyVersion,
          'requiresAcceptance': user.legalAcceptance.requiresAcceptance,
        },
        'roles': user.roles,
        'avatar': user.avatar == null
            ? null
            : {
                'url': user.avatar!.url,
                'fileName': user.avatar!.fileName,
                'contentType': user.avatar!.contentType,
                'fileSizeBytes': user.avatar!.fileSizeBytes,
                'updatedAtUtc': user.avatar!.updatedAtUtc?.toIso8601String(),
              },
      },
    };
  }

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: (json['accessToken'] as String? ?? '').trim(),
      refreshToken: (json['refreshToken'] as String? ?? '').trim(),
      expiresAtUtc:
          DateTime.tryParse(json['expiresAtUtc'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      user: MobileUserProfile.fromJson(
        json['user'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}
