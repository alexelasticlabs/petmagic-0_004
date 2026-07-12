class PetProfile {
  const PetProfile({
    required this.id,
    required this.name,
    required this.type,
    required this.photosCount,
    required this.generationsCount,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    this.breed,
    this.avatarMediaAssetId,
    this.avatarUrl,
  });

  final String id;
  final String name;
  final String type;
  final String? breed;
  final String? avatarMediaAssetId;
  final String? avatarUrl;
  final int photosCount;
  final int generationsCount;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;

  factory PetProfile.fromJson(Map<String, dynamic> json) {
    return PetProfile(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? 'other',
      breed: json['breed'] as String?,
      avatarMediaAssetId: json['avatarMediaAssetId'] as String?,
      avatarUrl: _firstNonEmptyString(json, const [
        'avatarUrl',
        'avatarPhotoUrl',
        'avatarThumbnailUrl',
        'mainPhotoUrl',
        'photoUrl',
        'thumbnailUrl',
      ]),
      photosCount: (json['photosCount'] as num?)?.toInt() ?? 0,
      generationsCount: (json['generationsCount'] as num?)?.toInt() ?? 0,
      createdAtUtc: _dateTime(json['createdAtUtc']) ?? DateTime.now().toUtc(),
      updatedAtUtc: _dateTime(json['updatedAtUtc']) ?? DateTime.now().toUtc(),
    );
  }
}

class PetPhoto {
  const PetPhoto({
    required this.id,
    required this.petId,
    required this.mediaAssetId,
    required this.url,
    required this.fileName,
    required this.contentType,
    required this.isFavorite,
    required this.isAvatar,
    required this.sortOrder,
    required this.createdAtUtc,
    this.thumbnailUrl,
    this.fileSizeBytes,
  });

  final String id;
  final String petId;
  final String mediaAssetId;
  final String url;
  final String? thumbnailUrl;
  final String fileName;
  final String contentType;
  final int? fileSizeBytes;
  final bool isFavorite;
  final bool isAvatar;
  final int sortOrder;
  final DateTime createdAtUtc;

  factory PetPhoto.fromJson(Map<String, dynamic> json) {
    return PetPhoto(
      id: json['id'] as String? ?? '',
      petId: json['petId'] as String? ?? '',
      mediaAssetId: json['mediaAssetId'] as String? ?? '',
      url: json['url'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String?,
      fileName: json['fileName'] as String? ?? '',
      contentType: json['contentType'] as String? ?? '',
      fileSizeBytes: (json['fileSizeBytes'] as num?)?.toInt(),
      isFavorite: json['isFavorite'] as bool? ?? false,
      isAvatar: json['isAvatar'] as bool? ?? false,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      createdAtUtc: _dateTime(json['createdAtUtc']) ?? DateTime.now().toUtc(),
    );
  }
}

String? _firstNonEmptyString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}

DateTime? _dateTime(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value)?.toUtc();
}
