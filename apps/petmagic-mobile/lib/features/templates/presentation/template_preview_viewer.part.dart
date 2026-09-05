part of 'template_preview_page.dart';

class _TemplatePreviewPageState extends ConsumerState<TemplatePreviewPage>
    with WidgetsBindingObserver {
  static const _pageAnimationDuration = Duration(milliseconds: 460);
  static const _contentAnimationDuration = Duration(milliseconds: 320);
  static const _thumbnailExtent = 62.0;
  static const _thumbnailSpacing = 8.0;

  late final TemplatePreviewSession _session;
  late final PageController _pageController;
  final ScrollController _thumbnailController = ScrollController();
  final ScrollController _informationController = ScrollController(
    keepScrollOffset: false,
  );
  final Map<String, Future<TemplateItem?>> _detailRequests = {};
  final Set<String> _detailResolvedIds = {};
  final Set<String> _detailAttemptedIds = {};
  late final TemplatePreviewPrefetcher _prefetcher;
  final TemplatePreviewPlaybackRegistry _playbackRegistry =
      TemplatePreviewPlaybackRegistry();
  bool _isAppResumed = true;
  bool _isRouteVisible = false;

  late List<TemplateItem> _items;
  late int _selectedIndex;
  late int _mediaIndex;
  int? _candidateIndex;
  int _selectionDirection = 1;
  bool _isPageSettling = false;
  bool _isResolvingAction = false;
  bool _isDetailsOpen = false;
  bool _isUnlockingPremium = false;
  bool _isLoadingMore = false;
  bool _paginationFailed = false;
  bool _paginationExhausted = false;
  bool _isClosing = false;
  bool _reduceMotion = false;
  double? _informationDragDistance;
  bool _isMuted = false;

  TemplateItem get _selectedTemplate => _items[_selectedIndex];

  void _setViewerState(VoidCallback update) => setState(update);

  @override
  void initState() {
    super.initState();
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    _isAppResumed =
        lifecycleState == null || lifecycleState == AppLifecycleState.resumed;
    _prefetcher = TemplatePreviewPrefetcher(
      canPrefetch: () => _canPrefetchPreview,
      policy: () => _previewPrefetchPolicy,
      onReady: () {
        if (mounted && _canPrefetchPreview) setState(() {});
      },
    );
    WidgetsBinding.instance.addObserver(this);
    _session = widget.session ?? TemplatePreviewSession.single(widget.template);
    _items = List<TemplateItem>.of(_session.items);
    _selectedIndex = _session.initialIndex;
    _mediaIndex = _selectedIndex;
    if (_session.initialDetailResolved) {
      _detailResolvedIds.add(_selectedTemplate.templateId);
    }
    _pageController = PageController(initialPage: _selectedIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _ensureSelectedThumbnailVisible(animate: false);
      unawaited(_resolveTemplateDetails(_selectedIndex));
      unawaited(_loadMoreIfNeeded(_selectedIndex));
      _schedulePreviewPrefetch();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final mediaQuery = MediaQuery.of(context);
    _reduceMotion = mediaQuery.disableAnimations;
    _isRouteVisible =
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.isCurrentOf(context) ?? true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _schedulePreviewPrefetch();
    });
  }

  bool get _canPrefetchPreview {
    if (!mounted || !_isAppResumed || !_isRouteVisible || _isClosing) {
      return false;
    }
    final network = ref.read(networkStatusControllerProvider);
    return network.hasInternet;
  }

  TemplatePreviewPrefetchPolicy get _previewPrefetchPolicy {
    final network = ref.read(networkStatusControllerProvider);
    if (!network.hasInternet) return TemplatePreviewPrefetchPolicy.disabled;
    return switch (network.transport) {
      NetworkTransportKind.wifi ||
      NetworkTransportKind.ethernet => TemplatePreviewPrefetchPolicy.wifi,
      NetworkTransportKind.cellular => TemplatePreviewPrefetchPolicy.cellular,
      _ => TemplatePreviewPrefetchPolicy.disabled,
    };
  }

  void _schedulePreviewPrefetch() {
    _prefetcher.schedule(
      _items,
      _selectedIndex,
      direction: _selectionDirection,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppResumed = state == AppLifecycleState.resumed;
    if (_isAppResumed) {
      _schedulePreviewPrefetch();
    } else {
      _prefetcher.cancelPending();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _prefetcher.dispose();
    _playbackRegistry.dispose();
    _pageController.dispose();
    _thumbnailController.dispose();
    _informationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preferLowResolution = ref.watch(
      networkStatusControllerProvider.select(
        (network) =>
            network.transport != NetworkTransportKind.wifi &&
            network.transport != NetworkTransportKind.ethernet,
      ),
    );
    ref.listen(networkStatusControllerProvider, (_, _) {
      _schedulePreviewPrefetch();
    });
    final livePremiumAccess =
        widget.hasPremiumAccess || ref.watch(templatePremiumAccessProvider);
    final template = _selectedTemplate;
    final isPremiumLocked = template.isPremium && !livePremiumAccess;
    final colors = context.petMagicColors;

    return PopScope<Object?>(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _isClosing = true;
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: _handlePageScrollNotification,
              child: PageView.builder(
                key: const ValueKey('template-preview-page-view'),
                controller: _pageController,
                allowImplicitScrolling: true,
                physics: _items.length > 1 && !_isResolvingAction
                    ? const BouncingScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                itemCount: _items.length,
                onPageChanged: _handleVisiblePageChanged,
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return KeyedSubtree(
                    key: ValueKey('template-preview-page:${item.templateId}'),
                    child: AnimatedBuilder(
                      animation: _pageController,
                      builder: (context, child) {
                        final offset =
                            _reduceMotion || !_pageController.hasClients
                            ? 0.0
                            : ((_pageController.page ??
                                          _selectedIndex.toDouble()) -
                                      index)
                                  .clamp(-1.0, 1.0);
                        final distance = offset.abs();
                        return ClipRect(
                          child: Transform.translate(
                            offset: Offset(
                              offset * MediaQuery.sizeOf(context).width * 0.1,
                              0,
                            ),
                            child: Transform.scale(
                              scale: 1 + 0.22 * distance,
                              child: Opacity(
                                opacity: 1 - 0.24 * distance,
                                child: child,
                              ),
                            ),
                          ),
                        );
                      },
                      child: RepaintBoundary(
                        child: TemplateMediaFrame(
                          template: item,
                          expand: true,
                          immersive: true,
                          preferLowResolution: preferLowResolution,
                          muted: _isMuted,
                          onMutedChanged: (muted) =>
                              setState(() => _isMuted = muted),
                          isActive: index == _mediaIndex && _canPresentMedia,
                          playWhenActive: true,
                          allowDetailUpgrade: !_isPageSettling,
                          playbackRegistry: _playbackRegistry,
                          prepareOffscreen:
                              _canPresentMedia &&
                              (index - _selectedIndex).abs() <= 1,
                          autoplay: true,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const IgnorePointer(child: _TemplatePreviewScrim()),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _TemplatePreviewIconButton(
                          key: const ValueKey('template-preview-back'),
                          icon: Icons.arrow_back_rounded,
                          tooltip: MaterialLocalizations.of(
                            context,
                          ).backButtonTooltip,
                          onPressed: _isClosing ? null : _closeViewer,
                        ),
                        if (template.isPremium) ...[
                          const SizedBox(width: 10),
                          Flexible(
                            child: _TemplatePreviewPremiumBadge(
                              isLocked: isPremiumLocked,
                            ),
                          ),
                          if (template.detailPreviewIsVideo)
                            const SizedBox(width: 110),
                        ],
                      ],
                    ),
                    Expanded(child: _buildInformationPanel(template, colors)),
                    const SizedBox(height: 8),
                    _buildPrimaryAction(
                      template: template,
                      isPremiumLocked: isPremiumLocked,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _isInteractionLocked =>
      _isClosing ||
      _isPageSettling ||
      _isResolvingAction ||
      _isUnlockingPremium;

  bool get _canPresentMedia =>
      _isAppResumed && _isRouteVisible && !_isDetailsOpen && !_isClosing;

  bool get _canContinueViewerAction {
    if (!mounted || _isClosing) {
      return false;
    }
    final route = ModalRoute.of(context);
    return route == null || route.isCurrent;
  }

  Future<void> _closeViewer() async {
    if (_isClosing) {
      return;
    }
    setState(() => _isClosing = true);
    final didPop = await Navigator.of(context).maybePop();
    if (mounted && !didPop) {
      setState(() => _isClosing = false);
    }
  }

  double _thumbnailEmphasis(int index) {
    final page = _pageController.hasClients
        ? _pageController.page
        : _selectedIndex.toDouble();
    if (page == null || !page.isFinite) {
      return index == _selectedIndex ? 1 : 0;
    }
    return (1 - (page - index).abs()).clamp(0.0, 1.0).toDouble();
  }

  void _handleVisiblePageChanged(int index) {
    if (!mounted || index < 0 || index >= _items.length) {
      return;
    }
    setState(() {
      _candidateIndex = index;
      _mediaIndex = index;
      _isPageSettling = true;
    });
  }

  bool _handlePageScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0 ||
        notification.metrics.axis != Axis.horizontal) {
      return false;
    }
    if (notification is ScrollStartNotification) {
      if (!_isPageSettling && mounted) {
        setState(() => _isPageSettling = true);
      }
      return false;
    }
    if (notification is! ScrollEndNotification) {
      return false;
    }
    final page = _pageController.hasClients
        ? _pageController.page?.round()
        : null;
    _commitSelection(page ?? _candidateIndex ?? _selectedIndex);
    return false;
  }

  void _selectThumbnail(int index) {
    if (index == _selectedIndex || !_pageController.hasClients) {
      return;
    }
    setState(() {
      _candidateIndex = index;
      _isPageSettling = true;
    });
    if (_reduceMotion) {
      _pageController.jumpToPage(index);
      _commitSelection(index);
      return;
    }
    unawaited(
      _pageController
          .animateToPage(
            index,
            duration: _pageAnimationDuration,
            curve: Curves.easeOutCubic,
          )
          .whenComplete(_reconcilePageSelection),
    );
  }

  void _reconcilePageSelection() {
    if (!mounted ||
        !_pageController.hasClients ||
        _pageController.position.isScrollingNotifier.value) {
      return;
    }
    _commitSelection(_pageController.page?.round() ?? _selectedIndex);
  }

  void _commitSelection(int index) {
    if (!mounted || index < 0 || index >= _items.length) {
      return;
    }
    _candidateIndex = null;
    if (index == _selectedIndex) {
      if (_isPageSettling || _mediaIndex != index) {
        setState(() {
          _mediaIndex = index;
          _isPageSettling = false;
        });
      }
      return;
    }
    if (_informationController.hasClients) _informationController.jumpTo(0);
    setState(() {
      _selectionDirection = index > _selectedIndex ? 1 : -1;
      _selectedIndex = index;
      _mediaIndex = index;
      _isPageSettling = false;
    });
    unawaited(HapticFeedback.selectionClick());
    _ensureSelectedThumbnailVisible();
    unawaited(_resolveTemplateDetails(index));
    unawaited(_loadMoreIfNeeded(index));
    _schedulePreviewPrefetch();
  }

  void _ensureSelectedThumbnailVisible({bool animate = true}) {
    if (!_thumbnailController.hasClients || _items.length <= 1) {
      return;
    }
    final position = _thumbnailController.position;
    final edgePadding = ((position.viewportDimension - _thumbnailExtent) / 2)
        .clamp(4.0, double.infinity)
        .toDouble();
    final itemCenter =
        edgePadding +
        _selectedIndex * (_thumbnailExtent + _thumbnailSpacing) +
        _thumbnailExtent / 2;
    final targetOffset = (itemCenter - position.viewportDimension / 2)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if ((targetOffset - position.pixels).abs() < 1) {
      return;
    }
    final duration = !animate || _reduceMotion
        ? Duration.zero
        : _pageAnimationDuration;
    if (duration == Duration.zero) {
      _thumbnailController.jumpTo(targetOffset);
      return;
    }
    unawaited(
      _thumbnailController.animateTo(
        targetOffset,
        duration: duration,
        curve: Curves.easeOutCubic,
      ),
    );
  }
}
