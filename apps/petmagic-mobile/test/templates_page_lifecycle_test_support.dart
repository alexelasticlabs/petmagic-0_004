import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/templates/data/templates_query.dart';
import 'package:petmagic_mobile/features/templates/data/templates_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_history_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_page.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_models.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

Finder randomTemplateActionFinder() {
  return find.byKey(const ValueKey('templates-random-floating-button'));
}

Future<void> tapRandomTemplateAction(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pump();
  await tester.tap(randomTemplateActionFinder());
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> tapFindRandomTemplateAction(
  WidgetTester tester,
  AppLocalizations text,
) async {
  final button = find.widgetWithText(
    FilledButton,
    text.randomTemplateFindAction,
  );
  await tester.tap(button);
  await tester.pump();
}

Future<void> tapSheetText(WidgetTester tester, String label) async {
  final finder = find.text(label);
  await tester.scrollUntilVisible(
    finder,
    120,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

Widget buildTemplatesPageApp({
  required Widget child,
  Locale locale = const Locale('en'),
}) {
  return MaterialApp(
    theme: AppTheme.light(),
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

class TemplatesTickerModeHost extends StatefulWidget {
  const TemplatesTickerModeHost({this.child, super.key});

  final Widget? child;

  @override
  State<TemplatesTickerModeHost> createState() =>
      TemplatesTickerModeHostState();
}

class TemplatesTickerModeHostState extends State<TemplatesTickerModeHost> {
  bool _enabled = true;

  void setEnabled(bool enabled) {
    setState(() {
      _enabled = enabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    return TickerMode(
      enabled: _enabled,
      child:
          widget.child ??
          MaterialApp(
            theme: AppTheme.light(),
            locale: const Locale('ru'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: TemplatesPage()),
          ),
    );
  }
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

class IdleWalletController extends WalletController {
  @override
  WalletState build() {
    return const WalletState();
  }

  @override
  Future<void> load({bool refresh = false}) async {}
}

class TrackingWalletController extends WalletController {
  TrackingWalletController({
    this.hasWallet = false,
    this.hasCompletedFullLoad = false,
  });

  final bool hasWallet;
  final bool hasCompletedFullLoad;
  int loadCalls = 0;

  @override
  WalletState build() {
    return WalletState(
      wallet: hasWallet
          ? WalletStateModel(
              userId: 'user-1',
              balance: 50,
              adRewardsRemainingToday: 0,
              isPremium: false,
              updatedAtUtc: DateTime.utc(2035),
            )
          : null,
      hasCompletedFullLoad: hasCompletedFullLoad,
    );
  }

  @override
  Future<void> load({bool refresh = false}) async {
    loadCalls++;
    state = state.copyWith(isLoading: true);
  }
}

class FundedWalletController extends WalletController {
  int loadCalls = 0;

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
  Future<void> load({bool refresh = false}) async {
    loadCalls++;
  }
}

class LoadingTemplatesController extends TemplatesController {
  @override
  TemplatesState build() {
    return const TemplatesState(isLoading: true);
  }

  @override
  Future<void> loadInitial({
    bool forceRefresh = false,
    int? knownCatalogVersion,
  }) async {}

  @override
  void setScreenVisible(bool visible, {bool clearLoadingState = true}) {}
}

class FakeTemplatesController extends TemplatesController {
  FakeTemplatesController({
    this.items,
    this.templateOfTheDay,
    this.templateOfTheDayError,
    this.isTemplateOfTheDayLoading = false,
    this.query = const TemplatesQuery(),
    this.categories = const [],
    this.hasMore = false,
    this.nextCursor,
  });

  final List<TemplateItem>? items;
  final TemplateOfTheDayItem? templateOfTheDay;
  final String? templateOfTheDayError;
  final bool isTemplateOfTheDayLoading;
  final TemplatesQuery query;
  final List<String> categories;
  final bool hasMore;
  final String? nextCursor;
  final List<bool> loadInitialCalls = <bool>[];
  final List<bool> setScreenVisibleCalls = <bool>[];
  final List<String> setSearchValues = <String>[];
  int loadMoreCalls = 0;

  @override
  TemplatesState build() {
    return const TemplatesState();
  }

  @override
  Future<void> loadInitial({
    bool forceRefresh = false,
    int? knownCatalogVersion,
  }) async {
    loadInitialCalls.add(forceRefresh);
    state = TemplatesState(
      query: query,
      items: items ?? [templateFixture('template-1', 'Template 1')],
      itemsQueryKey: query.cacheKey,
      categories: categories,
      templateOfTheDay: templateOfTheDay,
      isTemplateOfTheDayLoading: isTemplateOfTheDayLoading,
      templateOfTheDayError: templateOfTheDayError,
      isLoading: false,
      isRefreshing: false,
      hasMore: hasMore,
      nextCursor: nextCursor,
    );
  }

  @override
  Future<void> loadMore() async {
    loadMoreCalls++;
  }

  @override
  void setSearch(String value) {
    setSearchValues.add(value);
  }

  @override
  void setScreenVisible(bool visible) {
    setScreenVisibleCalls.add(visible);
  }
}

TemplateItem templateFixture(
  String id,
  String title, {
  TemplateType type = TemplateType.image,
  String? thumbnailUrl,
}) {
  return TemplateItem(
    templateId: id,
    templateType: type,
    title: title,
    shortDescription: title,
    petPhotoRequirements: const ['Clear photo'],
    category: 'Portrait',
    tags: const ['pet'],
    isPremium: false,
    tokenCost: 1,
    thumbnailUrl: thumbnailUrl,
  );
}

class RandomTemplatesRepository implements TemplatesRepository {
  RandomTemplatesRepository({
    this.items = const [],
    this.templateDetailsById = const {},
    this.throwOnRandom = false,
    this.randomTemplateCompleter,
  });

  final List<TemplateItem> items;
  final Map<String, TemplateItem> templateDetailsById;
  final bool throwOnRandom;
  final Completer<TemplateItem?>? randomTemplateCompleter;
  int readSyncedCatalogItemsCalls = 0;
  int fetchRandomTemplateCalls = 0;
  int cancelPendingRandomTemplateRequestCalls = 0;
  int fetchTemplateCalls = 0;
  TemplateRandomMode? lastRandomMode;
  String? lastRandomCategory;
  bool? lastIncludePremium;
  TemplateRandomAccess? lastRandomAccess;

  @override
  Future<List<String>> fetchCategories() async => const ['Portrait'];

  @override
  Future<TemplatesCatalogChanges> fetchCatalogChanges(int sinceVersion) async {
    return TemplatesCatalogChanges(
      fromVersion: sinceVersion,
      toVersion: 1,
      upserts: const [],
      deletedIds: const [],
      needsFullResync: false,
    );
  }

  @override
  Future<int> fetchCatalogVersion() async => 1;

  @override
  Future<TemplatesFeedPage> fetchFeed(TemplatesQuery query) async {
    return TemplatesFeedPage(items: items, hasMore: false);
  }

  @override
  void cancelPendingFeedRequest() {}

  @override
  void cancelPendingRandomTemplateRequest() {
    cancelPendingRandomTemplateRequestCalls++;
  }

  @override
  void cancelPendingMetadataRequests() {}

  @override
  Future<TemplateItem> fetchTemplate(String templateId) async {
    fetchTemplateCalls++;
    final detail = templateDetailsById[templateId];
    if (detail != null) {
      return detail;
    }

    return items.firstWhere((item) => item.templateId == templateId);
  }

  @override
  Future<TemplateItem?> fetchRandomTemplate({
    required TemplateRandomMode mode,
    required String? category,
    required bool includePremium,
    TemplateRandomAccess access = TemplateRandomAccess.available,
  }) async {
    fetchRandomTemplateCalls++;
    lastRandomMode = mode;
    lastRandomCategory = category;
    lastIncludePremium = includePremium;
    lastRandomAccess = access;
    if (throwOnRandom) {
      throw StateError('random template unavailable');
    }

    final delayedResult = randomTemplateCompleter;
    if (delayedResult != null) {
      return delayedResult.future;
    }

    return items.isEmpty ? null : items.first;
  }

  @override
  Future<TemplatesFeedPage?> readCachedFirstPage(TemplatesQuery query) async {
    return TemplatesFeedPage(items: items, hasMore: false);
  }

  @override
  Future<int> readLocalCatalogVersion() async => 1;

  @override
  Future<List<TemplateItem>> readSyncedCatalogItems() async {
    readSyncedCatalogItemsCalls++;
    return items;
  }

  @override
  Future<TemplateOfTheDayItem?> fetchTemplateOfTheDay() async => null;

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

class PetFlowGenerationRepository extends TemplateGenerationRepository {
  PetFlowGenerationRepository({this.photoId = 'photo-7'})
    : super(
        dio: Dio(),
        sessionStorage: AuthSessionStorage(),
        preferences: SharedPreferencesAsync(),
      );

  final String photoId;
  int startFromPetCalls = 0;
  String? lastPetId;
  String? lastPetPhotoId;
  String? lastTemplateId;
  final rememberedGenerationIds = <String>[];

  @override
  Future<({String correlationId, String generationId})?>
  readActiveGeneration() async {
    return null;
  }

  @override
  Future<List<PetProfile>> fetchPets({CancelToken? cancelToken}) async {
    return const [];
  }

  @override
  Future<List<PetPhoto>> fetchPetPhotos(
    String petId, {
    CancelToken? cancelToken,
  }) async {
    return [
      PetPhoto(
        id: photoId,
        petId: petId,
        mediaAssetId: 'pet-photo-asset-1',
        url: 'https://cdn.petmagic.app/pet-original.jpg',
        thumbnailUrl: 'https://cdn.petmagic.app/pet-thumb.jpg',
        fileName: 'pet.jpg',
        contentType: 'image/jpeg',
        isFavorite: true,
        isAvatar: true,
        sortOrder: 1,
        createdAtUtc: DateTime.utc(2035),
      ),
    ];
  }

  @override
  Future<TemplateGenerationResult> startGenerationFromPet({
    required String petId,
    String? petPhotoId,
    required String templateId,
    String? correlationId,
    CancelToken? cancelToken,
  }) async {
    startFromPetCalls++;
    lastPetId = petId;
    lastPetPhotoId = petPhotoId;
    lastTemplateId = templateId;
    final now = DateTime.utc(2035);
    return TemplateGenerationResult(
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
  }

  @override
  Future<void> rememberActiveGeneration({
    required String generationId,
    String? correlationId,
  }) async {
    rememberedGenerationIds.add(generationId);
  }
}

class CrossGalleryPetFlowRepository extends PetFlowGenerationRepository {
  final createdCreations = <TemplateGenerationResult>[];

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
    final generation = await super.startGenerationFromPet(
      petId: petId,
      petPhotoId: petPhotoId,
      templateId: templateId,
      correlationId: correlationId,
      cancelToken: cancelToken,
    );
    final completedAtUtc = DateTime.utc(2035, 1, 1, 12, 1);
    createdCreations
      ..clear()
      ..add(
        generation.copyWith(
          status: TemplateGenerationStatus.completed,
          outputUrl: 'https://cdn.petmagic.app/generated-bella.jpg',
          resultPreviewUrl:
              'https://cdn.petmagic.app/generated-bella-thumb.jpg',
          completedAtUtc: completedAtUtc,
          updatedAtUtc: completedAtUtc,
          isUnread: true,
        ),
      );
    return generation;
  }
}

class PetFlowHistoryController extends GenerationHistoryController {
  PetFlowHistoryController(this.repository);

  final CrossGalleryPetFlowRepository repository;
  int loadCalls = 0;

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
    final updated = [
      for (final item in state.items)
        item.generationId == generationId
            ? item.copyWith(isUnread: false)
            : item,
    ];
    state = state.copyWith(
      items: updated,
      unreadCount: updated.where((item) => item.isUnread).length,
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

String readTemplatesPageLibrarySource() {
  const files = [
    'lib/features/templates/presentation/templates_page.dart',
    'lib/features/templates/presentation/templates_page_feed.part.dart',
    'lib/features/templates/presentation/templates_page_generation_flow.part.dart',
    'lib/features/templates/presentation/templates_page_lifecycle.part.dart',
    'lib/features/templates/presentation/templates_page_template_actions.part.dart',
  ];

  return files.map((path) => File(path).readAsStringSync()).join('\n');
}
