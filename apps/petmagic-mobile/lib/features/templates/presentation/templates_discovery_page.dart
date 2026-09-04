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
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
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

class TemplatesDiscoveryPage extends ConsumerStatefulWidget {
  const TemplatesDiscoveryPage({super.key});

  static const routePath = '/discover';

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
    _syncControllerVisibility();
    if (_isAppResumed) {
      _refreshAccessForAuthenticatedUser(forceRefresh: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _discoveryController.setScreenVisible(false);
    super.dispose();
  }

  void _syncTabVisibility(bool active) {
    if (_isTabActive == active) {
      return;
    }
    _isTabActive = active;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
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
    if (notification.metrics.axis != Axis.vertical) {
      return false;
    }
    final scrolling = notification.direction != ScrollDirection.idle;
    if (_isVerticalScrolling != scrolling && mounted) {
      setState(() => _isVerticalScrolling = scrolling);
    }
    return false;
  }

  void _openCategory(String category) {
    context.appNavigator.push<void>(TemplatesDestination(category: category));
  }

  void _openTemplate(TemplateItem template, String category) {
    context.appNavigator.push<void>(
      TemplatesDestination(category: category, payload: template),
    );
  }

  @override
  Widget build(BuildContext context) {
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
        unawaited(_discoveryController.refreshIfNeeded());
      }
    });

    final state = ref.watch(templateDiscoveryControllerProvider);
    final controller = _discoveryController;
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final bottomInset = petMagicScrollableBottomInset(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.backgroundTop, colors.backgroundBottom],
        ),
      ),
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
                        Text(
                          text.discoverHomeTitle,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: colors.textStrong,
                                fontSize: 22,
                                height: 1.05,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.6,
                              ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          text.discoverHomeSubtitle,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: colors.textSoft,
                                fontSize: 11.5,
                                height: 1.3,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        if (state.sections.isNotEmpty) ...[
                          const SizedBox(height: PetMagicSpacing.sm),
                          TemplateCategoryCarousel(
                            sections: state.sections,
                            eyebrowLabel: text.discoverCategoryEyebrow,
                            openLabel: text.discoverOpenCategoryAction,
                            autoplayEnabled: !_isVerticalScrolling,
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
                    label: text.searchTemplates,
                    onPressed: () => context.appNavigator.push<void>(
                      const TemplatesDestination(autofocusSearch: true),
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
                  SliverList.separated(
                    itemCount: state.sections.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: PetMagicSpacing.lg),
                    itemBuilder: (context, index) {
                      final section = state.sections[index];
                      return TemplateDiscoveryRail(
                        section: section,
                        sectionIndex: index,
                        moreLabel: text.discoverMoreAction,
                        onMorePressed: () => _openCategory(section.category),
                        onTemplatePressed: (template) =>
                            _openTemplate(template, section.category),
                      );
                    },
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

class _DiscoverySearchHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _DiscoverySearchHeaderDelegate({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  double get minExtent => 62;

  @override
  double get maxExtent => 62;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final colors = context.petMagicColors;
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            colors.backgroundTop.withValues(alpha: 0.94),
            colors.backgroundBottom,
          ),
          boxShadow: overlapsContent
              ? [
                  BoxShadow(
                    color: colors.shadow.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            PetMagicSpacing.sm,
            7,
            PetMagicSpacing.sm,
            7,
          ),
          child: Semantics(
            container: true,
            button: true,
            label: label,
            onTap: onPressed,
            child: ExcludeSemantics(
              child: PetMagicInteractiveSurface(
                key: const ValueKey('discovery-search-launcher'),
                onTap: onPressed,
                borderRadius: BorderRadius.circular(PetMagicRadii.pill),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surfaceGlass,
                    borderRadius: BorderRadius.circular(PetMagicRadii.pill),
                    border: Border.all(color: colors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 17),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search_rounded,
                          color: colors.textSoft,
                          size: 20,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: colors.textSoft,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: colors.accent,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _DiscoverySearchHeaderDelegate oldDelegate) =>
      oldDelegate.label != label || oldDelegate.onPressed != onPressed;
}

class _DiscoveryStateView extends StatelessWidget {
  const _DiscoveryStateView({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    required this.bottomInset,
    this.unavailableKind,
  });

  final AppUnavailableKind? unavailableKind;
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final unavailable = unavailableKind;
    if (unavailable != null) {
      return PetMagicUnavailableView(
        kind: unavailable,
        onRetry: onAction,
        padding: EdgeInsets.fromLTRB(28, 36, 28, bottomInset),
      );
    }

    return PetMagicAsyncStateView(
      icon: icon,
      title: title,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
      padding: EdgeInsets.fromLTRB(28, 36, 28, bottomInset),
    );
  }
}
