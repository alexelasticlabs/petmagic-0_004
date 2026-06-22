import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';

const _petGalleryProviderCacheTtl = Duration(minutes: 1);

Duration? _noPetGalleryProviderRetry(int retryCount, Object error) => null;

final petsProvider = FutureProvider.autoDispose<List<PetProfile>>((ref) {
  final cacheLink = ref.keepAlive();
  final cancelToken = CancelToken();
  Timer? cacheTimer;
  ref.onCancel(() {
    cacheTimer = Timer(_petGalleryProviderCacheTtl, cacheLink.close);
  });
  ref.onResume(() => cacheTimer?.cancel());
  ref.onDispose(() {
    cacheTimer?.cancel();
    if (!cancelToken.isCancelled) {
      cancelToken.cancel('pets_provider_disposed');
    }
  });
  return ref
      .watch(templateGenerationRepositoryProvider)
      .fetchPets(cancelToken: cancelToken);
}, retry: _noPetGalleryProviderRetry);

final petPhotosProvider = FutureProvider.autoDispose
    .family<List<PetPhoto>, String>((ref, petId) {
      final cacheLink = ref.keepAlive();
      final cancelToken = CancelToken();
      Timer? cacheTimer;
      ref.onCancel(() {
        cacheTimer = Timer(_petGalleryProviderCacheTtl, cacheLink.close);
      });
      ref.onResume(() => cacheTimer?.cancel());
      ref.onDispose(() {
        cacheTimer?.cancel();
        if (!cancelToken.isCancelled) {
          cancelToken.cancel('pet_photos_provider_disposed');
        }
      });
      return ref
          .watch(templateGenerationRepositoryProvider)
          .fetchPetPhotos(petId, cancelToken: cancelToken);
    }, retry: _noPetGalleryProviderRetry);

final petGenerationsProvider = FutureProvider.autoDispose
    .family<List<TemplateGenerationResult>, String>((ref, petId) {
      final cacheLink = ref.keepAlive();
      final cancelToken = CancelToken();
      Timer? cacheTimer;
      ref.onCancel(() {
        cacheTimer = Timer(_petGalleryProviderCacheTtl, cacheLink.close);
      });
      ref.onResume(() => cacheTimer?.cancel());
      ref.onDispose(() {
        cacheTimer?.cancel();
        if (!cancelToken.isCancelled) {
          cancelToken.cancel('pet_generations_provider_disposed');
        }
      });
      return ref
          .watch(templateGenerationRepositoryProvider)
          .fetchPetGenerations(petId, cancelToken: cancelToken);
    }, retry: _noPetGalleryProviderRetry);
