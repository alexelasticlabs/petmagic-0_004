part of 'template_generation_repository.dart';

Future<PetPhoto> _uploadPetPhoto(
  TemplateGenerationRepository repository, {
  required String petId,
  required XFile photo,
  RequestCancellation? cancelToken,
}) async {
  OptimizedUploadFile? optimizedPhoto;
  try {
    final encodedPetId = repository._apiPathSegment(petId);
    final sourceRawFileName = photo.name.isNotEmpty
        ? photo.name
        : photo.path.split(Platform.pathSeparator).last;
    final sourceFileName = TemplateImageUploadSupport.safeFileName(
      sourceRawFileName,
    );
    final sourceDeclaredContentType =
        photo.mimeType ??
        TemplateImageUploadSupport.contentTypeFromName(sourceFileName);

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
    final fileName = TemplateImageUploadSupport.safeFileName(rawFileName);
    final declaredContentType =
        uploadFile.mimeType ??
        TemplateImageUploadSupport.contentTypeFromName(fileName);

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
        cancelToken: cancelToken.toDioCancelToken(),
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
  if (!TemplateImageUploadSupport.isAllowedImageContentType(contentType) &&
      !TemplateImageUploadSupport.isGenericBinaryContentType(contentType)) {
    throw const AppException('pets.photo_type_not_allowed');
  }

  final fileSize = await TemplateImageUploadSupport.fileSize(
    filePath,
    unavailableMessage: 'pets.photo_type_not_allowed',
  );
  if (fileSize <= 0 ||
      fileSize > TemplateGenerationRepository._maxPetPhotoBytes) {
    throw const AppException('pets.photo_type_not_allowed');
  }

  final detectedContentType =
      await TemplateImageUploadSupport.detectContentType(
        filePath,
        unavailableMessage: 'pets.photo_type_not_allowed',
      );
  if (detectedContentType == null ||
      !TemplateImageUploadSupport.isAllowedImageContentType(
        detectedContentType,
      )) {
    throw const AppException('pets.photo_type_not_allowed');
  }

  return detectedContentType;
}

Future<List<PetPhoto>> _fetchPetPhotos(
  TemplateGenerationRepository repository, {
  required String petId,
  RequestCancellation? cancelToken,
}) async {
  final encodedPetId = repository._apiPathSegment(petId);
  final response = await repository._authorizedRequest<List<dynamic>>(
    (session) => repository._dio.get<List<dynamic>>(
      '/api/pets/$encodedPetId/photos',
      options: authenticatedRequestOptions(session.accessToken),
      cancelToken: cancelToken.toDioCancelToken(),
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
  RequestCancellation? cancelToken,
}) async {
  final encodedPetId = repository._apiPathSegment(petId);
  final encodedPhotoId = repository._apiPathSegment(photoId);
  final response = await repository._authorizedRequest<Map<String, dynamic>>(
    (session) => repository._dio.post<Map<String, dynamic>>(
      '/api/pets/$encodedPetId/photos/$encodedPhotoId/set-avatar',
      options: authenticatedRequestOptions(session.accessToken),
      cancelToken: cancelToken.toDioCancelToken(),
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
  RequestCancellation? cancelToken,
}) async {
  final encodedPetId = repository._apiPathSegment(petId);
  final encodedPhotoId = repository._apiPathSegment(photoId);
  final response = await repository._authorizedRequest<Map<String, dynamic>>(
    (session) => repository._dio.post<Map<String, dynamic>>(
      '/api/pets/$encodedPetId/photos/$encodedPhotoId/favorite',
      data: {'isFavorite': isFavorite},
      options: authenticatedRequestOptions(session.accessToken),
      cancelToken: cancelToken.toDioCancelToken(),
    ),
    retryTransientFailures: false,
  );

  return mapPetPhotoDto(response.data ?? const {});
}

Future<void> _deletePetPhoto(
  TemplateGenerationRepository repository, {
  required String petId,
  required String photoId,
  RequestCancellation? cancelToken,
}) async {
  final encodedPetId = repository._apiPathSegment(petId);
  final encodedPhotoId = repository._apiPathSegment(photoId);
  await repository._authorizedRequest<void>(
    (session) => repository._dio.delete<void>(
      '/api/pets/$encodedPetId/photos/$encodedPhotoId',
      options: authenticatedRequestOptions(session.accessToken),
      cancelToken: cancelToken.toDioCancelToken(),
    ),
    retryTransientFailures: false,
  );
}

Future<List<TemplateGenerationResult>> _fetchPetGenerations(
  TemplateGenerationRepository repository, {
  required String petId,
  RequestCancellation? cancelToken,
}) async {
  final encodedPetId = repository._apiPathSegment(petId);
  final response = await repository._authorizedRequest<List<dynamic>>(
    (session) => repository._dio.get<List<dynamic>>(
      '/api/pets/$encodedPetId/generations',
      options: authenticatedRequestOptions(session.accessToken),
      cancelToken: cancelToken.toDioCancelToken(),
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
