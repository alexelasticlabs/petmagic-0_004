part of 'template_preview_page.dart';

class _TemplatePreviewPageState extends ConsumerState<TemplatePreviewPage> {
  static const _pageAnimationDuration = Duration(milliseconds: 280);
  static const _contentAnimationDuration = Duration(milliseconds: 180);
  static const _thumbnailExtent = 64.0;
  static const _thumbnailSpacing = 6.0;

  late final TemplatePreviewSession _session;
  late final PageController _pageController;
  final ScrollController _thumbnailController = ScrollController();
  final Map<String, Future<TemplateItem?>> _detailRequests = {};
  final Set<String> _detailResolvedIds = {};
  final Set<String> _detailAttemptedIds = {};

  late List<TemplateItem> _items;
  late int _selectedIndex;
  late int _mediaIndex;
  int? _candidateIndex;
  int _selectionDirection = 1;
  bool _isPageSettling = false;
  bool _isResolvingAction = false;
  bool _isOpeningDetails = false;
  bool _isDetailsOpen = false;
  bool _isUnlockingPremium = false;
  bool _isLoadingMore = false;
  bool _paginationFailed = false;
  bool _paginationExhausted = false;
  bool _isClosing = false;
  bool _reduceMotion = false;

  TemplateItem get _selectedTemplate => _items[_selectedIndex];

  void _setViewerState(VoidCallback update) => setState(update);

  @override
  void initState() {
    super.initState();
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
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final mediaQuery = MediaQuery.of(context);
    _reduceMotion =
        mediaQuery.disableAnimations || mediaQuery.accessibleNavigation;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _thumbnailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                physics:
                    _items.length > 1 &&
                        !_isResolvingAction &&
                        !_isOpeningDetails
                    ? const BouncingScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                itemCount: _items.length,
                onPageChanged: _handleVisiblePageChanged,
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return KeyedSubtree(
                    key: ValueKey('template-preview-page:${item.templateId}'),
                    child: TemplateMediaFrame(
                      template: item,
                      expand: true,
                      isActive:
                          index == _mediaIndex &&
                          !_isOpeningDetails &&
                          !_isDetailsOpen,
                      autoplay: !_reduceMotion,
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
                        const Spacer(),
                        _TemplatePreviewIconButton(
                          key: const ValueKey('template-preview-details'),
                          icon: Icons.info_outline_rounded,
                          tooltip: AppLocalizations.of(
                            context,
                          ).templateFlowCheckDetailsSubtitle,
                          isLoading: _isOpeningDetails,
                          onPressed: _isInteractionLocked ? null : _showDetails,
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (_items.length > 1 ||
                        _isLoadingMore ||
                        _paginationFailed) ...[
                      _buildThumbnailRail(colors),
                      const SizedBox(height: 14),
                    ],
                    _TemplatePreviewSummary(
                      template: template,
                      isPremiumLocked: isPremiumLocked,
                      reduceMotion: _reduceMotion,
                      direction: _selectionDirection,
                    ),
                    const SizedBox(height: 16),
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

  Widget _buildThumbnailRail(PetMagicColors colors) {
    return SizedBox(
      height: 82,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final edgePadding = ((constraints.maxWidth - _thumbnailExtent) / 2)
              .clamp(4.0, double.infinity)
              .toDouble();
          return ListView.separated(
            key: const ValueKey('template-preview-thumbnail-rail'),
            controller: _thumbnailController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: edgePadding),
            itemCount:
                _items.length + (_isLoadingMore || _paginationFailed ? 1 : 0),
            separatorBuilder: (_, _) =>
                const SizedBox(width: _thumbnailSpacing),
            itemBuilder: (context, index) {
              if (index == _items.length) {
                return SizedBox(
                  width: _thumbnailExtent,
                  child: _TemplatePreviewPaginationStatus(
                    isLoading: _isLoadingMore,
                    onRetry: _retryPagination,
                  ),
                );
              }
              final template = _items[index];
              final selected = index == _selectedIndex;
              final text = AppLocalizations.of(context);
              return SizedBox(
                width: _thumbnailExtent,
                child: Semantics(
                  button: true,
                  selected: selected,
                  enabled: !_isInteractionLocked,
                  label: template.title,
                  hint: template.isVideo ? text.videoLabel : text.imageLabel,
                  value: '${index + 1} / ${_items.length}',
                  onTap: _isInteractionLocked
                      ? null
                      : () => _selectThumbnail(index),
                  child: ExcludeSemantics(
                    child: GestureDetector(
                      key: ValueKey(
                        'template-preview-thumbnail:${template.templateId}',
                      ),
                      behavior: HitTestBehavior.opaque,
                      onTap: _isInteractionLocked
                          ? null
                          : () => _selectThumbnail(index),
                      child: AnimatedBuilder(
                        animation: _pageController,
                        builder: (context, child) {
                          final emphasis = _thumbnailEmphasis(index);
                          final borderColor = Color.lerp(
                            Colors.white.withValues(alpha: 0.28),
                            colors.accent,
                            emphasis,
                          )!;
                          return Transform.scale(
                            scale: 0.9 + (0.1 * emphasis),
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 3),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: borderColor,
                                  width: 1 + (1.2 * emphasis),
                                ),
                                boxShadow: emphasis <= 0.01
                                    ? null
                                    : [
                                        BoxShadow(
                                          color: colors.accent.withValues(
                                            alpha: 0.26 * emphasis,
                                          ),
                                          blurRadius: 4 + (8 * emphasis),
                                          offset: Offset(0, 2 + (3 * emphasis)),
                                        ),
                                      ],
                              ),
                              child: child,
                            ),
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(13),
                          child: _TemplatePreviewThumbnail(template: template),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPrimaryAction({
    required TemplateItem template,
    required bool isPremiumLocked,
  }) {
    final text = AppLocalizations.of(context);
    final label = isPremiumLocked
        ? text.templateUnlockPremiumAction
        : template.isVideo
        ? text.templateDetailUploadPhotoForVideoAction
        : text.templateFlowUploadPetPhotoAction;

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        key: const ValueKey('template-preview-cta'),
        onPressed: _isInteractionLocked ? null : _completeWithSelectedTemplate,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        icon: AnimatedSwitcher(
          duration: _reduceMotion ? Duration.zero : _contentAnimationDuration,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeIn,
          child: _isResolvingAction
              ? const SizedBox.square(
                  key: ValueKey('template-preview-cta-loading'),
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  isPremiumLocked
                      ? Icons.workspace_premium_rounded
                      : Icons.add_photo_alternate_outlined,
                  key: ValueKey(
                    'template-preview-cta-icon:${template.templateId}',
                  ),
                ),
        ),
        label: AnimatedSwitcher(
          duration: _reduceMotion ? Duration.zero : _contentAnimationDuration,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: Offset(0.025 * _selectionDirection, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: Text(
            label,
            key: ValueKey('template-preview-cta-label:${template.templateId}'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  bool get _isInteractionLocked =>
      _isClosing ||
      _isPageSettling ||
      _isResolvingAction ||
      _isOpeningDetails ||
      _isUnlockingPremium;

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
    if (notification.metrics.axis != Axis.horizontal) {
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
      _pageController.animateToPage(
        index,
        duration: _pageAnimationDuration,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  void _commitSelection(int index) {
    if (!mounted || index < 0 || index >= _items.length) {
      return;
    }
    _candidateIndex = null;
    if (index == _selectedIndex) {
      if (_isPageSettling) {
        setState(() => _isPageSettling = false);
      }
      return;
    }
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
