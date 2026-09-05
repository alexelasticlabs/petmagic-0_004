import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/errors/app_unavailable_state.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/navigation/app_navigator.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/profile/application/profile_controller.dart';
import 'package:petmagic_mobile/features/templates/application/template_discovery_controller.dart';
import 'package:petmagic_mobile/features/templates/application/template_discovery_realtime.dart';
import 'package:petmagic_mobile/features/templates/application/template_catalog_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_discovery_models.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_feed_media_preload_queue.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_feed_playback_manager.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_preview_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_entitlement_provider.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/random_template_sheet.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/create_with_pet_block.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/discovery_collection_style.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/discovery_section_reveal.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/discovery_atmosphere.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/discovery_motion.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_card_playback_coordinator.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_category_carousel.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_discovery_rail.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/templates_top_bar.dart';
import 'package:petmagic_mobile/features/wallet/application/wallet_controller.dart';
import 'package:petmagic_mobile/shared/loading/magic_loading_screen.dart';
import 'package:petmagic_mobile/shared/navigation/app_navigation_context.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_navigation_layout.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_async_state_view.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_interactive_surface.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_unavailable_view.dart';

part 'templates_discovery_access.part.dart';
part 'templates_discovery_chrome.part.dart';
part 'templates_discovery_playback.part.dart';
part 'templates_discovery_random.part.dart';

class TemplatesDiscoveryPage extends ConsumerStatefulWidget {
  const TemplatesDiscoveryPage({this.previewControllerFactory, super.key});

  static const routePath = '/discover';
  final TemplatePreviewControllerFactory? previewControllerFactory;

  @override
  ConsumerState<TemplatesDiscoveryPage> createState() =>
      _TemplatesDiscoveryPageState();
}

class _TemplatesDiscoveryPageState extends ConsumerState<TemplatesDiscoveryPage>
    with WidgetsBindingObserver {
  late final TemplateDiscoveryController _discoveryController;
  bool _isAppResumed = true;
  bool? _isTabActive;
  bool _isVerticalScrolling = false;
  bool _shouldRefreshAccessOnReconnect = false;
  String? _localeTag;
  Future<void>? _walletAccessRefreshInFlight;
  Future<void>? _profileAccessRefreshInFlight;
  TemplatesRepository? _randomRepository;
  bool _randomSheetOpen = false;
  int _randomRequestEpoch = 0;
  final _activeCollection = ValueNotifier<int>(0);

  void _setRandomSheetOpen(bool open) {
    if (mounted) setState(() => _randomSheetOpen = open);
  }

  @override
  void initState() {
    super.initState();
    _discoveryController = ref.read(
      templateDiscoveryControllerProvider.notifier,
    );
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _syncControllerVisibility();
      if (ref.read(networkStatusControllerProvider).hasInternet) {
        _discoveryController.handleNetworkAvailable();
      } else {
        _discoveryController.handleNetworkUnavailable();
      }
      if (_isAppResumed && _isTabActive == true) {
        unawaited(_discoveryController.refreshIfNeeded());
      }
      _refreshAccessForAuthenticatedUser();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTabVisibility(TickerMode.valuesOf(context).enabled);
    final nextLocaleTag = Localizations.localeOf(context).toLanguageTag();
    final localeChanged = _localeTag != null && _localeTag != nextLocaleTag;
    _localeTag = nextLocaleTag;
    if (localeChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _discoveryController.resetForLocale();
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppResumed = state == AppLifecycleState.resumed;
    if (!_isAppResumed) {
      _cancelRandomRequest();
      ref
          .read(templateDiscoveryPlaybackManagerProvider)
          .disposeAll(reason: 'discovery_app_background');
    }
    _syncControllerVisibility();
    if (_isAppResumed) {
      _refreshAccessForAuthenticatedUser(forceRefresh: true);
    }
  }

  @override
  void dispose() {
    _activeCollection.dispose();
    _cancelRandomRequest();
    WidgetsBinding.instance.removeObserver(this);
    _discoveryController.setScreenVisible(false);
    super.dispose();
  }

  void _syncTabVisibility(bool active) {
    if (_isTabActive == active) {
      return;
    }
    _isTabActive = active;
    if (!active) {
      _cancelRandomRequest();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (!active) {
          ref
              .read(templateDiscoveryPlaybackManagerProvider)
              .disposeAll(reason: 'discovery_tab_hidden');
        }
        _syncControllerVisibility();
      }
    });
  }

  void _syncControllerVisibility() {
    if (!mounted) {
      return;
    }
    _discoveryController.setScreenVisible(
      _isAppResumed && _isTabActive == true,
    );
  }

  bool _handleUserScroll(UserScrollNotification notification) {
    // Card visibility and network budgets own video playback. A scroll gesture
    // alone must not tear down an already visible preview.
    if (notification.metrics.axis == Axis.vertical) {
      final scrolling = notification.direction != ScrollDirection.idle;
      if (_isVerticalScrolling != scrolling && mounted) {
        setState(() => _isVerticalScrolling = scrolling);
      }
    }
    return false;
  }

  void _openCategory(String category) {
    context.appNavigator.push<void>(TemplatesDestination(category: category));
  }

  void _openTemplate(
    TemplateItem template,
    String category,
    List<TemplateItem> previewItems,
  ) {
    final session = TemplatePreviewSession.fromSelection(
      items: previewItems,
      selectedTemplate: template,
      source: TemplatePreviewSource.discovery,
    );
    context.appNavigator.push<void>(
      TemplatesDestination(category: category, payload: session),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(templateDiscoveryRealtimeProvider);
    ref.listen<NetworkStatusState>(networkStatusControllerProvider, (
      previous,
      next,
    ) {
      if (!next.hasInternet) {
        _discoveryController.handleNetworkUnavailable();
        _shouldRefreshAccessOnReconnect = true;
        return;
      }
      if (previous?.hasInternet == false && next.hasInternet) {
        if (_shouldRefreshAccessOnReconnect) {
          _refreshAccessForAuthenticatedUser(forceRefresh: true);
        }
        _discoveryController.handleNetworkAvailable();
      }
    });

    final state = ref.watch(templateDiscoveryControllerProvider);
    final controller = _discoveryController;
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final bottomInset = petMagicScrollableBottomInset(context);
    final page = state.page;
    final carouselSections = state.carouselSections;
    final railSections = state.railSections;
    final searchEnabled = page?.searchEnabled == true;

    return DiscoveryAtmosphere(
      collectionIndex: _activeCollection,
      child: RefreshIndicator.adaptive(
        onRefresh: () async {
          await controller.loadInitial(forceRefresh: true);
        },
        color: colors.accent,
        child: NotificationListener<UserScrollNotification>(
          onNotification: _handleUserScroll,
          child: SafeArea(
            bottom: false,
            child: CustomScrollView(
              key: const PageStorageKey<String>('templates-discovery-scroll'),
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      PetMagicSpacing.sm,
                      6,
                      PetMagicSpacing.sm,
                      PetMagicSpacing.sm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TemplatesTopBarSlot(
                          onAuthPressed: () => context.appNavigator.go(
                            const AuthDestination(
                              redirectPath: TemplatesDiscoveryPage.routePath,
                            ),
                          ),
                          onRewardsPressed: () => context.appNavigator.go(
                            const RewardsDestination(),
                          ),
                          onTopUpPressed: () => context.appNavigator.push(
                            const WalletDestination(),
                          ),
                          onWalletPressed: () => context.appNavigator.push(
                            const WalletDestination(),
                          ),
                        ),
                        const SizedBox(height: PetMagicSpacing.lg),
                        DiscoveryIntroduction(
                          title: page?.title ?? text.discoverHomeTitle,
                          subtitle: page?.subtitle ?? text.discoverHomeSubtitle,
                        ),
                        const CreateWithPetBlockSlot(
                          selectedPetId: null,
                          selectedPetPhotoId: null,
                          padding: EdgeInsets.only(top: 12),
                        ),
                        if (carouselSections.isNotEmpty) ...[
                          const SizedBox(height: PetMagicSpacing.sm),
                          TemplateCategoryCarousel(
                            sections: carouselSections,
                            eyebrowLabel: text.discoverCategoryEyebrow,
                            openLabel: text.discoverOpenCategoryAction,
                            autoplayEnabled:
                                !_isVerticalScrolling &&
                                (page?.autoplayEnabled ?? true),
                            autoAdvanceInterval:
                                page?.autoAdvanceInterval ??
                                const Duration(seconds: 7),
                            onActiveCategoryChanged: (index) =>
                                _activeCollection.value =
                                    discoveryCollectionIndex(
                                      carouselSections[index].category,
                                    ),
                            onCategoryPressed: _openCategory,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _DiscoverySearchHeaderDelegate(
                    randomLabel: text.randomTemplateAction,
                    catalogLabel: searchEnabled
                        ? text.searchTemplates
                        : text.generationStatusAllTemplatesAction,
                    searchEnabled: searchEnabled,
                    actionHeight:
                        (MediaQuery.textScalerOf(context).scale(13) * 2 + 16)
                            .clamp(48.0, 88.0),
                    onRandomPressed: _randomSheetOpen || state.isInitialLoading
                        ? null
                        : _openRandomTemplate,
                    onCatalogPressed: () => context.appNavigator.push<void>(
                      TemplatesDestination(autofocusSearch: searchEnabled),
                    ),
                  ),
                ),
                if (state.isInitialLoading)
                  const SliverMagicLoadingScreen()
                else if (state.sections.isEmpty && state.errorMessage != null)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _DiscoveryStateView(
                      unavailableKind: classifyAppUnavailable(
                        raw: state.errorMessage,
                        hasInternet: ref.watch(
                          networkStatusControllerProvider.select(
                            (network) => network.hasInternet,
                          ),
                        ),
                      ),
                      icon: Icons.cloud_off_rounded,
                      title: text.templatesErrorTitle,
                      message: text.templatesRequestFailedError,
                      actionLabel: text.retryAction,
                      onAction: () =>
                          controller.loadInitial(forceRefresh: true),
                      bottomInset: bottomInset,
                    ),
                  )
                else if (state.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _DiscoveryStateView(
                      icon: Icons.auto_awesome_motion_rounded,
                      title: text.emptyTemplatesTitle,
                      message: text.emptyTemplatesMessage,
                      actionLabel: text.retryAction,
                      onAction: () =>
                          controller.loadInitial(forceRefresh: true),
                      bottomInset: bottomInset,
                    ),
                  )
                else
                  _TemplateDiscoveryRails(
                    sections: railSections,
                    moreLabel: text.discoverMoreAction,
                    previewControllerFactory: widget.previewControllerFactory,
                    onMorePressed: _openCategory,
                    onTemplatePressed: _openTemplate,
                  ),
                SliverToBoxAdapter(child: SizedBox(height: bottomInset)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
