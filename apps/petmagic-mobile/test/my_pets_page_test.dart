import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart'
    as image_picker_platform;
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/features/pets/presentation/my_pets_page.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/shared/widgets/protected_auth_gate.dart';
import 'my_pets_page_test_support.dart';

void main() {
  final petsPageCombinedSource = readPetsPresentationSource();
  configurePetPageTestHarness();

  test('Pet photo mutations evict cached image URLs before refresh', () {
    final source = petsPageCombinedSource;

    expect(source, contains('Future<void> _evictPetPhotoMedia'));
    expect(source, contains('CachedNetworkImage.evictFromCache(imageUrl)'));
    expect(source, contains('currentAvatarUrl: pet.avatarUrl'));
    expect(source, contains('currentAvatarUrl: widget.currentAvatarUrl'));
    expect(
      source,
      contains(
        'if ((currentAvatarUrl == null || currentAvatarUrl.trim().isEmpty) &&\n'
        '      !uploadedPhoto.isAvatar &&\n'
        '      uploadedPhoto.id.isNotEmpty)',
      ),
    );
    expect(
      source,
      contains('uploadedPhoto = await repository.setPetPhotoAsAvatar'),
    );
    expect(source, contains('await _evictPetPhotoMedia(uploadedPhoto);'));
    expect(
      source,
      contains(
        'await _evictPetMediaUrl(currentAvatarUrl);\n'
        '  await _evictPetPhotoMedia(photo);\n'
        '  await _evictPetPhotoMedia(updatedPhoto);\n'
        '  if (cancelToken.isCancelled)',
      ),
    );
    expect(
      source,
      contains(
        'await _evictPetMediaUrl(currentAvatarUrl);\n'
        '  await _evictPetPhotoMedia(photo);\n'
        '  if (cancelToken.isCancelled)',
      ),
    );
  });

  test('pet form step widgets stay in a dedicated part file', () {
    final pageSource = File(
      'lib/features/pets/presentation/my_pets_page.dart',
    ).readAsStringSync();
    final formSource = File(
      'lib/features/pets/presentation/my_pets_form_sheet.part.dart',
    ).readAsStringSync();
    final detailsSource = File(
      'lib/features/pets/presentation/my_pets_detail_page.part.dart',
    ).readAsStringSync();
    final widgetsSource = File(
      'lib/features/pets/presentation/my_pets_display_widgets.part.dart',
    ).readAsStringSync();
    final actionsSource = File(
      'lib/features/pets/presentation/my_pets_photo_actions.part.dart',
    ).readAsStringSync();

    expect(pageSource, contains("part 'my_pets_form_sheet.part.dart';"));
    expect(pageSource, contains("part 'my_pets_detail_page.part.dart';"));
    expect(pageSource, contains("part 'my_pets_display_widgets.part.dart';"));
    expect(pageSource, contains("part 'my_pets_photo_actions.part.dart';"));
    expect(pageSource, isNot(contains('class _PetFormProgress')));
    expect(pageSource, isNot(contains('class _PetNameStep')));
    expect(pageSource, isNot(contains('class _PetTypeStep')));
    expect(pageSource, isNot(contains('class _PetPhotoStep')));
    expect(pageSource, isNot(contains('class _PetPhotoCard')));
    expect(pageSource, isNot(contains('class _PetHeader')));
    expect(pageSource, isNot(contains('Future<void> _pickAndUploadPhoto')));
    expect(pageSource, isNot(contains('Future<void> _deletePhoto')));
    expect(formSource, contains("part of 'my_pets_page.dart';"));
    expect(formSource, contains('class _PetFormProgress'));
    expect(formSource, contains('class _PetNameStep'));
    expect(formSource, contains('class _PetTypeStep'));
    expect(formSource, contains('class _PetPhotoStep'));
    expect(detailsSource, contains("part of 'my_pets_page.dart';"));
    expect(detailsSource, contains('class PetDetailsPage'));
    expect(widgetsSource, contains("part of 'my_pets_page.dart';"));
    expect(widgetsSource, contains('class _PetPhotoCard'));
    expect(widgetsSource, contains('class _PetHeader'));
    expect(actionsSource, contains("part of 'my_pets_page.dart';"));
    expect(actionsSource, contains('Future<void> _pickAndUploadPhoto'));
    expect(actionsSource, contains('Future<void> _deletePhoto'));
    expect(formSource, contains('AppLogger.warn('));
    expect(formSource, contains("feature: 'Pets.Form'"));
    expect(formSource, contains("operation: 'save_pet'"));
    expect(formSource, contains('text.profileActionFailed'));
    expect(formSource, isNot(contains('} catch (_) {')));
  });

  test(
    'pet generation history uses localized status labels instead of raw enums',
    () {
      final pageSource = File(
        'lib/features/pets/presentation/my_pets_page.dart',
      ).readAsStringSync();
      final widgetsSource = File(
        'lib/features/pets/presentation/my_pets_display_widgets.part.dart',
      ).readAsStringSync();

      expect(
        pageSource,
        contains(
          "import 'package:petmagic_mobile/features/templates/presentation/mappers/generation_status_mappers.dart';",
        ),
      );
      expect(widgetsSource, contains('statusTitle(text, generation)'));
      expect(
        widgetsSource,
        isNot(
          contains(
            r'generation.templateType ?? text.petsTemplateFallback} • ${generation.status.name}',
          ),
        ),
      );
    },
  );

  test(
    'pet photo cards fall back to original URL when thumbnail is missing or unsafe',
    () {
      final source = petsPageCombinedSource;

      expect(
        source,
        contains(
          'if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {\n'
          '    final normalizedThumbnail = normalizePetMediaUrl(thumbnailUrl);\n'
          '    if (normalizedThumbnail != null) {\n'
          '      return normalizedThumbnail;\n'
          '    }\n'
          '  }\n'
          '\n'
          '  return normalizePetMediaUrl(photo.url);',
        ),
      );
    },
  );

  for (final config in <PetUiVariant>[
    PetUiVariant(
      name: 'Android light',
      platform: TargetPlatform.android,
      brightness: Brightness.light,
    ),
    PetUiVariant(
      name: 'Android dark',
      platform: TargetPlatform.android,
      brightness: Brightness.dark,
    ),
    PetUiVariant(
      name: 'iOS light',
      platform: TargetPlatform.iOS,
      brightness: Brightness.light,
    ),
    PetUiVariant(
      name: 'iOS dark',
      platform: TargetPlatform.iOS,
      brightness: Brightness.dark,
    ),
  ]) {
    testWidgets('My Pets renders in ${config.name}', (tester) async {
      debugDefaultTargetPlatformOverride = config.platform;
      try {
        await pumpMyPets(
          tester,
          repository: FakePetRepository(
            pets: [
              PetProfile(
                id: 'pet-1',
                name: 'Bella',
                type: 'dog',
                breed: 'Corgi',
                avatarUrl: 'https://cdn.petmagic.app/avatar.jpg',
                photosCount: 3,
                generationsCount: 7,
                createdAtUtc: DateTime.utc(2026),
                updatedAtUtc: DateTime.utc(2026),
              ),
            ],
          ),
          brightness: config.brightness,
        );

        expect(find.text('My pets'), findsOneWidget);
        expect(find.text('Bella'), findsOneWidget);
        expect(find.textContaining('3 photos'), findsOneWidget);
        expect(find.textContaining('7 generations'), findsOneWidget);
        final avatar = tester.widget<CachedNetworkImage>(
          find.byType(CachedNetworkImage).first,
        );
        expect(avatar.imageUrl, 'https://cdn.petmagic.app/avatar.jpg');
        expect(avatar.memCacheWidth, 192);
        expect(avatar.maxWidthDiskCache, 192);
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  testWidgets('My Pets empty state renders add pet action', (tester) async {
    await pumpMyPets(
      tester,
      repository: FakePetRepository(pets: const []),
      brightness: Brightness.light,
    );

    expect(find.text('Add your first pet'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Add pet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('My Pets add pet flow saves without crashing', (tester) async {
    final repository = FakePetRepository(pets: const []);
    await pumpMyPets(
      tester,
      repository: repository,
      brightness: Brightness.light,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Add pet'));
    await tester.pumpAndSettle();

    expect(find.text('Add pet'), findsWidgets);
    expect(find.text('Pet name'), findsWidgets);

    await tester.enterText(find.byType(TextField).first, 'Buddy');
    await tester.tap(find.widgetWithText(FilledButton, 'Next').hitTestable());
    await tester.pumpAndSettle();

    expect(find.text('Type and breed'), findsWidgets);

    await tester.tap(find.widgetWithText(FilledButton, 'Next').hitTestable());
    await tester.pumpAndSettle();

    expect(find.text('Pet photo'), findsWidgets);

    await tester.tap(find.widgetWithText(FilledButton, 'Done').hitTestable());
    await tester.pumpAndSettle();

    expect(repository.createdPetNames, ['Buddy']);
    expect(repository.createdPetTypes, ['dog']);
    expect(repository.createdPetBreeds, [null]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('My Pets add pet flow uploads selected first photo', (
    tester,
  ) async {
    final previousImagePickerPlatform =
        image_picker_platform.ImagePickerPlatform.instance;
    final picker = FakeImagePickerPlatform(
      pickedFile: XFile(
        '/tmp/petmagic-create-photo.jpg',
        name: 'petmagic-create-photo.jpg',
      ),
    );
    image_picker_platform.ImagePickerPlatform.instance = picker;
    addTearDown(() {
      image_picker_platform.ImagePickerPlatform.instance =
          previousImagePickerPlatform;
    });

    final repository = FakePetRepository(pets: const []);
    await pumpMyPets(
      tester,
      repository: repository,
      brightness: Brightness.light,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Add pet'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Puçu');
    await tester.tap(find.widgetWithText(FilledButton, 'Next').hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Next').hitTestable());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add photo'));
    await tester.pumpAndSettle();

    expect(find.text('Photo selected'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Done').hitTestable());
    await tester.pumpAndSettle();

    expect(picker.pickImageCalls, 1);
    expect(repository.createdPetNames, ['Puçu']);
    expect(repository.uploadCalls, 1);
    expect(repository.uploadedPhotoPaths, ['/tmp/petmagic-create-photo.jpg']);
    expect(repository.petsFetchCount, greaterThanOrEqualTo(2));
    expect(repository.petPhotoFetchCount, greaterThanOrEqualTo(1));
    expect(tester.takeException(), isNull);
  });

  test('pet gallery provider refresh futures wait for refetches', () async {
    final petsCompleter = Completer<void>();
    final photosCompleter = Completer<void>();
    final generationsCompleter = Completer<void>();
    final repository = FakePetRepository(
      pets: [
        PetProfile(
          id: 'pet-1',
          name: 'Bella',
          type: 'dog',
          photosCount: 1,
          generationsCount: 1,
          createdAtUtc: DateTime.utc(2026),
          updatedAtUtc: DateTime.utc(2026),
        ),
      ],
      photos: [
        PetPhoto(
          id: 'photo-1',
          petId: 'pet-1',
          mediaAssetId: 'media-1',
          url: 'https://cdn.petmagic.app/original.jpg',
          thumbnailUrl: 'https://cdn.petmagic.app/thumb.jpg',
          fileName: 'bella.jpg',
          contentType: 'image/jpeg',
          isFavorite: false,
          isAvatar: false,
          sortOrder: 1,
          createdAtUtc: DateTime.utc(2026),
        ),
      ],
      generations: [
        TemplateGenerationResult(
          generationId: 'generation-1',
          userId: 'user-1',
          templateId: 'template-1',
          status: TemplateGenerationStatus.completed,
          tokenCost: 1,
          attemptCount: 1,
          createdAtUtc: DateTime.utc(2026),
          updatedAtUtc: DateTime.utc(2026),
          userMediaExpired: false,
          templateTitle: 'Magic portrait',
          outputUrl: 'https://cdn.petmagic.app/output.jpg',
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        templateGenerationRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await Future.wait([
      container.read(petsProvider.future),
      container.read(petPhotosProvider('pet-1').future),
      container.read(petGenerationsProvider('pet-1').future),
    ]);
    expect(repository.petsFetchCount, 1);
    expect(repository.petPhotoFetchCount, 1);
    expect(repository.petGenerationFetchCount, 1);

    repository
      ..petsFetchCompleter = petsCompleter
      ..petPhotosRefreshCompleter = photosCompleter
      ..petGenerationsFetchCompleter = generationsCompleter;
    container
      ..invalidate(petsProvider)
      ..invalidate(petPhotosProvider('pet-1'))
      ..invalidate(petGenerationsProvider('pet-1'));

    var petsRefreshCompleted = false;
    var photosRefreshCompleted = false;
    var generationsRefreshCompleted = false;
    final petsRefresh = container
        .read(petsProvider.future)
        .then((_) => petsRefreshCompleted = true);
    final photosRefresh = container
        .read(petPhotosProvider('pet-1').future)
        .then((_) => photosRefreshCompleted = true);
    final generationsRefresh = container
        .read(petGenerationsProvider('pet-1').future)
        .then((_) => generationsRefreshCompleted = true);
    await Future<void>.delayed(Duration.zero);

    expect(repository.petsFetchCount, 2);
    expect(repository.petPhotoFetchCount, 2);
    expect(repository.petGenerationFetchCount, 2);
    expect(petsRefreshCompleted, isFalse);
    expect(photosRefreshCompleted, isFalse);
    expect(generationsRefreshCompleted, isFalse);

    petsCompleter.complete();
    photosCompleter.complete();
    await Future<void>.delayed(Duration.zero);
    expect(petsRefreshCompleted, isTrue);
    expect(photosRefreshCompleted, isTrue);
    expect(generationsRefreshCompleted, isFalse);

    generationsCompleter.complete();
    await Future.wait([petsRefresh, photosRefresh, generationsRefresh]);
    expect(generationsRefreshCompleted, isTrue);
  });

  testWidgets('My Pets shows auth gate for guests without fetching pets', (
    tester,
  ) async {
    final repository = FakePetRepository(pets: const []);

    await pumpMyPets(
      tester,
      repository: repository,
      brightness: Brightness.light,
      authenticated: false,
    );

    expect(find.byType(ProtectedAuthGate), findsOneWidget);
    expect(repository.petsFetchCount, 0);
    expect(repository.petPhotoFetchCount, 0);
    expect(repository.petGenerationFetchCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('My Pets shows auth gate after pet list unauthorized error', (
    tester,
  ) async {
    final repository = FakePetRepository(
      pets: const [],
      fetchPetsError: const AppException(
        'auth.sign_in_required',
        statusCode: 401,
      ),
    );

    await pumpMyPets(
      tester,
      repository: repository,
      brightness: Brightness.light,
    );

    expect(find.byType(ProtectedAuthGate), findsOneWidget);
    expect(find.text('Could not load pets'), findsNothing);
    expect(find.widgetWithText(FloatingActionButton, 'Add pet'), findsNothing);
    expect(repository.petsFetchCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('My Pets shows unavailable state for online load failures', (
    tester,
  ) async {
    await pumpMyPets(
      tester,
      repository: FakePetRepository(
        pets: const [],
        fetchPetsError: const FormatException(
          'raw socket trace /private/token should never reach the UI',
        ),
      ),
      brightness: Brightness.light,
    );

    expect(find.text('Server is unavailable'), findsOneWidget);
    expect(find.text('Could not load pets'), findsNothing);
    expect(
      find.textContaining('/private/token should never reach the UI'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('My Pets create action preserves reserved pet ID for templates', (
    tester,
  ) async {
    const petId = 'pet/list #1?x=2&kind=dog';
    final repository = FakePetRepository(
      pets: [
        PetProfile(
          id: petId,
          name: 'Bella',
          type: 'dog',
          photosCount: 1,
          generationsCount: 0,
          createdAtUtc: DateTime.utc(2026),
          updatedAtUtc: DateTime.utc(2026),
        ),
      ],
      photos: [
        PetPhoto(
          id: 'photo-1',
          petId: petId,
          mediaAssetId: 'media-1',
          url: 'https://cdn.petmagic.app/original.jpg',
          fileName: 'bella.jpg',
          contentType: 'image/jpeg',
          isFavorite: false,
          isAvatar: false,
          sortOrder: 1,
          createdAtUtc: DateTime.utc(2026),
        ),
      ],
    );

    await pumpMyPets(
      tester,
      repository: repository,
      brightness: Brightness.light,
      templatesBuilder: (context, state) => Scaffold(
        body: Center(
          child: Text(
            'decoded:${state.uri.queryParameters['petId']}|'
            '${state.uri.queryParameters['petPhotoId'] ?? '<none>'}',
          ),
        ),
      ),
    );

    await tester.tap(find.text('Bella'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.widgetWithText(FilledButton, 'Generate with Bella'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('decoded:$petId|<none>'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
