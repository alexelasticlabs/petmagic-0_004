import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/performance/performance_guard.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/premium/presentation/premium_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/widgets/auth_required_sheet.dart';
import 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_history_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_status_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/mappers/generations_gallery_mappers.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_page.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_controller.dart';
import 'package:petmagic_mobile/shared/files/device_file_saver.dart';
import 'package:petmagic_mobile/shared/files/file_name_sanitizer.dart';
import 'package:petmagic_mobile/shared/navigation/external_url_policy.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_shell.dart';
import 'package:petmagic_mobile/shared/widgets/motion.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_toast.dart';
import 'package:petmagic_mobile/shared/widgets/premium_banner_style.dart';
import 'package:petmagic_mobile/shared/widgets/premium_crown_icon.dart';
import 'package:petmagic_mobile/shared/widgets/premium_shimmer_button.dart';

part 'generations_gallery_page_cards.dart';
part 'generations_gallery_page_filters_and_chrome.dart';
part 'generations_gallery_page_states_and_actions.dart';

class GenerationsGalleryPage extends ConsumerStatefulWidget {
  const GenerationsGalleryPage({super.key});

  static const routePath = '/creations';

  @override
  ConsumerState<GenerationsGalleryPage> createState() =>
      _GenerationsGalleryPageState();
}

class _GenerationsGalleryPageState extends ConsumerState<GenerationsGalleryPage>
    with WidgetsBindingObserver {
  bool _readyExpanded = false;
  bool _isMediaActionInFlight = false;
  CancelToken? _activeMediaActionCancelToken;
  late final GenerationHistoryController _historyController;
  late final WalletController _walletController;

  @override
  void initState() {
    super.initState();
    _historyController = ref.read(generationHistoryControllerProvider.notifier);
    _walletController = ref.read(walletControllerProvider.notifier);
    _historyController.setScreenVisible(
      ref.read(appLaunchControllerProvider).isAuthenticated,
    );
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() async {
      if (!mounted) {
        return;
      }

      final launch = ref.read(appLaunchControllerProvider);
      final hasWallet = ref.read(walletControllerProvider).wallet != null;
      if (launch.isAuthenticated && !hasWallet) {
        unawaited(_walletController.load());
      }

      if (!launch.isAuthenticated) {
        _historyController.setScreenVisible(false);
        return;
      }

      _historyController.setScreenVisible(true);
      await _historyController.load();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isAuthenticated = ref
        .read(appLaunchControllerProvider)
        .isAuthenticated;
    if (!isAuthenticated) {
      _historyController.setScreenVisible(false);
      return;
    }

    if (state == AppLifecycleState.resumed) {
      _historyController.setScreenVisible(true);
      unawaited(_historyController.load(refresh: true));
      return;
    }

    _historyController.setScreenVisible(false);
  }

  @override
  void deactivate() {
    _cancelActiveMediaAction();
    _historyController.setScreenVisible(false);
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    if (!ref.read(appLaunchControllerProvider).isAuthenticated) {
      _historyController.setScreenVisible(false);
      return;
    }

    _historyController.setScreenVisible(true);
    unawaited(_historyController.load(refresh: true));
  }

  @override
  void dispose() {
    _cancelActiveMediaAction();
    _historyController.setScreenVisible(false);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final state = ref.watch(generationHistoryControllerProvider);
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
              const Positioned.fill(child: _GalleryAtmosphere()),
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
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
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
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: colors.textSoft,
                                    height: 1.35,
                                  ),
                            ),
                            const SizedBox(height: 16),
                            _FilterBar(selected: state.filter),
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
    GenerationHistoryState state, {
    required bool isAuthenticated,
  }) {
    if (!isAuthenticated) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _GuestAccessState(
            onOpenSignIn: () {
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
      return const [
        SliverFillRemaining(hasScrollBody: false, child: _EmptyState()),
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
      slivers.add(SliverToBoxAdapter(child: SizedBox(height: bottomInset)));
      return slivers;
    }

    if (state.filter == GenerationHistoryFilter.ready) {
      return [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(18, 8, 18, bottomInset),
          sliver: SliverGrid.builder(
            itemCount: filteredItems.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.82,
            ),
            itemBuilder: (context, index) =>
                _ReadyGridCard(generation: filteredItems[index]),
          ),
        ),
      ];
    }

    if (state.filter == GenerationHistoryFilter.active) {
      return [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
          sliver: const SliverToBoxAdapter(child: _ActiveInfoCard()),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(18, 0, 18, bottomInset),
          sliver: SliverList.separated(
            itemCount: filteredItems.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) =>
                _ActiveCard(generation: filteredItems[index]),
          ),
        ),
      ];
    }

    if (state.filter == GenerationHistoryFilter.failed) {
      return [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(18, 8, 18, bottomInset),
          sliver: SliverList.separated(
            itemCount: filteredItems.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) =>
                _FailedCard(generation: filteredItems[index]),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(18, 8, 18, bottomInset),
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
      await context.push(PremiumPage.routePath);
      return;
    }

    await showAuthRequiredSheet(context, redirectPath: PremiumPage.routePath);
  }

  CancelToken? _startMediaAction() {
    if (_activeMediaActionCancelToken != null) {
      return null;
    }

    final cancelToken = CancelToken();
    _activeMediaActionCancelToken = cancelToken;
    if (mounted) {
      setState(() => _isMediaActionInFlight = true);
    } else {
      _isMediaActionInFlight = true;
    }
    return cancelToken;
  }

  void _completeMediaAction(CancelToken cancelToken) {
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
            itemBuilder: (context, index) =>
                _ReadyGridCard(generation: visibleItems[index]),
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
}
