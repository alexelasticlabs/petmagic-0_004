import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_card.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_type_filters.dart';
import 'package:petmagic_mobile/shared/loading/magic_loading_screen.dart';

class TemplatesPage extends ConsumerStatefulWidget {
  const TemplatesPage({super.key});

  static const routePath = '/templates';

  @override
  ConsumerState<TemplatesPage> createState() => _TemplatesPageState();
}

class _TemplatesPageState extends ConsumerState<TemplatesPage> {
  static const _refreshCooldown = Duration(seconds: 15);

  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  DateTime? _lastRefreshAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
    _scrollController.addListener(_handleScroll);
    Future.microtask(() => _refreshFeed(forceRefresh: true));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  late final WidgetsBindingObserver _lifecycleObserver =
      _TemplatesLifecycleObserver(onResumed: () => _refreshFeed());

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(templatesControllerProvider);
    final controller = ref.read(templatesControllerProvider.notifier);
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final titleStyle = Theme.of(context).textTheme.titleLarge;
    final subtitleStyle = Theme.of(context).textTheme.bodySmall;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.backgroundTop, colors.backgroundBottom],
        ),
      ),
      child: RefreshIndicator.adaptive(
        onRefresh: controller.refresh,
        color: colors.accent,
        child: CustomScrollView(
          controller: _scrollController,
          cacheExtent: 560,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 1),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _TopBar(tokenBalance: 125),
                      const SizedBox(height: 6),
                      Text(
                        text.createMagicTitle,
                        style: titleStyle?.copyWith(
                          color: colors.textStrong,
                          fontSize: 17,
                          height: 1.08,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        text.pickTemplateSubtitle,
                        style: subtitleStyle?.copyWith(
                          color: colors.textSoft,
                          fontSize: 10.2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      _SearchField(
                        controller: _searchController,
                        onChanged: _handleSearchChanged,
                      ),
                      const SizedBox(height: 6),
                      TemplateTypeFilters(
                        selectedType: state.query.type,
                        categories: state.categories,
                        selectedCategory: state.query.category,
                        onTypeSelected: controller.setType,
                        onCategorySelected: controller.setCategory,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (state.isInitialLoading)
              const SliverMagicLoadingScreen()
            else if (state.errorMessage != null && state.items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _StateMessage(
                  icon: Icons.cloud_off_rounded,
                  title: text.templatesErrorTitle,
                  message: state.errorMessage!,
                  actionLabel: text.retryAction,
                  onAction: () => controller.loadInitial(forceRefresh: true),
                ),
              )
            else if (state.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _StateMessage(
                  icon: Icons.auto_awesome_motion_rounded,
                  title: text.emptyTemplatesTitle,
                  message: text.emptyTemplatesMessage,
                  actionLabel: text.retryAction,
                  onAction: () => controller.loadInitial(forceRefresh: true),
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                sliver: SliverGrid.builder(
                  itemCount: state.items.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.72,
                  ),
                  itemBuilder: (context, index) {
                    return TemplateCard(template: state.items[index]);
                  },
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 90),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: state.isLoadingMore
                        ? Center(
                            child: CircularProgressIndicator.adaptive(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                colors.accent,
                              ),
                            ),
                          )
                        : state.errorMessage != null
                        ? TextButton.icon(
                            onPressed: controller.loadMore,
                            icon: const Icon(Icons.refresh_rounded),
                            label: Text(text.retryAction),
                          )
                        : const SizedBox(height: 28),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels > position.maxScrollExtent - 720) {
      ref.read(templatesControllerProvider.notifier).loadMore();
    }
  }

  void _handleSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 360), () {
      ref.read(templatesControllerProvider.notifier).setSearch(value);
    });
  }

  Future<void> _refreshFeed({bool forceRefresh = false}) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _lastRefreshAt != null &&
        now.difference(_lastRefreshAt!) < _refreshCooldown) {
      return;
    }

    _lastRefreshAt = now;
    await ref
        .read(templatesControllerProvider.notifier)
        .loadInitial(forceRefresh: true);
  }
}

class _TemplatesLifecycleObserver with WidgetsBindingObserver {
  _TemplatesLifecycleObserver({required this.onResumed});

  final VoidCallback onResumed;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      onResumed();
    }
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.tokenBalance});

  final int tokenBalance;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    return Row(
      children: [
        Icon(Icons.pets_rounded, color: colors.accent, size: 28),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'PetMagic',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.comfortaa(
              color: colors.textStrong,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ),
        _GiftButton(tooltip: text.giftTooltip),
        const SizedBox(width: 8),
        _TokenBalance(balance: tokenBalance, addTooltip: text.addTokensTooltip),
      ],
    );
  }
}

class _GiftButton extends StatelessWidget {
  const _GiftButton({required this.tooltip});

  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Tooltip(
      message: tooltip,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _HeaderButton(icon: Icons.card_giftcard_rounded, color: colors.gold),
          Positioned(
            top: -4,
            right: -2,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.danger,
                shape: BoxShape.circle,
              ),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Text(
                  '1',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TokenBalance extends StatelessWidget {
  const _TokenBalance({required this.balance, required this.addTooltip});

  final int balance;
  final String addTooltip;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceGlass,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.pets_rounded, color: colors.accent, size: 18),
                const SizedBox(width: 6),
                Text(
                  '$balance',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colors.textStrong,
                    fontSize: 12.8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 32, color: colors.border),
          Tooltip(
            message: addTooltip,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Icon(
                Icons.add_rounded,
                color: colors.textStrong,
                size: 19,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceGlass,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.12), blurRadius: 18),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: TextStyle(
        color: colors.textStrong,
        fontSize: 10.2,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        hintText: text.searchTemplates,
        hintStyle: TextStyle(
          color: colors.textMuted,
          fontSize: 9.8,
          fontWeight: FontWeight.w700,
        ),
        prefixIcon: Icon(
          Icons.search_rounded,
          color: colors.textMuted,
          size: 15,
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 36, 28, 120),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: colors.accent, size: 46),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: colors.textStrong,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.textMuted,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}
