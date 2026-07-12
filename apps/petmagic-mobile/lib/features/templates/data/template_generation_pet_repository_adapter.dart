import 'package:image_picker/image_picker.dart';
import 'package:petmagic_mobile/core/files/local_media_file.dart';

import 'package:petmagic_mobile/core/operations/request_cancellation.dart';
import 'package:petmagic_mobile/features/pets/application/pet_repository.dart';
import 'package:petmagic_mobile/features/pets/domain/pet_generation_summary.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';

final class TemplateGenerationPetRepositoryAdapter implements PetRepository {
  const TemplateGenerationPetRepositoryAdapter(this._repository);

  final TemplateGenerationRepository _repository;

  @override
  Future<List<PetProfile>> fetchPets({RequestCancellation? cancellation}) {
    return _repository.fetchPets(cancelToken: cancellation);
  }

  @override
  Future<PetProfile> createPet({
    required String name,
    required String type,
    String? breed,
    RequestCancellation? cancellation,
  }) {
    return _repository.createPet(
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
    return _repository.updatePet(
      petId: petId,
      name: name,
      type: type,
      breed: breed,
      cancelToken: cancellation,
    );
  }

  @override
  Future<void> deletePet(String petId, {RequestCancellation? cancellation}) {
    return _repository.deletePet(petId, cancelToken: cancellation);
  }

  @override
  Future<PetPhoto> uploadPetPhoto({
    required String petId,
    required LocalMediaFile photo,
    RequestCancellation? cancellation,
  }) {
    return _repository.uploadPetPhoto(
      petId: petId,
      photo: XFile(photo.path, name: photo.name, mimeType: photo.mimeType),
      cancelToken: cancellation,
    );
  }

  @override
  Future<List<PetPhoto>> fetchPetPhotos(
    String petId, {
    RequestCancellation? cancellation,
  }) {
    return _repository.fetchPetPhotos(petId, cancelToken: cancellation);
  }

  @override
  Future<PetPhoto> setPetPhotoAsAvatar({
    required String petId,
    required String photoId,
    RequestCancellation? cancellation,
  }) {
    return _repository.setPetPhotoAsAvatar(
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
    return _repository.setPetPhotoFavorite(
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
    return _repository.deletePetPhoto(
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
    final generations = await _repository.fetchPetGenerations(
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
