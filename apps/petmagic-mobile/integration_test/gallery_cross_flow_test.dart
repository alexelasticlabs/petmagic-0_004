import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/realtime/realtime_client.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/pets/presentation/my_pets_page.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/templates/data/templates_query.dart';
import 'package:petmagic_mobile/features/templates/data/templates_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_history_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_status_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/generations_gallery_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_preview_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_flow_sheets.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_models.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('pet photo flow creates a result visible in Creations', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final generationRepository = _CrossGalleryPetFlowRepository();
    final historyController = _PetFlowHistoryController(generationRepository);
    final mediaActions = _RecordingGenerationStatusMediaActions();
    final template = _template('template-pet', 'Pet portrait');
    final router = GoRouter(
      initialLocation: MyPetsPage.routePath,
      routes: [
        GoRoute(
          path: MyPetsPage.routePath,
          builder: (context, state) => const Scaffold(body: MyPetsPage()),
        ),
        GoRoute(
          path: PetDetailsPage.routePath,
          builder: (context, state) =>
              PetDetailsPage(petId: state.pathParameters['petId'] ?? ''),
        ),
        GoRoute(
          path: TemplatesPage.routePath,
          builder: (context, state) => const Scaffold(body: TemplatesPage()),
        ),
        GoRoute(
          path: TemplatePreviewPage.routePath,
          builder: (context, state) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => context.pop<TemplateDetailAction>(
                  TemplateDetailAction.upload,
                ),
                child: const Text('Upload'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '${GenerationStatusPage.routePrefix}/:generationId',
          builder: (context, state) {
            return Scaffold(
              body: Center(
                child: Text(
                  'status:${state.pathParameters['generationId'] ?? ''}',
                ),
              ),
            );
          },
        ),
        GoRoute(
          path: GenerationsGalleryPage.routePath,
          builder: (context, state) => const GenerationsGalleryPage(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLaunchControllerProvider.overrideWith(_AuthenticatedLaunch.new),
          walletControllerProvider.overrideWith(_FundedWalletController.new),
          templatesControllerProvider.overrideWith(
            () => _SingleTemplateController(template),
          ),
          templatesRepositoryProvider.overrideWithValue(
            _SingleTemplateRepository(template),
          ),
          templateGenerationRepositoryProvider.overrideWithValue(
            generationRepository,
          ),
          generationHistoryControllerProvider.overrideWith(
            () => historyController,
          ),
          generationStatusMediaActionsProvider.overrideWithValue(mediaActions),
          realtimeClientProvider.overrideWith(
            (ref) => const NoopRealtimeClient(),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
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
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Bella').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.scrollUntilVisible(
      find.byTooltip('Use for generation'),
      120,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.byTooltip('Use for generation'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.ensureVisible(find.text('Pet portrait').first);
    await tester.tap(find.text('Pet portrait').first);
    await _pumpUntil(tester, () => find.text('Upload').evaluate().isNotEmpty);
    expect(find.text('Upload'), findsOneWidget);

    await tester.tap(find.text('Upload'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Start'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(generationRepository.lastPetId, 'pet-42');
    expect(generationRepository.lastPetPhotoId, 'photo-7');
    expect(find.text('status:generation-pet-1'), findsOneWidget);

    router.go(GenerationsGalleryPage.routePath);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(historyController.loadCalls, greaterThan(0));
    expect(find.byType(GenerationsGalleryPage), findsOneWidget);
    expect(find.text('Pet portrait'), findsOneWidget);

    final text = AppLocalizations.of(
      tester.element(find.byType(GenerationsGalleryPage)),
    );
    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await _tapSheetAction(tester, text.generationStatusOpenStatusAction);
    await tester.pump(const Duration(milliseconds: 300));

    expect(historyController.markReadCalls, ['generation-pet-1']);
    expect(find.text('status:generation-pet-1'), findsOneWidget);

    expect(router.canPop(), isTrue);
    router.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(GenerationsGalleryPage), findsOneWidget);
    expect(find.text('Pet portrait'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await _tapSheetAction(tester, text.generationStatusSaveAction);
    await _pumpUntil(tester, () => mediaActions.saveCalls.isNotEmpty);

    expect(mediaActions.saveCalls, [
      'https://cdn.petmagic.app/generated-bella.jpg',
    ]);
    expect(mediaActions.saveLocalPaths, [null]);

    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await _tapSheetAction(tester, text.supportChatShareAction);
    await _pumpUntil(tester, () => mediaActions.shareCalls.isNotEmpty);

    expect(mediaActions.shareCalls, [
      'https://cdn.petmagic.app/generated-bella.jpg',
    ]);
    expect(mediaActions.shareLocalPaths, [null]);

    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await _tapSheetAction(tester, text.generationStatusDeleteAction);
    await _pumpUntil(
      tester,
      () =>
          historyController.deleteCalls.isNotEmpty &&
          generationRepository.createdCreations.isEmpty,
    );

    expect(historyController.deleteCalls, ['generation-pet-1']);
    expect(generationRepository.createdCreations, isEmpty);
    expect(find.text('Pet portrait'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _tapSheetAction(WidgetTester tester, String label) async {
  final action = find.widgetWithText(ListTile, label);
  expect(action, findsOneWidget);
  await tester.ensureVisible(action);
  await tester.tap(action);
  await tester.pump();
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = tester.binding.clock.now().add(timeout);
  while (!condition() && tester.binding.clock.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

class _RecordingGenerationStatusMediaActions
    extends GenerationStatusMediaActions {
  final saveCalls = <String>[];
  final shareCalls = <String>[];
  final saveLocalPaths = <String?>[];
  final shareLocalPaths = <String?>[];

  @override
  Future<bool> saveToGallery({
    required String mediaUrl,
    required String fileName,
    required bool isVideo,
    required String albumName,
    required CancelToken cancelToken,
    String? localPath,
  }) async {
    saveCalls.add(mediaUrl);
    saveLocalPaths.add(localPath);
    return true;
  }

  @override
  Future<void> share({
    required String mediaUrl,
    required String fileName,
    required String title,
    required CancelToken cancelToken,
    String? localPath,
  }) async {
    shareCalls.add(mediaUrl);
    shareLocalPaths.add(localPath);
  }
}

class _AuthenticatedLaunch extends AppLaunchController {
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

class _FundedWalletController extends WalletController {
  @override
  WalletState build() {
    return WalletState(
      wallet: WalletStateModel(
        userId: 'user-1',
        balance: 50,
        adRewardsRemainingToday: 0,
        isPremium: false,
        updatedAtUtc: DateTime.utc(2035),
      ),
    );
  }

  @override
  Future<void> load({bool refresh = false}) async {}
}

class _SingleTemplateController extends TemplatesController {
  _SingleTemplateController(this.template);

  final TemplateItem template;

  @override
  TemplatesState build() {
    return const TemplatesState();
  }

  @override
  Future<void> loadInitial({
    bool forceRefresh = false,
    int? knownCatalogVersion,
  }) async {
    state = TemplatesState(
      items: [template],
      isLoading: false,
      isRefreshing: false,
      hasMore: false,
    );
  }

  @override
  void setScreenVisible(bool visible) {}
}

class _SingleTemplateRepository implements TemplatesRepository {
  const _SingleTemplateRepository(this.template);

  final TemplateItem template;

  @override
  void cancelPendingFeedRequest() {}

  @override
  void cancelPendingRandomTemplateRequest() {}

  @override
  void cancelPendingMetadataRequests() {}

  @override
  Future<List<String>> fetchCategories() async {
    return const [];
  }

  @override
  Future<TemplatesCatalogChanges> fetchCatalogChanges(int sinceVersion) async {
    return TemplatesCatalogChanges(
      fromVersion: sinceVersion,
      toVersion: sinceVersion,
      upserts: const [],
      deletedIds: const [],
      needsFullResync: false,
    );
  }

  @override
  Future<int> fetchCatalogVersion() async {
    return 1;
  }

  @override
  Future<TemplatesFeedPage> fetchFeed(TemplatesQuery query) async {
    return TemplatesFeedPage(items: [template], hasMore: false);
  }

  @override
  Future<TemplateItem?> fetchRandomTemplate({
    required TemplateRandomMode mode,
    required String? category,
    required bool includePremium,
    TemplateRandomAccess access = TemplateRandomAccess.available,
  }) async {
    return null;
  }

  @override
  Future<TemplateItem> fetchTemplate(String templateId) async {
    return template;
  }

  @override
  Future<TemplateOfTheDayItem?> fetchTemplateOfTheDay() async {
    return null;
  }

  @override
  Future<TemplatesFeedPage?> readCachedFirstPage(TemplatesQuery query) async {
    return TemplatesFeedPage(items: [template], hasMore: false);
  }

  @override
  Future<int> readLocalCatalogVersion() async {
    return 1;
  }

  @override
  Future<List<TemplateItem>> readSyncedCatalogItems() async {
    return [template];
  }

  @override
  Future<void> recordAnalyticsEvent({
    required String templateId,
    required String eventType,
    String? source,
    String? generationId,
    Map<String, Object?>? metadata,
  }) async {}

  @override
  Future<int> syncCatalog({int? knownRemoteVersion}) async {
    return knownRemoteVersion ?? 1;
  }
}

class _CrossGalleryPetFlowRepository extends TemplateGenerationRepository {
  _CrossGalleryPetFlowRepository()
    : super(
        dio: Dio(),
        sessionStorage: AuthSessionStorage(),
        preferences: SharedPreferencesAsync(),
      );

  String? lastPetId;
  String? lastPetPhotoId;
  final createdCreations = <TemplateGenerationResult>[];

  @override
  Future<({String correlationId, String generationId})?>
  readActiveGeneration() async {
    return null;
  }

  @override
  Future<List<PetProfile>> fetchPets({CancelToken? cancelToken}) async {
    return [
      PetProfile(
        id: 'pet-42',
        name: 'Bella',
        type: 'dog',
        breed: 'Corgi',
        avatarUrl: 'https://cdn.petmagic.app/bella-avatar.jpg',
        photosCount: 1,
        generationsCount: createdCreations.length,
        createdAtUtc: DateTime.utc(2035),
        updatedAtUtc: DateTime.utc(2035),
      ),
    ];
  }

  @override
  Future<List<PetPhoto>> fetchPetPhotos(
    String petId, {
    CancelToken? cancelToken,
  }) async {
    return [
      PetPhoto(
        id: 'photo-7',
        petId: petId,
        mediaAssetId: 'pet-photo-asset-7',
        url: 'https://cdn.petmagic.app/bella-original.jpg',
        thumbnailUrl: 'https://cdn.petmagic.app/bella-thumb.jpg',
        fileName: 'bella.jpg',
        contentType: 'image/jpeg',
        isFavorite: true,
        isAvatar: true,
        sortOrder: 1,
        createdAtUtc: DateTime.utc(2035),
      ),
    ];
  }

  @override
  Future<List<TemplateGenerationResult>> fetchPetGenerations(
    String petId, {
    CancelToken? cancelToken,
  }) async {
    return const [];
  }

  @override
  Future<TemplateGenerationResult> startGenerationFromPet({
    required String petId,
    String? petPhotoId,
    required String templateId,
    String? correlationId,
    CancelToken? cancelToken,
  }) async {
    lastPetId = petId;
    lastPetPhotoId = petPhotoId;
    final now = DateTime.utc(2035, 1, 1, 12);
    final generation = TemplateGenerationResult(
      generationId: 'generation-pet-1',
      userId: 'user-1',
      templateId: templateId,
      status: TemplateGenerationStatus.queued,
      tokenCost: 1,
      attemptCount: 1,
      createdAtUtc: now,
      updatedAtUtc: now,
      userMediaExpired: false,
      templateTitle: 'Pet portrait',
      templateType: 'image',
      petId: petId,
      petPhotoId: petPhotoId,
    );
    createdCreations
      ..clear()
      ..add(
        generation.copyWith(
          status: TemplateGenerationStatus.completed,
          outputUrl: 'https://cdn.petmagic.app/generated-bella.jpg',
          resultPreviewUrl:
              'https://cdn.petmagic.app/generated-bella-thumb.jpg',
          completedAtUtc: now.add(const Duration(minutes: 1)),
          updatedAtUtc: now.add(const Duration(minutes: 1)),
          isUnread: true,
        ),
      );
    return generation;
  }

  @override
  Future<void> rememberActiveGeneration({
    required String generationId,
    String? correlationId,
  }) async {}
}

class _PetFlowHistoryController extends GenerationHistoryController {
  _PetFlowHistoryController(this.repository);

  final _CrossGalleryPetFlowRepository repository;
  int loadCalls = 0;
  final markReadCalls = <String>[];
  final deleteCalls = <String>[];

  @override
  GenerationHistoryState build() {
    return const GenerationHistoryState();
  }

  @override
  void setScreenVisible(bool visible, {bool clearLoadingState = true}) {}

  @override
  Future<void> load({
    GenerationHistoryFilter? filter,
    bool refresh = false,
  }) async {
    loadCalls++;
    final nextFilter = filter ?? state.filter;
    final items = _filter(repository.createdCreations, nextFilter);
    state = GenerationHistoryState(
      items: items,
      filter: nextFilter,
      unreadCount: items.where((item) => item.isUnread).length,
      lastSyncedAtUtc: DateTime.utc(2035, 1, 1, 12, 1),
    );
  }

  @override
  Future<void> markRead(String generationId) async {
    markReadCalls.add(generationId);
    _replaceGeneration(generationId, (item) => item.copyWith(isUnread: false));
  }

  @override
  Future<void> deleteGeneration(String generationId) async {
    deleteCalls.add(generationId);
    repository.createdCreations.removeWhere(
      (item) => item.generationId == generationId,
    );
    state = state.copyWith(
      items: _filter(repository.createdCreations, state.filter),
      unreadCount: repository.createdCreations
          .where((item) => item.isUnread)
          .length,
    );
  }

  void _replaceGeneration(
    String generationId,
    TemplateGenerationResult Function(TemplateGenerationResult item) replace,
  ) {
    for (var i = 0; i < repository.createdCreations.length; i++) {
      final item = repository.createdCreations[i];
      if (item.generationId == generationId) {
        repository.createdCreations[i] = replace(item);
        break;
      }
    }
    state = state.copyWith(
      items: _filter(repository.createdCreations, state.filter),
      unreadCount: repository.createdCreations
          .where((item) => item.isUnread)
          .length,
    );
  }

  List<TemplateGenerationResult> _filter(
    List<TemplateGenerationResult> items,
    GenerationHistoryFilter filter,
  ) {
    return switch (filter) {
      GenerationHistoryFilter.all => List<TemplateGenerationResult>.from(items),
      GenerationHistoryFilter.active =>
        items.where((item) => !item.isTerminal).toList(growable: false),
      GenerationHistoryFilter.ready =>
        items.where((item) => item.isCompleted).toList(growable: false),
      GenerationHistoryFilter.failed =>
        items.where((item) => item.isFailed).toList(growable: false),
    };
  }
}

TemplateItem _template(String id, String title) {
  return TemplateItem(
    templateId: id,
    templateType: TemplateType.image,
    title: title,
    shortDescription: title,
    petPhotoRequirements: const ['Clear photo'],
    category: 'Portrait',
    tags: const ['pet'],
    isPremium: false,
    tokenCost: 1,
  );
}
