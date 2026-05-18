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

class MobileUserProfile {
  const MobileUserProfile({
    required this.userId,
    required this.email,
    required this.displayName,
    required this.isPremium,
    required this.emailConfirmed,
    required this.roles,
    required this.avatar,
  });

  final String userId;
  final String email;
  final String? displayName;
  final bool isPremium;
  final bool emailConfirmed;
  final List<String> roles;
  final MobileUserAvatar? avatar;

  factory MobileUserProfile.fromJson(Map<String, dynamic> json) {
    return MobileUserProfile(
      userId: json['userId'] as String? ?? '',
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String?,
      isPremium: json['isPremium'] as bool? ?? false,
      emailConfirmed: json['emailConfirmed'] as bool? ?? false,
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
      accessToken: json['accessToken'] as String? ?? '',
      refreshToken: json['refreshToken'] as String? ?? '',
      expiresAtUtc:
          DateTime.tryParse(json['expiresAtUtc'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      user: MobileUserProfile.fromJson(
        json['user'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}
