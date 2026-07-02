import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/core/realtime/realtime_client.dart';
import 'package:petmagic_mobile/features/profile/data/auth_session_storage.dart';
import 'package:petmagic_mobile/features/templates/data/generation_gallery_store.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_history_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void configureGenerationHistoryControllerTestHarness() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });
}

class GenerationHistoryControllerHarness {
  factory GenerationHistoryControllerHarness({
    required FakeTemplateGenerationRepository repository,
    FakeGenerationGalleryStore? store,
    FakeRealtimeClient? realtimeClient,
    FakeGenerationHistoryNetworkStatusController? networkStatusController,
  }) {
    final resolvedStore = store ?? FakeGenerationGalleryStore();
    final resolvedRealtimeClient = realtimeClient ?? FakeRealtimeClient();
    final resolvedNetworkStatusController =
        networkStatusController ??
        FakeGenerationHistoryNetworkStatusController();
    return GenerationHistoryControllerHarness._(
      repository: repository,
      store: resolvedStore,
      realtimeClient: resolvedRealtimeClient,
      networkStatusController: resolvedNetworkStatusController,
    );
  }

  GenerationHistoryControllerHarness._({
    required FakeTemplateGenerationRepository repository,
    required this.store,
    required this.realtimeClient,
    required this.networkStatusController,
  }) : container = ProviderContainer(
         overrides: [
           templateGenerationRepositoryProvider.overrideWithValue(repository),
           generationGalleryStoreProvider.overrideWithValue(store),
           realtimeClientProvider.overrideWithValue(realtimeClient),
           networkStatusControllerProvider.overrideWith(
             () => networkStatusController,
           ),
         ],
       );

  final ProviderContainer container;
  final FakeGenerationGalleryStore store;
  final FakeRealtimeClient realtimeClient;
  final FakeGenerationHistoryNetworkStatusController networkStatusController;

  GenerationHistoryController get controller =>
      container.read(generationHistoryControllerProvider.notifier);

  GenerationHistoryState get state =>
      container.read(generationHistoryControllerProvider);

  void dispose() {
    container.dispose();
    realtimeClient.dispose();
  }
}

class FakeGenerationHistoryNetworkStatusController
    extends NetworkStatusController {
  @override
  NetworkStatusState build() {
    return const NetworkStatusState();
  }

  void setHasInternet(bool value) {
    state = state.copyWith(hasInternet: value);
  }
}

class FakeTemplateGenerationRepository extends TemplateGenerationRepository {
  FakeTemplateGenerationRepository({
    Map<String?, List<TemplateGenerationResult>> remoteByStatus = const {},
    Map<String, TemplateGenerationResult> remoteById = const {},
    Map<String, TemplateGenerationGalleryPage> remotePagesByCursor = const {},
    Map<String?, List<TemplateGenerationResult>> persistedByStatus = const {},
    this.fetchCompletersByStatus = const {},
    this.fetchError,
    this.deleteError,
    this.deleteCompleter,
    this.markReadError,
    this.markReadCompleter,
    this.unreadCountCompleter,
    this.unreadCountError,
    this.unreadCount = 0,
  }) : remoteByStatus = Map<String?, List<TemplateGenerationResult>>.from(
         remoteByStatus,
       ),
       remoteById = Map<String, TemplateGenerationResult>.from(remoteById),
       remotePagesByCursor = Map<String, TemplateGenerationGalleryPage>.from(
         remotePagesByCursor,
       ),
       persistedByStatus = Map<String?, List<TemplateGenerationResult>>.from(
         persistedByStatus,
       ),
       super(
         dio: Dio(),
         sessionStorage: AuthSessionStorage(),
         preferences: SharedPreferencesAsync(),
       );

  final Map<String?, List<TemplateGenerationResult>> remoteByStatus;
  final Map<String, TemplateGenerationResult> remoteById;
  final Map<String, TemplateGenerationGalleryPage> remotePagesByCursor;
  final Map<String?, List<TemplateGenerationResult>> persistedByStatus;
  final Map<String?, Completer<void>> fetchCompletersByStatus;
  final List<({String? status, int? take})> fetchCalls = [];
  final List<String> fetchGenerationCalls = [];
  final List<({String? status, String? cursor, int? take})> fetchPageCalls = [];
  final List<CancelToken?> fetchCancelTokens = [];
  final List<CancelToken?> fetchUnreadCancelTokens = [];
  final List<CancelToken?> deleteCancelTokens = [];
  final List<CancelToken?> markReadCancelTokens = [];
  final List<String> deleteGenerationCalls = [];
  final List<String> markReadCalls = [];
  final List<TemplateGenerationResult> cachedUpserts = [];
  int fetchUnreadCountCalls = 0;
  Object? fetchError;
  Object? deleteError;
  Completer<void>? deleteCompleter;
  Object? markReadError;
  Completer<void>? markReadCompleter;
  Completer<void>? unreadCountCompleter;
  Object? unreadCountError;
  int unreadCount;

  @override
  Future<List<TemplateGenerationResult>?> readCachedGenerations({
    String? status,
  }) async {
    return persistedByStatus[status];
  }

  @override
  Future<int?> readCachedUnreadGenerationCount() async => null;

  @override
  Future<TemplateGenerationResult> fetchGeneration(
    String generationId, {
    String? correlationId,
    CancelToken? cancelToken,
  }) async {
    fetchGenerationCalls.add(generationId);
    if (cancelToken?.isCancelled == true) {
      throw DioException(
        requestOptions: RequestOptions(
          path: '/api/templates/generations/$generationId',
        ),
        type: DioExceptionType.cancel,
      );
    }

    final direct = remoteById[generationId];
    if (direct != null) {
      return direct;
    }

    for (final items in remoteByStatus.values) {
      for (final item in items) {
        if (item.generationId == generationId) {
          return item;
        }
      }
    }

    final requestOptions = RequestOptions(
      path: '/api/templates/generations/$generationId',
    );
    throw DioException(
      requestOptions: requestOptions,
      response: Response<void>(
        requestOptions: requestOptions,
        statusCode: HttpStatus.notFound,
      ),
    );
  }

  @override
  Future<List<TemplateGenerationResult>> fetchGenerations({
    String? status,
    int? skip,
    int? take,
    CancelToken? cancelToken,
  }) async {
    fetchCalls.add((status: status, take: take));
    fetchCancelTokens.add(cancelToken);
    final completer = fetchCompletersByStatus[status];
    if (completer != null && !completer.isCompleted) {
      await completer.future;
    }
    if (cancelToken?.isCancelled == true) {
      throw DioException(
        requestOptions: RequestOptions(path: '/api/templates/generations'),
        type: DioExceptionType.cancel,
      );
    }
    final error = fetchError;
    if (error != null) {
      throw error;
    }
    return remoteByStatus[status] ?? const [];
  }

  @override
  Future<TemplateGenerationGalleryPage> fetchGenerationPage({
    String? status,
    String? cursor,
    int? take,
    CancelToken? cancelToken,
  }) async {
    fetchCalls.add((status: status, take: take));
    fetchPageCalls.add((status: status, cursor: cursor, take: take));
    fetchCancelTokens.add(cancelToken);
    final completer = fetchCompletersByStatus[status];
    if (completer != null && !completer.isCompleted) {
      await completer.future;
    }
    if (cancelToken?.isCancelled == true) {
      throw DioException(
        requestOptions: RequestOptions(path: '/api/templates/generations'),
        type: DioExceptionType.cancel,
      );
    }
    final error = fetchError;
    if (error != null) {
      throw error;
    }

    final page = remotePagesByCursor[_pageKey(status, cursor)];
    if (page != null) {
      return page;
    }

    final items = remoteByStatus[status] ?? const <TemplateGenerationResult>[];
    return TemplateGenerationGalleryPage(
      items: items,
      hasMore: false,
      serverTimeUtc: DateTime.utc(2026, 1),
      unreadCount: unreadCount,
      appliedFilter: status ?? 'all',
    );
  }

  @override
  Future<int> fetchUnreadGenerationCount({CancelToken? cancelToken}) async {
    fetchUnreadCountCalls++;
    fetchUnreadCancelTokens.add(cancelToken);
    final completer = unreadCountCompleter;
    if (completer != null && !completer.isCompleted) {
      await completer.future;
    }
    if (cancelToken?.isCancelled == true) {
      throw DioException(
        requestOptions: RequestOptions(
          path: '/api/templates/generations/unread-count',
        ),
        type: DioExceptionType.cancel,
      );
    }
    final error = unreadCountError;
    if (error != null) {
      throw error;
    }
    return unreadCount;
  }

  @override
  Future<void> deleteGeneration(
    String generationId, {
    CancelToken? cancelToken,
  }) async {
    deleteGenerationCalls.add(generationId);
    deleteCancelTokens.add(cancelToken);
    final completer = deleteCompleter;
    if (completer != null && !completer.isCompleted) {
      await completer.future;
    }
    if (cancelToken?.isCancelled == true) {
      throw DioException(
        requestOptions: RequestOptions(
          path: '/api/templates/generations/$generationId',
        ),
        type: DioExceptionType.cancel,
      );
    }
    final error = deleteError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<void> markGenerationRead(
    String generationId, {
    CancelToken? cancelToken,
  }) async {
    markReadCalls.add(generationId);
    markReadCancelTokens.add(cancelToken);
    final completer = markReadCompleter;
    if (completer != null) {
      await completer.future;
    }
    final error = markReadError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<void> upsertCachedGeneration(
    TemplateGenerationResult generation,
  ) async {
    cachedUpserts.add(generation);
  }
}

class FakeGenerationGalleryStore extends GenerationGalleryStore {
  FakeGenerationGalleryStore({
    this.materializeCompleter,
    this.markDeletedCompleter,
    List<GenerationGalleryMediaRecord> localReadyRecords = const [],
  }) : localReadyRecords = List<GenerationGalleryMediaRecord>.from(
         localReadyRecords,
       ),
       super(
         dio: Dio(),
         preferences: SharedPreferencesAsync(),
         sessionStorage: AuthSessionStorage(),
         rootDirectoryResolver: () async => Directory.systemTemp,
       );

  final Completer<GenerationGalleryMediaRecord?>? materializeCompleter;
  final Completer<void>? markDeletedCompleter;
  final List<GenerationGalleryMediaRecord> localReadyRecords;
  final List<String> materializedGenerationIds = [];
  final List<({String generationId, String? userId})> markDeletedCalls = [];
  final List<String> clearPendingServerDeleteCalls = [];
  final Set<String> deletedGenerationIds = {};
  final List<String> pendingServerDeleteIds = [];
  int cancelActiveDownloadsCalls = 0;
  int cleanupCurrentAccountArtifactsCalls = 0;

  @override
  Future<Set<String>> loadDeletedGenerationIds() async => deletedGenerationIds;

  @override
  Future<List<String>> loadPendingServerDeleteIds() async =>
      pendingServerDeleteIds;

  @override
  Future<List<GenerationGalleryMediaRecord>> loadLocalReadyItems() async =>
      localReadyRecords;

  @override
  Future<void> clearPendingServerDelete(String generationId) async {
    clearPendingServerDeleteCalls.add(generationId);
    pendingServerDeleteIds.remove(generationId);
  }

  @override
  Future<void> markDeletedLocally(String generationId, {String? userId}) async {
    markDeletedCalls.add((generationId: generationId, userId: userId));
    deletedGenerationIds.add(generationId);
    if (!pendingServerDeleteIds.contains(generationId)) {
      pendingServerDeleteIds.add(generationId);
    }
    final completer = markDeletedCompleter;
    if (completer != null && !completer.isCompleted) {
      await completer.future;
    }
  }

  @override
  Future<void> cancelActiveDownloads() async {
    cancelActiveDownloadsCalls++;
  }

  @override
  Future<void> cleanupCurrentAccountArtifacts() async {
    cleanupCurrentAccountArtifactsCalls++;
  }

  @override
  Future<GenerationGalleryMediaRecord?> materializeGenerationMedia(
    TemplateGenerationResult generation, {
    bool background = false,
  }) async {
    materializedGenerationIds.add(generation.generationId);
    final completer = materializeCompleter;
    if (completer != null) {
      return completer.future;
    }

    final nowUtc = DateTime.now().toUtc();
    final outputRemoteUrl = generation.outputUrl;
    final previewRemoteUrl = generation.resultPreviewUrl ?? outputRemoteUrl;
    return GenerationGalleryMediaRecord(
      generationId: generation.generationId,
      accountScope: generation.userId,
      userId: generation.userId,
      status: generation.status.name,
      updatedAtUtc: generation.updatedAtUtc,
      previewRemoteUrl: previewRemoteUrl,
      outputRemoteUrl: outputRemoteUrl,
      previewLocalPath: '/local/${generation.generationId}-preview.jpg',
      outputLocalPath: '/local/${generation.generationId}-output.jpg',
      isDownloadComplete: true,
      lastSyncedAtUtc: nowUtc,
      version: 1,
    );
  }
}

class FakeRealtimeClient implements RealtimeClient {
  FakeRealtimeClient({this.connectCompleter});

  final StreamController<RealtimeEvent> _controller =
      StreamController<RealtimeEvent>.broadcast();

  final Completer<void>? connectCompleter;
  int connectCalls = 0;
  int disconnectCalls = 0;

  @override
  Stream<RealtimeEvent> get events => _controller.stream;

  @override
  Future<void> connect() async {
    connectCalls++;
    final completer = connectCompleter;
    if (completer != null && !completer.isCompleted) {
      await completer.future;
    }
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls++;
  }

  void emit(RealtimeEvent event) {
    _controller.add(event);
  }

  void dispose() {
    unawaited(_controller.close());
  }
}

String generationHistoryPageKey(String? status, String? cursor) =>
    '${status ?? 'all'}|${cursor ?? ''}';

String _pageKey(String? status, String? cursor) =>
    generationHistoryPageKey(status, cursor);

TemplateGenerationResult generationFixture({
  required String generationId,
  required TemplateGenerationStatus status,
  String stage = 'queued',
  int progressPercent = 0,
  String? outputUrl,
  DateTime? completedAtUtc,
}) {
  final nowUtc = DateTime.utc(2026, 6, 14, 12);
  return TemplateGenerationResult(
    generationId: generationId,
    userId: 'user-1',
    templateId: 'template-1',
    status: status,
    tokenCost: 6,
    attemptCount: 1,
    createdAtUtc: nowUtc,
    updatedAtUtc: completedAtUtc ?? nowUtc,
    userMediaExpired: false,
    templateTitle: 'Magic Portrait',
    templateType: 'image',
    stage: stage,
    progressPercent: progressPercent,
    outputUrl: outputUrl,
    completedAtUtc: completedAtUtc,
    isUnread: true,
  );
}

Map<String, Object?> generationFixturePayload(
  TemplateGenerationResult generation,
) {
  return {
    'generationId': generation.generationId,
    'userId': generation.userId,
    'templateId': generation.templateId,
    'status': generation.status.name,
    'tokenCost': generation.tokenCost,
    'attemptCount': generation.attemptCount,
    'createdAtUtc': generation.createdAtUtc.toIso8601String(),
    'updatedAtUtc': generation.updatedAtUtc.toIso8601String(),
    'userMediaExpired': generation.userMediaExpired,
    'templateTitle': generation.templateTitle,
    'templateType': generation.templateType,
    'stage': generation.stage,
    'progressPercent': generation.progressPercent,
    'outputUrl': generation.outputUrl,
    'completedAtUtc': generation.completedAtUtc?.toIso8601String(),
    'isUnread': generation.isUnread,
  };
}

Map<String, Object?> generationRealtimePayload({
  required String generationId,
  String status = 'Completed',
}) {
  return {
    'eventType': 'generation.status_changed',
    'generationId': generationId,
    'status': status,
    'occurredAtUtc': DateTime.utc(2026, 6, 14, 12, 3).toIso8601String(),
    'requiresRefetch': true,
  };
}
