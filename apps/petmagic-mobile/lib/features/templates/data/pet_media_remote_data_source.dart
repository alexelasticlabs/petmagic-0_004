import 'dart:io';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petmagic_mobile/core/auth/auth_session.dart';
import 'package:petmagic_mobile/core/auth/auth_session_coordinator.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/files/local_media_file.dart';
import 'package:petmagic_mobile/core/network/authenticated_request_options.dart';
import 'package:petmagic_mobile/core/network/dio_request_cancellation.dart';
import 'package:petmagic_mobile/core/operations/request_cancellation.dart';
import 'package:petmagic_mobile/features/pets/domain/pet_models.dart';
import 'package:petmagic_mobile/features/templates/data/generation_repository_error_mapper.dart';
import 'package:petmagic_mobile/features/templates/data/pet_dto_mapper.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_dtos.dart';
import 'package:petmagic_mobile/features/templates/data/template_image_upload_support.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/shared/files/image_upload_optimizer.dart';
import 'package:petmagic_mobile/shared/files/upload_media_policy.dart';

/// Owns pet photo and pet-generation REST transport.
final class PetMediaRemoteDataSource {
  const PetMediaRemoteDataSource({
    required Dio dio,
    required AuthSessionCoordinator authSessionCoordinator,
    required GenerationRepositoryErrorMapper errorMapper,
    required ImageUploadOptimizer imageUploadOptimizer,
  }) : _dio = dio,
       _authSessionCoordinator = authSessionCoordinator,
       _errorMapper = errorMapper,
       _imageUploadOptimizer = imageUploadOptimizer;

  final Dio _dio;
  final AuthSessionCoordinator _authSessionCoordinator;
  final GenerationRepositoryErrorMapper _errorMapper;
  final ImageUploadOptimizer _imageUploadOptimizer;

  Future<PetPhoto> uploadPhoto({
    required String petId,
    required LocalMediaFile photo,
    RequestCancellation? cancelToken,
  }) async {
    final sourceRawName = photo.name.isNotEmpty
        ? photo.name
        : photo.path.split(Platform.pathSeparator).last;
    final sourceName = TemplateImageUploadSupport.safeFileName(sourceRawName);
    final sourceContentType =
        photo.mimeType ??
        TemplateImageUploadSupport.contentTypeFromName(sourceName);
    await _validate(filePath: photo.path, contentType: sourceContentType);

    final optimized = await _imageUploadOptimizer.optimizeForPetPhoto(
      XFile(photo.path, name: sourceName, mimeType: sourceContentType),
      cancelToken: cancelToken,
    );
    try {
      final uploadFile = optimized.file;
      final rawName = uploadFile.name.isNotEmpty
          ? uploadFile.name
          : uploadFile.path.split(Platform.pathSeparator).last;
      final fileName = TemplateImageUploadSupport.safeFileName(rawName);
      final declaredContentType =
          uploadFile.mimeType ??
          TemplateImageUploadSupport.contentTypeFromName(fileName);
      final contentType = await _validate(
        filePath: uploadFile.path,
        contentType: declaredContentType,
      );
      final response = await _authorizedRequest<Map<String, dynamic>>(
        (session) async => _dio.post<Map<String, dynamic>>(
          '/api/pets/${Uri.encodeComponent(petId)}/photos',
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
      await optimized.dispose();
    }
  }

  Future<List<PetPhoto>> fetchPhotos(
    String petId, {
    RequestCancellation? cancelToken,
  }) async {
    final response = await _authorizedRequest<List<dynamic>>(
      (session) => _dio.get<List<dynamic>>(
        '/api/pets/${Uri.encodeComponent(petId)}/photos',
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken.toDioCancelToken(),
      ),
    );
    return (response.data ?? const [])
        .whereType<Map>()
        .map((item) => mapPetPhotoDto(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  Future<PetPhoto> setAsAvatar({
    required String petId,
    required String photoId,
    RequestCancellation? cancelToken,
  }) => _mutatePhoto(
    petId: petId,
    photoId: photoId,
    action: 'set-avatar',
    cancelToken: cancelToken,
  );

  Future<PetPhoto> setFavorite({
    required String petId,
    required String photoId,
    required bool isFavorite,
    RequestCancellation? cancelToken,
  }) => _mutatePhoto(
    petId: petId,
    photoId: photoId,
    action: 'favorite',
    data: {'isFavorite': isFavorite},
    cancelToken: cancelToken,
  );

  Future<void> deletePhoto({
    required String petId,
    required String photoId,
    RequestCancellation? cancelToken,
  }) => _authorizedRequest<void>(
    (session) => _dio.delete<void>(
      _photoPath(petId, photoId),
      options: authenticatedRequestOptions(session.accessToken),
      cancelToken: cancelToken.toDioCancelToken(),
    ),
    retryTransientFailures: false,
  );

  Future<List<TemplateGenerationResult>> fetchGenerations(
    String petId, {
    RequestCancellation? cancelToken,
  }) async {
    final response = await _authorizedRequest<List<dynamic>>(
      (session) => _dio.get<List<dynamic>>(
        '/api/pets/${Uri.encodeComponent(petId)}/generations',
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

  Future<PetPhoto> _mutatePhoto({
    required String petId,
    required String photoId,
    required String action,
    Map<String, Object?>? data,
    RequestCancellation? cancelToken,
  }) async {
    final response = await _authorizedRequest<Map<String, dynamic>>(
      (session) => _dio.post<Map<String, dynamic>>(
        '${_photoPath(petId, photoId)}/$action',
        data: data,
        options: authenticatedRequestOptions(session.accessToken),
        cancelToken: cancelToken.toDioCancelToken(),
      ),
      retryTransientFailures: false,
    );
    return mapPetPhotoDto(response.data ?? const {});
  }

  Future<String> _validate({
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
    if (fileSize <= 0 || fileSize > UploadMediaPolicy.petPhotoMaxBytes) {
      throw const AppException('pets.photo_type_not_allowed');
    }
    final detected = await TemplateImageUploadSupport.detectContentType(
      filePath,
      unavailableMessage: 'pets.photo_type_not_allowed',
    );
    if (detected == null ||
        !TemplateImageUploadSupport.isAllowedImageContentType(detected)) {
      throw const AppException('pets.photo_type_not_allowed');
    }
    return detected;
  }

  String _photoPath(String petId, String photoId) =>
      '/api/pets/${Uri.encodeComponent(petId)}/photos/${Uri.encodeComponent(photoId)}';

  Future<Response<T>> _authorizedRequest<T>(
    Future<Response<T>> Function(AuthSession session) request, {
    bool retryTransientFailures = true,
  }) => _authSessionCoordinator.authorizedRequest(
    request: request,
    mapError: _errorMapper.map,
    requestFailedMessage: 'templates.generation_failed',
    sessionExpiredMessage: 'auth.session_expired',
    transientRetryAttempts: retryTransientFailures ? 2 : 1,
  );
}
