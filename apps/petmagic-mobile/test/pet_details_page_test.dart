import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/features/pets/presentation/my_pets_page.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/shared/widgets/protected_auth_gate.dart';
import 'my_pets_page_test_support.dart';

void main() {
  configurePetPageTestHarness();

  testWidgets('Pet details uses thumbnail grid and keeps petPhotoId route', (
    tester,
  ) async {
    final repository = FakePetRepository(
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

    await pumpPetDetails(tester, repository: repository);
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
      final router = petDetailsRouter(
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

      await pumpPetDetailsWithRouter(
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
    'Pet details falls back to safe original URLs when thumbnail is unsafe',
    (tester) async {
      final repository = FakePetRepository(
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

      await pumpPetDetails(tester, repository: repository);
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
      expect(networkImages, contains('https://cdn.petmagic.app/original.jpg'));
      expect(networkImages, isNot(contains('javascript:alert(1)')));
      expect(networkImages, isNot(contains('file:///private/photo.jpg')));
      expect(networkImages, isNot(contains('data:image/png;base64,AAAA')));
      expect(find.byIcon(Icons.pets_rounded), findsOneWidget);
    },
  );

  testWidgets('Pet generation history disables share for unsafe output URLs', (
    tester,
  ) async {
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

    await pumpPetDetails(tester, repository: repository);
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
    final repository = FakePetRepository(
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
    final router = petDetailsRouter(
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

    await pumpPetDetailsWithRouter(
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
      final repository = FakePetRepository(
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
      final router = petDetailsRouter(
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

      await pumpPetDetailsWithRouter(
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

    await pumpPetDetails(tester, repository: repository, authenticated: false);

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
      final repository = FakePetRepository(
        pets: const [],
        fetchPetsError: const AppException(
          'auth.session_expired',
          statusCode: 401,
        ),
      );

      await pumpPetDetails(tester, repository: repository);

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
    final repository = FakePetRepository(pets: const []);
    final router = petDetailsRouter(initialPetId: petId);
    addTearDown(router.dispose);

    await pumpPetDetailsWithRouter(
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
}
