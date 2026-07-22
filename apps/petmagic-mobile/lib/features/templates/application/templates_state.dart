import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/domain/templates_query.dart';

const Object _templateOfTheDayUnchanged = Object();

final class TemplatesState {
  const TemplatesState({
    this.items = const [],
    this.categories = const [],
    this.query = const TemplatesQuery(),
    this.catalogVersion = 0,
    this.currentPage = 1,
    this.nextCursor,
    this.itemsQueryKey,
    this.cachedPagesByQueryKey = const {},
    this.hasMore = true,
    this.isLoading = false,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.loadedFromCache = false,
    this.templateOfTheDay,
    this.isTemplateOfTheDayLoading = false,
    this.templateOfTheDayError,
    this.errorMessage,
  });

  final List<TemplateItem> items;
  final List<String> categories;
  final TemplatesQuery query;
  final int catalogVersion;
  final int currentPage;
  final String? nextCursor;
  final String? itemsQueryKey;
  final Map<String, TemplatesFeedPage> cachedPagesByQueryKey;
  final bool hasMore;
  final bool isLoading;
  final bool isRefreshing;
  final bool isLoadingMore;
  final bool loadedFromCache;
  final TemplateOfTheDayItem? templateOfTheDay;
  final bool isTemplateOfTheDayLoading;
  final String? templateOfTheDayError;
  final String? errorMessage;

  bool get isInitialLoading => isLoading && items.isEmpty;
  bool get isEmpty =>
      !isLoading && !isRefreshing && items.isEmpty && errorMessage == null;

  TemplatesState copyWith({
    List<TemplateItem>? items,
    List<String>? categories,
    TemplatesQuery? query,
    int? catalogVersion,
    int? currentPage,
    String? nextCursor,
    bool clearNextCursor = false,
    String? itemsQueryKey,
    bool clearItemsQueryKey = false,
    Map<String, TemplatesFeedPage>? cachedPagesByQueryKey,
    bool? hasMore,
    bool? isLoading,
    bool? isRefreshing,
    bool? isLoadingMore,
    bool? loadedFromCache,
    Object? templateOfTheDay = _templateOfTheDayUnchanged,
    bool? isTemplateOfTheDayLoading,
    String? templateOfTheDayError,
    bool clearTemplateOfTheDayError = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TemplatesState(
      items: items ?? this.items,
      categories: categories ?? this.categories,
      query: query ?? this.query,
      catalogVersion: catalogVersion ?? this.catalogVersion,
      currentPage: currentPage ?? this.currentPage,
      nextCursor: clearNextCursor ? null : nextCursor ?? this.nextCursor,
      itemsQueryKey: clearItemsQueryKey
          ? null
          : itemsQueryKey ?? this.itemsQueryKey,
      cachedPagesByQueryKey:
          cachedPagesByQueryKey ?? this.cachedPagesByQueryKey,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadedFromCache: loadedFromCache ?? this.loadedFromCache,
      templateOfTheDay: identical(templateOfTheDay, _templateOfTheDayUnchanged)
          ? this.templateOfTheDay
          : templateOfTheDay as TemplateOfTheDayItem?,
      isTemplateOfTheDayLoading:
          isTemplateOfTheDayLoading ?? this.isTemplateOfTheDayLoading,
      templateOfTheDayError: clearTemplateOfTheDayError
          ? null
          : templateOfTheDayError ?? this.templateOfTheDayError,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
