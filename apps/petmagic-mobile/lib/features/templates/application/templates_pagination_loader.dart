import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/features/templates/application/template_catalog_repository.dart';
import 'package:petmagic_mobile/features/templates/application/templates_feed_policy.dart';
import 'package:petmagic_mobile/features/templates/application/templates_feed_request_tracker.dart';
import 'package:petmagic_mobile/features/templates/application/templates_realtime_coordinator.dart';
import 'package:petmagic_mobile/features/templates/application/templates_state.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';

/// Appends cursor pages while rejecting stale filter and cursor responses.
final class TemplatesPaginationLoader {
  const TemplatesPaginationLoader({
    required this.repository,
    required this.readState,
    required this.writeState,
    required this.isMounted,
    required this.isScreenVisible,
    required this.requestTracker,
    required this.realtimeCoordinator,
  });

  final TemplatesRepository Function() repository;
  final TemplatesState Function() readState;
  final void Function(TemplatesState state) writeState;
  final bool Function() isMounted;
  final bool Function() isScreenVisible;
  final TemplatesFeedRequestTracker requestTracker;
  final TemplatesRealtimeCoordinator realtimeCoordinator;

  Future<void> loadMore() async {
    final current = readState();
    final cursor = current.nextCursor;
    if (current.isLoadingMore ||
        current.isLoading ||
        !current.hasMore ||
        cursor == null ||
        cursor.trim().isEmpty) {
      return;
    }

    final requestVersion = requestTracker.requestVersion;
    final queryKey = current.query.copyWith(resetPage: true).cacheKey;
    final query = current.query.copyWith(
      page: current.currentPage + 1,
      cursor: cursor,
    );
    writeState(current.copyWith(isLoadingMore: true, clearError: true));

    try {
      final page = await repository().fetchFeed(query);
      if (!_isCurrent(requestVersion) || !_isCurrentQuery(queryKey, cursor)) {
        _recordStale(requestVersion, 'fetch_feed_pagination');
        return;
      }

      final latest = readState();
      final existingIds = latest.items.map((item) => item.templateId).toSet();
      final mergedItems = [
        ...latest.items,
        ...page.items.where((item) => !existingIds.contains(item.templateId)),
      ];
      final hasAdvancedCursor =
          page.nextCursor != null && page.nextCursor != cursor;
      final hasMore = page.hasMore && hasAdvancedCursor;
      final cachedPage = TemplatesFeedPage(
        items: mergedItems,
        nextCursor: page.nextCursor,
        hasMore: hasMore,
        page: page.page,
      );
      final updatedCache = TemplatesFeedPolicy.rememberPage(
        latest.cachedPagesByQueryKey,
        queryKey,
        cachedPage,
      );
      writeState(
        latest.copyWith(
          items: mergedItems,
          currentPage: page.page,
          nextCursor: page.nextCursor,
          clearNextCursor: page.nextCursor == null,
          itemsQueryKey: queryKey,
          cachedPagesByQueryKey: updatedCache,
          hasMore: hasMore,
          isLoadingMore: false,
          clearError: true,
        ),
      );
    } on RequestCancelledException {
      _finishCancelled(requestVersion, 'fetch_feed_pagination_cancelled');
    } on AppException catch (error) {
      _finishError(
        requestVersion,
        'fetch_feed_pagination_app_error',
        error.message,
      );
    } catch (error) {
      _finishError(
        requestVersion,
        'fetch_feed_pagination_error',
        'templates.request_failed',
      );
    } finally {
      realtimeCoordinator.resumePendingRefreshIfNeeded();
    }
  }

  bool _isCurrentQuery(String queryKey, String cursor) {
    final state = readState();
    return state.query.copyWith(resetPage: true).cacheKey == queryKey &&
        state.itemsQueryKey == queryKey &&
        state.nextCursor == cursor;
  }

  void _finishCancelled(int requestVersion, String operation) {
    if (!_isCurrent(requestVersion)) {
      _recordStale(requestVersion, operation);
      return;
    }
    writeState(readState().copyWith(isLoadingMore: false));
  }

  void _finishError(int requestVersion, String operation, String message) {
    if (!_isCurrent(requestVersion)) {
      _recordStale(requestVersion, operation);
      return;
    }
    writeState(
      readState().copyWith(isLoadingMore: false, errorMessage: message),
    );
  }

  bool _isCurrent(int version) => requestTracker.isCurrent(
    requestVersion: version,
    isMounted: isMounted(),
    isScreenVisible: isScreenVisible(),
  );

  void _recordStale(int version, String operation) {
    requestTracker.recordStale(requestVersion: version, operation: operation);
  }
}
