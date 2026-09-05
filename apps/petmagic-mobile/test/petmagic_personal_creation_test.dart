import 'dart:io';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/navigation/app_navigator.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/pets/application/pets_contract.dart';
import 'package:petmagic_mobile/features/pets/domain/pet_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/create_with_pet_block.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/discovery_collection_style.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/pet_creation_identity.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/pet_generation_launch_sheet.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/pet_shortcut_avatar.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_generation_state.dart';

import 'template_card_test_support.dart';
import 'widget_test_support.dart';

const _avatar = 'https://cdn.petgpt.app/luna-fixture.png';

void main() {
  configureWidgetTestHarness();
  late Directory cache;
  setUpAll(() async {
    cache = await Directory.systemTemp.createTemp(
      'petmagic-personal-creation-',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => cache.path,
        );
    final photo = await rootBundle.load(
      'assets/rewards/profile-premium-dog.png',
    );
    await DefaultCacheManager().putFile(
      _avatar,
      photo.buffer.asUint8List(),
      key: _avatar,
      fileExtension: 'png',
    );
    // Warm the derived avatar before entering the widget test's fake clock.
    final codec = await ui.instantiateImageCodec(
      photo.buffer.asUint8List(),
      targetWidth: 64,
    );
    final frame = await codec.getNextFrame();
    final bytes = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    await DefaultCacheManager().putFile(
      _avatar,
      bytes!.buffer.asUint8List(),
      key: 'resized_w64_$_avatar',
      fileExtension: 'png',
    );
    frame.image.dispose();
    codec.dispose();
  });
  tearDownAll(() async {
    await DefaultCacheManager().dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    expect(cache.parent.absolute.path, Directory.systemTemp.absolute.path);
    await cache.delete(recursive: true);
  });

  for (final brightness in Brightness.values) {
    testWidgets('pet identity ${brightness.name} visual baseline', (
      tester,
    ) async {
      _size(tester, const Size(390, 360));
      await tester.pumpWidget(
        _host(
          brightness: brightness,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: CreateWithPetBlockSlot(
              selectedPetId: 'luna',
              selectedPetPhotoId: 'photo-1',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CachedNetworkImage), findsOneWidget);
      for (var attempt = 0; attempt < 20; attempt++) {
        await tester.pump();
        if (tester
            .widgetList<RawImage>(find.byType(RawImage))
            .any((image) => image.image != null)) {
          break;
        }
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
      }
      await tester.pumpAndSettle();
      expect(find.text('Луна'), findsOneWidget);
      expect(
        tester
            .widgetList<RawImage>(
              find.descendant(
                of: find.byType(PetShortcutAvatar),
                matching: find.byType(RawImage),
              ),
            )
            .any((image) => image.image != null),
        isTrue,
      );
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/pet_identity_${brightness.name}.png'),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('guest does not load pets and logout removes personal identity', (
    tester,
  ) async {
    var loads = 0;
    final navigator = _Navigator();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLaunchControllerProvider.overrideWith(_Guest.new),
          petsProvider.overrideWith((ref) async {
            loads++;
            return [_pet()];
          }),
        ],
        child: AppNavigationScope(
          navigator: navigator,
          child: _app(
            child: const CreateWithPetBlockSlot(
              selectedPetId: null,
              selectedPetPhotoId: null,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(loads, 0);
    expect(find.byType(PetCreationIdentity), findsNothing);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    final launch =
        container.read(appLaunchControllerProvider.notifier) as _Guest;
    launch.setAuthenticated(true);
    await tester.pumpAndSettle();
    expect(loads, 1);
    expect(find.byType(PetCreationIdentity), findsOneWidget);
    launch.setAuthenticated(false);
    await tester.pumpAndSettle();
    expect(find.byType(PetCreationIdentity), findsNothing);
    expect(find.text('Луна'), findsNothing);
  });

  testWidgets(
    'changing pets clears the previous photo and preserves exact IDs',
    (tester) async {
      final navigator = _Navigator();
      await tester.pumpWidget(
        _host(
          navigator: navigator,
          child: const CreateWithPetBlockSlot(
            selectedPetId: 'luna',
            selectedPetPhotoId: 'photo/1?#',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PetCreationIdentity));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('pet-picker-option:pet/2?#')));
      await tester.pumpAndSettle();
      final destination = navigator.destination! as TemplatesDestination;
      expect(
        Uri.parse(destination.location).queryParameters['petId'],
        'pet/2?#',
      );
      expect(
        Uri.parse(
          destination.location,
        ).queryParameters.containsKey('petPhotoId'),
        isFalse,
      );
    },
  );

  testWidgets(
    'launch resolves the exact pet identity when only petId is supplied',
    (tester) async {
      await tester.pumpWidget(
        _host(
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => showPetGenerationLaunchSheet(
                context: context,
                template: imageTemplate(id: 'portrait'),
                petId: 'luna',
                gate: const TemplateGenerationGate(
                  kind: TemplateGenerationGateKind.allowed,
                  balance: 10,
                  isPremium: false,
                ),
                pickPhoto: () async => null,
                uploadPhoto: (_) async =>
                    throw StateError('No upload expected'),
                startGeneration: (_) async =>
                    throw StateError('No generation expected'),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final avatars = tester.widgetList<PetShortcutAvatar>(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(PetShortcutAvatar),
        ),
      );
      expect(avatars.any((avatar) => avatar.avatarUrl == _avatar), isTrue);
      expect(find.textContaining('Луна'), findsWidgets);
      expect(find.textContaining('Рекс'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final language in ['ru', 'en', 'de', 'es', 'fr', 'it', 'pl']) {
    testWidgets(
      '$language pet identity at 200 percent text remains actionable',
      (tester) async {
        _size(tester, const Size(320, 568));
        await tester.pumpWidget(
          _host(
            locale: Locale(language),
            scale: 2,
            child: const SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CreateWithPetBlockSlot(
                  selectedPetId: 'luna',
                  selectedPetPhotoId: null,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byType(PetCreationIdentity));
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  test(
    'collection identity ignores position, case and surrounding whitespace',
    () {
      expect(
        discoveryCollectionIndex('  Portraits  '),
        discoveryCollectionIndex('portraits'),
      );
      final categories = ['Портреты', 'Кино', 'Приключения', 'Праздники'];
      final identities = {
        for (final category in categories)
          category: discoveryCollectionIndex(category),
      };
      for (final category in categories.reversed) {
        expect(discoveryCollectionIndex(category), identities[category]);
      }
    },
  );
}

PetProfile _pet({String id = 'luna', String name = 'Луна'}) => PetProfile(
  id: id,
  name: name,
  type: 'dog',
  avatarUrl: _avatar,
  photosCount: 1,
  generationsCount: 3,
  createdAtUtc: DateTime.utc(2026),
  updatedAtUtc: DateTime.utc(2026),
);

Widget _host({
  required Widget child,
  _Navigator? navigator,
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('ru'),
  double scale = 1,
}) => ProviderScope(
  overrides: [
    appLaunchControllerProvider.overrideWith(_Member.new),
    petsProvider.overrideWith(
      (ref) async => [_pet(), _pet(id: 'pet/2?#', name: 'Рекс')],
    ),
    petPhotosProvider.overrideWith((ref, id) async => <PetPhoto>[]),
  ],
  child: AppNavigationScope(
    navigator: navigator ?? _Navigator(),
    child: _app(
      child: child,
      brightness: brightness,
      locale: locale,
      scale: scale,
    ),
  ),
);

Widget _app({
  required Widget child,
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('ru'),
  double scale = 1,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: brightness == Brightness.light ? AppTheme.light() : AppTheme.dark(),
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(body: SafeArea(child: child)),
);

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

class _Guest extends AppLaunchController {
  @override
  AppLaunchState build() => const AppLaunchState(
    isLoading: false,
    isAuthenticated: false,
    requiresLegalAcceptance: false,
    hasSeenOnboarding: true,
    guestSessionReady: true,
  );
  void setAuthenticated(bool value) =>
      state = state.copyWith(isAuthenticated: value);
}

class _Member extends _Guest {
  @override
  AppLaunchState build() => super.build().copyWith(isAuthenticated: true);
}

class _Navigator implements AppNavigator {
  AppDestination? destination;
  @override
  void go(AppDestination value) => destination = value;
  @override
  Future<T?> push<T>(AppDestination value) async {
    destination = value;
    return null;
  }

  @override
  void replace(AppDestination value) => go(value);
  @override
  bool canPop() => false;
  @override
  void pop<T extends Object?>([T? result]) {}
}
