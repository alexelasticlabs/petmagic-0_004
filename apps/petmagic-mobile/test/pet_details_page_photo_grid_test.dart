import 'dart:async';

import 'package:dio/dio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart'
    as image_picker_platform;
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/permissions/app_permission_coordinator.dart';
import 'package:petmagic_mobile/features/pets/presentation/my_pets_page.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/shared/notifications/petmagic_notification_center.dart';
import 'my_pets_page_test_support.dart';
import 'test_permission_fakes.dart';

void main() {
  configurePetPageTestHarness();

  testWidgets('Pet details renders empty photo grid state', (tester) async {
    final repository = FakePetRepository(
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

    await pumpPetDetails(tester, repository: repository);

    expect(repository.petPhotoFetchCount, 1);
    expect(find.text('No photos yet.'), findsOneWidget);
    expect(find.byTooltip('Use for generation'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Pet details shows photo skeleton while photos load', (
    tester,
  ) async {
    final petPhotosCompleter = Completer<void>();
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
          isFavorite: false,
          isAvatar: false,
          sortOrder: 1,
          createdAtUtc: DateTime.utc(2026),
        ),
      ],
      petPhotosCompleter: petPhotosCompleter,
    );

    await pumpPetDetails(tester, repository: repository);

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

    await pumpPetDetails(
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
          isFavorite: true,
          isAvatar: false,
          sortOrder: 1,
          createdAtUtc: DateTime.utc(2026),
        ),
      ],
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
    await tester.pump(const Duration(milliseconds: 100));

    expect(repository.favoriteUpdates, ['photo-1:false']);
    expect(repository.petPhotoFetchCount, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Pet photo action taps are ignored while a request is in flight',
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
      avatarError: DioException(
        requestOptions: RequestOptions(
          path: '/api/pets/pet-1/photos/photo-1/set-avatar',
        ),
        type: DioExceptionType.cancel,
      ),
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
      uploadError: DioException(
        requestOptions: RequestOptions(path: '/api/pets/pet-1/photos'),
        type: DioExceptionType.cancel,
      ),
    );

    await pumpPetDetails(tester, repository: repository);

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
    final picker = FakeImagePickerPlatform(
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
      uploadError: const AppException('pets.photo_type_not_allowed'),
    );

    await pumpPetDetails(tester, repository: repository);

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

  testWidgets('Add photo permission denial shows localized warning', (
    tester,
  ) async {
    final previousImagePickerPlatform =
        image_picker_platform.ImagePickerPlatform.instance;
    final picker = FakeImagePickerPlatform(
      pickedFile: XFile(
        '/tmp/petmagic-upload-success.jpg',
        name: 'petmagic-upload-success.jpg',
      ),
    );
    image_picker_platform.ImagePickerPlatform.instance = picker;
    addTearDown(() async {
      image_picker_platform.ImagePickerPlatform.instance =
          previousImagePickerPlatform;
      await PetMagicNotificationCenter.instance.clearQueue();
    });

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

    await pumpPetDetails(
      tester,
      repository: repository,
      permissionCoordinator: FakeAppPermissionCoordinator(
        states: const {AppPermissionType.photos: AppPermissionState.denied},
      ),
    );

    await tester.tap(find.byTooltip('Add photos'));
    await tester.pump();

    expect(picker.pickImageCalls, 0);
    expect(repository.uploadCalls, 0);
    expect(
      PetMagicNotificationCenter.instance.current?.message,
      'Allow access to your gallery to choose a photo.',
    );
    await PetMagicNotificationCenter.instance.clearQueue();
    await tester.pump();
  });

  testWidgets('Add photo upload invalidates pets and photos after success', (
    tester,
  ) async {
    final previousImagePickerPlatform =
        image_picker_platform.ImagePickerPlatform.instance;
    final picker = FakeImagePickerPlatform(
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
}
