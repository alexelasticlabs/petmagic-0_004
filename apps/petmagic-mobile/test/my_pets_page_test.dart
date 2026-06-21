import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart'
    as image_picker_platform;
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/pets/presentation/my_pets_page.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/profile/presentation/auth_entry_page.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_page.dart';
import 'package:petmagic_mobile/shared/widgets/protected_auth_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('Pet photo mutations evict cached image URLs before refresh', () {
    final source = File(
      'lib/features/pets/presentation/my_pets_page.dart',
    ).readAsStringSync();

    expect(source, contains('Future<void> _evictPetPhotoMedia'));
    expect(source, contains('CachedNetworkImage.evictFromCache(imageUrl)'));
    expect(source, contains('currentAvatarUrl: pet.avatarUrl'));
    expect(source, contains('currentAvatarUrl: widget.currentAvatarUrl'));
    expect(
      source,
      contains(
        'await _evictPetMediaUrl(currentAvatarUrl);\n'
        '  await _evictPetPhotoMedia(uploadedPhoto);\n'
        '  if (cancelToken.isCancelled)',
      ),
    );
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

  for (final config in <_PetUiVariant>[
    _PetUiVariant(
      name: 'Android light',
      platform: TargetPlatform.android,
      brightness: Brightness.light,
    ),
    _PetUiVariant(
      name: 'Android dark',
      platform: TargetPlatform.android,
      brightness: Brightness.dark,
    ),
    _PetUiVariant(
      name: 'iOS light',
      platform: TargetPlatform.iOS,
      brightness: Brightness.light,
    ),
    _PetUiVariant(
      name: 'iOS dark',
      platform: TargetPlatform.iOS,
      brightness: Brightness.dark,
    ),
  ]) {
    testWidgets('My Pets renders in ${config.name}', (tester) async {
      debugDefaultTargetPlatformOverride = config.platform;
      try {
        await _pumpMyPets(
          tester,
          repository: _FakePetRepository(
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
        expect(find.text('Create with Bella'), findsOneWidget);
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
    await _pumpMyPets(
      tester,
      repository: _FakePetRepository(pets: const []),
      brightness: Brightness.light,
    );

    expect(find.text('Добавьте первого питомца'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Add pet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('pet gallery provider refresh futures wait for refetches', () async {
    final petsCompleter = Completer<void>();
    final photosCompleter = Completer<void>();
    final generationsCompleter = Completer<void>();
    final repository = _FakePetRepository(
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
    final repository = _FakePetRepository(pets: const []);

    await _pumpMyPets(
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
    final repository = _FakePetRepository(
      pets: const [],
      fetchPetsError: const AppException(
        'auth.sign_in_required',
        statusCode: 401,
      ),
    );

    await _pumpMyPets(
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

  testWidgets('My Pets create action preserves reserved pet ID for templates', (
    tester,
  ) async {
    const petId = 'pet/list #1?x=2&kind=dog';
    final repository = _FakePetRepository(
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
    );

    await _pumpMyPets(
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

    await tester.tap(find.widgetWithText(FilledButton, 'Create with Bella'));
    await tester.pumpAndSettle();

    expect(find.text('decoded:$petId|<none>'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Pet details uses thumbnail grid and keeps petPhotoId route', (
    tester,
  ) async {
    final repository = _FakePetRepository(
      pets: [
        PetProfile(
          id: 'pet-1',
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
          petId: 'pet-1',
          mediaAssetId: 'media-1',
          url: 'https://cdn.petmagic.app/original.jpg',
          thumbnailUrl: 'https://cdn.petmagic.app/thumb.jpg',
          fileName: 'bella.jpg',
          contentType: 'image/jpeg',
          isFavorite: true,
          isAvatar: true,
          sortOrder: 1,
          createdAtUtc: DateTime.utc(2026),
        ),
      ],
    );

    await _pumpPetDetails(tester, repository: repository);
    await tester.scrollUntilVisible(
      find.byTooltip('Use for generation'),
      120,
      scrollable: find.byType(Scrollable),
    );
    await tester.pump();

    final thumbnail = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage).first,
    );
    expect(thumbnail.imageUrl, 'https://cdn.petmagic.app/thumb.jpg');
    expect(thumbnail.memCacheWidth, 512);
    expect(thumbnail.maxWidthDiskCache, 512);
    expect(find.byTooltip('Set as avatar'), findsOneWidget);
    expect(find.byTooltip('Mark favorite'), findsOneWidget);
    expect(find.byTooltip('Use for generation'), findsOneWidget);
    expect(find.byTooltip('Delete photo'), findsOneWidget);

    await tester.tap(find.byTooltip('Use for generation'));
    await tester.pumpAndSettle();

    expect(
      find.text('templates:petId=pet-1&petPhotoId=photo-1'),
      findsOneWidget,
    );
  });

  testWidgets(
    'Pet details preserves reserved pet and photo IDs for templates',
    (tester) async {
      const petId = 'pet/space #1?x=2&y=3';
      const photoId = 'photo/space #7?x=1&tag=a&b';
      final repository = _FakePetRepository(
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
            id: photoId,
            petId: petId,
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
      );
      final router = _petDetailsRouter(
        initialPetId: petId,
        templatesBuilder: (context, state) => Scaffold(
          body: Center(
            child: Text(
              'decoded:${state.uri.queryParameters['petId']}|'
              '${state.uri.queryParameters['petPhotoId']}',
            ),
          ),
        ),
      );
      addTearDown(router.dispose);

      await _pumpPetDetailsWithRouter(
        tester,
        repository: repository,
        router: router,
      );
      await tester.scrollUntilVisible(
        find.byTooltip('Use for generation'),
        120,
        scrollable: find.byType(Scrollable),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('Use for generation'));
      await tester.pumpAndSettle();

      expect(find.text('decoded:$petId|$photoId'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Pet details never loads original URLs for photo grid thumbnails',
    (tester) async {
      final repository = _FakePetRepository(
        pets: [
          PetProfile(
            id: 'pet-1',
            name: 'Bella',
            type: 'dog',
            photosCount: 2,
            generationsCount: 0,
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
            thumbnailUrl: 'javascript:alert(1)',
            fileName: 'bella.jpg',
            contentType: 'image/jpeg',
            isFavorite: false,
            isAvatar: false,
            sortOrder: 1,
            createdAtUtc: DateTime.utc(2026),
          ),
          PetPhoto(
            id: 'photo-2',
            petId: 'pet-1',
            mediaAssetId: 'media-2',
            url: 'file:///private/photo.jpg',
            thumbnailUrl: 'data:image/png;base64,AAAA',
            fileName: 'unsafe.jpg',
            contentType: 'image/jpeg',
            isFavorite: false,
            isAvatar: false,
            sortOrder: 2,
            createdAtUtc: DateTime.utc(2026),
          ),
        ],
      );

      await _pumpPetDetails(tester, repository: repository);
      await tester.scrollUntilVisible(
        find.byTooltip('Use for generation').first,
        120,
        scrollable: find.byType(Scrollable),
      );
      await tester.pump();

      final networkImages = tester
          .widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage))
          .map((image) => image.imageUrl)
          .toList(growable: false);
      expect(networkImages, isEmpty);
      expect(
        networkImages,
        isNot(contains('https://cdn.petmagic.app/original.jpg')),
      );
      expect(networkImages, isNot(contains('javascript:alert(1)')));
      expect(networkImages, isNot(contains('file:///private/photo.jpg')));
      expect(networkImages, isNot(contains('data:image/png;base64,AAAA')));
      expect(find.byIcon(Icons.broken_image_outlined), findsNWidgets(2));
    },
  );

  testWidgets('Pet generation history disables share for unsafe output URLs', (
    tester,
  ) async {
    final repository = _FakePetRepository(
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
          url: '',
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
          generationId: 'generation-unsafe',
          userId: 'user-1',
          templateId: 'template-1',
          status: TemplateGenerationStatus.completed,
          tokenCost: 6,
          attemptCount: 1,
          createdAtUtc: DateTime.utc(2026),
          updatedAtUtc: DateTime.utc(2026),
          userMediaExpired: false,
          outputUrl: 'javascript:alert(1)',
          templateTitle: 'Unsafe generation',
          templateType: 'image',
        ),
      ],
    );

    await _pumpPetDetails(tester, repository: repository);
    await tester.scrollUntilVisible(
      find.text('Unsafe generation'),
      120,
      scrollable: find.byType(Scrollable),
    );
    await tester.pump();

    final shareButton = tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip('Share'),
        matching: find.byType(IconButton),
      ),
    );

    expect(shareButton.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Pet generation history use-as-input preserves pet context', (
    tester,
  ) async {
    const petId = 'pet/history #1?x=2&kind=dog';
    const petPhotoId = 'photo/history #7?pose=1&tag=a';
    final repository = _FakePetRepository(
      pets: [
        PetProfile(
          id: petId,
          name: 'Bella',
          type: 'dog',
          photosCount: 0,
          generationsCount: 1,
          createdAtUtc: DateTime.utc(2026),
          updatedAtUtc: DateTime.utc(2026),
        ),
      ],
      generations: [
        TemplateGenerationResult(
          generationId: 'generation-history',
          userId: 'user-1',
          templateId: 'template-1',
          status: TemplateGenerationStatus.completed,
          tokenCost: 6,
          attemptCount: 1,
          createdAtUtc: DateTime.utc(2026),
          updatedAtUtc: DateTime.utc(2026),
          userMediaExpired: false,
          outputUrl: 'https://cdn.petmagic.app/output.jpg',
          templateTitle: 'Generated portrait',
          templateType: 'image',
          petId: petId,
          petPhotoId: petPhotoId,
        ),
      ],
    );
    final router = _petDetailsRouter(
      initialPetId: petId,
      templatesBuilder: (context, state) => Scaffold(
        body: Center(
          child: Text(
            'decoded:${state.uri.queryParameters['petId']}|'
            '${state.uri.queryParameters['petPhotoId']}',
          ),
        ),
      ),
    );
    addTearDown(router.dispose);

    await _pumpPetDetailsWithRouter(
      tester,
      repository: repository,
      router: router,
    );
    await tester.scrollUntilVisible(
      find.text('Generated portrait'),
      120,
      scrollable: find.byType(Scrollable),
    );
    await tester.pump();

    final historyTile = find.ancestor(
      of: find.text('Generated portrait'),
      matching: find.byType(ListTile),
    );
    final useInputButton = find.descendant(
      of: historyTile,
      matching: find.byTooltip('Use as input'),
    );
    await tester.tap(useInputButton);
    await tester.pumpAndSettle();

    expect(find.text('decoded:$petId|$petPhotoId'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Pet generation history use-as-input drops orphan photo context',
    (tester) async {
      final repository = _FakePetRepository(
        pets: [
          PetProfile(
            id: 'pet-1',
            name: 'Bella',
            type: 'dog',
            photosCount: 0,
            generationsCount: 1,
            createdAtUtc: DateTime.utc(2026),
            updatedAtUtc: DateTime.utc(2026),
          ),
        ],
        generations: [
          TemplateGenerationResult(
            generationId: 'generation-orphan-photo',
            userId: 'user-1',
            templateId: 'template-1',
            status: TemplateGenerationStatus.completed,
            tokenCost: 6,
            attemptCount: 1,
            createdAtUtc: DateTime.utc(2026),
            updatedAtUtc: DateTime.utc(2026),
            userMediaExpired: false,
            outputUrl: 'https://cdn.petmagic.app/output.jpg',
            templateTitle: 'Generated orphan photo',
            templateType: 'image',
            petPhotoId: 'photo-orphan',
          ),
        ],
      );
      final router = _petDetailsRouter(
        templatesBuilder: (context, state) => Scaffold(
          body: Center(
            child: Text(
              'decoded:${state.uri.queryParameters['petId'] ?? '<none>'}|'
              '${state.uri.queryParameters['petPhotoId'] ?? '<none>'}',
            ),
          ),
        ),
      );
      addTearDown(router.dispose);

      await _pumpPetDetailsWithRouter(
        tester,
        repository: repository,
        router: router,
      );
      await tester.scrollUntilVisible(
        find.text('Generated orphan photo'),
        120,
        scrollable: find.byType(Scrollable),
      );
      await tester.pump();

      final historyTile = find.ancestor(
        of: find.text('Generated orphan photo'),
        matching: find.byType(ListTile),
      );
      final useInputButton = find.descendant(
        of: historyTile,
        matching: find.byTooltip('Use as input'),
      );
      await tester.tap(useInputButton);
      await tester.pumpAndSettle();

      expect(find.text('decoded:<none>|<none>'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Pet details shows auth gate for guests without fetching data', (
    tester,
  ) async {
    final repository = _FakePetRepository(
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
          url: '',
          fileName: 'bella.jpg',
          contentType: 'image/jpeg',
          isFavorite: false,
          isAvatar: false,
          sortOrder: 1,
          createdAtUtc: DateTime.utc(2026),
        ),
      ],
    );

    await _pumpPetDetails(tester, repository: repository, authenticated: false);

    expect(find.byType(ProtectedAuthGate), findsOneWidget);
    expect(find.byTooltip('Delete pet'), findsNothing);
    expect(repository.petsFetchCount, 0);
    expect(repository.petPhotoFetchCount, 0);
    expect(repository.petGenerationFetchCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Pet details stops child fetches after pet list unauthorized error',
    (tester) async {
      final repository = _FakePetRepository(
        pets: const [],
        fetchPetsError: const AppException(
          'auth.session_expired',
          statusCode: 401,
        ),
      );

      await _pumpPetDetails(tester, repository: repository);

      expect(find.byType(ProtectedAuthGate), findsOneWidget);
      expect(find.byTooltip('Delete pet'), findsNothing);
      expect(find.text('Could not load pet'), findsNothing);
      expect(repository.petsFetchCount, 1);
      expect(repository.petPhotoFetchCount, 0);
      expect(repository.petGenerationFetchCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Pet details auth gate preserves reserved pet ID redirect', (
    tester,
  ) async {
    const petId = 'pet/auth #1?x=2&kind=cat';
    final repository = _FakePetRepository(pets: const []);
    final router = _petDetailsRouter(initialPetId: petId);
    addTearDown(router.dispose);

    await _pumpPetDetailsWithRouter(
      tester,
      repository: repository,
      router: router,
      authenticated: false,
    );
    final text = AppLocalizations.of(
      tester.element(find.byType(PetDetailsPage)),
    );

    await tester.tap(find.text(text.profileSignInAction).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(text.profileSignInAction).last);
    await tester.pumpAndSettle();

    expect(find.text('auth-route'), findsOneWidget);
    expect(
      find.text('auth-redirect:${PetDetailsPage.location(petId)}'),
      findsOneWidget,
    );
    expect(repository.petsFetchCount, 0);
    expect(repository.petPhotoFetchCount, 0);
    expect(repository.petGenerationFetchCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Pet details renders empty photo grid state', (tester) async {
    final repository = _FakePetRepository(
      pets: [
        PetProfile(
          id: 'pet-1',
          name: 'Bella',
          type: 'dog',
          photosCount: 0,
          generationsCount: 0,
          createdAtUtc: DateTime.utc(2026),
          updatedAtUtc: DateTime.utc(2026),
        ),
      ],
      photos: const [],
    );

    await _pumpPetDetails(tester, repository: repository);

    expect(repository.petPhotoFetchCount, 1);
    expect(find.text('No photos yet.'), findsOneWidget);
    expect(find.byTooltip('Use for generation'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Pet details shows photo skeleton while photos load', (
    tester,
  ) async {
    final petPhotosCompleter = Completer<void>();
    final repository = _FakePetRepository(
      pets: [
        PetProfile(
          id: 'pet-1',
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
      petPhotosCompleter: petPhotosCompleter,
    );

    await _pumpPetDetails(tester, repository: repository);

    expect(repository.petPhotoFetchCount, 1);
    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.byTooltip('Use for generation'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    petPhotosCompleter.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.scrollUntilVisible(
      find.byTooltip('Use for generation'),
      120,
      scrollable: find.byType(Scrollable),
    );
    await tester.pump();

    final thumbnail = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage).first,
    );
    expect(thumbnail.imageUrl, 'https://cdn.petmagic.app/thumb.jpg');
    expect(find.byTooltip('Use for generation'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Pet details photo load error retries photo provider only', (
    tester,
  ) async {
    final repository = _FakePetRepository(
      pets: [
        PetProfile(
          id: 'pet-1',
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
      petPhotosErrors: [
        DioException(requestOptions: RequestOptions(path: '/pet-photos')),
      ],
    );

    await _pumpPetDetails(
      tester,
      repository: repository,
      settleDuration: Duration.zero,
    );
    await tester.pump();

    expect(repository.petsFetchCount, 1);
    expect(repository.petPhotoFetchCount, 1);
    expect(repository.petGenerationFetchCount, 1);
    expect(find.text('Could not load photos'), findsOneWidget);
    expect(find.byTooltip('Use for generation'), findsNothing);

    await tester.tap(find.widgetWithText(TextButton, 'Retry'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.scrollUntilVisible(
      find.byTooltip('Use for generation'),
      120,
      scrollable: find.byType(Scrollable),
    );
    await tester.pump();

    final thumbnail = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage).first,
    );
    expect(thumbnail.imageUrl, 'https://cdn.petmagic.app/thumb.jpg');
    expect(repository.petsFetchCount, 1);
    expect(repository.petPhotoFetchCount, 2);
    expect(repository.petGenerationFetchCount, 1);
    expect(find.text('Could not load photos'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Pet photo actions call repository and invalidate safely', (
    tester,
  ) async {
    final repository = _FakePetRepository(
      pets: [
        PetProfile(
          id: 'pet-1',
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
          petId: 'pet-1',
          mediaAssetId: 'media-1',
          url: '',
          fileName: 'bella.jpg',
          contentType: 'image/jpeg',
          isFavorite: false,
          isAvatar: false,
          sortOrder: 1,
          createdAtUtc: DateTime.utc(2026),
        ),
      ],
    );

    await _pumpPetDetails(tester, repository: repository);
    await tester.scrollUntilVisible(
      find.byTooltip('Set as avatar'),
      120,
      scrollable: find.byType(Scrollable),
    );
    await tester.pump();
    expect(repository.petsFetchCount, 1);
    expect(repository.petPhotoFetchCount, 1);

    await tester.tap(find.byTooltip('Set as avatar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(repository.avatarPhotoIds, ['photo-1']);
    expect(repository.petsFetchCount, 2);
    expect(repository.petPhotoFetchCount, 2);

    await tester.tap(find.byTooltip('Mark favorite'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(repository.favoriteUpdates, ['photo-1:true']);
    expect(repository.petsFetchCount, 2);
    expect(repository.petPhotoFetchCount, 3);

    await tester.tap(find.byTooltip('Delete photo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(repository.deletedPhotoIds, ['photo-1']);
    expect(repository.petsFetchCount, 3);
    expect(repository.petPhotoFetchCount, 4);
  });

  testWidgets('Pet favorite action toggles off for existing favorites', (
    tester,
  ) async {
    final repository = _FakePetRepository(
      pets: [
        PetProfile(
          id: 'pet-1',
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
          petId: 'pet-1',
          mediaAssetId: 'media-1',
          url: '',
          fileName: 'bella.jpg',
          contentType: 'image/jpeg',
          isFavorite: true,
          isAvatar: false,
          sortOrder: 1,
          createdAtUtc: DateTime.utc(2026),
        ),
      ],
    );

    await _pumpPetDetails(tester, repository: repository);
    await tester.scrollUntilVisible(
      find.byTooltip('Mark favorite'),
      120,
      scrollable: find.byType(Scrollable),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Mark favorite'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(repository.favoriteUpdates, ['photo-1:false']);
    expect(repository.petPhotoFetchCount, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Pet photo action taps are ignored while a request is in flight',
    (tester) async {
      final avatarCompleter = Completer<void>();
      final repository = _FakePetRepository(
        pets: [
          PetProfile(
            id: 'pet-1',
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
            petId: 'pet-1',
            mediaAssetId: 'media-1',
            url: '',
            fileName: 'bella.jpg',
            contentType: 'image/jpeg',
            isFavorite: false,
            isAvatar: false,
            sortOrder: 1,
            createdAtUtc: DateTime.utc(2026),
          ),
        ],
        avatarCompleter: avatarCompleter,
      );

      await _pumpPetDetails(tester, repository: repository);
      await tester.scrollUntilVisible(
        find.byTooltip('Set as avatar'),
        120,
        scrollable: find.byType(Scrollable),
      );
      await tester.pump();

      expect(repository.petPhotoFetchCount, 1);

      await tester.tap(find.byTooltip('Set as avatar'));
      await tester.tap(find.byTooltip('Set as avatar'));
      await tester.pump();

      expect(repository.avatarPhotoIds, ['photo-1']);
      expect(repository.petPhotoFetchCount, 1);

      avatarCompleter.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(repository.avatarPhotoIds, ['photo-1']);
      expect(repository.petPhotoFetchCount, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Use for generation is disabled while photo action is in flight',
    (tester) async {
      final avatarCompleter = Completer<void>();
      final repository = _FakePetRepository(
        pets: [
          PetProfile(
            id: 'pet-1',
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
            petId: 'pet-1',
            mediaAssetId: 'media-1',
            url: '',
            fileName: 'bella.jpg',
            contentType: 'image/jpeg',
            isFavorite: false,
            isAvatar: false,
            sortOrder: 1,
            createdAtUtc: DateTime.utc(2026),
          ),
        ],
        avatarCompleter: avatarCompleter,
      );

      await _pumpPetDetails(tester, repository: repository);
      await tester.scrollUntilVisible(
        find.byTooltip('Set as avatar'),
        120,
        scrollable: find.byType(Scrollable),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('Set as avatar'));
      await tester.pump();

      final disabledUseButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.auto_awesome_rounded).first,
      );
      expect(disabledUseButton.onPressed, isNull);

      await tester.tap(
        find.byTooltip('Use for generation'),
        warnIfMissed: false,
      );
      await tester.pump();

      expect(find.byType(PetDetailsPage), findsOneWidget);
      expect(find.textContaining('templates:'), findsNothing);

      avatarCompleter.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final enabledUseButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.auto_awesome_rounded).first,
      );
      expect(enabledUseButton.onPressed, isNotNull);

      await tester.tap(find.byTooltip('Use for generation'));
      await tester.pumpAndSettle();

      expect(
        find.text('templates:petId=pet-1&petPhotoId=photo-1'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Pet photo action cancellation does not show an error snackbar', (
    tester,
  ) async {
    final repository = _FakePetRepository(
      pets: [
        PetProfile(
          id: 'pet-1',
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
          petId: 'pet-1',
          mediaAssetId: 'media-1',
          url: '',
          fileName: 'bella.jpg',
          contentType: 'image/jpeg',
          isFavorite: false,
          isAvatar: false,
          sortOrder: 1,
          createdAtUtc: DateTime.utc(2026),
        ),
      ],
      avatarError: DioException(
        requestOptions: RequestOptions(
          path: '/api/pets/pet-1/photos/photo-1/set-avatar',
        ),
        type: DioExceptionType.cancel,
      ),
    );

    await _pumpPetDetails(tester, repository: repository);
    await tester.scrollUntilVisible(
      find.byTooltip('Set as avatar'),
      120,
      scrollable: find.byType(Scrollable),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Set as avatar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(repository.avatarPhotoIds, ['photo-1']);
    expect(repository.petPhotoFetchCount, 1);
    expect(find.text('Could not update photo'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Add photo upload cancellation does not show an error snackbar', (
    tester,
  ) async {
    final previousImagePickerPlatform =
        image_picker_platform.ImagePickerPlatform.instance;
    final picker = _FakeImagePickerPlatform(
      pickedFile: XFile(
        '/tmp/petmagic-upload.jpg',
        name: 'petmagic-upload.jpg',
      ),
    );
    image_picker_platform.ImagePickerPlatform.instance = picker;
    addTearDown(() {
      image_picker_platform.ImagePickerPlatform.instance =
          previousImagePickerPlatform;
    });

    final repository = _FakePetRepository(
      pets: [
        PetProfile(
          id: 'pet-1',
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
          petId: 'pet-1',
          mediaAssetId: 'media-1',
          url: '',
          fileName: 'bella.jpg',
          contentType: 'image/jpeg',
          isFavorite: false,
          isAvatar: false,
          sortOrder: 1,
          createdAtUtc: DateTime.utc(2026),
        ),
      ],
      uploadError: DioException(
        requestOptions: RequestOptions(path: '/api/pets/pet-1/photos'),
        type: DioExceptionType.cancel,
      ),
    );

    await _pumpPetDetails(tester, repository: repository);

    await tester.tap(find.byTooltip('Add photos'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(picker.pickImageCalls, 1);
    expect(repository.uploadCalls, 1);
    expect(repository.petPhotoFetchCount, 1);
    expect(find.text('Could not upload photo'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Add photo upload shows specific unsupported type error', (
    tester,
  ) async {
    final previousImagePickerPlatform =
        image_picker_platform.ImagePickerPlatform.instance;
    final picker = _FakeImagePickerPlatform(
      pickedFile: XFile(
        '/tmp/petmagic-upload.txt',
        name: 'petmagic-upload.txt',
      ),
    );
    image_picker_platform.ImagePickerPlatform.instance = picker;
    addTearDown(() {
      image_picker_platform.ImagePickerPlatform.instance =
          previousImagePickerPlatform;
    });

    final repository = _FakePetRepository(
      pets: [
        PetProfile(
          id: 'pet-1',
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
          petId: 'pet-1',
          mediaAssetId: 'media-1',
          url: '',
          fileName: 'bella.jpg',
          contentType: 'image/jpeg',
          isFavorite: false,
          isAvatar: false,
          sortOrder: 1,
          createdAtUtc: DateTime.utc(2026),
        ),
      ],
      uploadError: const AppException('pets.photo_type_not_allowed'),
    );

    await _pumpPetDetails(tester, repository: repository);

    await tester.tap(find.byTooltip('Add photos'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(picker.pickImageCalls, 1);
    expect(repository.uploadCalls, 1);
    expect(repository.petPhotoFetchCount, 1);
    expect(find.text('This photo type is not supported'), findsOneWidget);
    expect(find.text('Could not upload photo'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Add photo upload invalidates pets and photos after success', (
    tester,
  ) async {
    final previousImagePickerPlatform =
        image_picker_platform.ImagePickerPlatform.instance;
    final picker = _FakeImagePickerPlatform(
      pickedFile: XFile(
        '/tmp/petmagic-upload-success.jpg',
        name: 'petmagic-upload-success.jpg',
      ),
    );
    image_picker_platform.ImagePickerPlatform.instance = picker;
    addTearDown(() {
      image_picker_platform.ImagePickerPlatform.instance =
          previousImagePickerPlatform;
    });

    final repository = _FakePetRepository(
      pets: [
        PetProfile(
          id: 'pet-1',
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
          petId: 'pet-1',
          mediaAssetId: 'media-1',
          url: '',
          fileName: 'bella.jpg',
          contentType: 'image/jpeg',
          isFavorite: false,
          isAvatar: false,
          sortOrder: 1,
          createdAtUtc: DateTime.utc(2026),
        ),
      ],
    );

    await _pumpPetDetails(tester, repository: repository);

    expect(repository.petsFetchCount, 1);
    expect(repository.petPhotoFetchCount, 1);

    await tester.tap(find.byTooltip('Add photos'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(picker.pickImageCalls, 1);
    expect(repository.uploadCalls, 1);
    expect(repository.uploadedPhotoPaths, ['/tmp/petmagic-upload-success.jpg']);
    expect(repository.petsFetchCount, 2);
    expect(repository.petPhotoFetchCount, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Add photo taps are ignored while upload is in flight', (
    tester,
  ) async {
    final previousImagePickerPlatform =
        image_picker_platform.ImagePickerPlatform.instance;
    final picker = _FakeImagePickerPlatform(
      pickedFile: XFile(
        '/tmp/petmagic-upload.jpg',
        name: 'petmagic-upload.jpg',
      ),
    );
    image_picker_platform.ImagePickerPlatform.instance = picker;
    addTearDown(() {
      image_picker_platform.ImagePickerPlatform.instance =
          previousImagePickerPlatform;
    });

    final uploadCompleter = Completer<void>();
    final repository = _FakePetRepository(
      pets: [
        PetProfile(
          id: 'pet-1',
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
          petId: 'pet-1',
          mediaAssetId: 'media-1',
          url: '',
          fileName: 'bella.jpg',
          contentType: 'image/jpeg',
          isFavorite: false,
          isAvatar: false,
          sortOrder: 1,
          createdAtUtc: DateTime.utc(2026),
        ),
      ],
      uploadCompleter: uploadCompleter,
    );

    await _pumpPetDetails(tester, repository: repository);

    expect(repository.petPhotoFetchCount, 1);

    await tester.tap(find.byTooltip('Add photos'));
    await tester.pump();
    await tester.tap(find.byTooltip('Add photos'), warnIfMissed: false);
    await tester.pump();

    expect(picker.pickImageCalls, 1);
    expect(repository.uploadCalls, 1);
    expect(repository.uploadedPhotoPaths, ['/tmp/petmagic-upload.jpg']);
    expect(repository.petPhotoFetchCount, 1);

    uploadCompleter.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(repository.uploadCalls, 1);
    expect(repository.petPhotoFetchCount, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Add photo upload cancel token is cancelled on dispose', (
    tester,
  ) async {
    final previousImagePickerPlatform =
        image_picker_platform.ImagePickerPlatform.instance;
    final picker = _FakeImagePickerPlatform(
      pickedFile: XFile(
        '/tmp/petmagic-upload.jpg',
        name: 'petmagic-upload.jpg',
      ),
    );
    image_picker_platform.ImagePickerPlatform.instance = picker;
    addTearDown(() {
      image_picker_platform.ImagePickerPlatform.instance =
          previousImagePickerPlatform;
    });

    final uploadCompleter = Completer<void>();
    final repository = _FakePetRepository(
      pets: [
        PetProfile(
          id: 'pet-1',
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
          petId: 'pet-1',
          mediaAssetId: 'media-1',
          url: '',
          fileName: 'bella.jpg',
          contentType: 'image/jpeg',
          isFavorite: false,
          isAvatar: false,
          sortOrder: 1,
          createdAtUtc: DateTime.utc(2026),
        ),
      ],
      uploadCompleter: uploadCompleter,
    );

    await _pumpPetDetails(tester, repository: repository);

    await tester.tap(find.byTooltip('Add photos'));
    await tester.pump();

    expect(repository.uploadCalls, 1);
    expect(repository.uploadCancelToken?.isCancelled, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(repository.uploadCancelToken?.isCancelled, isTrue);
    expect(repository.petPhotoFetchCount, 1);

    uploadCompleter.complete();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('Late add-photo upload failure after dispose is ignored', (
    tester,
  ) async {
    final previousImagePickerPlatform =
        image_picker_platform.ImagePickerPlatform.instance;
    final picker = _FakeImagePickerPlatform(
      pickedFile: XFile(
        '/tmp/petmagic-upload-late-failure.jpg',
        name: 'petmagic-upload-late-failure.jpg',
      ),
    );
    image_picker_platform.ImagePickerPlatform.instance = picker;
    addTearDown(() {
      image_picker_platform.ImagePickerPlatform.instance =
          previousImagePickerPlatform;
    });

    final uploadCompleter = Completer<void>();
    final repository = _FakePetRepository(
      pets: [
        PetProfile(
          id: 'pet-1',
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
          petId: 'pet-1',
          mediaAssetId: 'media-1',
          url: '',
          fileName: 'bella.jpg',
          contentType: 'image/jpeg',
          isFavorite: false,
          isAvatar: false,
          sortOrder: 1,
          createdAtUtc: DateTime.utc(2026),
        ),
      ],
      uploadCompleter: uploadCompleter,
      uploadError: const AppException('pets.upload_failed'),
    );

    await _pumpPetDetails(tester, repository: repository);

    await tester.tap(find.byTooltip('Add photos'));
    await tester.pump();

    expect(repository.uploadCalls, 1);
    expect(repository.uploadCancelToken?.isCancelled, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(repository.uploadCancelToken?.isCancelled, isTrue);

    uploadCompleter.complete();
    await tester.pump();

    expect(find.text('Could not upload photo'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Add photo upload state resets when navigating to another pet', (
    tester,
  ) async {
    final previousImagePickerPlatform =
        image_picker_platform.ImagePickerPlatform.instance;
    final picker = _FakeImagePickerPlatform(
      pickedFile: XFile(
        '/tmp/petmagic-upload-route-change.jpg',
        name: 'petmagic-upload-route-change.jpg',
      ),
    );
    image_picker_platform.ImagePickerPlatform.instance = picker;
    addTearDown(() {
      image_picker_platform.ImagePickerPlatform.instance =
          previousImagePickerPlatform;
    });

    final uploadCompleter = Completer<void>();
    final repository = _FakePetRepository(
      pets: [
        PetProfile(
          id: 'pet-1',
          name: 'Bella',
          type: 'dog',
          photosCount: 1,
          generationsCount: 0,
          createdAtUtc: DateTime.utc(2026),
          updatedAtUtc: DateTime.utc(2026),
        ),
        PetProfile(
          id: 'pet-2',
          name: 'Milo',
          type: 'cat',
          photosCount: 1,
          generationsCount: 0,
          createdAtUtc: DateTime.utc(2026),
          updatedAtUtc: DateTime.utc(2026),
        ),
      ],
      photos: [
        PetPhoto(
          id: 'photo-1',
          petId: 'pet-1',
          mediaAssetId: 'media-1',
          url: '',
          fileName: 'bella.jpg',
          contentType: 'image/jpeg',
          isFavorite: false,
          isAvatar: false,
          sortOrder: 1,
          createdAtUtc: DateTime.utc(2026),
        ),
        PetPhoto(
          id: 'photo-2',
          petId: 'pet-2',
          mediaAssetId: 'media-2',
          url: '',
          fileName: 'milo.jpg',
          contentType: 'image/jpeg',
          isFavorite: false,
          isAvatar: false,
          sortOrder: 1,
          createdAtUtc: DateTime.utc(2026),
        ),
      ],
      uploadCompleter: uploadCompleter,
    );
    final router = _petDetailsRouter();
    addTearDown(router.dispose);

    await _pumpPetDetailsWithRouter(
      tester,
      repository: repository,
      router: router,
    );

    await tester.tap(find.byTooltip('Add photos'));
    await tester.pump();

    final firstToken = repository.uploadCancelToken;
    expect(repository.uploadCalls, 1);
    expect(firstToken?.isCancelled, isFalse);
    expect(repository.petPhotoFetchCount, 1);

    router.go(PetDetailsPage.location('pet-2'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(firstToken?.isCancelled, isTrue);
    expect(find.text('Milo'), findsOneWidget);
    expect(repository.petPhotoFetchCount, 2);
    final addPhotoButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.add_a_photo_outlined),
    );
    expect(addPhotoButton.onPressed, isNotNull);

    uploadCompleter.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(repository.petPhotoFetchCount, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Stale add-photo completion after route change does not clear a newer upload',
    (tester) async {
      final previousImagePickerPlatform =
          image_picker_platform.ImagePickerPlatform.instance;
      final picker = _FakeImagePickerPlatform(
        pickedFile: XFile(
          '/tmp/petmagic-upload-route-race.jpg',
          name: 'petmagic-upload-route-race.jpg',
        ),
      );
      image_picker_platform.ImagePickerPlatform.instance = picker;
      addTearDown(() {
        image_picker_platform.ImagePickerPlatform.instance =
            previousImagePickerPlatform;
      });

      final firstUploadCompleter = Completer<void>();
      final secondUploadCompleter = Completer<void>();
      final repository = _FakePetRepository(
        pets: [
          PetProfile(
            id: 'pet-1',
            name: 'Bella',
            type: 'dog',
            photosCount: 1,
            generationsCount: 0,
            createdAtUtc: DateTime.utc(2026),
            updatedAtUtc: DateTime.utc(2026),
          ),
          PetProfile(
            id: 'pet-2',
            name: 'Milo',
            type: 'cat',
            photosCount: 1,
            generationsCount: 0,
            createdAtUtc: DateTime.utc(2026),
            updatedAtUtc: DateTime.utc(2026),
          ),
        ],
        photos: [
          PetPhoto(
            id: 'photo-1',
            petId: 'pet-1',
            mediaAssetId: 'media-1',
            url: '',
            fileName: 'bella.jpg',
            contentType: 'image/jpeg',
            isFavorite: false,
            isAvatar: false,
            sortOrder: 1,
            createdAtUtc: DateTime.utc(2026),
          ),
          PetPhoto(
            id: 'photo-2',
            petId: 'pet-2',
            mediaAssetId: 'media-2',
            url: '',
            fileName: 'milo.jpg',
            contentType: 'image/jpeg',
            isFavorite: false,
            isAvatar: false,
            sortOrder: 1,
            createdAtUtc: DateTime.utc(2026),
          ),
        ],
        uploadCompleters: [firstUploadCompleter, secondUploadCompleter],
      );
      final router = _petDetailsRouter();
      addTearDown(router.dispose);

      await _pumpPetDetailsWithRouter(
        tester,
        repository: repository,
        router: router,
      );

      await tester.tap(find.byTooltip('Add photos'));
      await tester.pump();
      final firstToken = repository.uploadCancelTokens.single;
      expect(repository.uploadCalls, 1);

      router.go(PetDetailsPage.location('pet-2'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(firstToken.isCancelled, isTrue);
      expect(find.text('Milo'), findsOneWidget);

      await tester.tap(find.byTooltip('Add photos'));
      await tester.pump();

      expect(repository.uploadCalls, 2);
      expect(repository.uploadCancelTokens.last.isCancelled, isFalse);

      firstUploadCompleter.complete();
      await tester.pump();
      await tester.tap(find.byTooltip('Add photos'), warnIfMissed: false);
      await tester.pump();

      expect(repository.uploadCalls, 2);

      secondUploadCompleter.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(repository.petPhotoFetchCount, 3);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Pet photo action cancel token is cancelled on dispose', (
    tester,
  ) async {
    final avatarCompleter = Completer<void>();
    final repository = _FakePetRepository(
      pets: [
        PetProfile(
          id: 'pet-1',
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
          petId: 'pet-1',
          mediaAssetId: 'media-1',
          url: '',
          fileName: 'bella.jpg',
          contentType: 'image/jpeg',
          isFavorite: false,
          isAvatar: false,
          sortOrder: 1,
          createdAtUtc: DateTime.utc(2026),
        ),
      ],
      avatarCompleter: avatarCompleter,
    );

    await _pumpPetDetails(tester, repository: repository);
    await tester.scrollUntilVisible(
      find.byTooltip('Set as avatar'),
      120,
      scrollable: find.byType(Scrollable),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Set as avatar'));
    await tester.pump();

    expect(repository.avatarPhotoIds, ['photo-1']);
    expect(repository.avatarCancelToken?.isCancelled, isFalse);
    expect(repository.petPhotoFetchCount, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(repository.avatarCancelToken?.isCancelled, isTrue);
    expect(repository.petPhotoFetchCount, 1);

    avatarCompleter.complete();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Pet favorite action cancellation does not refresh after dispose',
    (tester) async {
      final favoriteCompleter = Completer<void>();
      final repository = _FakePetRepository(
        pets: [
          PetProfile(
            id: 'pet-1',
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
            petId: 'pet-1',
            mediaAssetId: 'media-1',
            url: '',
            fileName: 'bella.jpg',
            contentType: 'image/jpeg',
            isFavorite: false,
            isAvatar: false,
            sortOrder: 1,
            createdAtUtc: DateTime.utc(2026),
          ),
        ],
        favoriteCompleter: favoriteCompleter,
      );

      await _pumpPetDetails(tester, repository: repository);
      await tester.scrollUntilVisible(
        find.byTooltip('Mark favorite'),
        120,
        scrollable: find.byType(Scrollable),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('Mark favorite'));
      await tester.pump();

      expect(repository.favoriteUpdates, ['photo-1:true']);
      expect(repository.favoriteCancelToken?.isCancelled, isFalse);
      expect(repository.petPhotoFetchCount, 1);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(repository.favoriteCancelToken?.isCancelled, isTrue);
      expect(repository.petPhotoFetchCount, 1);

      favoriteCompleter.complete();
      await tester.pump();

      expect(repository.petPhotoFetchCount, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Pet delete action cancellation does not refresh after dispose', (
    tester,
  ) async {
    final deleteCompleter = Completer<void>();
    final repository = _FakePetRepository(
      pets: [
        PetProfile(
          id: 'pet-1',
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
          petId: 'pet-1',
          mediaAssetId: 'media-1',
          url: '',
          fileName: 'bella.jpg',
          contentType: 'image/jpeg',
          isFavorite: false,
          isAvatar: false,
          sortOrder: 1,
          createdAtUtc: DateTime.utc(2026),
        ),
      ],
      deletePhotoCompleter: deleteCompleter,
    );

    await _pumpPetDetails(tester, repository: repository);
    await tester.scrollUntilVisible(
      find.byTooltip('Delete photo'),
      120,
      scrollable: find.byType(Scrollable),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Delete photo'));
    await tester.pump();

    expect(repository.deletedPhotoIds, ['photo-1']);
    expect(repository.deletePhotoCancelToken?.isCancelled, isFalse);
    expect(repository.petPhotoFetchCount, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(repository.deletePhotoCancelToken?.isCancelled, isTrue);
    expect(repository.petPhotoFetchCount, 1);

    deleteCompleter.complete();
    await tester.pump();

    expect(repository.petPhotoFetchCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Late photo action failure after dispose is ignored', (
    tester,
  ) async {
    final avatarCompleter = Completer<void>();
    final repository = _FakePetRepository(
      pets: [
        PetProfile(
          id: 'pet-1',
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
          petId: 'pet-1',
          mediaAssetId: 'media-1',
          url: '',
          fileName: 'bella.jpg',
          contentType: 'image/jpeg',
          isFavorite: false,
          isAvatar: false,
          sortOrder: 1,
          createdAtUtc: DateTime.utc(2026),
        ),
      ],
      avatarCompleter: avatarCompleter,
      avatarError: const AppException('pets.avatar_failed'),
    );

    await _pumpPetDetails(tester, repository: repository);
    await tester.scrollUntilVisible(
      find.byTooltip('Set as avatar'),
      120,
      scrollable: find.byType(Scrollable),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Set as avatar'));
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(repository.avatarCancelToken?.isCancelled, isTrue);

    avatarCompleter.complete();
    await tester.pump();

    expect(find.text('Could not update photo'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Pet photo action state is reset when navigating to another pet',
    (tester) async {
      final avatarCompleter = Completer<void>();
      final repository = _FakePetRepository(
        pets: [
          PetProfile(
            id: 'pet-1',
            name: 'Bella',
            type: 'dog',
            photosCount: 1,
            generationsCount: 0,
            createdAtUtc: DateTime.utc(2026),
            updatedAtUtc: DateTime.utc(2026),
          ),
          PetProfile(
            id: 'pet-2',
            name: 'Milo',
            type: 'cat',
            photosCount: 1,
            generationsCount: 0,
            createdAtUtc: DateTime.utc(2026),
            updatedAtUtc: DateTime.utc(2026),
          ),
        ],
        photos: [
          PetPhoto(
            id: 'photo-shared',
            petId: 'pet-1',
            mediaAssetId: 'media-1',
            url: '',
            fileName: 'bella.jpg',
            contentType: 'image/jpeg',
            isFavorite: false,
            isAvatar: false,
            sortOrder: 1,
            createdAtUtc: DateTime.utc(2026),
          ),
          PetPhoto(
            id: 'photo-shared',
            petId: 'pet-2',
            mediaAssetId: 'media-2',
            url: '',
            fileName: 'milo.jpg',
            contentType: 'image/jpeg',
            isFavorite: false,
            isAvatar: false,
            sortOrder: 1,
            createdAtUtc: DateTime.utc(2026),
          ),
        ],
        avatarCompleter: avatarCompleter,
      );
      final router = _petDetailsRouter();
      addTearDown(router.dispose);

      await _pumpPetDetailsWithRouter(
        tester,
        repository: repository,
        router: router,
      );
      await tester.scrollUntilVisible(
        find.byTooltip('Set as avatar'),
        120,
        scrollable: find.byType(Scrollable),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('Set as avatar'));
      await tester.pump();

      final firstToken = repository.avatarCancelToken;
      expect(repository.avatarPhotoIds, ['photo-shared']);
      expect(firstToken?.isCancelled, isFalse);

      router.go(PetDetailsPage.location('pet-2'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.scrollUntilVisible(
        find.byTooltip('Set as avatar'),
        120,
        scrollable: find.byType(Scrollable),
      );
      await tester.pump();

      expect(firstToken?.isCancelled, isTrue);
      expect(find.text('Milo'), findsOneWidget);
      expect(repository.petPhotoFetchCount, 2);
      final setAvatarButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.account_circle_outlined).first,
      );
      expect(setAvatarButton.onPressed, isNotNull);

      avatarCompleter.complete();
      await tester.pump();

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Stale photo action completion after route change does not clear a newer action',
    (tester) async {
      final firstAvatarCompleter = Completer<void>();
      final secondAvatarCompleter = Completer<void>();
      final repository = _FakePetRepository(
        pets: [
          PetProfile(
            id: 'pet-1',
            name: 'Bella',
            type: 'dog',
            photosCount: 1,
            generationsCount: 0,
            createdAtUtc: DateTime.utc(2026),
            updatedAtUtc: DateTime.utc(2026),
          ),
          PetProfile(
            id: 'pet-2',
            name: 'Milo',
            type: 'cat',
            photosCount: 1,
            generationsCount: 0,
            createdAtUtc: DateTime.utc(2026),
            updatedAtUtc: DateTime.utc(2026),
          ),
        ],
        photos: [
          PetPhoto(
            id: 'photo-shared',
            petId: 'pet-1',
            mediaAssetId: 'media-1',
            url: '',
            fileName: 'bella.jpg',
            contentType: 'image/jpeg',
            isFavorite: false,
            isAvatar: false,
            sortOrder: 1,
            createdAtUtc: DateTime.utc(2026),
          ),
          PetPhoto(
            id: 'photo-shared',
            petId: 'pet-2',
            mediaAssetId: 'media-2',
            url: '',
            fileName: 'milo.jpg',
            contentType: 'image/jpeg',
            isFavorite: false,
            isAvatar: false,
            sortOrder: 1,
            createdAtUtc: DateTime.utc(2026),
          ),
        ],
        avatarCompleters: [firstAvatarCompleter, secondAvatarCompleter],
      );
      final router = _petDetailsRouter();
      addTearDown(router.dispose);

      await _pumpPetDetailsWithRouter(
        tester,
        repository: repository,
        router: router,
      );
      await tester.scrollUntilVisible(
        find.byTooltip('Set as avatar'),
        120,
        scrollable: find.byType(Scrollable),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('Set as avatar'));
      await tester.pump();
      final firstToken = repository.avatarCancelTokens.single;
      expect(repository.avatarPhotoIds, ['photo-shared']);

      router.go(PetDetailsPage.location('pet-2'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.scrollUntilVisible(
        find.byTooltip('Set as avatar'),
        120,
        scrollable: find.byType(Scrollable),
      );
      await tester.pump();

      expect(firstToken.isCancelled, isTrue);
      expect(find.text('Milo'), findsOneWidget);

      await tester.tap(find.byTooltip('Set as avatar'));
      await tester.pump();

      expect(repository.avatarPhotoIds, ['photo-shared', 'photo-shared']);
      expect(repository.avatarCancelTokens.last.isCancelled, isFalse);

      firstAvatarCompleter.complete();
      await tester.pump();
      await tester.tap(find.byTooltip('Set as avatar'), warnIfMissed: false);
      await tester.pump();

      expect(repository.avatarPhotoIds, ['photo-shared', 'photo-shared']);

      secondAvatarCompleter.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(repository.petPhotoFetchCount, 3);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Pet details keeps a large photo grid lazy and avoids quick-return refetch',
    (tester) async {
      final repository = _FakePetRepository(
        pets: [
          PetProfile(
            id: 'pet-1',
            name: 'Bella',
            type: 'dog',
            photosCount: 500,
            generationsCount: 0,
            createdAtUtc: DateTime.utc(2026),
            updatedAtUtc: DateTime.utc(2026),
          ),
        ],
        photos: List<PetPhoto>.generate(
          500,
          (index) => PetPhoto(
            id: 'photo-$index',
            petId: 'pet-1',
            mediaAssetId: 'media-$index',
            url: '',
            fileName: 'photo-$index.jpg',
            contentType: 'image/jpeg',
            isFavorite: index.isEven,
            isAvatar: index == 0,
            sortOrder: index,
            createdAtUtc: DateTime.utc(2026),
          ),
        ),
      );
      final router = _petDetailsRouter();
      addTearDown(router.dispose);

      await _pumpPetDetailsWithRouter(
        tester,
        repository: repository,
        router: router,
      );
      await tester.pump();

      expect(repository.petPhotoFetchCount, 1);
      expect(
        find.byTooltip('Use for generation').evaluate().length,
        lessThan(40),
      );

      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
      await tester.pump();

      expect(
        find.byTooltip('Use for generation').evaluate().length,
        lessThan(40),
      );

      router.go(TemplatesPage.routePath);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('templates-route'), findsOneWidget);

      router.go(PetDetailsPage.location('pet-1'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(repository.petPhotoFetchCount, 1);
      expect(find.byType(PetDetailsPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Pet detail fetch cancel tokens are cancelled on dispose', (
    tester,
  ) async {
    final repository = _FakePetRepository(
      pets: [
        PetProfile(
          id: 'pet-1',
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
          petId: 'pet-1',
          mediaAssetId: 'media-1',
          url: '',
          fileName: 'bella.jpg',
          contentType: 'image/jpeg',
          isFavorite: false,
          isAvatar: false,
          sortOrder: 1,
          createdAtUtc: DateTime.utc(2026),
        ),
      ],
    );

    await _pumpPetDetails(tester, repository: repository);

    expect(repository.petsFetchCancelToken?.isCancelled, isFalse);
    expect(repository.petPhotoFetchCancelToken?.isCancelled, isFalse);
    expect(repository.petGenerationsFetchCancelToken?.isCancelled, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(repository.petsFetchCancelToken?.isCancelled, isTrue);
    expect(repository.petPhotoFetchCancelToken?.isCancelled, isTrue);
    expect(repository.petGenerationsFetchCancelToken?.isCancelled, isTrue);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpMyPets(
  WidgetTester tester, {
  required TemplateGenerationRepository repository,
  required Brightness brightness,
  bool authenticated = true,
  Widget Function(BuildContext, GoRouterState)? templatesBuilder,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final router = GoRouter(
    initialLocation: MyPetsPage.routePath,
    routes: [
      GoRoute(
        path: MyPetsPage.routePath,
        builder: (context, state) => const MyPetsPage(),
      ),
      GoRoute(
        path: TemplatesPage.routePath,
        builder:
            templatesBuilder ??
            (context, state) => const Scaffold(body: TemplatesPage()),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appLaunchControllerProvider.overrideWith(
          authenticated
              ? _AuthenticatedAppLaunchController.new
              : _UnauthenticatedAppLaunchController.new,
        ),
        templateGenerationRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: brightness == Brightness.dark
            ? ThemeMode.dark
            : ThemeMode.light,
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

Future<void> _pumpPetDetails(
  WidgetTester tester, {
  required TemplateGenerationRepository repository,
  bool authenticated = true,
  Duration settleDuration = const Duration(milliseconds: 250),
}) async {
  final router = _petDetailsRouter(
    templatesBuilder: (context, state) =>
        Scaffold(body: Center(child: Text('templates:${state.uri.query}'))),
  );
  addTearDown(router.dispose);

  await _pumpPetDetailsWithRouter(
    tester,
    repository: repository,
    router: router,
    authenticated: authenticated,
    settleDuration: settleDuration,
  );
}

Future<void> _pumpPetDetailsWithRouter(
  WidgetTester tester, {
  required TemplateGenerationRepository repository,
  required GoRouter router,
  bool authenticated = true,
  Duration settleDuration = const Duration(milliseconds: 250),
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appLaunchControllerProvider.overrideWith(
          authenticated
              ? _AuthenticatedAppLaunchController.new
              : _UnauthenticatedAppLaunchController.new,
        ),
        templateGenerationRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pump();
  if (settleDuration > Duration.zero) {
    await tester.pump(settleDuration);
  }
}

GoRouter _petDetailsRouter({
  String initialPetId = 'pet-1',
  Widget Function(BuildContext, GoRouterState)? templatesBuilder,
}) {
  return GoRouter(
    initialLocation: PetDetailsPage.location(initialPetId),
    routes: [
      GoRoute(
        path: PetDetailsPage.routePath,
        builder: (context, state) =>
            PetDetailsPage(petId: state.pathParameters['petId'] ?? ''),
      ),
      GoRoute(
        path: TemplatesPage.routePath,
        builder:
            templatesBuilder ??
            (context, state) =>
                const Scaffold(body: Center(child: Text('templates-route'))),
      ),
      GoRoute(
        path: AuthEntryPage.routePath,
        builder: (context, state) {
          final redirect = state.uri.queryParameters['redirect'] ?? '';
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('auth-route'),
                  Text('auth-redirect:$redirect'),
                ],
              ),
            ),
          );
        },
      ),
    ],
  );
}

class _PetUiVariant {
  const _PetUiVariant({
    required this.name,
    required this.platform,
    required this.brightness,
  });

  final String name;
  final TargetPlatform platform;
  final Brightness brightness;
}

class _AuthenticatedAppLaunchController extends AppLaunchController {
  @override
  AppLaunchState build() {
    return const AppLaunchState(
      isLoading: false,
      isAuthenticated: true,
      requiresLegalAcceptance: false,
      hasSeenOnboarding: true,
      guestSessionReady: true,
    );
  }
}

class _UnauthenticatedAppLaunchController extends AppLaunchController {
  @override
  AppLaunchState build() {
    return const AppLaunchState(
      isLoading: false,
      isAuthenticated: false,
      requiresLegalAcceptance: false,
      hasSeenOnboarding: true,
      guestSessionReady: true,
    );
  }
}

class _FakeImagePickerPlatform
    extends image_picker_platform.ImagePickerPlatform {
  _FakeImagePickerPlatform({this.pickedFile});

  final XFile? pickedFile;
  int pickImageCalls = 0;

  @override
  Future<XFile?> getImageFromSource({
    required image_picker_platform.ImageSource source,
    image_picker_platform.ImagePickerOptions options =
        const image_picker_platform.ImagePickerOptions(),
  }) async {
    pickImageCalls++;
    return pickedFile;
  }
}

class _FakePetRepository extends TemplateGenerationRepository {
  _FakePetRepository({
    required this.pets,
    this.photos = const [],
    this.generations = const [],
    this.avatarCompleter,
    this.avatarCompleters = const [],
    this.uploadCompleter,
    this.uploadCompleters = const [],
    this.petPhotosCompleter,
    this.favoriteCompleter,
    this.deletePhotoCompleter,
    List<Object> petPhotosErrors = const [],
    this.fetchPetsError,
    this.avatarError,
    this.uploadError,
  }) : petPhotosErrors = List<Object>.from(petPhotosErrors),
       super(
         dio: Dio(),
         sessionStorage: AuthSessionStorage(),
         preferences: SharedPreferencesAsync(),
       );

  final List<PetProfile> pets;
  final List<PetPhoto> photos;
  final List<TemplateGenerationResult> generations;
  final Completer<void>? avatarCompleter;
  final List<Completer<void>> avatarCompleters;
  final Completer<void>? uploadCompleter;
  final List<Completer<void>> uploadCompleters;
  final Completer<void>? petPhotosCompleter;
  final Completer<void>? favoriteCompleter;
  final Completer<void>? deletePhotoCompleter;
  final List<Object> petPhotosErrors;
  final Object? fetchPetsError;
  final Object? avatarError;
  final Object? uploadError;
  final List<String> avatarPhotoIds = [];
  final List<String> favoriteUpdates = [];
  final List<String> deletedPhotoIds = [];
  final List<String> uploadedPhotoPaths = [];
  final List<CancelToken> uploadCancelTokens = [];
  final List<CancelToken> avatarCancelTokens = [];
  Completer<void>? petsFetchCompleter;
  Completer<void>? petPhotosRefreshCompleter;
  Completer<void>? petGenerationsFetchCompleter;
  CancelToken? petsFetchCancelToken;
  CancelToken? petPhotoFetchCancelToken;
  CancelToken? petGenerationsFetchCancelToken;
  CancelToken? uploadCancelToken;
  CancelToken? avatarCancelToken;
  CancelToken? favoriteCancelToken;
  CancelToken? deletePhotoCancelToken;
  int petsFetchCount = 0;
  int petPhotoFetchCount = 0;
  int petGenerationFetchCount = 0;
  int uploadCalls = 0;

  @override
  Future<List<PetProfile>> fetchPets({CancelToken? cancelToken}) async {
    petsFetchCancelToken = cancelToken;
    petsFetchCount++;
    await petsFetchCompleter?.future;
    final error = fetchPetsError;
    if (error != null) {
      throw error;
    }
    return pets;
  }

  @override
  Future<PetProfile> createPet({
    required String name,
    required String type,
    String? breed,
    CancelToken? cancelToken,
  }) async {
    return PetProfile(
      id: 'pet-new',
      name: name,
      type: type,
      breed: breed,
      photosCount: 0,
      generationsCount: 0,
      createdAtUtc: DateTime.utc(2026),
      updatedAtUtc: DateTime.utc(2026),
    );
  }

  @override
  Future<PetProfile> updatePet({
    required String petId,
    required String name,
    required String type,
    String? breed,
    CancelToken? cancelToken,
  }) async {
    return PetProfile(
      id: petId,
      name: name,
      type: type,
      breed: breed,
      photosCount: 0,
      generationsCount: 0,
      createdAtUtc: DateTime.utc(2026),
      updatedAtUtc: DateTime.utc(2026),
    );
  }

  @override
  Future<void> deletePet(String petId, {CancelToken? cancelToken}) async {}

  @override
  Future<PetPhoto> uploadPetPhoto({
    required String petId,
    required XFile photo,
    CancelToken? cancelToken,
  }) async {
    uploadCalls++;
    uploadCancelToken = cancelToken;
    if (cancelToken != null) {
      uploadCancelTokens.add(cancelToken);
    }
    uploadedPhotoPaths.add(photo.path);
    final completer = uploadCompleters.length >= uploadCalls
        ? uploadCompleters[uploadCalls - 1]
        : uploadCompleter;
    await completer?.future;
    final error = uploadError;
    if (error != null) {
      throw error;
    }
    return PetPhoto(
      id: 'photo-1',
      petId: petId,
      mediaAssetId: 'media-1',
      url: 'https://cdn.petmagic.test/photo.jpg',
      fileName: 'photo.jpg',
      contentType: 'image/jpeg',
      isFavorite: false,
      isAvatar: true,
      sortOrder: 1,
      createdAtUtc: DateTime.utc(2026),
    );
  }

  @override
  Future<List<PetPhoto>> fetchPetPhotos(
    String petId, {
    CancelToken? cancelToken,
  }) async {
    petPhotoFetchCancelToken = cancelToken;
    petPhotoFetchCount++;
    if (petPhotoFetchCount > 1 && petPhotosRefreshCompleter != null) {
      await petPhotosRefreshCompleter!.future;
    } else {
      await petPhotosCompleter?.future;
    }
    if (petPhotosErrors.isNotEmpty) {
      throw petPhotosErrors.removeAt(0);
    }
    return photos
        .where((photo) => photo.petId == petId)
        .toList(growable: false);
  }

  @override
  Future<PetPhoto> setPetPhotoAsAvatar({
    required String petId,
    required String photoId,
    CancelToken? cancelToken,
  }) async {
    avatarCancelToken = cancelToken;
    if (cancelToken != null) {
      avatarCancelTokens.add(cancelToken);
    }
    avatarPhotoIds.add(photoId);
    final completer = avatarCompleters.length >= avatarPhotoIds.length
        ? avatarCompleters[avatarPhotoIds.length - 1]
        : avatarCompleter;
    await completer?.future;
    final error = avatarError;
    if (error != null) {
      throw error;
    }
    return photos.firstWhere((photo) => photo.id == photoId);
  }

  @override
  Future<PetPhoto> setPetPhotoFavorite({
    required String petId,
    required String photoId,
    required bool isFavorite,
    CancelToken? cancelToken,
  }) async {
    favoriteCancelToken = cancelToken;
    favoriteUpdates.add('$photoId:$isFavorite');
    await favoriteCompleter?.future;
    return photos.firstWhere((photo) => photo.id == photoId);
  }

  @override
  Future<void> deletePetPhoto({
    required String petId,
    required String photoId,
    CancelToken? cancelToken,
  }) async {
    deletePhotoCancelToken = cancelToken;
    deletedPhotoIds.add(photoId);
    await deletePhotoCompleter?.future;
  }

  @override
  Future<List<TemplateGenerationResult>> fetchPetGenerations(
    String petId, {
    CancelToken? cancelToken,
  }) async {
    petGenerationsFetchCancelToken = cancelToken;
    petGenerationFetchCount++;
    await petGenerationsFetchCompleter?.future;
    return generations;
  }
}
