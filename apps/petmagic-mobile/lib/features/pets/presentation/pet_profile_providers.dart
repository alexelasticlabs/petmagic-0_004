import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';

Duration? _noPetGalleryProviderRetry(int retryCount, Object error) => null;
const _petGalleryProviderCacheTtl = Duration(minutes: 5);

final petsProvider = FutureProvider.autoDispose<List<PetProfile>>((ref) {
  if (!ref.read(networkStatusControllerProvider).hasInternet) {
    throw const AppException('templates.network_unavailable');
  }

  final link = ref.keepAlive();
  Timer? disposeTimer;
  ref.onCancel(() {
    disposeTimer?.cancel();
    disposeTimer = Timer(_petGalleryProviderCacheTtl, link.close);
  });
  ref.onResume(() {
    disposeTimer?.cancel();
    disposeTimer = null;
  });
  final cancelToken = CancelToken();
  ref.onDispose(() {
    disposeTimer?.cancel();
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
      if (!ref.read(networkStatusControllerProvider).hasInternet) {
        throw const AppException('templates.network_unavailable');
      }

      final link = ref.keepAlive();
      Timer? disposeTimer;
      ref.onCancel(() {
        disposeTimer?.cancel();
        disposeTimer = Timer(_petGalleryProviderCacheTtl, link.close);
      });
      ref.onResume(() {
        disposeTimer?.cancel();
        disposeTimer = null;
      });
      final cancelToken = CancelToken();
      ref.onDispose(() {
        disposeTimer?.cancel();
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
      if (!ref.read(networkStatusControllerProvider).hasInternet) {
        throw const AppException('templates.network_unavailable');
      }

      final link = ref.keepAlive();
      Timer? disposeTimer;
      ref.onCancel(() {
        disposeTimer?.cancel();
        disposeTimer = Timer(_petGalleryProviderCacheTtl, link.close);
      });
      ref.onResume(() {
        disposeTimer?.cancel();
        disposeTimer = null;
      });
      final cancelToken = CancelToken();
      ref.onDispose(() {
        disposeTimer?.cancel();
        if (!cancelToken.isCancelled) {
          cancelToken.cancel('pet_generations_provider_disposed');
        }
      });
      return ref
          .watch(templateGenerationRepositoryProvider)
          .fetchPetGenerations(petId, cancelToken: cancelToken);
    }, retry: _noPetGalleryProviderRetry);
