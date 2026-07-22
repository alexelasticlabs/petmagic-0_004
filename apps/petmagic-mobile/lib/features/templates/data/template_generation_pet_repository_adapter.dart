import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petmagic_mobile/core/auth/auth_session_coordinator.dart';
import 'package:petmagic_mobile/core/files/local_media_file.dart';
import 'package:petmagic_mobile/core/network/dio_provider.dart';
import 'package:petmagic_mobile/core/operations/request_cancellation.dart';
import 'package:petmagic_mobile/features/pets/application/pet_repository.dart';
import 'package:petmagic_mobile/features/pets/domain/pet_generation_summary.dart';
import 'package:petmagic_mobile/features/templates/data/generation_repository_error_mapper.dart';
import 'package:petmagic_mobile/features/templates/data/pet_media_remote_data_source.dart';
import 'package:petmagic_mobile/features/templates/data/pet_profile_remote_data_source.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/shared/files/image_upload_optimizer.dart';

final dioPetRepositoryProvider = Provider<PetRepository>((ref) {
  final dio = ref.watch(dioProvider);
  final coordinator = ref.watch(authSessionCoordinatorProvider);
  const errorMapper = GenerationRepositoryErrorMapper();
  return TemplateGenerationPetRepositoryAdapter.fromSources(
    profileRemoteDataSource: PetProfileRemoteDataSource(
      dio: dio,
      authSessionCoordinator: coordinator,
      errorMapper: errorMapper,
    ),
    mediaRemoteDataSource: PetMediaRemoteDataSource(
      dio: dio,
      authSessionCoordinator: coordinator,
      errorMapper: errorMapper,
      imageUploadOptimizer: const ImageUploadOptimizer(),
    ),
  );
});

/// Bridges the PetRepository application port to pet-owned REST sources.
final class TemplateGenerationPetRepositoryAdapter implements PetRepository {
  TemplateGenerationPetRepositoryAdapter(
    TemplateGenerationRepository repository,
  ) : _legacyRepository = repository,
      _profileRemoteDataSource = null,
      _mediaRemoteDataSource = null;

  const TemplateGenerationPetRepositoryAdapter.fromSources({
    required PetProfileRemoteDataSource profileRemoteDataSource,
    required PetMediaRemoteDataSource mediaRemoteDataSource,
  }) : _legacyRepository = null,
       _profileRemoteDataSource = profileRemoteDataSource,
       _mediaRemoteDataSource = mediaRemoteDataSource;

  final TemplateGenerationRepository? _legacyRepository;
  final PetProfileRemoteDataSource? _profileRemoteDataSource;
  final PetMediaRemoteDataSource? _mediaRemoteDataSource;

  @override
  Future<List<PetProfile>> fetchPets({RequestCancellation? cancellation}) {
    final legacy = _legacyRepository;
    return legacy != null
        ? legacy.fetchPets(cancelToken: cancellation)
        : _profileRemoteDataSource!.fetchPets(cancelToken: cancellation);
  }

  @override
  Future<PetProfile> createPet({
    required String name,
    required String type,
    String? breed,
    RequestCancellation? cancellation,
  }) {
    final legacy = _legacyRepository;
    return legacy != null
        ? legacy.createPet(
            name: name,
            type: type,
            breed: breed,
            cancelToken: cancellation,
          )
        : _profileRemoteDataSource!.createPet(
            name: name,
            type: type,
            breed: breed,
            cancelToken: cancellation,
          );
  }

  @override
  Future<PetProfile> updatePet({
    required String petId,
    required String name,
    required String type,
    String? breed,
    RequestCancellation? cancellation,
  }) {
    final legacy = _legacyRepository;
    return legacy != null
        ? legacy.updatePet(
            petId: petId,
            name: name,
            type: type,
            breed: breed,
            cancelToken: cancellation,
          )
        : _profileRemoteDataSource!.updatePet(
            petId: petId,
            name: name,
            type: type,
            breed: breed,
            cancelToken: cancellation,
          );
  }

  @override
  Future<void> deletePet(String petId, {RequestCancellation? cancellation}) {
    final legacy = _legacyRepository;
    return legacy != null
        ? legacy.deletePet(petId, cancelToken: cancellation)
        : _profileRemoteDataSource!.deletePet(petId, cancelToken: cancellation);
  }

  @override
  Future<PetPhoto> uploadPetPhoto({
    required String petId,
    required LocalMediaFile photo,
    RequestCancellation? cancellation,
  }) {
    final legacy = _legacyRepository;
    return legacy != null
        ? legacy.uploadPetPhoto(
            petId: petId,
            photo: XFile(
              photo.path,
              name: photo.name,
              mimeType: photo.mimeType,
            ),
            cancelToken: cancellation,
          )
        : _mediaRemoteDataSource!.uploadPhoto(
            petId: petId,
            photo: photo,
            cancelToken: cancellation,
          );
  }

  @override
  Future<List<PetPhoto>> fetchPetPhotos(
    String petId, {
    RequestCancellation? cancellation,
  }) {
    final legacy = _legacyRepository;
    return legacy != null
        ? legacy.fetchPetPhotos(petId, cancelToken: cancellation)
        : _mediaRemoteDataSource!.fetchPhotos(petId, cancelToken: cancellation);
  }

  @override
  Future<PetPhoto> setPetPhotoAsAvatar({
    required String petId,
    required String photoId,
    RequestCancellation? cancellation,
  }) {
    final legacy = _legacyRepository;
    return legacy != null
        ? legacy.setPetPhotoAsAvatar(
            petId: petId,
            photoId: photoId,
            cancelToken: cancellation,
          )
        : _mediaRemoteDataSource!.setAsAvatar(
            petId: petId,
            photoId: photoId,
            cancelToken: cancellation,
          );
  }

  @override
  Future<PetPhoto> setPetPhotoFavorite({
    required String petId,
    required String photoId,
    required bool isFavorite,
    RequestCancellation? cancellation,
  }) {
    final legacy = _legacyRepository;
    return legacy != null
        ? legacy.setPetPhotoFavorite(
            petId: petId,
            photoId: photoId,
            isFavorite: isFavorite,
            cancelToken: cancellation,
          )
        : _mediaRemoteDataSource!.setFavorite(
            petId: petId,
            photoId: photoId,
            isFavorite: isFavorite,
            cancelToken: cancellation,
          );
  }

  @override
  Future<void> deletePetPhoto({
    required String petId,
    required String photoId,
    RequestCancellation? cancellation,
  }) {
    final legacy = _legacyRepository;
    return legacy != null
        ? legacy.deletePetPhoto(
            petId: petId,
            photoId: photoId,
            cancelToken: cancellation,
          )
        : _mediaRemoteDataSource!.deletePhoto(
            petId: petId,
            photoId: photoId,
            cancelToken: cancellation,
          );
  }

  @override
  Future<List<PetGenerationSummary>> fetchPetGenerations(
    String petId, {
    RequestCancellation? cancellation,
  }) async {
    final legacy = _legacyRepository;
    final generations = legacy != null
        ? await legacy.fetchPetGenerations(petId, cancelToken: cancellation)
        : await _mediaRemoteDataSource!.fetchGenerations(
            petId,
            cancelToken: cancellation,
          );
    return generations
        .map(
          (generation) => PetGenerationSummary(
            generationId: generation.generationId,
            templateId: generation.templateId,
            templateTitle: generation.templateTitle,
            templateType: generation.templateType,
            outputUrl: generation.outputUrl,
            petId: generation.petId,
            petPhotoId: generation.petPhotoId,
            createdAtUtc: generation.createdAtUtc,
            status: generation.status.name,
            stage: generation.stage ?? generation.status.name,
          ),
        )
        .toList(growable: false);
  }
}
