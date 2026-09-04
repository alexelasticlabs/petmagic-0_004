import 'package:petmagic_mobile/features/templates/application/templates_feed_policy.dart';
import 'package:petmagic_mobile/features/templates/application/templates_state.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/domain/templates_query.dart';

/// Produces the deterministic loading state for catalog filter changes.
abstract final class TemplatesFilterReducer {
  static TemplatesState? forRouteEntry(
    TemplatesState state, {
    String? category,
  }) {
    final normalizedCategory = TemplatesFeedPolicy.normalizeCategory(category);
    final currentQuery = state.query;
    if (currentQuery.type == null &&
        currentQuery.category == normalizedCategory &&
        currentQuery.search == null &&
        currentQuery.cursor == null &&
        currentQuery.page == 1) {
      return null;
    }

    return _reset(
      state,
      TemplatesQuery(
        category: normalizedCategory,
        pageSize: currentQuery.normalizedPageSize,
      ),
    );
  }

  static TemplatesState? forType(TemplatesState state, TemplateType? type) {
    if (state.query.type == type) return null;
    return _reset(
      state,
      state.query.copyWith(
        type: type,
        clearType: type == null,
        clearCursor: true,
        resetPage: true,
      ),
    );
  }

  static TemplatesState? forCategory(TemplatesState state, String? category) {
    final normalized = TemplatesFeedPolicy.normalizeCategory(category);
    if (state.query.category == normalized) return null;
    return _reset(
      state,
      state.query.copyWith(
        category: normalized,
        clearCategory: normalized == null,
        clearCursor: true,
        resetPage: true,
      ),
    );
  }

  static TemplatesState? forSearch(TemplatesState state, String value) {
    final normalized = value.trim();
    final search = normalized.isEmpty ? null : normalized;
    if (state.query.search == search) return null;
    return _reset(
      state,
      state.query.copyWith(
        search: search,
        clearSearch: search == null,
        clearCursor: true,
        resetPage: true,
      ),
    );
  }

  static TemplatesState _reset(TemplatesState state, TemplatesQuery query) {
    return state.copyWith(
      query: query,
      currentPage: 1,
      items: const [],
      clearItemsQueryKey: true,
      clearNextCursor: true,
      hasMore: true,
      isLoading: true,
      isRefreshing: false,
      isLoadingMore: false,
      clearError: true,
    );
  }
}
