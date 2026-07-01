import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/realtime/realtime_client.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_history_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_status_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/generations_gallery_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_page.dart';
import 'package:petmagic_mobile/features/wallet/data/wallet_models.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_controller.dart';
import 'package:petmagic_mobile/shared/notifications/petmagic_notification_center.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void configureGenerationsGalleryPageTestHarness() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });
  tearDown(() async {
    await PetMagicNotificationCenter.instance.clearQueue();
  });
}

AppLocalizations galleryText(WidgetTester tester) {
  final context = tester.element(find.byType(GenerationsGalleryPage).first);
  return AppLocalizations.of(context);
}

Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() isDone, {
  int maxPumps = 10,
}) async {
  for (var attempt = 0; attempt < maxPumps && !isDone(); attempt++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

class GalleryHarness {
  GalleryHarness({
    List<TemplateGenerationResult>? items,
    GenerationHistoryState? initialState,
    this.mediaActions,
    this.authenticated = true,
    this.hasPremiumAccess,
    this.walletController,
    Completer<void>? markReadCompleter,
  }) : controller = FakeGalleryGenerationHistoryController(
         items ?? initialState?.items ?? sampleGalleryItems(),
         initialState: initialState,
         markReadCompleter: markReadCompleter,
       ),
       router = GoRouter(
         initialLocation: GenerationsGalleryPage.routePath,
         routes: [
           GoRoute(
             path: GenerationsGalleryPage.routePath,
             pageBuilder: (context, state) =>
                 const NoTransitionPage(child: GenerationsGalleryPage()),
           ),
           GoRoute(
             path: '${GenerationStatusPage.routePrefix}/:generationId',
             pageBuilder: (context, state) => NoTransitionPage(
               child: Scaffold(
                 body: Center(
                   child: Text(
                     'status:${state.pathParameters['generationId']}',
                   ),
                 ),
               ),
             ),
           ),
           GoRoute(
             path: TemplatesPage.routePath,
             pageBuilder: (context, state) {
               final query = state.uri.queryParameters;
               return NoTransitionPage(
                 child: Scaffold(
                   body: Center(
                     child: Column(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                         const Text('templates-route'),
                         Text('templates-pet:${query['petId'] ?? ''}'),
                         Text('templates-photo:${query['petPhotoId'] ?? ''}'),
                       ],
                     ),
                   ),
                 ),
               );
             },
           ),
           GoRoute(
             path: SupportChatPage.routePath,
             pageBuilder: (context, state) {
               final query = state.uri.queryParameters;
               return NoTransitionPage(
                 child: Scaffold(
                   body: Center(
                     child: Column(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                         const Text('support-route'),
                         Text(
                           'support-generation:${query[SupportChatPage.relatedGenerationIdQueryParam] ?? ''}',
                         ),
                         Text(
                           'support-message:${query[SupportChatPage.initialMessageQueryParam] ?? ''}',
                         ),
                       ],
                     ),
                   ),
                 ),
               );
             },
           ),
         ],
       );

  final FakeGalleryGenerationHistoryController controller;
  final GoRouter router;
  final GenerationStatusMediaActions? mediaActions;
  final bool authenticated;
  final bool? hasPremiumAccess;
  final WalletController? walletController;

  Widget app() {
    return ProviderScope(
      overrides: [
        appLaunchControllerProvider.overrideWith(
          authenticated
              ? AuthenticatedGalleryAppLaunchController.new
              : UnauthenticatedGalleryAppLaunchController.new,
        ),
        generationHistoryControllerProvider.overrideWith(() => controller),
        walletControllerProvider.overrideWith(
          () =>
              walletController ??
              (hasPremiumAccess == null
                  ? IdleGalleryWalletController()
                  : StaticGalleryWalletController(
                      isPremium: hasPremiumAccess!,
                    )),
        ),
        realtimeClientProvider.overrideWith(
          (ref) => const NoopRealtimeClient(),
        ),
        if (mediaActions != null)
          generationStatusMediaActionsProvider.overrideWithValue(mediaActions!),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.dark(),
        locale: const Locale('ru'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }
}

class AuthenticatedGalleryAppLaunchController extends AppLaunchController {
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

class UnauthenticatedGalleryAppLaunchController extends AppLaunchController {
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

class IdleGalleryWalletController extends WalletController {
  @override
  WalletState build() {
    return const WalletState();
  }

  @override
  Future<void> load({bool refresh = false}) async {}
}

class StaticGalleryWalletController extends WalletController {
  StaticGalleryWalletController({required this.isPremium});

  final bool isPremium;

  @override
  WalletState build() {
    return WalletState(
      wallet: WalletStateModel(
        userId: 'user-1',
        balance: 20,
        adRewardsRemainingToday: 0,
        isPremium: isPremium,
        updatedAtUtc: DateTime.utc(2026, 6, 15),
      ),
    );
  }

  @override
  Future<void> load({bool refresh = false}) async {}
}

class TrackingGalleryWalletController extends WalletController {
  TrackingGalleryWalletController({
    this.hasWallet = false,
    this.hasCompletedFullLoad = false,
    this.initiallyLoading = false,
    this.initiallyRefreshing = false,
  });

  final bool hasWallet;
  final bool hasCompletedFullLoad;
  final bool initiallyLoading;
  final bool initiallyRefreshing;
  int loadCalls = 0;

  @override
  WalletState build() {
    return WalletState(
      wallet: hasWallet
          ? WalletStateModel(
              userId: 'user-1',
              balance: 20,
              adRewardsRemainingToday: 0,
              isPremium: false,
              updatedAtUtc: DateTime.utc(2026, 6, 15),
            )
          : null,
      hasCompletedFullLoad: hasCompletedFullLoad,
      isLoading: initiallyLoading,
      isRefreshing: initiallyRefreshing,
    );
  }

  @override
  Future<void> load({bool refresh = false}) async {
    loadCalls++;
    state = state.copyWith(isLoading: true);
  }
}

class FakeGalleryGenerationHistoryController
    extends GenerationHistoryController {
  FakeGalleryGenerationHistoryController(
    this._allItems, {
    GenerationHistoryState? initialState,
    Completer<void>? markReadCompleter,
  }) : _initialState = initialState,
       _markReadCompleter = markReadCompleter;

  final List<TemplateGenerationResult> _allItems;
  final GenerationHistoryState? _initialState;
  final Completer<void>? _markReadCompleter;
  final List<GenerationHistoryFilter> loadCalls = [];
  final List<GenerationHistoryFilter> refreshCalls = [];
  final List<String> markReadCalls = [];
  final List<String> deleteGenerationCalls = [];
  final List<bool> screenVisibilityCalls = [];

  @override
  GenerationHistoryState build() {
    final initialState = _initialState;
    if (initialState != null) {
      return initialState;
    }
    final unread = _allItems.where((item) => item.isUnread).length;
    return GenerationHistoryState(items: _allItems, unreadCount: unread);
  }

  @override
  void setScreenVisible(bool visible, {bool clearLoadingState = true}) {
    screenVisibilityCalls.add(visible);
  }

  @override
  Future<void> load({
    GenerationHistoryFilter? filter,
    bool refresh = false,
  }) async {
    final nextFilter = filter ?? state.filter;
    if (refresh) {
      refreshCalls.add(nextFilter);
    }
    loadCalls.add(nextFilter);
    if (_initialState != null) {
      return;
    }
    final filtered = _applyFilter(nextFilter);

    state = state.copyWith(
      filter: nextFilter,
      items: filtered,
      unreadCount: filtered.where((item) => item.isUnread).length,
      isLoading: false,
      clearError: true,
    );
  }

  @override
  Future<void> markRead(String generationId) async {
    markReadCalls.add(generationId);
    final completer = _markReadCompleter;
    if (completer != null && !completer.isCompleted) {
      await completer.future;
    }

    final updated = [
      for (final item in state.items)
        if (item.generationId == generationId)
          TemplateGenerationResult(
            generationId: item.generationId,
            userId: item.userId,
            templateId: item.templateId,
            status: item.status,
            tokenCost: item.tokenCost,
            attemptCount: item.attemptCount,
            createdAtUtc: item.createdAtUtc,
            updatedAtUtc: item.updatedAtUtc,
            userMediaExpired: item.userMediaExpired,
            templateTitle: item.templateTitle,
            templateType: item.templateType,
            stage: item.stage,
            progressPercent: item.progressPercent,
            estimatedDurationLabel: item.estimatedDurationLabel,
            sourceImageAsset: item.sourceImageAsset,
            normalizedImageUrl: item.normalizedImageUrl,
            referenceMotionUrl: item.referenceMotionUrl,
            outputUrl: item.outputUrl,
            usedPreprocessingModel: item.usedPreprocessingModel,
            usedKlingModel: item.usedKlingModel,
            outputVideoDurationSeconds: item.outputVideoDurationSeconds,
            failureCode: item.failureCode,
            failureMessage: item.failureMessage,
            startedAtUtc: item.startedAtUtc,
            preprocessingCompletedAtUtc: item.preprocessingCompletedAtUtc,
            motionGenerationCompletedAtUtc: item.motionGenerationCompletedAtUtc,
            mediaImportCompletedAtUtc: item.mediaImportCompletedAtUtc,
            completedAtUtc: item.completedAtUtc,
            chargedAtUtc: item.chargedAtUtc,
            refundedAtUtc: item.refundedAtUtc,
            isUnread: false,
          )
        else
          item,
    ];

    state = state.copyWith(
      items: updated,
      unreadCount: updated.where((item) => item.isUnread).length,
    );
  }

  @override
  Future<void> deleteGeneration(String generationId) async {
    deleteGenerationCalls.add(generationId);
    _allItems.removeWhere((item) => item.generationId == generationId);
    final updated = [
      for (final item in state.items)
        if (item.generationId != generationId) item,
    ];

    state = state.copyWith(
      items: updated,
      unreadCount: updated.where((item) => item.isUnread).length,
    );
  }

  List<TemplateGenerationResult> _applyFilter(GenerationHistoryFilter filter) {
    return switch (filter) {
      GenerationHistoryFilter.all => List<TemplateGenerationResult>.from(
        _allItems,
      ),
      GenerationHistoryFilter.active =>
        _allItems.where((item) => !item.isTerminal).toList(growable: false),
      GenerationHistoryFilter.ready =>
        _allItems.where((item) => item.isCompleted).toList(growable: false),
      GenerationHistoryFilter.failed =>
        _allItems.where((item) => item.isFailed).toList(growable: false),
    };
  }
}

class DelayedGalleryGenerationStatusMediaActions
    extends GenerationStatusMediaActions {
  DelayedGalleryGenerationStatusMediaActions({
    this.delaySave = false,
    this.delayShare = true,
  });

  final bool delaySave;
  final bool delayShare;
  final saveStarted = Completer<void>();
  final shareStarted = Completer<void>();
  CancelToken? saveCancelToken;
  CancelToken? shareCancelToken;
  int saveCalls = 0;
  int shareCalls = 0;
  final savedUrls = <String>[];
  final sharedUrls = <String>[];
  final savedLocalPaths = <String?>[];
  final sharedLocalPaths = <String?>[];
  final savedFileNames = <String>[];
  final sharedFileNames = <String>[];

  @override
  Future<bool> saveToGallery({
    required String mediaUrl,
    required String fileName,
    required bool isVideo,
    required String albumName,
    required CancelToken cancelToken,
    String? localPath,
  }) {
    saveCalls++;
    savedUrls.add(mediaUrl);
    savedLocalPaths.add(localPath);
    savedFileNames.add(fileName);
    saveCancelToken = cancelToken;
    if (!saveStarted.isCompleted) {
      saveStarted.complete();
    }
    if (!delaySave) {
      return Future.value(true);
    }
    return cancelToken.whenCancel.then((_) => false);
  }

  @override
  Future<void> share({
    required String mediaUrl,
    required String fileName,
    required String title,
    required CancelToken cancelToken,
    String? localPath,
  }) {
    shareCalls++;
    sharedUrls.add(mediaUrl);
    sharedLocalPaths.add(localPath);
    sharedFileNames.add(fileName);
    shareCancelToken = cancelToken;
    if (!shareStarted.isCompleted) {
      shareStarted.complete();
    }
    if (!delayShare) {
      return Future.value();
    }
    return cancelToken.whenCancel.then((_) {});
  }
}

List<TemplateGenerationResult> sampleGalleryItems() {
  final now = DateTime.utc(2026, 5, 25, 14, 30);

  return [
    galleryGenerationFixture(
      generationId: 'g-active-1',
      status: TemplateGenerationStatus.generating,
      templateTitle: 'Little Space Explorer',
      templateType: 'video',
      tokenCost: 60,
      stage: 'generating',
      progressPercent: 65,
      estimatedDurationLabel: '1-2 мин',
      outputVideoDurationSeconds: 5,
      updatedAtUtc: now,
      isUnread: true,
    ),
    galleryGenerationFixture(
      generationId: 'g-active-2',
      status: TemplateGenerationStatus.queued,
      templateTitle: 'Birthday Pet Party',
      templateType: 'video',
      tokenCost: 40,
      stage: 'queued',
      progressPercent: 15,
      updatedAtUtc: now.subtract(const Duration(minutes: 1)),
    ),
    galleryGenerationFixture(
      generationId: 'g-ready-1',
      status: TemplateGenerationStatus.completed,
      templateTitle: 'Movie Star Pet Poster',
      templateType: 'image',
      tokenCost: 6,
      outputUrl: 'https://cdn.petmagic.test/ready-1.jpg',
      updatedAtUtc: now.subtract(const Duration(minutes: 2)),
      isUnread: true,
    ),
    galleryGenerationFixture(
      generationId: 'g-ready-2',
      status: TemplateGenerationStatus.completed,
      templateTitle: 'Superhero Pet',
      templateType: 'image',
      tokenCost: 6,
      updatedAtUtc: now.subtract(const Duration(minutes: 3)),
    ),
    galleryGenerationFixture(
      generationId: 'g-ready-3',
      status: TemplateGenerationStatus.completed,
      templateTitle: 'Dance With Me',
      templateType: 'video',
      tokenCost: 60,
      outputVideoDurationSeconds: 4,
      updatedAtUtc: now.subtract(const Duration(minutes: 4)),
    ),
    galleryGenerationFixture(
      generationId: 'g-ready-4',
      status: TemplateGenerationStatus.completed,
      templateTitle: 'Magic Wizard',
      templateType: 'image',
      tokenCost: 6,
      updatedAtUtc: now.subtract(const Duration(minutes: 5)),
    ),
    galleryGenerationFixture(
      generationId: 'g-ready-5',
      status: TemplateGenerationStatus.completed,
      templateTitle: 'Hidden Ready',
      templateType: 'image',
      tokenCost: 6,
      updatedAtUtc: now.subtract(const Duration(minutes: 6)),
    ),
    galleryGenerationFixture(
      generationId: 'g-failed-1',
      status: TemplateGenerationStatus.failed,
      templateTitle: 'Funny Hoodie',
      templateType: 'video',
      tokenCost: 60,
      stage: 'finalizing',
      updatedAtUtc: now.subtract(const Duration(minutes: 7)),
      refundedAtUtc: now.subtract(const Duration(minutes: 6)),
      petId: 'pet/route',
      petPhotoId: 'photo route',
    ),
  ];
}

TemplateGenerationResult galleryGenerationFixture({
  required String generationId,
  required TemplateGenerationStatus status,
  required String templateTitle,
  required String templateType,
  required int tokenCost,
  required DateTime updatedAtUtc,
  String? stage,
  int? progressPercent,
  String? estimatedDurationLabel,
  String? outputUrl,
  double? outputVideoDurationSeconds,
  DateTime? refundedAtUtc,
  bool isUnread = false,
  String? localPreviewPath,
  String? localOutputPath,
  String? petId,
  String? petPhotoId,
}) {
  return TemplateGenerationResult(
    generationId: generationId,
    userId: 'user-1',
    templateId: 'template-1',
    status: status,
    tokenCost: tokenCost,
    attemptCount: 1,
    createdAtUtc: updatedAtUtc.subtract(const Duration(minutes: 2)),
    updatedAtUtc: updatedAtUtc,
    userMediaExpired: false,
    templateTitle: templateTitle,
    templateType: templateType,
    stage: stage,
    progressPercent: progressPercent,
    estimatedDurationLabel: estimatedDurationLabel,
    outputUrl: outputUrl,
    outputVideoDurationSeconds: outputVideoDurationSeconds,
    refundedAtUtc: refundedAtUtc,
    isUnread: isUnread,
    localPreviewPath: localPreviewPath,
    localOutputPath: localOutputPath,
    petId: petId,
    petPhotoId: petPhotoId,
  );
}

class GalleryTickerModeHost extends StatefulWidget {
  const GalleryTickerModeHost({super.key, required this.child});

  final Widget child;

  @override
  State<GalleryTickerModeHost> createState() => GalleryTickerModeHostState();
}

class GalleryTickerModeHostState extends State<GalleryTickerModeHost> {
  bool _enabled = true;

  void setEnabled(bool enabled) {
    setState(() {
      _enabled = enabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    return TickerMode(enabled: _enabled, child: widget.child);
  }
}
