import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/pets/presentation/my_pets_page.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
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
}

Future<void> _pumpMyPets(
  WidgetTester tester, {
  required TemplateGenerationRepository repository,
  required Brightness brightness,
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
        builder: (context, state) => const Scaffold(body: TemplatesPage()),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
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

class _FakePetRepository extends TemplateGenerationRepository {
  _FakePetRepository({required this.pets})
    : super(
        dio: Dio(),
        sessionStorage: AuthSessionStorage(),
        preferences: SharedPreferencesAsync(),
      );

  final List<PetProfile> pets;

  @override
  Future<List<PetProfile>> fetchPets({CancelToken? cancelToken}) async => pets;

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
    return const [];
  }

  @override
  Future<List<TemplateGenerationResult>> fetchPetGenerations(
    String petId, {
    CancelToken? cancelToken,
  }) async {
    return const [];
  }
}
