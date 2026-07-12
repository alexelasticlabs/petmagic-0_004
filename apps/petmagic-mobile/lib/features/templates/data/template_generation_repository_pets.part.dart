part of 'template_generation_repository.dart';

Future<PetPhoto> _uploadPetPhoto(
  TemplateGenerationRepository repository, {
  required String petId,
  required XFile photo,
  CancelToken? cancelToken,
}) async {
  OptimizedUploadFile? optimizedPhoto;
  try {
    final encodedPetId = repository._apiPathSegment(petId);
    final sourceRawFileName = photo.name.isNotEmpty
        ? photo.name
        : photo.path.split(Platform.pathSeparator).last;
    final sourceFileName = repository._safeSourceImageFileName(
      sourceRawFileName,
    );
    final sourceDeclaredContentType =
        photo.mimeType ?? repository._resolveImageContentType(sourceFileName);

    await _validatePetPhotoUploadFile(
      repository,
      filePath: photo.path,
      contentType: sourceDeclaredContentType,
    );

    optimizedPhoto = await repository._imageUploadOptimizer.optimizeForPetPhoto(
      XFile(
        photo.path,
        name: sourceFileName,
        mimeType: sourceDeclaredContentType,
      ),
      cancelToken: cancelToken,
    );
    final uploadFile = optimizedPhoto.file;
    final rawFileName = uploadFile.name.isNotEmpty
        ? uploadFile.name
        : uploadFile.path.split(Platform.pathSeparator).last;
    final fileName = repository._safeSourceImageFileName(rawFileName);
    final declaredContentType =
        uploadFile.mimeType ?? repository._resolveImageContentType(fileName);

    final contentType = await _validatePetPhotoUploadFile(
      repository,
      filePath: uploadFile.path,
      contentType: declaredContentType,
    );

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

    return mapPetPhotoDto(response.data ?? const {});
  } finally {
    await optimizedPhoto?.dispose();
  }
}

Future<String> _validatePetPhotoUploadFile(
  TemplateGenerationRepository repository, {
  required String filePath,
  required String contentType,
}) async {
  if (!repository._isAllowedImageContentType(contentType) &&
      !repository._isGenericBinaryContentType(contentType)) {
    throw const AppException('pets.photo_type_not_allowed');
  }

  final fileSize = await repository._uploadImageSizeBytes(
    filePath,
    unavailableMessage: 'pets.photo_type_not_allowed',
  );
  if (fileSize <= 0 ||
      fileSize > TemplateGenerationRepository._maxPetPhotoBytes) {
    throw const AppException('pets.photo_type_not_allowed');
  }

  final detectedContentType = await repository._detectSourceImageContentType(
    filePath,
    unavailableMessage: 'pets.photo_type_not_allowed',
  );
  if (detectedContentType == null ||
      !repository._isAllowedImageContentType(detectedContentType)) {
    throw const AppException('pets.photo_type_not_allowed');
  }

  return detectedContentType;
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
      .map((item) => mapPetPhotoDto(Map<String, dynamic>.from(item)))
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

  return mapPetPhotoDto(response.data ?? const {});
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

  return mapPetPhotoDto(response.data ?? const {});
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
  return detectTemplateSourceImageContentType(header);
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
