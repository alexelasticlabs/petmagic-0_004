import 'package:dio/dio.dart';
import 'package:petmagic_mobile/core/operations/request_cancellation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/app/router/go_router_app_navigator.dart';
import 'package:petmagic_mobile/core/navigation/app_navigator.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/core/realtime/realtime_client.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/pets/presentation/my_pets_page.dart';
import 'package:petmagic_mobile/features/pets/application/pet_repository.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_pet_repository_adapter.dart';
import 'package:petmagic_mobile/features/templates/domain/templates_query.dart';
import 'package:petmagic_mobile/features/templates/data/templates_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/application/generation_history_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_status_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/generations_gallery_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_preview_page.dart';
import 'package:petmagic_mobile/features/templates/application/templates_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_flow_sheets.dart';
import 'package:petmagic_mobile/features/wallet/domain/wallet_models.dart';
import 'package:petmagic_mobile/features/wallet/application/wallet_controller.dart';
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
          builder: (context, state) => Scaffold(
            body: TemplatesPage(
              initialPetId:
                  state.uri.queryParameters[TemplatesPage.petIdQueryParam],
              initialPetPhotoId:
                  state.uri.queryParameters[TemplatesPage.petPhotoIdQueryParam],
            ),
          ),
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
          networkStatusControllerProvider.overrideWith(
            _OnlineNetworkStatusController.new,
          ),
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
          petRepositoryProvider.overrideWithValue(
            TemplateGenerationPetRepositoryAdapter(generationRepository),
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
          builder: (context, child) => AppNavigationScope(
            navigator: GoRouterAppNavigator(router),
            child: child!,
          ),
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
    final text = AppLocalizations.of(tester.element(find.text('Upload')));

    await tester.tap(find.text('Upload'));
    await _pumpUntil(
      tester,
      () => find.text(text.templateFlowCreateMagicAction).evaluate().isNotEmpty,
    );
    expect(
      find.text(text.templateFlowCreateMagicAction),
      findsOneWidget,
      reason:
          'Expected the pet generation launch sheet after selecting Upload.',
    );

    await tester.tap(find.text(text.templateFlowCreateMagicAction));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(generationRepository.lastPetId, 'pet-42');
    expect(generationRepository.lastPetPhotoId, 'photo-7');
    expect(find.text('status:generation-pet-1'), findsOneWidget);

    generationRepository.addGalleryMatrixItems();
    expect(
      generationRepository.createdCreations.map(
        (item) => item.galleryMedia.state,
      ),
      containsAll([
        GalleryMediaState.resultReady,
        GalleryMediaState.processing,
        GalleryMediaState.expired,
        GalleryMediaState.storageUnavailable,
        GalleryMediaState.failed,
      ]),
    );

    router.go(GenerationsGalleryPage.routePath);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(historyController.loadCalls, greaterThan(0));
    expect(find.byType(GenerationsGalleryPage), findsOneWidget);
    expect(find.text('Pet portrait'), findsOneWidget);

    await _tapGalleryFilter(
      tester,
      text.generationStatusFilterActive,
      GenerationHistoryFilter.active,
      historyController,
    );
    expect(historyController.state.items.map((item) => item.templateTitle), [
      'Active video',
    ]);
    expect(find.text('Active video'), findsOneWidget);

    await _tapGalleryFilter(
      tester,
      text.generationStatusFilterReady,
      GenerationHistoryFilter.ready,
      historyController,
    );
    expect(
      historyController.state.items.map((item) => item.templateTitle),
      containsAll(['Pet portrait', 'Ready video']),
    );
    expect(find.text('Pet portrait'), findsOneWidget);
    expect(find.text('Ready video'), findsOneWidget);

    await _tapGalleryFilter(
      tester,
      text.generationStatusFilterFailed,
      GenerationHistoryFilter.failed,
      historyController,
    );
    expect(historyController.state.items.map((item) => item.templateTitle), [
      'Failed portrait',
    ]);

    await _tapGalleryFilter(
      tester,
      text.allFilter,
      GenerationHistoryFilter.all,
      historyController,
    );
    expect(find.text('Pet portrait'), findsOneWidget);

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
      'https://cdn.petmagic.app/fresh-download-bella.jpg?sig=download',
    ]);
    expect(mediaActions.saveLocalPaths, [null]);
    expect(generationRepository.downloadCalls, ['generation-pet-1']);
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await _tapSheetAction(tester, text.supportChatShareAction);
    await _pumpUntil(tester, () => mediaActions.shareCalls.isNotEmpty);

    expect(mediaActions.shareCalls, [
      'https://cdn.petmagic.app/fresh-share-bella.jpg?sig=share',
    ]);
    expect(mediaActions.shareLocalPaths, [null]);
    expect(mediaActions.shareTexts, [
      'https://app.petgpt.app/share/generation/generation-pet-1',
    ]);
    expect(generationRepository.shareCalls, ['generation-pet-1']);
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await _tapSheetAction(tester, text.generationStatusCopyLinkAction);
    await _pumpUntil(tester, () => generationRepository.shareCalls.length == 2);
    final copied = await Clipboard.getData('text/plain');

    expect(
      copied?.text,
      'https://app.petgpt.app/share/generation/generation-pet-1',
    );
    expect(generationRepository.shareCalls, [
      'generation-pet-1',
      'generation-pet-1',
    ]);

    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await _tapSheetAction(tester, text.generationStatusDeleteAction);
    await _pumpUntil(
      tester,
      () =>
          historyController.deleteCalls.isNotEmpty &&
          generationRepository.createdCreations.every(
            (item) => item.generationId != 'generation-pet-1',
          ),
    );

    expect(historyController.deleteCalls, ['generation-pet-1']);
    expect(
      generationRepository.createdCreations.map((item) => item.generationId),
      isNot(contains('generation-pet-1')),
    );
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

Future<void> _tapGalleryFilter(
  WidgetTester tester,
  String label,
  GenerationHistoryFilter expectedFilter,
  _PetFlowHistoryController historyController,
) async {
  final filter = find.widgetWithText(ChoiceChip, label);
  expect(filter, findsOneWidget);
  await tester.ensureVisible(filter);
  await tester.tap(filter);
  await _pumpUntil(
    tester,
    () => historyController.state.filter == expectedFilter,
  );
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
  final shareTexts = <String?>[];

  @override
  Future<bool> saveToGallery({
    required String mediaUrl,
    required String fileName,
    required bool isVideo,
    required String albumName,
    required RequestCancellation cancelToken,
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
    required RequestCancellation cancelToken,
    String? shareText,
    String? localPath,
  }) async {
    shareCalls.add(mediaUrl);
    shareLocalPaths.add(localPath);
    shareTexts.add(shareText);
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

class _OnlineNetworkStatusController extends NetworkStatusController {
  @override
  NetworkStatusState build() => const NetworkStatusState(hasInternet: true);
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
  Future<TemplateItem> fetchTemplate(
    String templateId, {
    bool forceRefresh = false,
    String? analyticsSource,
    int? minimumVersion,
  }) async {
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
  final downloadCalls = <String>[];
  final shareCalls = <String>[];

  void addGalleryMatrixItems() {
    final now = DateTime.utc(2035, 1, 1, 12);
    createdCreations.addAll([
      _generation(
        id: 'generation-video-ready',
        title: 'Ready video',
        status: TemplateGenerationStatus.completed,
        templateType: 'video',
        outputUrl: 'https://cdn.petmagic.app/ready-video.mp4',
        completedAtUtc: now.add(const Duration(minutes: 2)),
        galleryMedia: const GalleryMedia(
          state: GalleryMediaState.resultReady,
          mediaType: 'video',
          previewUrl: 'https://cdn.petmagic.app/ready-video-thumb.jpg',
          resultUrl: 'https://cdn.petmagic.app/ready-video.mp4',
          canDownload: true,
          canShare: true,
        ),
      ),
      _generation(
        id: 'generation-active-video',
        title: 'Active video',
        status: TemplateGenerationStatus.providerProcessing,
        templateType: 'video',
        progressPercent: 52,
        stage: 'provider_processing',
        galleryMedia: const GalleryMedia(
          state: GalleryMediaState.processing,
          mediaType: 'video',
          retryAfterSeconds: 10,
        ),
      ),
      _generation(
        id: 'generation-expired',
        title: 'Expired portrait',
        status: TemplateGenerationStatus.completed,
        galleryMedia: const GalleryMedia(
          state: GalleryMediaState.expired,
          mediaType: 'image',
          reasonCode: 'media_expired',
          userMessageKey: 'generation.media_expired',
        ),
      ),
      _generation(
        id: 'generation-unavailable',
        title: 'Unavailable portrait',
        status: TemplateGenerationStatus.completed,
        galleryMedia: const GalleryMedia(
          state: GalleryMediaState.storageUnavailable,
          mediaType: 'image',
          reasonCode: 'storage_unavailable',
          userMessageKey: 'generation.storage_unavailable',
        ),
      ),
      _generation(
        id: 'generation-failed',
        title: 'Failed portrait',
        status: TemplateGenerationStatus.failed,
        failureCode: 'provider_failed',
        failureMessage: 'Provider failed',
        galleryMedia: const GalleryMedia(
          state: GalleryMediaState.failed,
          mediaType: 'image',
          reasonCode: 'provider_failed',
          userMessageKey: 'generation.media_failed',
        ),
      ),
    ]);
  }

  @override
  Future<({String correlationId, String generationId})?>
  readActiveGeneration() async {
    return null;
  }

  @override
  Future<List<PetProfile>> fetchPets({RequestCancellation? cancelToken}) async {
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
    RequestCancellation? cancelToken,
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
    RequestCancellation? cancelToken,
  }) async {
    return const [];
  }

  @override
  Future<TemplateGenerationResult> startGenerationFromPet({
    required String petId,
    String? petPhotoId,
    required String templateId,
    int? expectedTemplateVersion,
    String? correlationId,
    RequestCancellation? cancelToken,
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
          galleryMedia: const GalleryMedia(
            state: GalleryMediaState.resultReady,
            mediaType: 'image',
            previewUrl: 'https://cdn.petmagic.app/generated-bella-thumb.jpg',
            resultUrl: 'https://cdn.petmagic.app/generated-bella.jpg',
            canDownload: true,
            canShare: true,
          ),
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

  @override
  Future<GenerationMediaAccessResult> fetchDownloadUrl(
    String generationId, {
    RequestCancellation? cancelToken,
  }) async {
    downloadCalls.add(generationId);
    return const GenerationMediaAccessResult(
      mediaUrl:
          'https://cdn.petmagic.app/fresh-download-bella.jpg?sig=download',
      hasWatermark: false,
      fileName: 'fresh-download-bella.jpg',
    );
  }

  @override
  Future<GenerationMediaAccessResult> fetchShareUrl(
    String generationId, {
    RequestCancellation? cancelToken,
  }) async {
    shareCalls.add(generationId);
    return GenerationMediaAccessResult(
      mediaUrl: 'https://cdn.petmagic.app/fresh-share-bella.jpg?sig=share',
      hasWatermark: false,
      fileName: 'fresh-share-bella.jpg',
      shareUrl: 'https://app.petgpt.app/share/generation/$generationId',
    );
  }

  TemplateGenerationResult _generation({
    required String id,
    required String title,
    required TemplateGenerationStatus status,
    required GalleryMedia galleryMedia,
    String templateType = 'image',
    String? outputUrl,
    String? failureCode,
    String? failureMessage,
    String? stage,
    int? progressPercent,
    DateTime? completedAtUtc,
  }) {
    final now = DateTime.utc(2035, 1, 1, 12);
    return TemplateGenerationResult(
      generationId: id,
      userId: 'user-1',
      templateId: 'template-pet',
      status: status,
      tokenCost: 1,
      attemptCount: 1,
      createdAtUtc: now,
      updatedAtUtc: completedAtUtc ?? now,
      completedAtUtc: completedAtUtc,
      userMediaExpired: galleryMedia.state == GalleryMediaState.expired,
      templateTitle: title,
      templateType: templateType,
      outputUrl: outputUrl,
      failureCode: failureCode,
      failureMessage: failureMessage,
      stage: stage,
      progressPercent: progressPercent,
      galleryMedia: galleryMedia,
    );
  }
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
