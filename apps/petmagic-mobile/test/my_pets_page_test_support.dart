import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
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
import 'package:petmagic_mobile/app/router/go_router_app_navigator.dart';
import 'package:petmagic_mobile/core/navigation/app_navigator.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/core/permissions/app_permission_coordinator.dart';
import 'package:petmagic_mobile/core/permissions/media_permission_feedback.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/pets/presentation/my_pets_page.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/profile/presentation/auth_entry_page.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'test_permission_fakes.dart';

void configurePetPageTestHarness() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });
}

String readPetsPresentationSource() {
  const files = [
    'lib/features/pets/presentation/my_pets_page.dart',
    'lib/features/pets/presentation/my_pets_detail_page.part.dart',
    'lib/features/pets/presentation/my_pets_display_widgets.part.dart',
    'lib/features/pets/presentation/my_pets_form_sheet.part.dart',
    'lib/features/pets/presentation/my_pets_photo_actions.part.dart',
  ];

  return files.map((path) => File(path).readAsStringSync()).join('\n');
}

Future<void> pumpMyPets(
  WidgetTester tester, {
  required TemplateGenerationRepository repository,
  required Brightness brightness,
  bool authenticated = true,
  Widget Function(BuildContext, GoRouterState)? templatesBuilder,
  AppPermissionCoordinator? permissionCoordinator,
  NetworkStatusController? networkStatusController,
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
        path: PetDetailsPage.routePath,
        builder: (context, state) =>
            PetDetailsPage(petId: state.pathParameters['petId'] ?? ''),
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
              ? AuthenticatedAppLaunchController.new
              : UnauthenticatedAppLaunchController.new,
        ),
        templateGenerationRepositoryProvider.overrideWithValue(repository),
        appPermissionCoordinatorProvider.overrideWithValue(
          permissionCoordinator ?? FakeAppPermissionCoordinator(),
        ),
        networkStatusControllerProvider.overrideWith(
          () =>
              networkStatusController ??
              TestMyPetsNetworkStatusController(initialHasInternet: true),
        ),
      ],
      child: AppNavigationScope(
        navigator: GoRouterAppNavigator(router),
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
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

Future<void> pumpPetDetails(
  WidgetTester tester, {
  required TemplateGenerationRepository repository,
  bool authenticated = true,
  Duration settleDuration = const Duration(milliseconds: 250),
  AppPermissionCoordinator? permissionCoordinator,
}) async {
  final router = petDetailsRouter(
    templatesBuilder: (context, state) =>
        Scaffold(body: Center(child: Text('templates:${state.uri.query}'))),
  );
  addTearDown(router.dispose);

  await pumpPetDetailsWithRouter(
    tester,
    repository: repository,
    router: router,
    authenticated: authenticated,
    settleDuration: settleDuration,
    permissionCoordinator: permissionCoordinator,
  );
}

Future<void> pumpPetDetailsWithRouter(
  WidgetTester tester, {
  required TemplateGenerationRepository repository,
  required GoRouter router,
  bool authenticated = true,
  Duration settleDuration = const Duration(milliseconds: 250),
  AppPermissionCoordinator? permissionCoordinator,
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
              ? AuthenticatedAppLaunchController.new
              : UnauthenticatedAppLaunchController.new,
        ),
        templateGenerationRepositoryProvider.overrideWithValue(repository),
        appPermissionCoordinatorProvider.overrideWithValue(
          permissionCoordinator ?? FakeAppPermissionCoordinator(),
        ),
      ],
      child: AppNavigationScope(
        navigator: GoRouterAppNavigator(router),
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
    ),
  );
  await tester.pump();
  if (settleDuration > Duration.zero) {
    await tester.pump(settleDuration);
  }
}

GoRouter petDetailsRouter({
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

class PetUiVariant {
  const PetUiVariant({
    required this.name,
    required this.platform,
    required this.brightness,
  });

  final String name;
  final TargetPlatform platform;
  final Brightness brightness;
}

class AuthenticatedAppLaunchController extends AppLaunchController {
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

class UnauthenticatedAppLaunchController extends AppLaunchController {
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

class TestMyPetsNetworkStatusController extends NetworkStatusController {
  TestMyPetsNetworkStatusController({required this.initialHasInternet});

  final bool initialHasInternet;

  @override
  NetworkStatusState build() {
    return NetworkStatusState(hasInternet: initialHasInternet);
  }

  void setHasInternet(bool value) {
    state = state.copyWith(hasInternet: value);
  }
}

class FakeImagePickerPlatform
    extends image_picker_platform.ImagePickerPlatform {
  FakeImagePickerPlatform({this.pickedFile});

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

class FakePetRepository extends TemplateGenerationRepository {
  FakePetRepository({
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
  final List<String> createdPetNames = [];
  final List<String> createdPetTypes = [];
  final List<String?> createdPetBreeds = [];
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
    createdPetNames.add(name);
    createdPetTypes.add(type);
    createdPetBreeds.add(breed);
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
