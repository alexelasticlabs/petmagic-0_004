import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/realtime/realtime_client.dart';
import 'package:petmagic_mobile/features/templates/data/templates_query.dart';
import 'package:petmagic_mobile/features/templates/data/templates_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';

final templatesControllerProvider =
    NotifierProvider<TemplatesController, TemplatesState>(
      TemplatesController.new,
    );

class TemplatesState {
  const TemplatesState({
    this.items = const [],
    this.categories = const [],
    this.query = const TemplatesQuery(),
    this.nextCursor,
    this.hasMore = true,
    this.isLoading = false,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.loadedFromCache = false,
    this.errorMessage,
  });

  final List<TemplateItem> items;
  final List<String> categories;
  final TemplatesQuery query;
  final String? nextCursor;
  final bool hasMore;
  final bool isLoading;
  final bool isRefreshing;
  final bool isLoadingMore;
  final bool loadedFromCache;
  final String? errorMessage;

  bool get isInitialLoading => isLoading && items.isEmpty;
  bool get isEmpty =>
      !isLoading && !isRefreshing && items.isEmpty && errorMessage == null;

  TemplatesState copyWith({
    List<TemplateItem>? items,
    List<String>? categories,
    TemplatesQuery? query,
    String? nextCursor,
    bool clearNextCursor = false,
    bool? hasMore,
    bool? isLoading,
    bool? isRefreshing,
    bool? isLoadingMore,
    bool? loadedFromCache,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TemplatesState(
      items: items ?? this.items,
      categories: categories ?? this.categories,
      query: query ?? this.query,
      nextCursor: clearNextCursor ? null : nextCursor ?? this.nextCursor,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadedFromCache: loadedFromCache ?? this.loadedFromCache,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class TemplatesController extends Notifier<TemplatesState> {
  late final TemplatesRepository _repository;
  late final RealtimeClient _realtimeClient;
  int _requestVersion = 0;

  @override
  TemplatesState build() {
    _repository = ref.watch(templatesRepositoryProvider);
    _realtimeClient = ref.watch(realtimeClientProvider);
    _realtimeClient.connect();
    ref.onDispose(() => _realtimeClient.disconnect());
    return const TemplatesState();
  }

  Future<void> loadInitial({bool forceRefresh = false}) async {
    final requestVersion = ++_requestVersion;
    final query = state.query.copyWith(clearCursor: true);

    state = state.copyWith(
      query: query,
      isLoading: !forceRefresh,
      isRefreshing: forceRefresh,
      clearError: true,
      clearNextCursor: true,
      hasMore: true,
    );

    if (!forceRefresh) {
      final cached = await _repository.readCachedFirstPage(query);
      if (cached != null && requestVersion == _requestVersion) {
        state = state.copyWith(
          items: cached.items,
          nextCursor: cached.nextCursor,
          hasMore: cached.hasMore,
          loadedFromCache: true,
          isLoading: false,
        );
      }
    }

    try {
      if (state.categories.isEmpty || forceRefresh) {
        final categories = await _repository.fetchCategories();
        if (requestVersion == _requestVersion) {
          state = state.copyWith(categories: categories);
        }
      }

      final page = await _repository.fetchFeed(query);
      if (requestVersion != _requestVersion) return;
      state = state.copyWith(
        items: page.items,
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
        loadedFromCache: false,
        isLoading: false,
        isRefreshing: false,
        clearError: true,
      );
    } catch (error) {
      if (requestVersion != _requestVersion) return;
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore ||
        state.isLoading ||
        !state.hasMore ||
        state.nextCursor == null) {
      return;
    }

    final requestVersion = _requestVersion;
    final query = state.query.copyWith(cursor: state.nextCursor);
    state = state.copyWith(isLoadingMore: true, clearError: true);

    try {
      final page = await _repository.fetchFeed(query);
      if (requestVersion != _requestVersion) {
        return;
      }

      final existingIds = state.items.map((item) => item.templateId).toSet();
      final appended = page.items.where(
        (item) => !existingIds.contains(item.templateId),
      );

      state = state.copyWith(
        items: [...state.items, ...appended],
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
        isLoadingMore: false,
        clearError: true,
      );
    } catch (error) {
      if (requestVersion != _requestVersion) {
        return;
      }

      state = state.copyWith(
        isLoadingMore: false,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> refresh() => loadInitial(forceRefresh: true);

  void setType(TemplateType? type) {
    state = state.copyWith(
      query: state.query.copyWith(
        type: type,
        clearType: type == null,
        clearCursor: true,
      ),
      clearNextCursor: true,
    );
    loadInitial();
  }

  void setCategory(String? category) {
    final normalized = category?.trim();
    state = state.copyWith(
      query: state.query.copyWith(
        category: normalized,
        clearCategory: normalized == null || normalized.isEmpty,
        clearCursor: true,
      ),
      clearNextCursor: true,
    );
    loadInitial();
  }

  void setSearch(String value) {
    final normalized = value.trim();
    state = state.copyWith(
      query: state.query.copyWith(
        search: normalized.isEmpty ? null : normalized,
        clearSearch: normalized.isEmpty,
        clearCursor: true,
      ),
      clearNextCursor: true,
    );
    loadInitial();
  }
}
