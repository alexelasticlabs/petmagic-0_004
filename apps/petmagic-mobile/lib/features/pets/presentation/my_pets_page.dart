import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/errors/app_unavailable_state.dart';
import 'package:petmagic_mobile/core/files/local_media_file.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/core/navigation/app_navigator.dart';
import 'package:petmagic_mobile/core/operations/request_cancellation.dart';
import 'package:petmagic_mobile/core/permissions/media_permission_feedback.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/pets/application/pet_media_url_normalizer.dart';
import 'package:petmagic_mobile/features/pets/application/pet_profile_providers.dart';
import 'package:petmagic_mobile/features/pets/application/pet_repository.dart';
import 'package:petmagic_mobile/features/pets/domain/pet_generation_summary.dart';
import 'package:petmagic_mobile/features/pets/domain/pet_models.dart';
import 'package:petmagic_mobile/features/pets/presentation/widgets/pet_form_steps.dart';
import 'package:petmagic_mobile/shared/files/persistent_media_url.dart';
import 'package:petmagic_mobile/shared/navigation/external_url_policy.dart';
import 'package:petmagic_mobile/shared/navigation/app_navigation_context.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_navigation_layout.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_toast.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_unavailable_view.dart';
import 'package:petmagic_mobile/shared/widgets/protected_auth_gate.dart';
import 'package:share_plus/share_plus.dart';

export 'package:petmagic_mobile/features/pets/application/pet_profile_providers.dart';

part 'my_pets_detail_page.part.dart';
part 'my_pets_overview_widgets.part.dart';
part 'my_pets_photo_grid.part.dart';
part 'my_pets_generation_widgets.part.dart';
part 'my_pets_state_widgets.part.dart';
part 'my_pets_form_sheet.part.dart';
part 'my_pets_photo_actions.part.dart';

const int _petPhotoThumbnailMemCacheWidth = 512;
const int _petAvatarMemCacheWidth = 192;

class MyPetsPage extends ConsumerStatefulWidget {
  const MyPetsPage({super.key});

  static const routePath = '/profile/pets';

  @override
  ConsumerState<MyPetsPage> createState() => _MyPetsPageState();
}

class _MyPetsPageState extends ConsumerState<MyPetsPage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      return;
    }

    final pets = ref.read(petsProvider);
    final hasInternet = ref.read(networkStatusControllerProvider).hasInternet;
    if (!hasInternet) {
      return;
    }

    if (_petsUnavailableKind(pets, hasInternet) == null) {
      return;
    }

    ref.invalidate(petsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final launchState = ref.watch(appLaunchControllerProvider);
    final text = AppLocalizations.of(context);
    final bottomInset = petMagicScrollableBottomInset(context);
    final hasInternet = ref.watch(
      networkStatusControllerProvider.select((status) => status.hasInternet),
    );

    if (launchState.isLoading || !launchState.isAuthenticated) {
      return Scaffold(
        appBar: AppBar(title: Text(text.profilePetsTitle)),
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [colors.backgroundTop, colors.backgroundBottom],
            ),
          ),
          child: launchState.isLoading
              ? const Center(child: CircularProgressIndicator.adaptive())
              : Padding(
                  padding: EdgeInsets.only(bottom: bottomInset),
                  child: _PetAuthGate(redirectPath: MyPetsPage.routePath),
                ),
        ),
      );
    }

    final pets = ref.watch(petsProvider);
    final hasPets = pets.asData?.value.isNotEmpty ?? false;
    final petsLoadRequiresSignIn = _isUnauthorizedError(pets.asError?.error);
    final unavailableKind = petsLoadRequiresSignIn
        ? null
        : _petsUnavailableKind(pets, hasInternet);

    ref.listen<NetworkStatusState>(networkStatusControllerProvider, (
      previous,
      next,
    ) {
      if (previous?.hasInternet != false || !next.hasInternet) {
        return;
      }

      final currentPets = ref.read(petsProvider);
      if (_petsUnavailableKind(currentPets, next.hasInternet) == null) {
        return;
      }

      ref.invalidate(petsProvider);
    });

    return Scaffold(
      appBar: AppBar(title: Text(text.profilePetsTitle)),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colors.backgroundTop, colors.backgroundBottom],
          ),
        ),
        child: pets.when(
          loading: () =>
              const Center(child: CircularProgressIndicator.adaptive()),
          error: (error, _) {
            if (_isUnauthorizedError(error)) {
              return Padding(
                padding: EdgeInsets.only(bottom: bottomInset),
                child: _PetAuthGate(redirectPath: MyPetsPage.routePath),
              );
            }

            if (unavailableKind != null) {
              return PetMagicUnavailableView(
                kind: unavailableKind,
                onRetry: () => ref.invalidate(petsProvider),
                padding: EdgeInsets.fromLTRB(28, 36, 28, bottomInset),
              );
            }

            return _StateView(
              title: text.petsLoadErrorTitle,
              actionLabel: text.petsRetryAction,
              onAction: () => ref.invalidate(petsProvider),
            );
          },
          data: (items) {
            if (items.isEmpty) {
              return _StateView(
                title: text.petsEmptyTitle,
                subtitle: text.petsEmptySubtitle,
                actionLabel: text.petsAddAction,
                onAction: () => _showPetForm(context, ref),
              );
            }

            return RefreshIndicator.adaptive(
              onRefresh: () => _refreshPets(ref),
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final pet = items[index];
                  return _PetCard(
                    pet: pet,
                    text: text,
                    onTap: () => context.appNavigator.push(
                      PetDetailsDestination(pet.id),
                    ),
                    onGenerate: () => context.appNavigator.go(
                      TemplatesDestination(petId: pet.id),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
      floatingActionButton:
          petsLoadRequiresSignIn || unavailableKind != null || !hasPets
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showPetForm(context, ref),
              icon: const Icon(Icons.add_rounded),
              label: Text(text.petsAddAction),
            ),
    );
  }
}

AppUnavailableKind? _petsUnavailableKind(
  AsyncValue<List<PetProfile>> pets,
  bool hasInternet,
) {
  final error = pets.asError?.error;
  final raw = _petsErrorMessage(error);
  if (raw == null || _isUnauthorizedError(error)) {
    return null;
  }

  return classifyAppUnavailable(raw: raw, hasInternet: hasInternet);
}

String? _petsErrorMessage(Object? error) {
  if (error == null) {
    return null;
  }

  if (error is AppException) {
    final message = error.message.trim();
    return message.isEmpty ? 'pets.request_failed' : message;
  }

  if (error is String) {
    final message = error.trim();
    return message.isEmpty ? 'pets.request_failed' : message;
  }

  return 'pets.request_failed';
}
