import 'package:petmagic_mobile/features/pets/domain/pet_models.dart';

PetProfile mapPetProfileDto(Map<String, dynamic> json) {
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

PetPhoto mapPetPhotoDto(Map<String, dynamic> json) {
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
