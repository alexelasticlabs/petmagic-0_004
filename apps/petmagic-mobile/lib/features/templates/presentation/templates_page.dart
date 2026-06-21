// ignore_for_file: unused_element, unused_element_parameter, use_null_aware_elements

import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/config/app_config.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/performance/media_lifecycle_policy.dart';
import 'package:petmagic_mobile/core/performance/performance_guard.dart';
import 'package:petmagic_mobile/core/performance/template_preview_video_controller.dart';
import 'package:petmagic_mobile/core/permissions/app_permission_coordinator.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/premium/presentation/premium_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/auth_entry_page.dart';
import 'package:petmagic_mobile/features/profile/presentation/widgets/auth_required_sheet.dart';
import 'package:petmagic_mobile/features/rewards/presentation/rewards_page.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/templates/data/templates_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_status_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_generation_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_preview_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_card.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_flow_sheets.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_preview_image.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_type_filters.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_controller.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_page.dart';
import 'package:petmagic_mobile/shared/loading/magic_loading_screen.dart';
import 'package:petmagic_mobile/shared/navigation/external_url_policy.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_modal_sheet.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_shell.dart';
import 'package:petmagic_mobile/shared/widgets/pawspark_icon.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_async_state_view.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_haptics.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_interactive_surface.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_toast.dart';
import 'package:petmagic_mobile/shared/widgets/pressable_scale.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

final _templateHomePetsProvider = FutureProvider.autoDispose<List<PetProfile>>((
  ref,
) {
  return ref.watch(templateGenerationRepositoryProvider).fetchPets();
});

enum _TemplateInputChoice { upload, myPets }

enum _PetGenerationConfirmAction { start, change }

class TemplatesPage extends ConsumerStatefulWidget {
  const TemplatesPage({super.key});

  static const routePath = '/templates';

  @override
  ConsumerState<TemplatesPage> createState() => _TemplatesPageState();
}

class _TemplatesPageState extends ConsumerState<TemplatesPage> {
  static const _refreshCooldown = Duration(seconds: 45);
  static const _gridCacheExtent = 400.0;

  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final _imagePicker = ImagePicker();
  final _permissionCoordinator = AppPermissionCoordinator();
  late final TemplatesController _templatesController;
  late final WalletController _walletController;
  TemplatesRepository? _activeRandomTemplateRepository;
  Timer? _searchDebounce;
  DateTime? _lastRefreshAt;
  bool _disposed = false;
  bool _isRandomTemplateLoading = false;
  bool _isAppResumed = true;
  bool? _isTabActive;
  final Set<String> _trackedTemplateOfTheDayViews = <String>{};

  @override
  void initState() {
    super.initState();
    _templatesController = ref.read(templatesControllerProvider.notifier);
    _walletController = ref.read(walletControllerProvider.notifier);
    final shouldLoadWallet = ref.read(walletControllerProvider).wallet == null;
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
    _scrollController.addListener(_handleScroll);
    _runAfterBuild(() {
      if (!mounted) {
        return;
      }
      if (shouldLoadWallet) {
        unawaited(_walletController.load());
      }
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
  void dispose() {
    _disposed = true;
    _templatesController.setScreenVisible(false);
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    _cancelPendingSearchDebounce();
    _cancelPendingRandomTemplateRequest(clearLoadingState: false);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  late final WidgetsBindingObserver _lifecycleObserver =
      _TemplatesLifecycleObserver(onStateChanged: _handleLifecycleState);

  void _handleLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _isAppResumed = true;
      _runAfterBuild(() {
        if (!mounted) {
          return;
        }
        _syncTabVisibility(
          TickerMode.valuesOf(context).enabled,
          fromAppResume: true,
        );
      });
      return;
    }

    _isAppResumed = false;
    _runAfterBuild(() {
      if (!mounted) {
        return;
      }
      _cancelPendingSearchDebounce();
      _cancelPendingRandomTemplateRequest();
      _templatesController.setScreenVisible(false);
    });
  }

  void _handleScreenBecameVisible({required bool fromAppResume}) {
    _templatesController.setScreenVisible(true);

    final state = ref.read(templatesControllerProvider);
    final shouldRefresh =
        state.items.isEmpty ||
        state.errorMessage != null ||
        (fromAppResume && _isRefreshStale(DateTime.now()));

    if (shouldRefresh) {
      final shouldBypassCooldown =
          _lastRefreshAt != null &&
          (state.items.isEmpty || state.errorMessage != null);
      unawaited(_refreshFeed(forceRefresh: shouldBypassCooldown));
    }
  }

  void _syncTabVisibility(bool isTabActive, {required bool fromAppResume}) {
    if (_isTabActive == isTabActive) {
      if (isTabActive && fromAppResume) {
        _handleScreenBecameVisible(fromAppResume: true);
      }
      return;
    }

    _isTabActive = isTabActive;
    _runAfterBuild(() {
      if (!mounted) {
        return;
      }

      if (!isTabActive) {
        _cancelPendingSearchDebounce();
        _cancelPendingRandomTemplateRequest();
        _templatesController.setScreenVisible(false);
        return;
      }

      _handleScreenBecameVisible(fromAppResume: fromAppResume);
    });
  }

  bool _isRefreshStale(DateTime now) {
    final lastRefreshAt = _lastRefreshAt;
    if (lastRefreshAt == null) {
      return true;
    }

    return now.difference(lastRefreshAt) >= _refreshCooldown;
  }

  void _runAfterBuild(VoidCallback action) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed) {
        return;
      }
      action();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(
      templatesControllerProvider.select((state) => state.query.search),
      (previous, next) => _syncSearchFieldWithQuery(next),
    );
    final headerState = ref.watch(
      templatesControllerProvider.select(
        (state) => (
          query: state.query,
          categories: state.categories,
          templateOfTheDay: state.templateOfTheDay,
          isTemplateOfTheDayLoading: state.isTemplateOfTheDayLoading,
          templateOfTheDayError: state.templateOfTheDayError,
          isInitialLoading: state.isInitialLoading,
        ),
      ),
    );
    final controller = ref.read(templatesControllerProvider.notifier);
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final titleStyle = Theme.of(context).textTheme.titleLarge;
    final subtitleStyle = Theme.of(context).textTheme.bodySmall;
    final bottomInset = petMagicScrollableBottomInset(context);
    final templateOfTheDay = headerState.templateOfTheDay;
    final selectedPetId = _routeQueryParameter(context, 'petId');
    final selectedPetPhotoId = _routeQueryParameter(context, 'petPhotoId');
    _trackTemplateOfTheDayViewed(templateOfTheDay);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.backgroundTop, colors.backgroundBottom],
        ),
      ),
      child: Stack(
        children: [
          RefreshIndicator.adaptive(
            onRefresh: () async {
              await PetMagicHaptics.medium();
              await controller.refresh();
            },
            color: colors.accent,
            child: CustomScrollView(
              scrollCacheExtent: ScrollCacheExtent.pixels(_gridCacheExtent),
              controller: _scrollController,
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
                          _TemplatesTopBarSlot(
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
                          const SizedBox(height: 8),
                          _CreateWithPetBlockSlot(
                            selectedPetId: selectedPetId,
                            selectedPetPhotoId: selectedPetPhotoId,
                          ),
                          const SizedBox(height: 5),
                          _SearchField(
                            controller: _searchController,
                            onChanged: _handleSearchChanged,
                          ),
                          const SizedBox(height: 6),
                          TemplateTypeFilters(
                            selectedType: headerState.query.type,
                            categories: headerState.categories,
                            selectedCategory: headerState.query.category,
                            onTypeSelected: controller.setType,
                            onCategorySelected: controller.setCategory,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                _TemplateFeedSlivers(
                  bottomInset: bottomInset,
                  templateOfTheDay: templateOfTheDay,
                  selectedType: headerState.query.type,
                  selectedCategory: headerState.query.category,
                  searchQuery: headerState.query.search,
                  onTemplateSelected: (template) =>
                      unawaited(_handleTemplateSelected(template)),
                  onTemplateOfTheDaySelected: (featured) =>
                      unawaited(_handleTemplateOfTheDaySelected(featured)),
                ),
              ],
            ),
          ),
          Positioned(
            right: 16,
            bottom: petMagicBottomNavInset(context, extraSpacing: 24),
            child: _FloatingRandomTemplateButton(
              isLoading: _isRandomTemplateLoading,
              isEnabled: !headerState.isInitialLoading,
              onPressed: _handleRandomTemplatePressed,
            ),
          ),
        ],
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
      _searchDebounce = null;
      if (!mounted) {
        return;
      }
      _templatesController.setSearch(value);
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
        now.difference(_lastRefreshAt!) < _refreshCooldown) {
      return;
    }

    _lastRefreshAt = now;
    await _templatesController.loadInitial(forceRefresh: forceRefresh);
  }

  Future<void> _handleTemplateSelected(
    TemplateItem template, {
    TemplateOfTheDayItem? templateOfTheDay,
    bool fetchLatestDetails = true,
  }) async {
    final previewTemplate = fetchLatestDetails
        ? await _fetchTemplateDetailsOrFallback(template)
        : template;
    if (!mounted) {
      return;
    }

    final isAuthenticated = ref
        .read(appLaunchControllerProvider)
        .isAuthenticated;
    final hasPremiumAccess =
        ref.read(walletControllerProvider).wallet?.isPremium ?? false;
    final action = await context.push<TemplateDetailAction>(
      TemplatePreviewPage.routePath,
      extra: TemplatePreviewRouteArgs(
        template: previewTemplate,
        hasPremiumAccess: hasPremiumAccess,
        isAuthenticated: isAuthenticated,
      ),
    );
    if (!mounted || action != TemplateDetailAction.upload) {
      return;
    }

    await _startTemplateUploadFlow(
      previewTemplate,
      templateOfTheDay: templateOfTheDay,
    );
  }

  Future<TemplateItem> _fetchTemplateDetailsOrFallback(
    TemplateItem template,
  ) async {
    try {
      return await ref
          .read(templatesRepositoryProvider)
          .fetchTemplate(template.templateId);
    } catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'templates',
        operation: 'fetch_template_detail_before_preview',
        message:
            'Failed to fetch template detail before preview; using feed payload.',
        context: {'templateId': template.templateId},
        error: error,
        stackTrace: stackTrace,
      );
      return template;
    }
  }

  Future<void> _handleTemplateOfTheDaySelected(
    TemplateOfTheDayItem featured,
  ) async {
    unawaited(_recordTemplateOfTheDayAnalytics(featured, 'clicked'));

    final visibleTemplate = _findTemplateById(
      ref.read(templatesControllerProvider).items,
      featured.templateId,
    );
    if (visibleTemplate != null) {
      await _openTemplateOfTheDayTemplate(featured, visibleTemplate);
      return;
    }

    try {
      final template = await ref
          .read(templatesRepositoryProvider)
          .fetchTemplate(featured.templateId);
      if (!mounted) {
        return;
      }

      await _openTemplateOfTheDayTemplate(
        featured,
        template,
        fetchLatestDetails: false,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      await _openTemplateOfTheDayTemplate(
        featured,
        featured.toFallbackTemplateItem(),
        fetchLatestDetails: false,
      );
    }
  }

  Future<void> _openTemplateOfTheDayTemplate(
    TemplateOfTheDayItem featured,
    TemplateItem template, {
    bool fetchLatestDetails = true,
  }) async {
    unawaited(_recordTemplateOfTheDayAnalytics(featured, 'opened'));
    await _handleTemplateSelected(
      template,
      templateOfTheDay: featured,
      fetchLatestDetails: fetchLatestDetails,
    );
  }

  Future<void> _handleRandomTemplatePressed() async {
    if (!mounted || !_canUseVisibleTemplatesUi) {
      return;
    }

    final activeQuery = ref.read(templatesControllerProvider).query;
    final categories = ref.read(templatesControllerProvider).categories;
    final template = await _showRandomTemplateSettingsSheet(
      context,
      initialType: activeQuery.type,
      initialCategory: activeQuery.category,
      categories: categories,
      onFind: _findRandomTemplate,
    );
    if (!mounted || !_canUseVisibleTemplatesUi || template == null) {
      return;
    }

    await _handleTemplateSelected(template, fetchLatestDetails: false);
  }

  Future<TemplateItem?> _findRandomTemplate(
    _RandomTemplateSettings settings,
  ) async {
    if (!mounted || !_canUseVisibleTemplatesUi) {
      return null;
    }

    final mode = _randomModeForTemplateType(settings.type);

    setState(() {
      _isRandomTemplateLoading = true;
    });

    final hasPremiumAccess =
        ref.read(walletControllerProvider).wallet?.isPremium ?? false;
    final randomRepository = ref.read(templatesRepositoryProvider);
    _activeRandomTemplateRepository = randomRepository;

    try {
      final template = await randomRepository.fetchRandomTemplate(
        mode: mode,
        category: settings.category,
        includePremium: hasPremiumAccess,
        access: settings.access,
      );
      if (identical(_activeRandomTemplateRepository, randomRepository)) {
        _activeRandomTemplateRepository = null;
      }

      if (!mounted || !_canUseVisibleTemplatesUi) {
        return null;
      }

      return template;
    } catch (_) {
      rethrow;
    } finally {
      if (identical(_activeRandomTemplateRepository, randomRepository)) {
        _activeRandomTemplateRepository = null;
      }

      if (mounted && _canUseVisibleTemplatesUi) {
        setState(() {
          _isRandomTemplateLoading = false;
        });
      } else {
        _isRandomTemplateLoading = false;
      }
    }
  }

  bool get _canUseVisibleTemplatesUi =>
      mounted && _isAppResumed && _isTabActive == true;

  void _cancelPendingRandomTemplateRequest({bool clearLoadingState = true}) {
    final repository = _activeRandomTemplateRepository;
    _activeRandomTemplateRepository = null;
    repository?.cancelPendingRandomTemplateRequest();
    if (!_isRandomTemplateLoading) {
      return;
    }

    if (clearLoadingState && mounted) {
      setState(() {
        _isRandomTemplateLoading = false;
      });
      return;
    }

    _isRandomTemplateLoading = false;
  }

  Future<void> _startTemplateUploadFlow(
    TemplateItem template, {
    TemplateOfTheDayItem? templateOfTheDay,
  }) async {
    final petId = _routeQueryParameter(context, 'petId');
    final petPhotoId = _routeQueryParameter(context, 'petPhotoId');
    if (petId != null && petId.isNotEmpty) {
      await _startTemplateFromPetFlow(
        template,
        petId,
        petPhotoId: petPhotoId,
        templateOfTheDay: templateOfTheDay,
      );
      return;
    }

    while (mounted) {
      if (!ref.read(appLaunchControllerProvider).isAuthenticated) {
        await showAuthRequiredSheet(context);
        return;
      }

      final inputChoice = await _showTemplateInputChoiceSheet(context);
      if (!mounted || inputChoice == null) {
        return;
      }

      if (inputChoice == _TemplateInputChoice.myPets) {
        await _startFromMyPetsChoice(
          template,
          templateOfTheDay: templateOfTheDay,
        );
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
        final hasPremiumAccess =
            ref.read(walletControllerProvider).wallet?.isPremium ?? false;
        final blockerAction = await showTemplateBlockedSheet(
          context: context,
          template: template,
          gate: gate,
          hasPremiumAccess: hasPremiumAccess,
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

        final featured = templateOfTheDay;
        if (featured != null) {
          unawaited(
            _recordTemplateOfTheDayAnalytics(
              featured,
              'generation_failed',
              extraMetadata: <String, Object?>{
                if (errorMessage != null && errorMessage.isNotEmpty)
                  'error': errorMessage,
              },
            ),
          );
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

      final featured = templateOfTheDay;
      if (featured != null) {
        unawaited(
          _recordTemplateOfTheDayAnalytics(
            featured,
            'generation_started',
            generationId: generation.generationId,
          ),
        );
      }

      router.push(
        GenerationStatusPage.routeFor(generation.generationId),
        extra: featured,
      );
      return;
    }
  }

  Future<void> _startTemplateFromPetFlow(
    TemplateItem template,
    String petId, {
    String? petPhotoId,
    String? petName,
    bool showChangeAction = false,
    TemplateOfTheDayItem? templateOfTheDay,
  }) async {
    if (!ref.read(appLaunchControllerProvider).isAuthenticated) {
      await showAuthRequiredSheet(context);
      return;
    }

    final generationController = ref.read(
      templateGenerationControllerProvider.notifier,
    );
    final gate = await generationController.checkGate(template);
    if (!mounted) {
      return;
    }

    if (!gate.isAllowed) {
      final hasPremiumAccess =
          ref.read(walletControllerProvider).wallet?.isPremium ?? false;
      final blockerAction = await showTemplateBlockedSheet(
        context: context,
        template: template,
        gate: gate,
        hasPremiumAccess: hasPremiumAccess,
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

    final action = await showDialog<_PetGenerationConfirmAction>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          petName == null || petName.isEmpty
              ? 'Generate with pet'
              : 'Generate with $petName',
        ),
        content: Text('This generation costs ${template.tokenCost} PawSpark.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          if (showChangeAction)
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(_PetGenerationConfirmAction.change),
              child: const Text('Change'),
            ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(_PetGenerationConfirmAction.start),
            child: const Text('Start'),
          ),
        ],
      ),
    );
    if (!mounted || action == null) {
      return;
    }

    if (action == _PetGenerationConfirmAction.change) {
      context.push('/profile/pets');
      return;
    }

    if (action != _PetGenerationConfirmAction.start) {
      return;
    }

    try {
      final generation = await ref
          .read(templateGenerationRepositoryProvider)
          .startGenerationFromPet(
            petId: petId,
            petPhotoId: petPhotoId,
            templateId: template.templateId,
          );
      await ref
          .read(templateGenerationRepositoryProvider)
          .rememberActiveGeneration(generationId: generation.generationId);
      ref.invalidate(walletControllerProvider);
      if (!mounted) {
        return;
      }

      final featured = templateOfTheDay;
      if (featured != null) {
        unawaited(
          _recordTemplateOfTheDayAnalytics(
            featured,
            'generation_started',
            generationId: generation.generationId,
          ),
        );
      }

      context.go(
        GenerationStatusPage.routeFor(generation.generationId),
        extra: featured,
      );
    } on Object {
      if (!mounted) {
        return;
      }

      PetMagicToast.show(
        context,
        message: 'Добавьте фото питомца, чтобы начать',
        tone: PetMagicToastTone.warning,
      );
    }
  }

  Future<void> _startFromMyPetsChoice(
    TemplateItem template, {
    TemplateOfTheDayItem? templateOfTheDay,
  }) async {
    try {
      final pets = await ref
          .read(templateGenerationRepositoryProvider)
          .fetchPets();
      if (!mounted) {
        return;
      }

      if (pets.isEmpty) {
        PetMagicToast.show(
          context,
          message: 'Добавьте первого питомца',
          tone: PetMagicToastTone.info,
        );
        context.push('/profile/pets');
        return;
      }

      final selectedPet = pets.length == 1
          ? pets.first
          : await _showPetPickerSheet(context, pets);
      if (!mounted || selectedPet == null) {
        return;
      }

      await _startTemplateFromPetFlow(
        template,
        selectedPet.id,
        petName: selectedPet.name,
        showChangeAction: pets.length == 1,
        templateOfTheDay: templateOfTheDay,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      PetMagicToast.show(
        context,
        message: 'Could not load pets',
        tone: PetMagicToastTone.warning,
      );
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

  void _trackTemplateOfTheDayViewed(TemplateOfTheDayItem? featured) {
    if (featured == null) {
      return;
    }

    final key =
        '${featured.templateId}:${_templateOfTheDayDateValue(featured)}:templates';
    if (!_trackedTemplateOfTheDayViews.add(key)) {
      return;
    }

    _runAfterBuild(() {
      unawaited(_recordTemplateOfTheDayAnalytics(featured, 'viewed'));
    });
  }

  Future<void> _recordTemplateOfTheDayAnalytics(
    TemplateOfTheDayItem featured,
    String eventType, {
    String? generationId,
    Map<String, Object?>? extraMetadata,
  }) async {
    try {
      final wallet = ref.read(walletControllerProvider).wallet;
      await ref
          .read(templatesRepositoryProvider)
          .recordAnalyticsEvent(
            templateId: featured.templateId,
            eventType: eventType,
            source: featured.source,
            generationId: generationId,
            metadata: <String, Object?>{
              'templateId': featured.templateId,
              'type': featured.templateType.apiValue.toLowerCase(),
              'source': featured.source,
              'isPremium': featured.isPremium,
              'userPlan': wallet?.isPremium == true ? 'premium' : 'free',
              'date': _templateOfTheDayDateValue(featured),
              'screen': 'templates',
              ...?extraMetadata,
            },
          );
    } catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'Templates.TemplateOfTheDay',
        operation: 'analytics',
        message: 'Could not record Template of the Day analytics event.',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{
          'eventType': eventType,
          'templateId': featured.templateId,
        },
      );
    }
  }
}

Future<_TemplateInputChoice?> _showTemplateInputChoiceSheet(
  BuildContext context,
) {
  final colors = context.petMagicColors;
  return showPetMagicModalBottomSheet<_TemplateInputChoice>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext, bottomInset) => SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceStrong,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colors.border.withValues(alpha: 0.8)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 6),
              ListTile(
                leading: Icon(Icons.upload_file_rounded, color: colors.accent),
                title: Text(
                  'Upload',
                  style: TextStyle(color: colors.textStrong),
                ),
                onTap: () =>
                    Navigator.of(sheetContext).pop(_TemplateInputChoice.upload),
              ),
              ListTile(
                leading: Icon(Icons.pets_rounded, color: colors.accent),
                title: Text(
                  'Choose from My Pets',
                  style: TextStyle(color: colors.textStrong),
                ),
                onTap: () =>
                    Navigator.of(sheetContext).pop(_TemplateInputChoice.myPets),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<PetProfile?> _showPetPickerSheet(
  BuildContext context,
  List<PetProfile> pets,
) {
  final colors = context.petMagicColors;
  return showPetMagicModalBottomSheet<PetProfile>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext, bottomInset) => SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceStrong,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colors.border.withValues(alpha: 0.8)),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                for (final pet in pets)
                  ListTile(
                    leading: _PetShortcutAvatar(avatarUrl: pet.avatarUrl),
                    title: Text(
                      pet.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textStrong,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: Text(
                      [pet.type, pet.breed].whereType<String>().join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.textSoft),
                    ),
                    onTap: () => Navigator.of(sheetContext).pop(pet),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

typedef _RandomTemplateFinder =
    Future<TemplateItem?> Function(_RandomTemplateSettings settings);

Future<TemplateItem?> _showRandomTemplateSettingsSheet(
  BuildContext context, {
  required TemplateType? initialType,
  required String? initialCategory,
  required List<String> categories,
  required _RandomTemplateFinder onFind,
}) {
  return showPetMagicModalBottomSheet<TemplateItem>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.78,
    ),
    builder: (sheetContext, bottomInset) => _RandomTemplateSettingsSheet(
      initialType: initialType,
      initialCategory: initialCategory,
      categories: categories,
      bottomInset: bottomInset,
      onFind: onFind,
    ),
  );
}

class _RandomTemplateSettings {
  const _RandomTemplateSettings({
    required this.type,
    required this.category,
    required this.access,
  });

  final TemplateType? type;
  final String? category;
  final TemplateRandomAccess access;
}

enum _RandomTemplateSheetStatus { idle, loading, empty, error }

class _RandomTemplateSettingsSheet extends StatefulWidget {
  const _RandomTemplateSettingsSheet({
    required this.initialType,
    required this.initialCategory,
    required this.categories,
    required this.bottomInset,
    required this.onFind,
  });

  final TemplateType? initialType;
  final String? initialCategory;
  final List<String> categories;
  final double bottomInset;
  final _RandomTemplateFinder onFind;

  @override
  State<_RandomTemplateSettingsSheet> createState() =>
      _RandomTemplateSettingsSheetState();
}

class _RandomTemplateSettingsSheetState
    extends State<_RandomTemplateSettingsSheet> {
  late TemplateType? _type = widget.initialType;
  late String? _category = _normalizeRandomCategory(widget.initialCategory);
  TemplateRandomAccess _access = TemplateRandomAccess.available;
  _RandomTemplateSheetStatus _status = _RandomTemplateSheetStatus.idle;

  List<String> get _categories {
    final seen = <String>{};
    final result = <String>[];
    for (final category in widget.categories) {
      final normalized = _normalizeRandomCategory(category);
      if (normalized == null) {
        continue;
      }
      if (seen.add(normalized.toLowerCase())) {
        result.add(normalized);
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final isLoading = _status == _RandomTemplateSheetStatus.loading;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 0, 12, widget.bottomInset),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceGlass.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: colors.border.withValues(alpha: 0.78)),
            boxShadow: [
              BoxShadow(
                color: colors.shadow.withValues(alpha: 0.30),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.78,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 42,
                              height: 4,
                              decoration: BoxDecoration(
                                color: colors.border,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Icon(
                                Icons.casino_rounded,
                                color: colors.accent,
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  text.randomTemplateAction,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: colors.textStrong,
                                        fontWeight: FontWeight.w900,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            text.randomTemplateSheetDescription,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: colors.textSoft,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 16),
                          _RandomTemplateSection(
                            title: text.randomTemplateTypeLabel,
                            children: [
                              _RandomTemplateChip(
                                label: text.allFilter,
                                selected: _type == null,
                                enabled: !isLoading,
                                onTap: () => setState(() => _type = null),
                              ),
                              _RandomTemplateChip(
                                label: text.videosFilter,
                                icon: Icons.play_circle_outline_rounded,
                                selected: _type == TemplateType.video,
                                enabled: !isLoading,
                                onTap: () =>
                                    setState(() => _type = TemplateType.video),
                              ),
                              _RandomTemplateChip(
                                label: text.imagesFilter,
                                icon: Icons.image_outlined,
                                selected: _type == TemplateType.image,
                                enabled: !isLoading,
                                onTap: () =>
                                    setState(() => _type = TemplateType.image),
                              ),
                            ],
                          ),
                          _RandomTemplateSection(
                            title: text.randomTemplateCategoryLabel,
                            children: [
                              _RandomTemplateChip(
                                label: text.allFilter,
                                selected: _category == null,
                                enabled: !isLoading,
                                onTap: () => setState(() => _category = null),
                              ),
                              for (final category in _categories)
                                _RandomTemplateChip(
                                  label: category,
                                  selected: _category == category,
                                  enabled: !isLoading,
                                  onTap: () =>
                                      setState(() => _category = category),
                                ),
                            ],
                          ),
                          _RandomTemplateSection(
                            title: text.randomTemplateAccessLabel,
                            children: [
                              _RandomTemplateChip(
                                label: text.randomTemplateAccessAvailable,
                                selected:
                                    _access == TemplateRandomAccess.available,
                                enabled: !isLoading,
                                onTap: () => setState(
                                  () =>
                                      _access = TemplateRandomAccess.available,
                                ),
                              ),
                              _RandomTemplateChip(
                                label: text.randomTemplateAccessFree,
                                selected: _access == TemplateRandomAccess.free,
                                enabled: !isLoading,
                                onTap: () => setState(
                                  () => _access = TemplateRandomAccess.free,
                                ),
                              ),
                              _RandomTemplateChip(
                                label: text.randomTemplateAccessPremium,
                                selected:
                                    _access == TemplateRandomAccess.premium,
                                enabled: !isLoading,
                                onTap: () => setState(
                                  () => _access = TemplateRandomAccess.premium,
                                ),
                              ),
                            ],
                          ),
                          AnimatedSwitcher(
                            duration: AppTheme.motionFast,
                            child: _status == _RandomTemplateSheetStatus.empty
                                ? _RandomTemplateStatusMessage(
                                    key: const ValueKey('random-empty'),
                                    title: text.randomTemplateNoMatches,
                                    message: text.randomTemplateNoMatchesHint,
                                    actionLabel:
                                        text.randomTemplateResetFilters,
                                    onAction: _resetFilters,
                                  )
                                : _status == _RandomTemplateSheetStatus.error
                                ? _RandomTemplateStatusMessage(
                                    key: const ValueKey('random-error'),
                                    title: text.randomTemplateLoadFailed,
                                    message: text.randomTemplateNoMatchesHint,
                                    actionLabel: text.retryAction,
                                    onAction: _findRandomTemplate,
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: isLoading ? null : _findRandomTemplate,
                      icon: isLoading
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator.adaptive(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  colors.textStrong,
                                ),
                              ),
                            )
                          : const Icon(Icons.casino_rounded),
                      label: Text(
                        isLoading
                            ? text.randomTemplateFinding
                            : text.randomTemplateFindAction,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _findRandomTemplate() async {
    if (_status == _RandomTemplateSheetStatus.loading) {
      return;
    }

    setState(() => _status = _RandomTemplateSheetStatus.loading);
    try {
      final template = await widget.onFind(
        _RandomTemplateSettings(
          type: _type,
          category: _category,
          access: _access,
        ),
      );
      if (!mounted) {
        return;
      }
      if (template == null) {
        setState(() => _status = _RandomTemplateSheetStatus.empty);
        return;
      }
      Navigator.of(context).pop(template);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _status = _RandomTemplateSheetStatus.error);
    }
  }

  void _resetFilters() {
    setState(() {
      _type = null;
      _category = null;
      _access = TemplateRandomAccess.available;
      _status = _RandomTemplateSheetStatus.idle;
    });
  }
}

class _RandomTemplateSection extends StatelessWidget {
  const _RandomTemplateSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colors.textStrong,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: children),
        ],
      ),
    );
  }
}

class _RandomTemplateChip extends StatelessWidget {
  const _RandomTemplateChip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return PressableScale(
      enabled: enabled,
      onTap: enabled ? onTap : null,
      haptic: PressableScaleHaptic.selection,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: AppTheme.motionFast,
        curve: AppTheme.motionEmphasized,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [colors.accent, colors.gold.withValues(alpha: 0.82)],
                )
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colors.surfaceGlass,
                    colors.surface.withValues(alpha: 0.88),
                  ],
                ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? colors.accent
                : colors.border.withValues(alpha: 0.78),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: colors.accent.withValues(alpha: 0.20),
                    blurRadius: 14,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: selected ? Colors.white : colors.textStrong,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected ? Colors.white : colors.textStrong,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RandomTemplateStatusMessage extends StatelessWidget {
  const _RandomTemplateStatusMessage({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    super.key,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border.withValues(alpha: 0.72)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colors.textStrong,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            message,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.textSoft,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

String? _normalizeRandomCategory(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return normalized;
}

TemplateRandomMode _randomModeForTemplateType(TemplateType? type) {
  return switch (type) {
    null => TemplateRandomMode.any,
    TemplateType.image => TemplateRandomMode.image,
    TemplateType.video => TemplateRandomMode.video,
  };
}

TemplateItem? _findTemplateById(Iterable<TemplateItem> items, String id) {
  final normalizedId = id.trim();
  if (normalizedId.isEmpty) {
    return null;
  }

  for (final item in items) {
    if (item.templateId == normalizedId) {
      return item;
    }
  }

  return null;
}

String? _routeQueryParameter(BuildContext context, String key) {
  try {
    final value = GoRouterState.of(context).uri.queryParameters[key];
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  } catch (_) {
    return null;
  }
}

String _templatesPetShortcutLocation({
  required String petId,
  required String? selectedPetId,
  required String? selectedPetPhotoId,
}) {
  final keepSelectedPhoto =
      selectedPetId == petId &&
      selectedPetPhotoId != null &&
      selectedPetPhotoId.isNotEmpty;
  return Uri(
    path: TemplatesPage.routePath,
    queryParameters: {
      'petId': petId,
      if (keepSelectedPhoto) 'petPhotoId': selectedPetPhotoId,
    },
  ).toString();
}

class _TemplateGridEntry {
  const _TemplateGridEntry({required this.template, this.templateOfTheDay});

  final TemplateItem template;
  final TemplateOfTheDayItem? templateOfTheDay;
}

_TemplateGridEntry? _buildFeaturedTemplateGridEntry({
  required TemplateOfTheDayItem? templateOfTheDay,
  required List<TemplateItem> visibleTemplates,
  required TemplateType? selectedType,
  required String? selectedCategory,
  required String? searchQuery,
}) {
  final featured = templateOfTheDay;
  if (featured == null ||
      !_matchesTemplateOfTheDayFilters(
        featured,
        selectedType: selectedType,
        selectedCategory: selectedCategory,
        searchQuery: searchQuery,
      )) {
    return null;
  }

  return _TemplateGridEntry(
    template: _mergeFeaturedTemplateWithVisibleItem(
      featured: featured,
      visibleTemplate: _findTemplateById(visibleTemplates, featured.templateId),
    ),
    templateOfTheDay: featured,
  );
}

TemplateItem _mergeFeaturedTemplateWithVisibleItem({
  required TemplateOfTheDayItem featured,
  required TemplateItem? visibleTemplate,
}) {
  final fallbackTemplate = featured.toFallbackTemplateItem();
  final template = visibleTemplate;
  if (template == null) {
    return fallbackTemplate;
  }

  return TemplateItem(
    templateId: template.templateId,
    templateType: template.templateType,
    title: featured.title.trim().isEmpty ? template.title : featured.title,
    shortDescription: featured.subtitle.trim().isEmpty
        ? template.shortDescription
        : featured.subtitle,
    petPhotoRequirements: template.petPhotoRequirements,
    category: featured.category.trim().isEmpty
        ? template.category
        : featured.category,
    tags: featured.tags.isNotEmpty ? featured.tags : template.tags,
    isPremium: featured.isPremium || template.isPremium,
    tokenCost: template.tokenCost,
    effectivePromoBadge: template.effectivePromoBadge,
    thumbnailUrl: template.thumbnailUrl ?? fallbackTemplate.thumbnailUrl,
    previewAsset: template.previewAsset ?? fallbackTemplate.previewAsset,
    musicDescription: template.musicDescription,
    referenceVideoDurationSeconds: template.referenceVideoDurationSeconds,
    supportsGenerationResultInput: template.supportsGenerationResultInput,
    requiredInputMediaType: template.requiredInputMediaType,
    recommendedAfterImageGeneration: template.recommendedAfterImageGeneration,
    supportsGenerateSimilar: template.supportsGenerateSimilar,
    defaultVariationStrength: template.defaultVariationStrength,
    version: template.version,
    updatedAtUtc: template.updatedAtUtc,
  );
}

bool _matchesTemplateOfTheDayFilters(
  TemplateOfTheDayItem template, {
  required TemplateType? selectedType,
  required String? selectedCategory,
  required String? searchQuery,
}) {
  if (selectedType != null && template.templateType != selectedType) {
    return false;
  }

  final normalizedCategory = selectedCategory?.trim().toLowerCase();
  if (normalizedCategory != null &&
      normalizedCategory.isNotEmpty &&
      template.category.trim().toLowerCase() != normalizedCategory) {
    return false;
  }

  final normalizedSearch = searchQuery?.trim().toLowerCase();
  if (normalizedSearch == null || normalizedSearch.isEmpty) {
    return true;
  }

  return [
        template.title,
        template.subtitle,
        template.category,
        ...template.tags,
      ]
      .map((value) => value.trim().toLowerCase())
      .any((value) => value.contains(normalizedSearch));
}

DateTime _templateOfTheDayCountdownTarget(TemplateOfTheDayItem featured) {
  return featured.expiresAtUtc?.toUtc() ??
      DateTime.utc(
        featured.date.year,
        featured.date.month,
        featured.date.day + 1,
      );
}

String _templateCardIdentity({
  required TemplateItem template,
  TemplateOfTheDayItem? featured,
}) {
  return featured == null
      ? '${template.templateId}|${template.mediaIdentity}'
      : '${template.templateId}|featured|${template.mediaIdentity}|${_templateOfTheDayDateValue(featured)}';
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

  return text.templatesRequestFailedError;
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

  return text.templateFlowStartFailedError;
}

bool _isAuthRequiredError(String? raw) {
  if (raw == null || raw.isEmpty) {
    return false;
  }

  return raw.contains('auth.sign_in_required') ||
      raw.contains('auth.session_expired');
}

String _templateOfTheDayDateValue(TemplateOfTheDayItem featured) {
  final date = featured.date.toUtc();
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

class _TemplatesLifecycleObserver with WidgetsBindingObserver {
  _TemplatesLifecycleObserver({required this.onStateChanged});

  final ValueChanged<AppLifecycleState> onStateChanged;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    onStateChanged(state);
  }
}

class _TemplateFeedSlivers extends ConsumerWidget {
  const _TemplateFeedSlivers({
    required this.bottomInset,
    required this.templateOfTheDay,
    required this.selectedType,
    required this.selectedCategory,
    required this.searchQuery,
    required this.onTemplateSelected,
    required this.onTemplateOfTheDaySelected,
  });

  final double bottomInset;
  final TemplateOfTheDayItem? templateOfTheDay;
  final TemplateType? selectedType;
  final String? selectedCategory;
  final String? searchQuery;
  final ValueChanged<TemplateItem> onTemplateSelected;
  final ValueChanged<TemplateOfTheDayItem> onTemplateOfTheDaySelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      templatesControllerProvider.select(
        (state) => (
          items: state.items,
          isInitialLoading: state.isInitialLoading,
          isEmpty: state.isEmpty,
          isLoadingMore: state.isLoadingMore,
          errorMessage: state.errorMessage,
        ),
      ),
    );
    final hasPremiumAccess = ref.watch(
      walletControllerProvider.select(
        (walletState) => walletState.wallet?.isPremium ?? false,
      ),
    );
    final controller = ref.read(templatesControllerProvider.notifier);
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;

    if (state.isInitialLoading) {
      return const SliverMagicLoadingScreen();
    }

    if (state.errorMessage != null && state.items.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _StateMessage(
          icon: Icons.cloud_off_rounded,
          title: text.templatesErrorTitle,
          message: _mapTemplatesError(text, state.errorMessage!),
          actionLabel: text.retryAction,
          onAction: () => controller.loadInitial(forceRefresh: true),
        ),
      );
    }

    if (state.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _StateMessage(
          icon: Icons.auto_awesome_motion_rounded,
          title: text.emptyTemplatesTitle,
          message: text.emptyTemplatesMessage,
          actionLabel: text.retryAction,
          onAction: () => controller.loadInitial(forceRefresh: true),
        ),
      );
    }

    final featuredEntry = _buildFeaturedTemplateGridEntry(
      templateOfTheDay: templateOfTheDay,
      visibleTemplates: state.items,
      selectedType: selectedType,
      selectedCategory: selectedCategory,
      searchQuery: searchQuery,
    );
    final visibleEntries = <_TemplateGridEntry>[
      if (featuredEntry != null) featuredEntry,
      for (final template in state.items)
        if (template.templateId != templateOfTheDay?.templateId)
          _TemplateGridEntry(template: template),
    ];

    return SliverMainAxisGroup(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
          sliver: SliverLayoutBuilder(
            builder: (context, constraints) {
              final logicalCardWidth = (constraints.crossAxisExtent - 5) / 2;
              final imageCacheWidth =
                  templateCardImageCacheWidthForLogicalWidth(
                    logicalCardWidth,
                    MediaQuery.devicePixelRatioOf(context),
                  );

              return SliverGrid.builder(
                itemCount: visibleEntries.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 5,
                  mainAxisSpacing: 6,
                  childAspectRatio: 0.72,
                ),
                itemBuilder: (context, index) {
                  final entry = visibleEntries[index];
                  final template = entry.template;
                  final featured = entry.templateOfTheDay;
                  final templateIdentity = _templateCardIdentity(
                    template: template,
                    featured: featured,
                  );
                  final card = TemplateCard(
                    key: ValueKey(templateIdentity),
                    template: template,
                    hasPremiumAccess: hasPremiumAccess,
                    imageCacheWidth: imageCacheWidth,
                    highlightBadgeLabel: featured != null
                        ? text.templateOfTheDayFeedBadge
                        : null,
                    featuredData: featured == null
                        ? null
                        : TemplateCardFeaturedData(
                            badgeLabel: text.templateOfTheDayFeedBadge,
                            actionLabel: text.templateOfTheDayTryAction,
                            countdownTarget: _templateOfTheDayCountdownTarget(
                              featured,
                            ),
                            popularityCount: featured.popularityCount,
                            isNew: featured.isNew,
                          ),
                    onPressed: () => featured != null
                        ? onTemplateOfTheDaySelected(featured)
                        : onTemplateSelected(template),
                  );
                  if (index >= 6) {
                    return card;
                  }

                  return TweenAnimationBuilder<double>(
                    key: ValueKey('template-item-$templateIdentity'),
                    tween: Tween(begin: 0, end: 1),
                    duration: Duration(milliseconds: 130 + (index % 6) * 20),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      final clamped = value.clamp(0.0, 1.0);
                      return Opacity(
                        opacity: clamped,
                        child: Transform.translate(
                          offset: Offset(0, (1 - clamped) * 8),
                          child: child,
                        ),
                      );
                    },
                    child: card,
                  );
                },
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
    );
  }
}

class _TemplatesTopBarSlot extends ConsumerWidget {
  const _TemplatesTopBarSlot({
    required this.onAuthPressed,
    required this.onRewardsPressed,
    required this.onTopUpPressed,
    required this.onWalletPressed,
  });

  final VoidCallback onAuthPressed;
  final VoidCallback onRewardsPressed;
  final VoidCallback onTopUpPressed;
  final VoidCallback onWalletPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokenBalance = ref.watch(
      walletControllerProvider.select(
        (walletState) => walletState.wallet?.balance ?? 0,
      ),
    );
    final isAuthenticated = ref.watch(
      appLaunchControllerProvider.select(
        (launchState) => launchState.isAuthenticated,
      ),
    );

    return _TopBar(
      isAuthenticated: isAuthenticated,
      tokenBalance: tokenBalance,
      onAuthPressed: onAuthPressed,
      onRewardsPressed: onRewardsPressed,
      onTopUpPressed: onTopUpPressed,
      onWalletPressed: onWalletPressed,
    );
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _HeaderActionSurface(
            onPressed: onPressed,
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
            child: _HeaderActionSurface(
              onPressed: onAddPressed,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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

    return _HeaderActionSurface(
      onPressed: onPressed,
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
    );
  }
}

class _TemplateOfTheDayCard extends StatelessWidget {
  const _TemplateOfTheDayCard({
    required this.template,
    required this.hasPremiumAccess,
    required this.onPressed,
    super.key,
  });

  final TemplateOfTheDayItem template;
  final bool hasPremiumAccess;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final thumbnailUrl = _normalizeTemplateOfTheDayMediaUrl(
      template.thumbnailUrl,
    );
    final previewMediaUrl = _normalizeTemplateOfTheDayMediaUrl(
      template.previewMediaUrl ?? template.previewAsset?.url,
    );
    final videoPreviewUrl =
        template.isVideo &&
            previewMediaUrl != null &&
            isVideoUrl(previewMediaUrl)
        ? previewMediaUrl
        : null;
    final imageUrl =
        thumbnailUrl ?? (!template.isVideo ? previewMediaUrl : null);
    final isPremiumLocked = template.isPremium && !hasPremiumAccess;
    final visibleTags = template.tags.take(3).toList(growable: false);
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxWidth < 340 ? 208.0 : 232.0;
        return PetMagicInteractiveSurface(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(22),
          scaleDown: 0.985,
          child: SizedBox(
            height: height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: colors.accent.withValues(alpha: 0.5)),
                boxShadow: [
                  BoxShadow(
                    color: colors.accent.withValues(
                      alpha: isLight ? 0.14 : 0.2,
                    ),
                    blurRadius: 24,
                    offset: const Offset(0, 14),
                  ),
                ],
                color: colors.backgroundBottom,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(21),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imageUrl != null || videoPreviewUrl != null)
                      Positioned.fill(
                        child: LayoutBuilder(
                          builder: (context, mediaConstraints) {
                            final cacheWidth = _templateMediaCacheDimension(
                              mediaConstraints.maxWidth,
                              MediaQuery.devicePixelRatioOf(context),
                            );

                            if (videoPreviewUrl != null) {
                              return _TemplateOfTheDayVideoPreview(
                                previewUrl: videoPreviewUrl,
                                thumbnailUrl: thumbnailUrl,
                                cacheWidth: cacheWidth,
                              );
                            }

                            if (imageUrl != null) {
                              return TemplatePreviewImage(
                                imageUrl: imageUrl,
                                cacheWidth: cacheWidth,
                                fit: BoxFit.cover,
                                placeholder:
                                    const _TemplateOfTheDayMediaFallback(),
                                errorBuilder: (_) =>
                                    const _TemplateOfTheDayMediaFallback(),
                              );
                            }

                            return const _TemplateOfTheDayMediaFallback();
                          },
                        ),
                      )
                    else
                      const _TemplateOfTheDayMediaFallback(),
                    const _TemplateOfTheDayDarkOverlay(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(13, 12, 13, 13),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 6,
                            runSpacing: 5,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _TemplateOfTheDayBadge(
                                icon: Icons.auto_awesome_rounded,
                                label: template.badgeText.trim().isEmpty
                                    ? text.templateOfTheDayTitle
                                    : template.badgeText,
                              ),
                              _TemplateOfTheDayBadge(
                                icon: template.isVideo
                                    ? Icons.play_circle_outline_rounded
                                    : Icons.image_outlined,
                                label: template.isVideo
                                    ? text.videoLabel
                                    : text.imageLabel,
                                isSubtle: true,
                              ),
                              if (template.isPremium)
                                _TemplateOfTheDayBadge(
                                  icon: Icons.workspace_premium_rounded,
                                  label: text.premiumLabel,
                                  isPremium: true,
                                ),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            template.title.trim().isEmpty
                                ? text.templateOfTheDaySubtitle
                                : template.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontSize: constraints.maxWidth < 340
                                      ? 17
                                      : 18.5,
                                  height: 1.03,
                                  fontWeight: FontWeight.w900,
                                  shadows: const [
                                    Shadow(
                                      color: Color.fromRGBO(0, 0, 0, 0.74),
                                      blurRadius: 18,
                                      offset: Offset(0, 5),
                                    ),
                                  ],
                                ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            template.subtitle.trim().isEmpty
                                ? text.templateOfTheDaySubtitle
                                : template.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.88),
                                  fontSize: 11.2,
                                  height: 1.16,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          if (visibleTags.isNotEmpty) ...[
                            const SizedBox(height: 7),
                            _TemplateOfTheDayTags(tags: visibleTags),
                          ],
                          const SizedBox(height: 9),
                          Wrap(
                            spacing: 8,
                            runSpacing: 7,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (template.tokenCost > 0)
                                _TemplateOfTheDayCostChip(
                                  cost: template.tokenCost,
                                ),
                              _TemplateOfTheDayAction(
                                label: isPremiumLocked
                                    ? text.templateUnlockPremiumAction
                                    : text.templateOfTheDayTryAction,
                                isPremium: template.isPremium,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TemplateOfTheDayDarkOverlay extends StatelessWidget {
  const _TemplateOfTheDayDarkOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.2),
              Colors.black.withValues(alpha: 0.08),
              Colors.black.withValues(alpha: 0.58),
              Colors.black.withValues(alpha: 0.9),
            ],
            stops: const [0, 0.34, 0.72, 1],
          ),
        ),
      ),
    );
  }
}

class _TemplateOfTheDayTags extends StatelessWidget {
  const _TemplateOfTheDayTags({required this.tags});

  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 22,
      child: ClipRect(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: Row(
            children: [
              for (var index = 0; index < tags.length; index++) ...[
                if (index > 0) const SizedBox(width: 6),
                _TemplateOfTheDayTag(label: tags[index]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TemplateOfTheDayTag extends StatelessWidget {
  const _TemplateOfTheDayTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        child: Text(
          '#$label',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _TemplateOfTheDayCostChip extends StatelessWidget {
  const _TemplateOfTheDayCostChip({required this.cost});

  final int cost;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.44),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PawSparkIcon(size: 13),
            const SizedBox(width: 5),
            Text(
              '$cost PawSpark',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10.2,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateOfTheDayVideoPreview extends StatefulWidget {
  const _TemplateOfTheDayVideoPreview({
    required this.previewUrl,
    required this.thumbnailUrl,
    required this.cacheWidth,
  });

  final String previewUrl;
  final String? thumbnailUrl;
  final int? cacheWidth;

  @override
  State<_TemplateOfTheDayVideoPreview> createState() =>
      _TemplateOfTheDayVideoPreviewState();
}

class _TemplateOfTheDayVideoPreviewState
    extends State<_TemplateOfTheDayVideoPreview>
    with WidgetsBindingObserver {
  static const double _loadVisibilityFraction = 0.18;
  static const double _playVisibilityFraction = 0.58;

  final Key _visibilityKey = UniqueKey();
  VideoPlayerController? _controller;
  bool _controllerInitInFlight = false;
  bool _failedToLoad = false;
  bool _isVisibleEnoughToLoad = false;
  bool _shouldPlay = false;
  bool _hasPreviewSlot = false;
  int _initializeRequestVersion = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant _TemplateOfTheDayVideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.previewUrl != widget.previewUrl) {
      _failedToLoad = false;
      unawaited(_disposeVideoController());
      if (_isVisibleEnoughToLoad) {
        unawaited(_initialize());
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_isVisibleEnoughToLoad &&
          _controller == null &&
          !_controllerInitInFlight &&
          !_failedToLoad) {
        unawaited(_initialize());
      }
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_disposeVideoController());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _initializeRequestVersion++;
    _controllerInitInFlight = false;
    _releasePreviewSlot();
    final controller = _controller;
    _controller = null;
    unawaited(controller?.dispose());
    super.dispose();
  }

  void _handleVisibilityChanged(VisibilityInfo info) {
    final visibleFraction = info.visibleFraction;
    final shouldLoad = visibleFraction >= _loadVisibilityFraction;
    final shouldPlay = visibleFraction >= _playVisibilityFraction;
    if (shouldLoad == _isVisibleEnoughToLoad && shouldPlay == _shouldPlay) {
      return;
    }

    _isVisibleEnoughToLoad = shouldLoad;
    _shouldPlay = shouldPlay;

    if (!shouldLoad) {
      unawaited(_disposeVideoController());
      return;
    }

    if (_controller == null && !_controllerInitInFlight && !_failedToLoad) {
      unawaited(_initialize());
      return;
    }

    unawaited(_syncPlaybackState());
  }

  Future<void> _initialize() async {
    if (!_isVisibleEnoughToLoad || _controllerInitInFlight) {
      return;
    }

    final requestVersion = ++_initializeRequestVersion;
    final previewUrl = widget.previewUrl;
    final safeUri = parseSafeGenerationMediaUri(previewUrl);
    if (safeUri == null) {
      if (mounted) {
        setState(() => _failedToLoad = true);
      }
      return;
    }

    _controllerInitInFlight = true;
    if (!MediaLifecyclePolicy.tryAcquireVideoPreviewSlot()) {
      _controllerInitInFlight = false;
      return;
    }
    _hasPreviewSlot = true;
    if (mounted) {
      setState(() => _failedToLoad = false);
    }

    VideoPlayerController? controller;
    try {
      controller = await createCachedTemplatePreviewVideoController(
        previewUrl,
        fallbackUri: safeUri,
      );
      if (!_isCurrentVideoRequestToken(requestVersion, previewUrl)) {
        await controller.dispose();
        _releasePreviewSlot();
        return;
      }

      await controller.setVolume(0);
      await controller.setLooping(true);
      if (!_isCurrentVideoRequestToken(requestVersion, previewUrl)) {
        await controller.dispose();
        _releasePreviewSlot();
        return;
      }

      await controller.initialize();
      if (!_isCurrentVideoRequestToken(requestVersion, previewUrl)) {
        await controller.dispose();
        _releasePreviewSlot();
        return;
      }

      _controller = controller;
      await _syncPlaybackState();
      if (!_isCurrentVideoRequest(requestVersion, previewUrl, controller)) {
        if (_controller == controller) {
          _controller = null;
        }
        await controller.dispose();
        _releasePreviewSlot();
        return;
      }

      setState(() => _failedToLoad = false);
    } catch (_) {
      await controller?.dispose();
      if (_isCurrentVideoRequestToken(requestVersion, previewUrl)) {
        _releasePreviewSlot();
        setState(() {
          if (_controller == controller) {
            _controller = null;
          }
          _failedToLoad = true;
        });
      }
    } finally {
      if (mounted && requestVersion == _initializeRequestVersion) {
        _controllerInitInFlight = false;
      }
    }
  }

  Future<void> _disposeVideoController() async {
    _initializeRequestVersion++;
    _controllerInitInFlight = false;
    _releasePreviewSlot();
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      try {
        await controller.pause();
      } catch (_) {
        // Best effort: the platform controller may already be gone.
      }
      await controller.dispose();
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _releasePreviewSlot() {
    if (!_hasPreviewSlot) {
      return;
    }

    MediaLifecyclePolicy.releaseVideoPreviewSlot();
    _hasPreviewSlot = false;
  }

  Future<void> _syncPlaybackState() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    try {
      if (_shouldPlay && !controller.value.isPlaying) {
        await controller.play();
      } else if (!_shouldPlay && controller.value.isPlaying) {
        await controller.pause();
      }
    } catch (_) {
      return;
    }

    if (mounted) {
      setState(() {});
    }
  }

  bool _isCurrentVideoRequestToken(int requestVersion, String previewUrl) {
    return mounted &&
        requestVersion == _initializeRequestVersion &&
        widget.previewUrl == previewUrl;
  }

  bool _isCurrentVideoRequest(
    int requestVersion,
    String previewUrl,
    VideoPlayerController? controller,
  ) {
    return _isCurrentVideoRequestToken(requestVersion, previewUrl) &&
        _controller == controller;
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return VisibilityDetector(
      key: _visibilityKey,
      onVisibilityChanged: _handleVisibilityChanged,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _TemplateOfTheDayVideoFallback(
            thumbnailUrl: widget.thumbnailUrl,
            cacheWidth: widget.cacheWidth,
          ),
          if (!_failedToLoad &&
              controller != null &&
              controller.value.isInitialized)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller.value.size.width,
                height: controller.value.size.height,
                child: VideoPlayer(controller),
              ),
            ),
        ],
      ),
    );
  }
}

class _TemplateOfTheDayVideoFallback extends StatelessWidget {
  const _TemplateOfTheDayVideoFallback({
    required this.thumbnailUrl,
    required this.cacheWidth,
  });

  final String? thumbnailUrl;
  final int? cacheWidth;

  @override
  Widget build(BuildContext context) {
    final url = thumbnailUrl;
    if (url == null || url.isEmpty) {
      return const _TemplateOfTheDayMediaFallback();
    }

    return TemplatePreviewImage(
      imageUrl: url,
      cacheWidth: cacheWidth,
      fit: BoxFit.cover,
      placeholder: const _TemplateOfTheDayMediaFallback(),
      errorBuilder: (_) => const _TemplateOfTheDayMediaFallback(),
    );
  }
}

class _TemplateOfTheDayMediaFallback extends StatelessWidget {
  const _TemplateOfTheDayMediaFallback();

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.accent.withValues(alpha: 0.26),
            colors.surfaceStrong.withValues(alpha: 0.4),
          ],
        ),
      ),
      child: Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 28),
          child: Icon(
            Icons.auto_awesome_rounded,
            color: colors.accent.withValues(alpha: 0.72),
            size: 42,
          ),
        ),
      ),
    );
  }
}

class _TemplateOfTheDayBadge extends StatelessWidget {
  const _TemplateOfTheDayBadge({
    required this.icon,
    required this.label,
    this.isSubtle = false,
    this.isPremium = false,
  });

  final IconData icon;
  final String label;
  final bool isSubtle;
  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final background = isPremium
        ? const Color(0xFFEFC35C).withValues(alpha: 0.9)
        : isSubtle
        ? colors.surfaceStrong.withValues(alpha: 0.72)
        : colors.accent.withValues(alpha: 0.9);
    final foreground = isPremium || !isSubtle
        ? const Color(0xFF062316)
        : colors.textStrong;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border.withValues(alpha: 0.48)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: foreground),
            const SizedBox(width: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateOfTheDayAction extends StatelessWidget {
  const _TemplateOfTheDayAction({required this.label, required this.isPremium});

  final String label;
  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final textColor = isPremium ? const Color(0xFF251102) : Colors.white;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 190),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isPremium ? const Color(0xFFEFC35C) : colors.accent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_forward_rounded, size: 13, color: textColor),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _templateOfTheDayLoadErrorLabel(BuildContext context) {
  return Localizations.localeOf(context).languageCode == 'ru'
      ? 'Не удалось загрузить шаблон дня'
      : 'Could not load Template of the Day';
}

String? _normalizeTemplateOfTheDayMediaUrl(String? rawUrl) {
  final trimmed = rawUrl?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }

  final sanitized = Uri.encodeFull(trimmed.replaceAll('\\', '/'));
  final parsed = Uri.tryParse(sanitized);
  final String candidate;
  if (parsed?.hasScheme == true) {
    candidate = parsed.toString();
  } else if (sanitized.startsWith('//')) {
    final baseUri = Uri.tryParse(AppConfig.apiBaseUrl);
    final scheme = (baseUri?.scheme.isNotEmpty ?? false)
        ? baseUri!.scheme
        : 'http';
    candidate = '$scheme:$sanitized';
  } else {
    final baseUri = Uri.tryParse(AppConfig.apiBaseUrl);
    if (baseUri == null) {
      return null;
    }

    final relativePath = sanitized.startsWith('/') ? sanitized : '/$sanitized';
    candidate = baseUri.resolve(relativePath).toString();
  }

  return parseSafeGenerationMediaUri(candidate)?.toString();
}

int? _templateMediaCacheDimension(double logicalSize, double pixelRatio) {
  if (!logicalSize.isFinite || logicalSize <= 0) {
    return null;
  }

  return (logicalSize * pixelRatio).ceil();
}

class _CreateWithPetBlockSlot extends ConsumerWidget {
  const _CreateWithPetBlockSlot({
    required this.selectedPetId,
    required this.selectedPetPhotoId,
  });

  final String? selectedPetId;
  final String? selectedPetPhotoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _CreateWithPetBlock(
      pets: ref.watch(_templateHomePetsProvider),
      selectedPetId: selectedPetId,
      selectedPetPhotoId: selectedPetPhotoId,
    );
  }
}

class _CreateWithPetBlock extends StatelessWidget {
  const _CreateWithPetBlock({
    required this.pets,
    required this.selectedPetId,
    required this.selectedPetPhotoId,
  });

  final AsyncValue<List<PetProfile>> pets;
  final String? selectedPetId;
  final String? selectedPetPhotoId;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final labelStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: colors.textStrong,
      fontSize: 12,
      fontWeight: FontWeight.w800,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border.withValues(alpha: 0.62)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Создать с питомцем', style: labelStyle),
            const SizedBox(height: 8),
            pets.when(
              loading: () => const SizedBox(
                height: 34,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                  ),
                ),
              ),
              error: (_, _) => _PetShortcutButton(
                label: 'Add pet',
                isSelected: false,
                onPressed: () => context.push('/profile/pets'),
              ),
              data: (items) {
                final visiblePets = items.take(2).toList(growable: false);
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      for (final pet in visiblePets) ...[
                        _PetShortcutButton(
                          label: pet.name,
                          avatarUrl: pet.avatarUrl,
                          isSelected: selectedPetId == pet.id,
                          onPressed: () => context.go(
                            _templatesPetShortcutLocation(
                              petId: pet.id,
                              selectedPetId: selectedPetId,
                              selectedPetPhotoId: selectedPetPhotoId,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      _PetShortcutButton(
                        label: 'Add pet',
                        isSelected: false,
                        icon: Icons.add_rounded,
                        onPressed: () => context.push('/profile/pets'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PetShortcutButton extends StatelessWidget {
  const _PetShortcutButton({
    required this.label,
    required this.isSelected,
    required this.onPressed,
    this.avatarUrl,
    this.icon,
  });

  final String label;
  final String? avatarUrl;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final background = isSelected
        ? colors.accent.withValues(alpha: 0.18)
        : colors.surface.withValues(alpha: 0.82);
    final border = isSelected
        ? colors.accent
        : colors.border.withValues(alpha: 0.56);

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onPressed,
      child: Container(
        height: 34,
        padding: const EdgeInsets.fromLTRB(4, 3, 11, 3),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PetShortcutAvatar(avatarUrl: avatarUrl, icon: icon),
            const SizedBox(width: 7),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 96),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.textStrong,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const int _petShortcutAvatarCacheWidth = 64;

class _PetShortcutAvatar extends StatelessWidget {
  const _PetShortcutAvatar({this.avatarUrl, this.icon});

  final String? avatarUrl;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final iconData = icon ?? Icons.pets_rounded;
    final url = avatarUrl;

    if (url != null && url.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: url,
          width: 26,
          height: 26,
          fit: BoxFit.cover,
          memCacheWidth: _petShortcutAvatarCacheWidth,
          maxWidthDiskCache: _petShortcutAvatarCacheWidth,
          filterQuality: FilterQuality.medium,
          errorWidget: (_, _, _) => _PetShortcutIcon(iconData: iconData),
        ),
      );
    }

    return _PetShortcutIcon(iconData: iconData, color: colors.accent);
  }
}

class _PetShortcutIcon extends StatelessWidget {
  const _PetShortcutIcon({required this.iconData, this.color});

  final IconData iconData;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Icon(iconData, size: 15, color: color ?? colors.textStrong),
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
      key: const ValueKey('templates-search-field'),
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

class _FloatingRandomTemplateButton extends StatelessWidget {
  const _FloatingRandomTemplateButton({
    required this.isLoading,
    required this.isEnabled,
    required this.onPressed,
  });

  final bool isLoading;
  final bool isEnabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final avoidBlur = PerformanceGuard.shouldAvoidBlur(context);
    final enabled = isEnabled && !isLoading;

    return RepaintBoundary(
      child: Tooltip(
        message: text.randomTemplateAction,
        child: Semantics(
          button: true,
          enabled: enabled,
          label: text.randomTemplateAction,
          child: AnimatedOpacity(
            duration: AppTheme.motionFast,
            opacity: enabled ? 1 : 0.4,
            child: PressableScale(
              enabled: enabled,
              onTap: enabled ? onPressed : null,
              haptic: PressableScaleHaptic.selection,
              borderRadius: BorderRadius.circular(24),
              scaleDown: 0.96,
              child: ClipOval(
                child: _FloatingRandomTemplateSurface(
                  isLight: isLight,
                  colors: colors,
                  avoidBlur: avoidBlur,
                  isLoading: isLoading,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingRandomTemplateSurface extends StatelessWidget {
  const _FloatingRandomTemplateSurface({
    required this.isLight,
    required this.colors,
    required this.avoidBlur,
    required this.isLoading,
  });

  final bool isLight;
  final PetMagicColors colors;
  final bool avoidBlur;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final content = DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.surfaceGlass.withValues(alpha: isLight ? 0.92 : 0.74),
        border: Border.all(
          color: colors.accent.withValues(alpha: isLight ? 0.72 : 0.64),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: colors.accent.withValues(alpha: 0.22),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: SizedBox(
        key: const ValueKey('templates-random-floating-button'),
        width: 48,
        height: 48,
        child: Center(
          child: AnimatedSwitcher(
            duration: AppTheme.motionFast,
            child: isLoading
                ? SizedBox(
                    key: const ValueKey('random-template-loading'),
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator.adaptive(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
                    ),
                  )
                : Icon(
                    Icons.casino_rounded,
                    key: const ValueKey('random-template-icon'),
                    size: 22,
                    color: isLight ? colors.accent : colors.textStrong,
                  ),
          ),
        ),
      ),
    );

    if (avoidBlur) {
      return content;
    }

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: content,
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
    final bottomInset = petMagicBottomNavInset(
      context,
      extraSpacing: kPetMagicBottomContentInsetRelaxed,
    );

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

class _HeaderActionSurface extends StatelessWidget {
  const _HeaderActionSurface({required this.onPressed, required this.child});

  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PetMagicInteractiveSurface(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(22),
      scaleDown: 0.97,
      child: child,
    );
  }
}
