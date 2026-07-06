part of 'templates_page.dart';

extension _TemplatesPageLifecycle on _TemplatesPageState {
  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final now = DateTime.now();
    final previousAt = _lastScrollSampleAt;
    final previousOffset = _lastScrollSampleOffset;
    if (previousAt != null && previousOffset != null) {
      final elapsedSeconds =
          now.difference(previousAt).inMicroseconds /
          Duration.microsecondsPerSecond;
      if (elapsedSeconds > 0) {
        final velocity = (position.pixels - previousOffset) / elapsedSeconds;
        ref
            .read(templateFeedPlaybackManagerProvider)
            .updateScrollVelocity(velocity);
      }
    }
    _lastScrollSampleAt = now;
    _lastScrollSampleOffset = position.pixels;

    if (position.pixels > position.maxScrollExtent - 720) {
      ref.read(templatesControllerProvider.notifier).loadMore();
    }
  }

  void _handleSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 360), () {
      _searchDebounce = null;
      if (!mounted) {
        return;
      }
      ref.read(templatesControllerProvider.notifier).setSearch(value);
    });
  }

  void _cancelPendingSearchDebounce() {
    _searchDebounce?.cancel();
    _searchDebounce = null;
  }

  void _syncSearchFieldWithQuery(String? search) {
    if (_searchDebounce?.isActive == true) {
      return;
    }

    final nextText = search ?? '';
    if (_searchController.text == nextText) {
      return;
    }

    _searchController.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextText.length),
    );
  }

  Future<void> _refreshFeed({bool forceRefresh = false}) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _lastRefreshAt != null &&
        now.difference(_lastRefreshAt!) <
            _TemplatesPageState._refreshCooldown) {
      return;
    }

    _lastRefreshAt = now;
    await ref
        .read(templatesControllerProvider.notifier)
        .loadInitial(forceRefresh: forceRefresh);
  }
}
