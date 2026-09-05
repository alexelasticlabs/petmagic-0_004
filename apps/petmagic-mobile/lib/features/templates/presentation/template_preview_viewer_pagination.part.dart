part of 'template_preview_page.dart';

extension _TemplatePreviewViewerPagination on _TemplatePreviewPageState {
  Future<void> _loadMoreIfNeeded(int index) async {
    final loadMore = _session.loadMore;
    if (loadMore == null ||
        _isLoadingMore ||
        _paginationExhausted ||
        index < _items.length - 3) {
      return;
    }

    _setViewerState(() {
      _isLoadingMore = true;
      _paginationFailed = false;
    });
    try {
      final batch = await loadMore();
      if (!mounted) {
        return;
      }
      final existingIds = _items.map((item) => item.templateId).toSet();
      final additions = batch.items
          .where((item) => existingIds.add(item.templateId))
          .toList(growable: false);
      _setViewerState(() {
        _items.addAll(additions);
        _paginationExhausted = !batch.hasMore;
        _paginationFailed = additions.isEmpty && batch.hasMore;
      });
    } catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'Templates.PreviewViewer',
        operation: 'load_more_templates',
        message: 'Template preview pagination failed; keeping current items.',
        context: {'source': _session.source.name},
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        _setViewerState(() => _paginationFailed = true);
      }
    } finally {
      if (mounted) {
        _setViewerState(() => _isLoadingMore = false);
      } else {
        _isLoadingMore = false;
      }
    }
  }

  void _retryPagination() {
    if (_isLoadingMore) {
      return;
    }
    unawaited(_loadMoreIfNeeded(_selectedIndex));
  }
}
