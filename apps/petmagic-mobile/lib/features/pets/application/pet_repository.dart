import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/files/local_media_file.dart';
import 'package:petmagic_mobile/core/operations/request_cancellation.dart';
import 'package:petmagic_mobile/features/pets/domain/pet_generation_summary.dart';
import 'package:petmagic_mobile/features/pets/domain/pet_models.dart';

final petRepositoryProvider = Provider<PetRepository>((ref) {
  throw StateError(
    'PetRepository is not bound. Add the app composition overrides.',
  );
});

abstract interface class PetRepository {
  Future<List<PetProfile>> fetchPets({RequestCancellation? cancellation});

  Future<PetProfile> createPet({
    required String name,
    required String type,
    String? breed,
    RequestCancellation? cancellation,
  });

  Future<PetProfile> updatePet({
    required String petId,
    required String name,
    required String type,
    String? breed,
    RequestCancellation? cancellation,
  });

  Future<void> deletePet(String petId, {RequestCancellation? cancellation});

  Future<PetPhoto> uploadPetPhoto({
    required String petId,
    required LocalMediaFile photo,
    RequestCancellation? cancellation,
  });

  Future<List<PetPhoto>> fetchPetPhotos(
    String petId, {
    RequestCancellation? cancellation,
  });

  Future<PetPhoto> setPetPhotoAsAvatar({
    required String petId,
    required String photoId,
    RequestCancellation? cancellation,
  });

  Future<PetPhoto> setPetPhotoFavorite({
    required String petId,
    required String photoId,
    required bool isFavorite,
    RequestCancellation? cancellation,
  });

  Future<void> deletePetPhoto({
    required String petId,
    required String photoId,
    RequestCancellation? cancellation,
  });

  Future<List<PetGenerationSummary>> fetchPetGenerations(
    String petId, {
    RequestCancellation? cancellation,
  });
}
