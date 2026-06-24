// ignore_for_file: unused_element, unused_element_parameter, use_null_aware_elements

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/permissions/app_permission_coordinator.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/pets/presentation/pet_profile_providers.dart';
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
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_type_filters.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/create_with_pet_block.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/pet_generation_launch_sheet.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/random_template_sheet.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/templates_search_and_fab.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/templates_top_bar.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_controller.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_page.dart';
import 'package:petmagic_mobile/shared/loading/magic_loading_screen.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_modal_sheet.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_shell.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_async_state_view.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_haptics.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_toast.dart';

enum _TemplateInputChoice { upload, myPets }

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
              cacheExtent: _gridCacheExtent,
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
                          TemplatesTopBarSlot(
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
                          CreateWithPetBlockSlot(
                            selectedPetId: selectedPetId,
                            selectedPetPhotoId: selectedPetPhotoId,
                          ),
                          const SizedBox(height: 5),
                          TemplatesSearchField(
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
            child: FloatingRandomTemplateButton(
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
    final template = await showRandomTemplateSettingsSheet(
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
    RandomTemplateSettings settings,
  ) async {
    if (!mounted || !_canUseVisibleTemplatesUi) {
      return null;
    }

    final mode = randomModeForTemplateType(settings.type);

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
    final text = AppLocalizations.of(context);
    if (!ref.read(appLaunchControllerProvider).isAuthenticated) {
      await showAuthRequiredSheet(
        context,
        title: text.petsAuthRequiredTitle,
        message: text.petsAuthRequiredMessage,
        showSignUp: true,
      );
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

    final action = await showPetGenerationLaunchSheet(
      context: context,
      template: template,
      petId: petId,
      initialPetPhotoId: petPhotoId,
      petName: petName,
      gate: gate,
      showChangeAction: showChangeAction,
      pickPhoto: _pickPetGalleryPhoto,
      uploadPhoto: (photo) => ref
          .read(templateGenerationRepositoryProvider)
          .uploadPetPhoto(petId: petId, photo: photo),
      startGeneration: (selectedPhoto) async {
        return ref
            .read(templateGenerationRepositoryProvider)
            .startGenerationFromPet(
              petId: petId,
              petPhotoId: selectedPhoto.id,
              templateId: template.templateId,
            );
      },
    );
    if (!mounted || action == null) {
      return;
    }

    if (action.changePet) {
      context.push('/profile/pets');
      return;
    }

    final generation = action.generation;
    if (generation == null) {
      return;
    }

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
  }

  Future<void> _startFromMyPetsChoice(
    TemplateItem template, {
    TemplateOfTheDayItem? templateOfTheDay,
  }) async {
    try {
      final pets = await ref.read(petsProvider.future);
      if (!mounted) {
        return;
      }

      if (pets.isEmpty) {
        final text = AppLocalizations.of(context);
        PetMagicToast.show(
          context,
          message: text.petsFirstPetToast,
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
        message: AppLocalizations.of(context).petsCouldNotLoadToast,
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

  Future<XFile?> _pickPetGalleryPhoto() async {
    final permission = await _permissionCoordinator.requestOnDemand(
      AppPermissionType.photos,
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
      source: ImageSource.gallery,
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
  final text = AppLocalizations.of(context);
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
                  text.petsUploadAction,
                  style: TextStyle(color: colors.textStrong),
                ),
                onTap: () =>
                    Navigator.of(sheetContext).pop(_TemplateInputChoice.upload),
              ),
              ListTile(
                leading: Icon(Icons.pets_rounded, color: colors.accent),
                title: Text(
                  text.petsChooseFromMyPetsAction,
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
  final text = AppLocalizations.of(context);
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
            child: Material(
              type: MaterialType.transparency,
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
                      leading: PetShortcutAvatar(avatarUrl: pet.avatarUrl),
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
                        [
                          templatePetTypeLabel(pet.type, text),
                          pet.breed,
                        ].whereType<String>().join(' • '),
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
    ),
  );
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
