import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/features/pets/presentation/my_pets_page.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_page.dart';
import 'my_pets_page_test_support.dart';

void main() {
  configurePetPageTestHarness();

  testWidgets('Pet delete action cancellation does not refresh after dispose', (
    tester,
  ) async {
    final deleteCompleter = Completer<void>();
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

    await pumpPetDetails(tester, repository: repository);
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

    await pumpPetDetails(tester, repository: repository);
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
      final router = petDetailsRouter();
      addTearDown(router.dispose);

      await pumpPetDetailsWithRouter(
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
      final router = petDetailsRouter();
      addTearDown(router.dispose);

      await pumpPetDetailsWithRouter(
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
      final repository = FakePetRepository(
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
      final router = petDetailsRouter();
      addTearDown(router.dispose);

      await pumpPetDetailsWithRouter(
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

    await pumpPetDetails(tester, repository: repository);

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
