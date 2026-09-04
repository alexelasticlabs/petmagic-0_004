part of 'templates_page.dart';

extension _TemplatesPageLifecycle on _TemplatesPageState {
  void _scheduleRouteEntryUpdate({bool refreshIfVisible = false}) {
    _runAfterBuild(() {
      final filtersChanged = _applyRouteEntryFilters();
      _handleRouteEntryActions();
      if (refreshIfVisible &&
          filtersChanged &&
          _isTabActive == true &&
          _isAppResumed) {
        unawaited(_refreshFeed(forceRefresh: true));
      }
    });
  }

  bool _applyRouteEntryFilters() {
    _cancelPendingSearchDebounce();
    _searchController.clear();
    _lastRefreshAt = null;
    return ref
        .read(templatesControllerProvider.notifier)
        .applyRouteEntryFilters(category: widget.initialCategory);
  }

  void _handleRouteEntryActions() {
    if (widget.autofocusSearch && !_searchAutofocusHandled) {
      _searchAutofocusHandled = true;
      if (_searchFocusNode.canRequestFocus) {
        _searchFocusNode.requestFocus();
      }
    }

    final initialTemplate = widget.initialTemplate;
    if (initialTemplate == null || _initialTemplateHandled) {
      return;
    }

    _initialTemplateHandled = true;
    unawaited(_handleTemplateSelected(initialTemplate));
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final now = DateTime.now();
    _scrollIdleTimer?.cancel();
    _scrollIdleTimer = Timer(
      _TemplatesPageState._scrollIdleVelocityResetDelay,
      () {
        _scrollIdleTimer = null;
        if (_disposed || !mounted || !context.mounted) {
          return;
        }

        _lastScrollSampleAt = null;
        _lastScrollSampleOffset = null;
        ref.read(templateFeedPlaybackManagerProvider).updateScrollVelocity(0);
      },
    );
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
