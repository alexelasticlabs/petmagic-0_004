import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:petmagic_mobile/core/operations/request_cancellation.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/errors/auth_feedback_mapper.dart';
import 'package:petmagic_mobile/core/navigation/app_navigator.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/core/performance/performance_guard.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/shared/auth/auth_required_sheet.dart';
import 'package:petmagic_mobile/features/templates/application/template_generation_contract.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_status_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/mappers/generations_gallery_mappers.dart';
import 'package:petmagic_mobile/features/templates/presentation/mappers/generation_status_mappers.dart'
    show galleryMediaStateIcon, galleryMediaStateMessage, statusTitle;
import 'package:petmagic_mobile/features/templates/application/template_error_key_mapper.dart';
import 'package:petmagic_mobile/features/wallet/application/wallet_controller.dart';
import 'package:petmagic_mobile/shared/files/device_file_saver.dart';
import 'package:petmagic_mobile/shared/files/file_name_sanitizer.dart';
import 'package:petmagic_mobile/shared/files/media_share_save.dart';
import 'package:petmagic_mobile/shared/files/persistent_media_url.dart';
import 'package:petmagic_mobile/shared/navigation/external_url_policy.dart';
import 'package:petmagic_mobile/shared/navigation/app_navigation_context.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_navigation_layout.dart';
import 'package:petmagic_mobile/shared/widgets/motion.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_toast.dart';
import 'package:petmagic_mobile/shared/widgets/protected_auth_gate.dart';
import 'package:petmagic_mobile/shared/widgets/premium_banner_style.dart';
import 'package:petmagic_mobile/shared/widgets/premium_crown_icon.dart';
import 'package:petmagic_mobile/shared/widgets/premium_shimmer_button.dart';

part 'generations_gallery_page_cards.dart';
part 'generations_gallery_page_card_chrome.part.dart';
part 'generations_gallery_page_filters_and_chrome.dart';
part 'generations_gallery_page_states_and_actions.dart';

class GenerationsGalleryPage extends ConsumerStatefulWidget {
  const GenerationsGalleryPage({super.key});

  static const routePath = '/creations';

  @override
  ConsumerState<GenerationsGalleryPage> createState() =>
      _GenerationsGalleryPageState();
}

TemplatesDestination _templatesDestinationForGeneration(
  TemplateGenerationResult generation,
) {
  final petId = generation.petId?.trim();
  if (petId == null || petId.isEmpty) {
    return const TemplatesDestination();
  }

  final petPhotoId = generation.petPhotoId?.trim();
  return TemplatesDestination(petId: petId, petPhotoId: petPhotoId);
}

class _GalleryPageViewState {
  const _GalleryPageViewState({
    required this.items,
    required this.filter,
    required this.unreadCount,
    required this.isLoading,
    required this.isLoadingMore,
    required this.hasMore,
    required this.shouldShowOfflineBanner,
    required this.isConnectionRecovered,
    required this.loadMoreError,
    required this.lastSyncedAtUtc,
    required this.errorMessage,
    required this.cachedItemsByFilter,
  });

  factory _GalleryPageViewState.from(GenerationHistoryState state) {
    return _GalleryPageViewState(
      items: state.items,
      filter: state.filter,
      unreadCount: state.unreadCount,
      isLoading: state.isLoading,
      isLoadingMore: state.isLoadingMore,
      hasMore: state.hasMore,
      shouldShowOfflineBanner: state.shouldShowOfflineBanner,
      isConnectionRecovered: state.isConnectionRecovered,
      loadMoreError: state.loadMoreError,
      lastSyncedAtUtc: state.lastSyncedAtUtc,
      errorMessage: state.errorMessage,
      cachedItemsByFilter: state.cachedItemsByFilter,
    );
  }

  final List<TemplateGenerationResult> items;
  final GenerationHistoryFilter filter;
  final int unreadCount;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final bool shouldShowOfflineBanner;
  final bool isConnectionRecovered;
  final String? loadMoreError;
  final DateTime? lastSyncedAtUtc;
  final String? errorMessage;
  final Map<GenerationHistoryFilter, List<TemplateGenerationResult>>
  cachedItemsByFilter;

  @override
  bool operator ==(Object other) {
    return other is _GalleryPageViewState &&
        identical(items, other.items) &&
        filter == other.filter &&
        unreadCount == other.unreadCount &&
        isLoading == other.isLoading &&
        isLoadingMore == other.isLoadingMore &&
        hasMore == other.hasMore &&
        shouldShowOfflineBanner == other.shouldShowOfflineBanner &&
        isConnectionRecovered == other.isConnectionRecovered &&
        loadMoreError == other.loadMoreError &&
        lastSyncedAtUtc == other.lastSyncedAtUtc &&
        errorMessage == other.errorMessage &&
        identical(cachedItemsByFilter, other.cachedItemsByFilter);
  }

  @override
  int get hashCode => Object.hash(
    identityHashCode(items),
    filter,
    unreadCount,
    isLoading,
    isLoadingMore,
    hasMore,
    shouldShowOfflineBanner,
    isConnectionRecovered,
    loadMoreError,
    lastSyncedAtUtc,
    errorMessage,
    identityHashCode(cachedItemsByFilter),
  );
}

class _GenerationsGalleryPageState extends ConsumerState<GenerationsGalleryPage>
    with WidgetsBindingObserver {
  bool _readyExpanded = false;
  bool _isMediaActionInFlight = false;
  bool _hasLoadedInitially = false;
  bool? _isTabActive;
  RequestCancellation? _activeMediaActionCancelToken;
  GenerationHistoryController? _visibleHistoryController;
  ProviderSubscription<GenerationHistoryState>? _historySubscription;
  bool _historyScreenVisible = false;

  @override
  void initState() {
    super.initState();
    _historySubscription = ref.listenManual<GenerationHistoryState>(
      generationHistoryControllerProvider,
      (_, _) => _syncVisibleHistoryController(),
    );
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() async {
      if (!mounted) {
        return;
      }

      _maybeLoadWalletForAuthenticatedUser();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTabVisibility(
      TickerMode.valuesOf(context).enabled,
      fromAppResume: false,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isAuthenticated = ref
        .read(appLaunchControllerProvider)
        .isAuthenticated;
    if (!isAuthenticated) {
      _setHistoryScreenVisible(false);
      return;
    }

    if (state == AppLifecycleState.resumed) {
      _syncTabVisibility(
        TickerMode.valuesOf(context).enabled,
        fromAppResume: true,
      );
      return;
    }

    _setHistoryScreenVisible(false);
  }

  @override
  void dispose() {
    _cancelActiveMediaAction();
    _historySubscription?.close();
    _setStoredHistoryScreenVisible(false, clearLoadingState: false);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<NetworkStatusState>(networkStatusControllerProvider, (
      previous,
      next,
    ) {
      if (previous?.hasInternet != false || !next.hasInternet) {
        return;
      }

      _maybeLoadWalletForAuthenticatedUser();
    });

    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final state = ref.watch(
      generationHistoryControllerProvider.select(_GalleryPageViewState.from),
    );
    final isAuthenticated = ref.watch(
      appLaunchControllerProvider.select((launch) => launch.isAuthenticated),
    );
    final hasPremiumAccess = ref.watch(
      walletControllerProvider.select(
        (walletState) => walletState.wallet?.isPremium,
      ),
    );
    final shouldShowPremiumUpsell =
        isAuthenticated && hasPremiumAccess == false;
    final filterCounts = _GalleryFilterCounts.fromState(state);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.backgroundTop, colors.backgroundBottom],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Stack(
            children: [
              RefreshIndicator.adaptive(
                color: colors.accent,
                onRefresh: () {
                  if (!isAuthenticated) {
                    return Future.value();
                  }

                  return ref
                      .read(generationHistoryControllerProvider.notifier)
                      .load(refresh: true);
                },
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    text.navCreations,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                          color: colors.textStrong,
                                          fontWeight: FontWeight.w900,
                                        ),
                                  ),
                                ),
                                if (state.unreadCount > 0)
                                  _UnreadPill(count: state.unreadCount),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              subtitleForFilter(text, state.filter),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: colors.textSoft,
                                    height: 1.35,
                                  ),
                            ),
                            const SizedBox(height: 14),
                            _FilterBar(
                              selected: state.filter,
                              counts: filterCounts,
                            ),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              child: shouldShowPremiumUpsell
                                  ? Padding(
                                      key: const ValueKey<String>(
                                        'gallery-premium-upsell',
                                      ),
                                      padding: const EdgeInsets.only(top: 12),
                                      child: _GalleryPremiumUpsellCard(
                                        onOpenPremium: _openPremiumUpsell,
                                      ),
                                    )
                                  : const SizedBox.shrink(
                                      key: ValueKey<String>(
                                        'gallery-premium-upsell-hidden',
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) {
                          final offsetAnimation = Tween<Offset>(
                            begin: const Offset(0, -0.08),
                            end: Offset.zero,
                          ).animate(animation);

                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: offsetAnimation,
                              child: child,
                            ),
                          );
                        },
                        child: state.shouldShowOfflineBanner
                            ? Padding(
                                key: ValueKey<String>(
                                  state.isConnectionRecovered
                                      ? 'gallery-banner-online'
                                      : 'gallery-banner-offline',
                                ),
                                padding: const EdgeInsets.fromLTRB(
                                  18,
                                  0,
                                  18,
                                  10,
                                ),
                                child: _OfflineCacheBanner(
                                  lastSyncedAtUtc: state.lastSyncedAtUtc,
                                  isRecovered: state.isConnectionRecovered,
                                ),
                              )
                            : const SizedBox.shrink(
                                key: ValueKey<String>('gallery-banner-hidden'),
                              ),
                      ),
                    ),
                    ..._buildContentSlivers(
                      context,
                      text,
                      state,
                      isAuthenticated: isAuthenticated,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildContentSlivers(
    BuildContext context,
    AppLocalizations text,
    _GalleryPageViewState state, {
    required bool isAuthenticated,
  }) {
    if (!isAuthenticated) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ProtectedAuthGate(
            subtitle: text.generationStatusEmptyMessage,
            onSignIn: () {
              unawaited(
                showAuthRequiredSheet(
                  context,
                  redirectPath: GenerationsGalleryPage.routePath,
                ),
              );
            },
          ),
        ),
      ];
    }

    final filteredItems = _itemsForSelectedFilter(state.items, state.filter);

    if (state.isLoading && filteredItems.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator.adaptive()),
        ),
      ];
    }
    if (state.errorMessage != null && filteredItems.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _ErrorState(message: state.errorMessage!),
        ),
      ];
    }
    if (filteredItems.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _EmptyState(filter: state.filter),
        ),
      ];
    }

    final bottomInset = petMagicBottomNavInset(context) + 22;

    if (state.filter == GenerationHistoryFilter.all) {
      final activeItems = state.items
          .where((item) => !item.isTerminal)
          .toList(growable: false);
      final readyItems = state.items
          .where((item) => item.isCompleted)
          .toList(growable: false);
      final failedItems = state.items
          .where((item) => item.isFailed)
          .toList(growable: false);

      final slivers = <Widget>[];
      if (activeItems.isNotEmpty) {
        slivers.add(
          _sectionHeaderSliver(
            text.generationStatusSectionActive,
            activeItems.length,
          ),
        );
        slivers.add(_activeListSliver(activeItems));
      }
      if (readyItems.isNotEmpty) {
        slivers.add(
          _sectionHeaderSliver(
            text.generationStatusSectionReady,
            readyItems.length,
          ),
        );
        slivers.add(_readyGridSliver(readyItems));
      }
      if (failedItems.isNotEmpty) {
        slivers.add(
          _sectionHeaderSliver(
            text.generationStatusSectionFailed,
            failedItems.length,
          ),
        );
        slivers.add(_failedListSliver(failedItems));
      }
      slivers.add(_paginationFooterSliver(state, bottomInset));
      return slivers;
    }

    if (state.filter == GenerationHistoryFilter.ready) {
      return [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
          sliver: SliverGrid.builder(
            itemCount: filteredItems.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.82,
            ),
            itemBuilder: (context, index) => _ReadyGridCard(
              generation: filteredItems[index],
              galleryState: this,
            ),
          ),
        ),
        _paginationFooterSliver(state, bottomInset),
      ];
    }

    if (state.filter == GenerationHistoryFilter.active) {
      return [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
          sliver: const SliverToBoxAdapter(child: _ActiveInfoCard()),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
          sliver: SliverList.separated(
            itemCount: filteredItems.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) =>
                _ActiveCard(generation: filteredItems[index]),
          ),
        ),
        _paginationFooterSliver(state, bottomInset),
      ];
    }

    if (state.filter == GenerationHistoryFilter.failed) {
      return [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
          sliver: SliverList.separated(
            itemCount: filteredItems.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) =>
                _FailedCard(generation: filteredItems[index]),
          ),
        ),
        _paginationFooterSliver(state, bottomInset),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
        sliver: SliverList.separated(
          itemCount: filteredItems.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final generation = filteredItems[index];
            if (generation.isFailed) {
              return _FailedCard(generation: generation);
            }
            return _ActiveCard(generation: generation);
          },
        ),
      ),
      _paginationFooterSliver(state, bottomInset),
    ];
  }

  List<TemplateGenerationResult> _itemsForSelectedFilter(
    List<TemplateGenerationResult> items,
    GenerationHistoryFilter filter,
  ) {
    return switch (filter) {
      GenerationHistoryFilter.all => items,
      GenerationHistoryFilter.active =>
        items.where((item) => !item.isTerminal).toList(growable: false),
      GenerationHistoryFilter.ready =>
        items.where((item) => item.isCompleted).toList(growable: false),
      GenerationHistoryFilter.failed =>
        items.where((item) => item.isFailed).toList(growable: false),
    };
  }

  Future<void> _openPremiumUpsell() async {
    if (ref.read(appLaunchControllerProvider).isAuthenticated) {
      await context.appNavigator.push(const PremiumDestination());
      return;
    }

    await showAuthRequiredSheet(
      context,
      redirectPath: const PremiumDestination().location,
    );
  }

  RequestCancellation? _startMediaAction() {
    if (!mounted || _activeMediaActionCancelToken != null) {
      return null;
    }

    final cancelToken = RequestCancellation();
    _activeMediaActionCancelToken = cancelToken;
    setState(() => _isMediaActionInFlight = true);
    return cancelToken;
  }

  void _completeMediaAction(RequestCancellation cancelToken) {
    if (!identical(_activeMediaActionCancelToken, cancelToken)) {
      return;
    }

    _activeMediaActionCancelToken = null;
    if (mounted) {
      setState(() => _isMediaActionInFlight = false);
    } else {
      _isMediaActionInFlight = false;
    }
  }

  void _cancelActiveMediaAction() {
    final cancelToken = _activeMediaActionCancelToken;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('generations_gallery_media_action_cancelled');
    }
    _activeMediaActionCancelToken = null;
    _isMediaActionInFlight = false;
  }

  void _syncTabVisibility(bool isTabActive, {required bool fromAppResume}) {
    if (_isTabActive == isTabActive) {
      if (isTabActive && fromAppResume) {
        _handleScreenBecameVisible(fromAppResume: true);
      }
      return;
    }

    _isTabActive = isTabActive;
    Future.microtask(() {
      if (!mounted) {
        return;
      }

      if (!isTabActive) {
        _cancelActiveMediaAction();
        _setHistoryScreenVisible(false);
        return;
      }

      _handleScreenBecameVisible(fromAppResume: fromAppResume);
    });
  }

  void _handleScreenBecameVisible({required bool fromAppResume}) {
    final isAuthenticated = ref
        .read(appLaunchControllerProvider)
        .isAuthenticated;
    if (!isAuthenticated) {
      _setHistoryScreenVisible(false);
      return;
    }

    _setHistoryScreenVisible(true);
    _maybeLoadWalletForAuthenticatedUser();
    if (!_hasLoadedInitially) {
      _hasLoadedInitially = true;
      unawaited(ref.read(generationHistoryControllerProvider.notifier).load());
      return;
    }

    if (fromAppResume) {
      unawaited(
        ref
            .read(generationHistoryControllerProvider.notifier)
            .load(refresh: true),
      );
    }
  }

  void _maybeLoadWalletForAuthenticatedUser() {
    final launchState = ref.read(appLaunchControllerProvider);
    final walletState = ref.read(walletControllerProvider);
    if (!launchState.isAuthenticated ||
        !ref.read(networkStatusControllerProvider).hasInternet ||
        walletState.isLoading ||
        walletState.isRefreshing ||
        walletState.hasCompletedFullLoad) {
      return;
    }

    unawaited(ref.read(walletControllerProvider.notifier).load());
  }

  void _setHistoryScreenVisible(bool visible) {
    final controller = ref.read(generationHistoryControllerProvider.notifier);
    final controllerChanged = !identical(_visibleHistoryController, controller);
    if (!controllerChanged && _historyScreenVisible == visible) {
      return;
    }

    _historyScreenVisible = visible;
    if (controllerChanged) {
      _visibleHistoryController?.setScreenVisible(false);
      _visibleHistoryController = controller;
    }

    controller.setScreenVisible(visible);
  }

  void _syncVisibleHistoryController() {
    final controller = ref.read(generationHistoryControllerProvider.notifier);
    if (!identical(_visibleHistoryController, controller)) {
      _visibleHistoryController?.setScreenVisible(false);
      _visibleHistoryController = controller;
      controller.setScreenVisible(_historyScreenVisible);
    }
  }

  void _setStoredHistoryScreenVisible(
    bool visible, {
    bool clearLoadingState = true,
  }) {
    if (_historyScreenVisible == visible) {
      return;
    }

    _historyScreenVisible = visible;
    _visibleHistoryController?.setScreenVisible(
      visible,
      clearLoadingState: clearLoadingState,
    );
  }

  Widget _sectionHeaderSliver(String title, int count) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 10),
      sliver: SliverToBoxAdapter(
        child: _SectionHeader(title: title, count: count),
      ),
    );
  }

  Widget _activeListSliver(List<TemplateGenerationResult> items) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
      sliver: SliverList.separated(
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) => _ActiveCard(generation: items[index]),
      ),
    );
  }

  Widget _failedListSliver(List<TemplateGenerationResult> items) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
      sliver: SliverList.separated(
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) => _FailedCard(generation: items[index]),
      ),
    );
  }

  Widget _readyGridSliver(List<TemplateGenerationResult> readyItems) {
    final visibleCount = _readyExpanded
        ? readyItems.length
        : (readyItems.length > 4 ? 4 : readyItems.length);
    final visibleItems = readyItems.take(visibleCount).toList(growable: false);
    final hiddenCount = readyItems.length - visibleItems.length;

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
      sliver: SliverMainAxisGroup(
        slivers: [
          SliverGrid.builder(
            itemCount: visibleItems.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.82,
            ),
            itemBuilder: (context, index) => _ReadyGridCard(
              generation: visibleItems[index],
              galleryState: this,
            ),
          ),
          if (hiddenCount > 0 || _readyExpanded)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: _ShowMoreButton(
                  expanded: _readyExpanded,
                  hiddenCount: hiddenCount,
                  onPressed: () =>
                      setState(() => _readyExpanded = !_readyExpanded),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _paginationFooterSliver(
    _GalleryPageViewState state,
    double bottomInset,
  ) {
    final shouldShowFooter =
        state.hasMore || state.isLoadingMore || state.loadMoreError != null;
    if (!shouldShowFooter) {
      return SliverToBoxAdapter(child: SizedBox(height: bottomInset));
    }

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(18, 4, 18, bottomInset),
      sliver: SliverToBoxAdapter(
        child: _GalleryLoadMoreFooter(
          isLoading: state.isLoadingMore,
          hasError: state.loadMoreError != null,
        ),
      ),
    );
  }
}
