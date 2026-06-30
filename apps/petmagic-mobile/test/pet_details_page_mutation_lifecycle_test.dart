import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart'
    as image_picker_platform;
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/features/pets/presentation/my_pets_page.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'my_pets_page_test_support.dart';

void main() {
  configurePetPageTestHarness();

  testWidgets('Add photo taps are ignored while upload is in flight', (
    tester,
  ) async {
    final previousImagePickerPlatform =
        image_picker_platform.ImagePickerPlatform.instance;
    final picker = FakeImagePickerPlatform(
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
      uploadCompleter: uploadCompleter,
    );

    await pumpPetDetails(tester, repository: repository);

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
    final picker = FakeImagePickerPlatform(
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
      uploadCompleter: uploadCompleter,
    );

    await pumpPetDetails(tester, repository: repository);

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
    final picker = FakeImagePickerPlatform(
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
      uploadCompleter: uploadCompleter,
      uploadError: const AppException('pets.upload_failed'),
    );

    await pumpPetDetails(tester, repository: repository);

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
    final picker = FakeImagePickerPlatform(
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
    final router = petDetailsRouter();
    addTearDown(router.dispose);

    await pumpPetDetailsWithRouter(
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
      find.widgetWithIcon(IconButton, Icons.photo_camera_outlined),
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
      final picker = FakeImagePickerPlatform(
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
      final router = petDetailsRouter();
      addTearDown(router.dispose);

      await pumpPetDetailsWithRouter(
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
        favoriteCompleter: favoriteCompleter,
      );

      await pumpPetDetails(tester, repository: repository);
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
}
