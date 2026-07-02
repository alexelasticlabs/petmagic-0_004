import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/realtime/realtime_client.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/templates/data/generation_gallery_store.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_history_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_status_page.dart';
import 'package:petmagic_mobile/shared/notifications/petmagic_notification_center.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void configureGenerationStatusPageTestHarness() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });
  tearDown(() async {
    await PetMagicNotificationCenter.instance.clearQueue();
  });
}

String readGenerationStatusLibrarySource() {
  const files = [
    'lib/features/templates/presentation/generation_status_page.dart',
    'lib/features/templates/presentation/generation_status_page_lifecycle.part.dart',
    'lib/features/templates/presentation/generation_status_page_media_actions.part.dart',
    'lib/features/templates/presentation/generation_status_page_result_actions.part.dart',
    'lib/features/templates/presentation/generation_status_page_feedback_actions.part.dart',
  ];

  return files.map((path) => File(path).readAsStringSync()).join('\n');
}

String readGenerationStatusSectionsLibrarySource() {
  const files = [
    'lib/features/templates/presentation/generation_status_page_sections.dart',
    'lib/features/templates/presentation/generation_status_page_active_card.part.dart',
    'lib/features/templates/presentation/generation_status_page_active_chrome.part.dart',
    'lib/features/templates/presentation/generation_status_page_result_sections.part.dart',
  ];

  return files.map((path) => File(path).readAsStringSync()).join('\n');
}

class FakeGenerationStatusTemplateGenerationRepository
    extends TemplateGenerationRepository {
  FakeGenerationStatusTemplateGenerationRepository(
    this.generation, {
    this.removeWatermarkStatusCode,
    this.mediaAccessUrl = 'https://cdn.petmagic.test/result.jpg',
    this.mediaAccessFileName = 'result.jpg',
    this.cancelRefunded = false,
    this.cancelError,
  }) : super(
         dio: Dio(),
         sessionStorage: AuthSessionStorage(),
         preferences: SharedPreferencesAsync(),
       );

  TemplateGenerationResult generation;
  final int? removeWatermarkStatusCode;
  final String mediaAccessUrl;
  final String mediaAccessFileName;
  final bool cancelRefunded;
  final AppException? cancelError;
  final List<String> analyticsEvents = [];
  final List<GenerationStatusAnalyticsCall> analyticsCalls = [];
  final List<String> removeWatermarkCalls = [];
  int fetchDownloadCalls = 0;
  int fetchShareCalls = 0;
  int cancelGenerationCalls = 0;

  @override
  Future<TemplateGenerationResult> fetchGeneration(
    String generationId, {
    String? correlationId,
    CancelToken? cancelToken,
  }) async {
    return generation;
  }

  @override
  Future<TemplateGenerationResult?> readCachedGeneration(
    String generationId,
  ) async {
    return generation;
  }

  @override
  Future<GenerationCancelResult> cancelGeneration(
    String generationId, {
    String? correlationId,
    CancelToken? cancelToken,
  }) async {
    cancelGenerationCalls++;
    final error = cancelError;
    if (error != null) {
      throw error;
    }

    generation = generation.copyWith(
      status: TemplateGenerationStatus.cancelled,
      canCancel: false,
    );
    return GenerationCancelResult(
      generation: generation,
      refunded: cancelRefunded,
    );
  }

  @override
  Future<GenerationMediaAccessResult> fetchDownloadUrl(
    String generationId, {
    CancelToken? cancelToken,
  }) async {
    fetchDownloadCalls++;
    return GenerationMediaAccessResult(
      mediaUrl: mediaAccessUrl,
      hasWatermark: false,
      fileName: mediaAccessFileName,
    );
  }

  @override
  Future<GenerationMediaAccessResult> fetchShareUrl(
    String generationId, {
    CancelToken? cancelToken,
  }) async {
    fetchShareCalls++;
    return GenerationMediaAccessResult(
      mediaUrl: mediaAccessUrl,
      hasWatermark: false,
      fileName: mediaAccessFileName,
      shareUrl: 'https://app.petmagic.test/share/generation/token',
      shareToken: 'token',
    );
  }

  @override
  Future<RemoveGenerationWatermarkResult> removeWatermark(
    String generationId, {
    String paymentMethod = 'credit',
    CancelToken? cancelToken,
  }) async {
    removeWatermarkCalls.add(generationId);
    if (removeWatermarkStatusCode != null) {
      throw DioException.badResponse(
        statusCode: removeWatermarkStatusCode!,
        requestOptions: RequestOptions(
          path: '/api/templates/generations/$generationId/remove-watermark',
        ),
        response: Response<Map<String, Object?>>(
          requestOptions: RequestOptions(
            path: '/api/templates/generations/$generationId/remove-watermark',
          ),
          statusCode: removeWatermarkStatusCode,
          data: const {'title': 'economy.insufficient_balance'},
        ),
      );
    }

    generation = generation.copyWith(
      outputUrl: 'https://cdn.petmagic.test/result-clean.jpg?signature=secret',
      hasWatermark: false,
      canRemoveWatermark: false,
      isWatermarkRemoved: true,
      watermarkMessage: 'Watermark removed',
    );
    return const RemoveGenerationWatermarkResult(
      watermarkRemoved: true,
      creditsSpent: 1,
      remainingCredits: 2,
      mediaUrl: 'https://cdn.petmagic.test/result-clean.jpg',
    );
  }

  @override
  Future<void> recordAnalyticsEvent({
    required String templateId,
    required String eventType,
    String? generationId,
    Map<String, Object?> metadata = const {},
    CancelToken? cancelToken,
  }) async {
    analyticsEvents.add(eventType);
    analyticsCalls.add(
      GenerationStatusAnalyticsCall(
        templateId: templateId,
        eventType: eventType,
        generationId: generationId,
        metadata: metadata,
      ),
    );
  }
}

class GenerationStatusAnalyticsCall {
  const GenerationStatusAnalyticsCall({
    required this.templateId,
    required this.eventType,
    required this.generationId,
    required this.metadata,
  });

  final String templateId;
  final String eventType;
  final String? generationId;
  final Map<String, Object?> metadata;
}

class DelayedLoadGenerationStatusTemplateGenerationRepository
    extends TemplateGenerationRepository {
  DelayedLoadGenerationStatusTemplateGenerationRepository()
    : super(
        dio: Dio(),
        sessionStorage: AuthSessionStorage(),
        preferences: SharedPreferencesAsync(),
      );

  final fetchStarted = Completer<CancelToken>();

  @override
  Future<TemplateGenerationResult> fetchGeneration(
    String generationId, {
    String? correlationId,
    CancelToken? cancelToken,
  }) async {
    final token = cancelToken ?? CancelToken();
    if (!fetchStarted.isCompleted) {
      fetchStarted.complete(token);
    }

    await token.whenCancel;
    throw DioException.requestCancelled(
      requestOptions: RequestOptions(path: ''),
      reason: 'generation_status_load_cancelled',
    );
  }
}

class FakeGenerationStatusRealtimeClient implements RealtimeClient {
  FakeGenerationStatusRealtimeClient({Completer<void>? connectCompleter})
    : _connectCompleter = connectCompleter;

  final StreamController<RealtimeEvent> _controller =
      StreamController<RealtimeEvent>.broadcast();
  final Completer<void>? _connectCompleter;

  int connectCalls = 0;
  int disconnectCalls = 0;

  @override
  Stream<RealtimeEvent> get events => _controller.stream;

  @override
  Future<void> connect() async {
    connectCalls++;
    await _connectCompleter?.future;
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls++;
  }

  void emitGenerationStatus(Map<String, Object?> payload) {
    _controller.add(
      RealtimeEvent(
        topic: RealtimeTopics.templatesGenerationStatusChanged,
        payload: payload,
      ),
    );
  }
}

class IdleGenerationStatusHistoryController
    extends GenerationHistoryController {
  @override
  GenerationHistoryState build() {
    return const GenerationHistoryState();
  }

  @override
  Future<void> mergeFetchedGeneration(
    TemplateGenerationResult generation,
  ) async {}

  @override
  Future<void> markRead(String generationId) async {}
}

class TrackingGenerationStatusHistoryController
    extends IdleGenerationStatusHistoryController {
  final List<String> mergedGenerationIds = [];
  final List<TemplateGenerationResult> mergedGenerations = [];

  @override
  Future<void> mergeFetchedGeneration(
    TemplateGenerationResult generation,
  ) async {
    mergedGenerationIds.add(generation.generationId);
    mergedGenerations.add(generation);
    state = state.copyWith(items: [generation]);
  }
}

class DelayedGenerationStatusMediaActions extends GenerationStatusMediaActions {
  final shareStarted = Completer<void>();
  CancelToken? shareCancelToken;

  @override
  Future<void> share({
    required String mediaUrl,
    required String fileName,
    required String title,
    required CancelToken cancelToken,
    String? shareText,
    String? localPath,
  }) {
    shareCancelToken = cancelToken;
    if (!shareStarted.isCompleted) {
      shareStarted.complete();
    }
    return cancelToken.whenCancel.then((_) {});
  }
}

class RecordingGenerationStatusMediaActions
    extends GenerationStatusMediaActions {
  int saveCalls = 0;
  int shareCalls = 0;
  final savedFileNames = <String>[];
  final sharedFileNames = <String>[];
  final savedLocalPaths = <String?>[];
  final sharedLocalPaths = <String?>[];
  final sharedTexts = <String?>[];

  @override
  Future<bool> saveToGallery({
    required String mediaUrl,
    required String fileName,
    required bool isVideo,
    required String albumName,
    required CancelToken cancelToken,
    String? localPath,
  }) async {
    saveCalls++;
    savedFileNames.add(fileName);
    savedLocalPaths.add(localPath);
    return true;
  }

  @override
  Future<void> share({
    required String mediaUrl,
    required String fileName,
    required String title,
    required CancelToken cancelToken,
    String? shareText,
    String? localPath,
  }) async {
    shareCalls++;
    sharedFileNames.add(fileName);
    sharedLocalPaths.add(localPath);
    sharedTexts.add(shareText);
  }
}

class DelayedGenerationStatusGalleryStore extends GenerationGalleryStore {
  DelayedGenerationStatusGalleryStore()
    : super(
        dio: Dio(),
        preferences: SharedPreferencesAsync(),
        sessionStorage: AuthSessionStorage(),
        rootDirectoryResolver: () async => Directory.systemTemp,
      );

  final materializeStarted = Completer<void>();
  final materializeCompleter = Completer<GenerationGalleryMediaRecord?>();
  int cancelActiveDownloadsCalls = 0;

  @override
  Future<GenerationGalleryMediaRecord?> materializeGenerationMedia(
    TemplateGenerationResult generation, {
    bool background = false,
  }) async {
    if (!materializeStarted.isCompleted) {
      materializeStarted.complete();
    }
    return materializeCompleter.future;
  }

  @override
  Future<void> cancelActiveDownloads() async {
    cancelActiveDownloadsCalls++;
  }
}

class NoopGenerationStatusGalleryStore extends GenerationGalleryStore {
  NoopGenerationStatusGalleryStore()
    : super(
        dio: Dio(),
        preferences: SharedPreferencesAsync(),
        sessionStorage: AuthSessionStorage(),
        rootDirectoryResolver: () async => Directory.systemTemp,
      );

  @override
  Future<GenerationGalleryMediaRecord?> materializeGenerationMedia(
    TemplateGenerationResult generation, {
    bool background = false,
  }) async {
    return null;
  }

  @override
  Future<void> cancelActiveDownloads() async {}
}

class ImmediateGenerationStatusGalleryStore extends GenerationGalleryStore {
  ImmediateGenerationStatusGalleryStore({required this.record})
    : super(
        dio: Dio(),
        preferences: SharedPreferencesAsync(),
        sessionStorage: AuthSessionStorage(),
        rootDirectoryResolver: () async => Directory.systemTemp,
      );

  final GenerationGalleryMediaRecord record;

  @override
  Future<GenerationGalleryMediaRecord?> materializeGenerationMedia(
    TemplateGenerationResult generation, {
    bool background = false,
  }) async {
    return record;
  }

  @override
  Future<void> cancelActiveDownloads() async {}
}

TemplateGenerationResult generationStatusFixture({
  String generationId = 'generation-1',
  String templateTitle = 'Movie Star Pet Poster',
  TemplateGenerationStatus status = TemplateGenerationStatus.completed,
  bool hasWatermark = false,
  bool canRemoveWatermark = false,
  bool isWatermarkRemoved = false,
  int removeWatermarkCostCredits = 1,
  String userPlan = 'free',
  String? watermarkMessage,
  bool supportsGenerateSimilar = false,
  String? failureCode,
  String? inputPreviewUrl,
  String? resultPreviewUrl,
  bool canCompareBeforeAfter = false,
  int? queuePosition,
  int? estimatedWaitSeconds,
  bool? canCancel,
  String? mediaType,
  String? templateType = 'image',
  String? localOutputPath,
  String? petId,
  String? petPhotoId,
}) {
  final now = DateTime.utc(2026, 5, 25, 14, 30);
  return TemplateGenerationResult(
    generationId: generationId,
    userId: 'user-1',
    templateId: 'template-1',
    status: status,
    tokenCost: 6,
    attemptCount: 1,
    createdAtUtc: now,
    updatedAtUtc: now,
    completedAtUtc: now,
    failureCode: failureCode,
    userMediaExpired: false,
    templateTitle: templateTitle,
    templateType: templateType,
    outputUrl: 'https://cdn.petmagic.test/result.jpg?signature=secret',
    hasWatermark: hasWatermark,
    canRemoveWatermark: canRemoveWatermark,
    isWatermarkRemoved: isWatermarkRemoved,
    removeWatermarkCostCredits: removeWatermarkCostCredits,
    userPlan: userPlan,
    watermarkMessage: watermarkMessage,
    supportsGenerateSimilar: supportsGenerateSimilar,
    inputPreviewUrl: inputPreviewUrl,
    resultPreviewUrl: resultPreviewUrl,
    canCompareBeforeAfter: canCompareBeforeAfter,
    queuePosition: queuePosition,
    estimatedWaitSeconds: estimatedWaitSeconds,
    mediaType: mediaType,
    canCancel: canCancel,
    localOutputPath: localOutputPath,
    petId: petId,
    petPhotoId: petPhotoId,
  );
}

TemplateOfTheDayItem templateOfTheDayFixture() {
  return TemplateOfTheDayItem(
    templateId: 'template-1',
    title: 'Movie Star Pet Poster',
    subtitle: 'Today magic idea',
    badgeText: 'Template of the Day',
    templateType: TemplateType.image,
    isPremium: false,
    requiredPlan: 'free',
    date: DateTime.utc(2026, 6, 14),
    source: 'auto',
  );
}

String methodBody(String source, String methodName) {
  final methodIndex = source.indexOf(methodName);
  if (methodIndex < 0) {
    fail('Method $methodName was not found.');
  }

  final asyncBodyIndex = source.indexOf('async {', methodIndex);
  final syncBodyIndex = source.indexOf(') {', methodIndex);
  final openBraceIndex =
      asyncBodyIndex >= 0 &&
          (syncBodyIndex < 0 || asyncBodyIndex < syncBodyIndex)
      ? source.indexOf('{', asyncBodyIndex)
      : source.indexOf('{', syncBodyIndex);
  if (openBraceIndex < 0) {
    fail('Method $methodName has no body.');
  }

  var depth = 0;
  for (var index = openBraceIndex; index < source.length; index++) {
    final char = source[index];
    if (char == '{') {
      depth++;
      continue;
    }
    if (char != '}') {
      continue;
    }

    depth--;
    if (depth == 0) {
      return source.substring(openBraceIndex, index + 1);
    }
  }

  fail('Method $methodName body did not close.');
}
