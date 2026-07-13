import 'package:image_picker/image_picker.dart';
import 'package:petmagic_mobile/core/files/local_media_file.dart';
import 'package:petmagic_mobile/core/operations/request_cancellation.dart';
import 'package:petmagic_mobile/features/pets/domain/pet_models.dart';
import 'package:petmagic_mobile/features/templates/data/pet_media_remote_data_source.dart';
import 'package:petmagic_mobile/features/templates/data/pet_profile_remote_data_source.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';

/// Backward-compatible concrete repository surface for legacy consumers.
/// New application code uses PetRepository through the dedicated adapter.
mixin GenerationPetRepositoryDelegate {
  PetProfileRemoteDataSource get petProfileRemoteDataSource;
  PetMediaRemoteDataSource get petMediaRemoteDataSource;

  Future<List<PetProfile>> fetchPets({RequestCancellation? cancelToken}) =>
      petProfileRemoteDataSource.fetchPets(cancelToken: cancelToken);

  Future<PetProfile> createPet({
    required String name,
    required String type,
    String? breed,
    RequestCancellation? cancelToken,
  }) => petProfileRemoteDataSource.createPet(
    name: name,
    type: type,
    breed: breed,
    cancelToken: cancelToken,
  );

  Future<PetProfile> updatePet({
    required String petId,
    required String name,
    required String type,
    String? breed,
    RequestCancellation? cancelToken,
  }) => petProfileRemoteDataSource.updatePet(
    petId: petId,
    name: name,
    type: type,
    breed: breed,
    cancelToken: cancelToken,
  );

  Future<void> deletePet(String petId, {RequestCancellation? cancelToken}) =>
      petProfileRemoteDataSource.deletePet(petId, cancelToken: cancelToken);

  Future<PetPhoto> uploadPetPhoto({
    required String petId,
    required XFile photo,
    RequestCancellation? cancelToken,
  }) => petMediaRemoteDataSource.uploadPhoto(
    petId: petId,
    photo: LocalMediaFile(
      path: photo.path,
      name: photo.name,
      mimeType: photo.mimeType,
    ),
    cancelToken: cancelToken,
  );

  Future<List<PetPhoto>> fetchPetPhotos(
    String petId, {
    RequestCancellation? cancelToken,
  }) => petMediaRemoteDataSource.fetchPhotos(petId, cancelToken: cancelToken);

  Future<PetPhoto> setPetPhotoAsAvatar({
    required String petId,
    required String photoId,
    RequestCancellation? cancelToken,
  }) => petMediaRemoteDataSource.setAsAvatar(
    petId: petId,
    photoId: photoId,
    cancelToken: cancelToken,
  );

  Future<PetPhoto> setPetPhotoFavorite({
    required String petId,
    required String photoId,
    required bool isFavorite,
    RequestCancellation? cancelToken,
  }) => petMediaRemoteDataSource.setFavorite(
    petId: petId,
    photoId: photoId,
    isFavorite: isFavorite,
    cancelToken: cancelToken,
  );

  Future<void> deletePetPhoto({
    required String petId,
    required String photoId,
    RequestCancellation? cancelToken,
  }) => petMediaRemoteDataSource.deletePhoto(
    petId: petId,
    photoId: photoId,
    cancelToken: cancelToken,
  );

  Future<List<TemplateGenerationResult>> fetchPetGenerations(
    String petId, {
    RequestCancellation? cancelToken,
  }) => petMediaRemoteDataSource.fetchGenerations(
    petId,
    cancelToken: cancelToken,
  );
}
