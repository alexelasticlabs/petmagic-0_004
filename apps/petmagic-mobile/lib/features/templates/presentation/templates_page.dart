import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/core/permissions/app_permission_coordinator.dart';
import 'package:petmagic_mobile/features/premium/presentation/premium_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/auth_entry_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/widgets/auth_required_sheet.dart';
import 'package:petmagic_mobile/features/rewards/presentation/rewards_page.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_status_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_preview_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_generation_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_card.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_flow_sheets.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_type_filters.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_controller.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_page.dart';
import 'package:petmagic_mobile/shared/loading/magic_loading_screen.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_shell.dart';
import 'package:petmagic_mobile/shared/widgets/pawspark_icon.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_haptics.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_toast.dart';

class TemplatesPage extends ConsumerStatefulWidget {
  const TemplatesPage({super.key});

  static const routePath = '/templates';

  @override
  ConsumerState<TemplatesPage> createState() => _TemplatesPageState();
}

class _TemplatesPageState extends ConsumerState<TemplatesPage> {
  static const _refreshCooldown = Duration(seconds: 15);
  static const _gridCacheExtent = 400.0;

  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final _imagePicker = ImagePicker();
  final _permissionCoordinator = AppPermissionCoordinator();
  late final TemplatesController _templatesController;
  late final WalletController _walletController;
  Timer? _searchDebounce;
  DateTime? _lastRefreshAt;

  @override
  void initState() {
    super.initState();
    _templatesController = ref.read(templatesControllerProvider.notifier);
    _walletController = ref.read(walletControllerProvider.notifier);
    final shouldLoadWallet = ref.read(walletControllerProvider).wallet == null;
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
    _scrollController.addListener(_handleScroll);
    Future.microtask(() {
      if (!mounted) {
        return;
      }

      _templatesController.setScreenVisible(true);
      _refreshFeed();
      if (shouldLoadWallet) {
        unawaited(_walletController.load());
      }
    });
  }

  @override
  void dispose() {
    _templatesController.setScreenVisible(false);
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  late final WidgetsBindingObserver _lifecycleObserver =
      _TemplatesLifecycleObserver(onStateChanged: _handleLifecycleState);

  void _handleLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _templatesController.setScreenVisible(true);
      unawaited(_refreshFeed());
      return;
    }

    _templatesController.setScreenVisible(false);
  }

  @override
  void deactivate() {
    _templatesController.setScreenVisible(false);
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _templatesController.setScreenVisible(true);
    unawaited(_refreshFeed());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(templatesControllerProvider);
    final wallet = ref.watch(
      walletControllerProvider.select((walletState) => walletState.wallet),
    );
    final isAuthenticated = ref.watch(
      appLaunchControllerProvider.select(
        (launchState) => launchState.isAuthenticated,
      ),
    );
    final controller = ref.read(templatesControllerProvider.notifier);
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final titleStyle = Theme.of(context).textTheme.titleLarge;
    final subtitleStyle = Theme.of(context).textTheme.bodySmall;
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
          await PetMagicHaptics.medium();
          await controller.refresh();
        },
        color: colors.accent,
        child: CustomScrollView(
          controller: _scrollController,
          cacheExtent: _gridCacheExtent,
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
                      _TopBar(
                        isAuthenticated: isAuthenticated,
                        tokenBalance: wallet?.balance ?? 0,
                        onAuthPressed: () =>
                            context.go(AuthEntryPage.routePath),
                        onRewardsPressed: () =>
                            context.go(RewardsPage.routePath),
                        onTopUpPressed: () =>
                            context.push(WalletPage.routePath),
                        onWalletPressed: () =>
                            context.push(WalletPage.routePath),
                      ),
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
                  message: _mapTemplatesError(text, state.errorMessage!),
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
                padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
                sliver: SliverGrid.builder(
                  itemCount: state.items.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 5,
                    mainAxisSpacing: 6,
                    childAspectRatio: 0.72,
                  ),
                  itemBuilder: (context, index) {
                    final template = state.items[index];
                    return TemplateCard(
                      template: template,
                      hasPremiumAccess: wallet?.isPremium ?? false,
                      onPressed: () => _handleTemplateSelected(template),
                    );
                  },
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(10, 8, 10, bottomInset),
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
      _templatesController.loadMore();
    }
  }

  void _handleSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 360), () {
      _templatesController.setSearch(value);
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
    await _templatesController.loadInitial(forceRefresh: forceRefresh);
  }

  Future<void> _handleTemplateSelected(TemplateItem template) async {
    final isAuthenticated = ref
        .read(appLaunchControllerProvider)
        .isAuthenticated;
    final hasPremiumAccess =
        ref.read(walletControllerProvider).wallet?.isPremium ?? false;
    final action = await context.push<TemplateDetailAction>(
      TemplatePreviewPage.routePath,
      extra: TemplatePreviewRouteArgs(
        template: template,
        hasPremiumAccess: hasPremiumAccess,
        isAuthenticated: isAuthenticated,
      ),
    );
    if (!mounted || action != TemplateDetailAction.upload) {
      return;
    }

    await _startTemplateUploadFlow(template);
  }

  Future<void> _startTemplateUploadFlow(TemplateItem template) async {
    while (mounted) {
      if (!ref.read(appLaunchControllerProvider).isAuthenticated) {
        await showAuthRequiredSheet(context);
        return;
      }

      final photo = await _pickPetPhoto();
      if (!mounted || photo == null) {
        return;
      }

      final generationController = ref.read(
        templateGenerationControllerProvider.notifier,
      );
      generationController.selectPhoto(photo);

      final gate = await generationController.checkGate(template);
      if (!mounted) {
        return;
      }

      if (!gate.isAllowed) {
        final blockerAction = await showTemplateBlockedSheet(
          context: context,
          template: template,
          gate: gate,
        );
        if (!mounted || blockerAction == null) {
          return;
        }

        switch (blockerAction) {
          case TemplateBlockedAction.wallet:
            context.push(WalletPage.routePath);
          case TemplateBlockedAction.premium:
            context.push(PremiumPage.routePath);
          case TemplateBlockedAction.chooseAnother:
            break;
        }
        return;
      }

      final confirmed = await showTemplateGenerationConfirmSheet(
        context: context,
        template: template,
        photo: photo,
        gate: gate,
      );
      if (!mounted) {
        return;
      }

      if (confirmed == false) {
        continue;
      }

      if (confirmed != true) {
        return;
      }

      final router = GoRouter.of(context);
      final text = AppLocalizations.of(context);
      final generation = await generationController.startGeneration(template);
      if (!mounted) {
        return;
      }

      if (generation == null) {
        final errorMessage = ref
            .read(templateGenerationControllerProvider)
            .errorMessage;
        if (_isAuthRequiredError(errorMessage)) {
          await showAuthRequiredSheet(context);
          return;
        }

        PetMagicToast.show(
          context,
          message: errorMessage == null || errorMessage.isEmpty
              ? text.templateFlowStartFailedError
              : _generationStartErrorText(text, errorMessage),
          tone: PetMagicToastTone.warning,
        );
        return;
      }

      router.push(
        '${GenerationStatusPage.routePrefix}/${generation.generationId}',
      );
      return;
    }
  }

  Future<XFile?> _pickPetPhoto() async {
    final sourceAction = await showPetPhotoSourceSheet(context);
    if (!mounted || sourceAction == null) {
      return null;
    }

    final source = switch (sourceAction) {
      PetPhotoSourceAction.camera => ImageSource.camera,
      PetPhotoSourceAction.gallery => ImageSource.gallery,
    };

    final requiredPermission = source == ImageSource.camera
        ? AppPermissionType.camera
        : AppPermissionType.photos;
    final permission = await _permissionCoordinator.requestOnDemand(
      requiredPermission,
    );
    if (!permission.granted) {
      if (mounted) {
        PetMagicToast.show(
          context,
          message:
              'Permission is required to continue. You can enable it in system settings.',
          tone: PetMagicToastTone.warning,
        );
      }
      return null;
    }

    return _imagePicker.pickImage(
      source: source,
      imageQuality: 92,
      maxWidth: 1800,
    );
  }
}

String _mapTemplatesError(AppLocalizations text, String raw) {
  final value = raw.toLowerCase();

  if (value.contains('templates.feed_response_empty')) {
    return text.templatesFeedEmptyError;
  }

  if (value.contains('templates.catalog_page_response_empty')) {
    return text.templatesFeedEmptyError;
  }

  if (value.contains('templates.connection_timeout')) {
    return text.templatesConnectionTimeoutError;
  }

  if (value.contains('templates.server_timeout')) {
    return text.templatesServerTimeoutError;
  }

  if (value.contains('templates.request_failed')) {
    return text.templatesRequestFailedError;
  }

  return raw;
}

String _generationStartErrorText(AppLocalizations text, String raw) {
  if (raw.contains('auth.sign_in_required')) {
    return text.authSignInRequired;
  }

  if (raw.contains('auth.session_expired')) {
    return text.authSessionExpired;
  }

  if (raw.contains('templates.premium_required')) {
    return text.templateFlowPremiumRequiredError;
  }

  if (raw.contains('templates.insufficient_balance')) {
    return text.templateFlowInsufficientBalanceError;
  }

  if (raw.contains('templates.network_unavailable')) {
    return text.templateFlowNetworkError;
  }

  if (raw.contains('templates.server_unavailable')) {
    return text.templateFlowServerError;
  }

  return raw;
}

bool _isAuthRequiredError(String? raw) {
  if (raw == null || raw.isEmpty) {
    return false;
  }

  return raw.contains('auth.sign_in_required') ||
      raw.contains('auth.session_expired');
}

class _TemplatesLifecycleObserver with WidgetsBindingObserver {
  _TemplatesLifecycleObserver({required this.onStateChanged});

  final ValueChanged<AppLifecycleState> onStateChanged;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    onStateChanged(state);
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.isAuthenticated,
    required this.tokenBalance,
    required this.onAuthPressed,
    required this.onRewardsPressed,
    required this.onTopUpPressed,
    required this.onWalletPressed,
  });

  final bool isAuthenticated;
  final int tokenBalance;
  final VoidCallback onAuthPressed;
  final VoidCallback onRewardsPressed;
  final VoidCallback onTopUpPressed;
  final VoidCallback onWalletPressed;

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
        if (!isAuthenticated)
          OutlinedButton.icon(
            onPressed: onAuthPressed,
            icon: const Icon(Icons.login_rounded, size: 17),
            label: Text(text.profileSignInAction),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              foregroundColor: colors.accent,
              side: BorderSide(color: colors.accent.withValues(alpha: 0.5)),
            ),
          )
        else ...[
          _GiftButton(tooltip: text.giftTooltip, onPressed: onRewardsPressed),
          const SizedBox(width: 8),
          _TokenBalance(
            balance: tokenBalance,
            addTooltip: text.addTokensTooltip,
            onAddPressed: onTopUpPressed,
            onPressed: onWalletPressed,
          ),
        ],
      ],
    );
  }
}

class _GiftButton extends StatelessWidget {
  const _GiftButton({required this.tooltip, required this.onPressed});

  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Tooltip(
      message: tooltip,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _HeaderButton(
            icon: Icons.card_giftcard_rounded,
            color: colors.gold,
            onPressed: onPressed,
          ),
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
  const _TokenBalance({
    required this.balance,
    required this.addTooltip,
    required this.onAddPressed,
    required this.onPressed,
  });

  final int balance;
  final String addTooltip;
  final VoidCallback onAddPressed;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceGlass,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(22),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const PawSparkIcon(size: 18),
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
            ),
            Container(width: 1, height: 32, color: colors.border),
            Tooltip(
              message: addTooltip,
              child: InkWell(
                onTap: onAddPressed,
                borderRadius: BorderRadius.circular(22),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    color: colors.textStrong,
                    size: 19,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.color,
    this.onPressed,
  });

  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(22),
        child: DecoratedBox(
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
        ),
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
    final bottomInset = petMagicBottomNavInset(
      context,
      extraSpacing: kPetMagicBottomContentInsetRelaxed,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(28, 36, 28, bottomInset),
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
