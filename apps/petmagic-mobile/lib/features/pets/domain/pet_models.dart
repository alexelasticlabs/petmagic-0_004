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
}
