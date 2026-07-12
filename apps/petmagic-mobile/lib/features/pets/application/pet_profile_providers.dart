import 'dart:async';

// Public pet selection application providers.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/templates/application/template_generation_contract.dart';

Duration? _noPetGalleryProviderRetry(int retryCount, Object error) => null;
const _petGalleryProviderCacheTtl = Duration(minutes: 5);

final petsProvider = FutureProvider.autoDispose<List<PetProfile>>((ref) {
  if (!ref.watch(_canLoadPrivatePetGalleryProvider)) {
    throw const AppException('auth.session_expired');
  }

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
      if (!ref.watch(_canLoadPrivatePetGalleryProvider)) {
        throw const AppException('auth.session_expired');
      }

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
      if (!ref.watch(_canLoadPrivatePetGalleryProvider)) {
        throw const AppException('auth.session_expired');
      }

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

final _canLoadPrivatePetGalleryProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(
    appLaunchControllerProvider.select((state) => state.isAuthenticated),
  );
});
// Public pets application providers.
