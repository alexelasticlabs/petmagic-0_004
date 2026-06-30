part of 'template_generation_repository.dart';

Future<PetPhoto> _uploadPetPhoto(
  TemplateGenerationRepository repository, {
  required String petId,
  required XFile photo,
  CancelToken? cancelToken,
}) async {
  OptimizedUploadFile? optimizedPhoto;
  try {
    optimizedPhoto = await repository._imageUploadOptimizer.optimizeForPetPhoto(
      photo,
      cancelToken: cancelToken,
    );
    final uploadFile = optimizedPhoto.file;
    final encodedPetId = repository._apiPathSegment(petId);
    final rawFileName = uploadFile.name.isNotEmpty
        ? uploadFile.name
        : uploadFile.path.split(Platform.pathSeparator).last;
    final fileName = repository._safeSourceImageFileName(rawFileName);
    final declaredContentType =
        uploadFile.mimeType ?? repository._resolveImageContentType(fileName);
    if (!repository._isAllowedImageContentType(declaredContentType) &&
        !repository._isGenericBinaryContentType(declaredContentType)) {
      throw const AppException('pets.photo_type_not_allowed');
    }

    final fileSize = await repository._uploadImageSizeBytes(
      uploadFile.path,
      unavailableMessage: 'pets.photo_type_not_allowed',
    );
    if (fileSize <= 0 ||
        fileSize > TemplateGenerationRepository._maxPetPhotoBytes) {
      throw const AppException('pets.photo_type_not_allowed');
    }

    final contentType = await repository._detectSourceImageContentType(
      uploadFile.path,
      unavailableMessage: 'pets.photo_type_not_allowed',
    );
    if (contentType == null) {
      throw const AppException('pets.photo_type_not_allowed');
    }

    final response = await repository._authorizedRequest<Map<String, dynamic>>(
      (session) async => repository._dio.post<Map<String, dynamic>>(
        '/api/pets/$encodedPetId/photos',
        data: FormData.fromMap({
          'photo': await MultipartFile.fromFile(
            uploadFile.path,
            filename: fileName,
            contentType: MediaType.parse(contentType),
          ),
        }),
        options: authenticatedMultipartRequestOptions(session.accessToken),
        cancelToken: cancelToken,
      ),
      retryTransientFailures: false,
    );

    return PetPhoto.fromJson(response.data ?? const {});
  } finally {
    await optimizedPhoto?.dispose();
  }
}

Future<List<PetPhoto>> _fetchPetPhotos(
  TemplateGenerationRepository repository, {
  required String petId,
  CancelToken? cancelToken,
}) async {
  final encodedPetId = repository._apiPathSegment(petId);
  final response = await repository._authorizedRequest<List<dynamic>>(
    (session) => repository._dio.get<List<dynamic>>(
      '/api/pets/$encodedPetId/photos',
      options: authenticatedRequestOptions(session.accessToken),
      cancelToken: cancelToken,
    ),
  );

  return (response.data ?? const [])
      .whereType<Map>()
      .map((item) => PetPhoto.fromJson(Map<String, dynamic>.from(item)))
      .toList(growable: false);
}

Future<PetPhoto> _setPetPhotoAsAvatar(
  TemplateGenerationRepository repository, {
  required String petId,
  required String photoId,
  CancelToken? cancelToken,
}) async {
  final encodedPetId = repository._apiPathSegment(petId);
  final encodedPhotoId = repository._apiPathSegment(photoId);
  final response = await repository._authorizedRequest<Map<String, dynamic>>(
    (session) => repository._dio.post<Map<String, dynamic>>(
      '/api/pets/$encodedPetId/photos/$encodedPhotoId/set-avatar',
      options: authenticatedRequestOptions(session.accessToken),
      cancelToken: cancelToken,
    ),
    retryTransientFailures: false,
  );

  return PetPhoto.fromJson(response.data ?? const {});
}

Future<PetPhoto> _setPetPhotoFavorite(
  TemplateGenerationRepository repository, {
  required String petId,
  required String photoId,
  required bool isFavorite,
  CancelToken? cancelToken,
}) async {
  final encodedPetId = repository._apiPathSegment(petId);
  final encodedPhotoId = repository._apiPathSegment(photoId);
  final response = await repository._authorizedRequest<Map<String, dynamic>>(
    (session) => repository._dio.post<Map<String, dynamic>>(
      '/api/pets/$encodedPetId/photos/$encodedPhotoId/favorite',
      data: {'isFavorite': isFavorite},
      options: authenticatedRequestOptions(session.accessToken),
      cancelToken: cancelToken,
    ),
    retryTransientFailures: false,
  );

  return PetPhoto.fromJson(response.data ?? const {});
}

Future<void> _deletePetPhoto(
  TemplateGenerationRepository repository, {
  required String petId,
  required String photoId,
  CancelToken? cancelToken,
}) async {
  final encodedPetId = repository._apiPathSegment(petId);
  final encodedPhotoId = repository._apiPathSegment(photoId);
  await repository._authorizedRequest<void>(
    (session) => repository._dio.delete<void>(
      '/api/pets/$encodedPetId/photos/$encodedPhotoId',
      options: authenticatedRequestOptions(session.accessToken),
      cancelToken: cancelToken,
    ),
    retryTransientFailures: false,
  );
}

Future<List<TemplateGenerationResult>> _fetchPetGenerations(
  TemplateGenerationRepository repository, {
  required String petId,
  CancelToken? cancelToken,
}) async {
  final encodedPetId = repository._apiPathSegment(petId);
  final response = await repository._authorizedRequest<List<dynamic>>(
    (session) => repository._dio.get<List<dynamic>>(
      '/api/pets/$encodedPetId/generations',
      options: authenticatedRequestOptions(session.accessToken),
      cancelToken: cancelToken,
    ),
  );

  return (response.data ?? const [])
      .whereType<Map>()
      .map(
        (item) => TemplateGenerationDto.fromJson(
          Map<String, dynamic>.from(item),
        ).toDomain(),
      )
      .toList(growable: false);
}

String _resolveImageContentTypeImpl(
  TemplateGenerationRepository repository,
  String fileName,
) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.png')) {
    return 'image/png';
  }
  if (lower.endsWith('.webp')) {
    return 'image/webp';
  }
  if (lower.endsWith('.heic')) {
    return 'image/heic';
  }
  return 'image/jpeg';
}

Future<String?> _detectSourceImageContentTypeImpl(
  TemplateGenerationRepository repository,
  String path, {
  required String unavailableMessage,
}) async {
  final header = await repository._sourceImageHeader(
    path,
    unavailableMessage: unavailableMessage,
  );
  if (repository._startsWith(header, const [0xFF, 0xD8, 0xFF])) {
    return 'image/jpeg';
  }
  if (repository._startsWith(header, const [
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
  ])) {
    return 'image/png';
  }
  if (header.length >= 12 &&
      repository._asciiEquals(header, 0, 'RIFF') &&
      repository._asciiEquals(header, 8, 'WEBP')) {
    return 'image/webp';
  }
  if (header.length >= 12 && repository._asciiEquals(header, 4, 'ftyp')) {
    final brand = String.fromCharCodes(header.skip(8).take(4)).toLowerCase();
    const heicBrands = {'heic', 'heix', 'hevc', 'hevx', 'heis', 'heim'};
    const heifBrands = {'mif1', 'msf1'};
    if (heicBrands.contains(brand)) {
      return 'image/heic';
    }
    if (heifBrands.contains(brand)) {
      return 'image/heif';
    }
  }

  return null;
}

Future<List<int>> _sourceImageHeaderImpl(
  TemplateGenerationRepository repository,
  String path, {
  required String unavailableMessage,
}) async {
  try {
    final chunks = await File(path).openRead(0, 32).toList();
    return [for (final chunk in chunks) ...chunk];
  } on FileSystemException catch (error) {
    throw AppException(unavailableMessage, cause: error);
  }
}

bool _startsWithImpl(
  TemplateGenerationRepository repository,
  List<int> bytes,
  List<int> prefix,
) {
  if (bytes.length < prefix.length) {
    return false;
  }
  for (var index = 0; index < prefix.length; index++) {
    if (bytes[index] != prefix[index]) {
      return false;
    }
  }
  return true;
}

bool _asciiEqualsImpl(
  TemplateGenerationRepository repository,
  List<int> bytes,
  int offset,
  String value,
) {
  if (bytes.length < offset + value.length) {
    return false;
  }
  for (var index = 0; index < value.length; index++) {
    if (bytes[offset + index] != value.codeUnitAt(index)) {
      return false;
    }
  }
  return true;
}

Future<int> _uploadImageSizeBytesImpl(
  TemplateGenerationRepository repository,
  String path, {
  required String unavailableMessage,
}) async {
  try {
    return await File(path).length();
  } on FileSystemException catch (error) {
    throw AppException(unavailableMessage, cause: error);
  }
}
