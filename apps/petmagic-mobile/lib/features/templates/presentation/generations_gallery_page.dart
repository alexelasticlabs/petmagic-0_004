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
import 'package:petmagic_mobile/shared/widgets/horizontal_filter_strip.dart';

part 'generations_gallery_page_cards.dart';
part 'generations_gallery_page_failed_card.part.dart';
part 'generations_gallery_page_card_chrome.part.dart';
part 'generations_gallery_page_filters_and_chrome.dart';
part 'generations_gallery_page_premium_chrome.part.dart';
part 'generations_gallery_page_states.dart';
part 'generations_gallery_page_action_sheets.dart';
part 'generations_gallery_page_media_actions.dart';
part 'generations_gallery_page_content.part.dart';
part 'generations_gallery_page_lifecycle.part.dart';
part 'generations_gallery_page_slivers.part.dart';

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

  void _updateState(VoidCallback update) {
    setState(update);
  }
}
