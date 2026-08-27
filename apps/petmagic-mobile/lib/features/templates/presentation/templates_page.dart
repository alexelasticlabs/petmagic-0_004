import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/errors/app_unavailable_state.dart';
import 'package:petmagic_mobile/core/files/local_media_file.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/core/navigation/app_navigator.dart';
import 'package:petmagic_mobile/core/permissions/media_permission_feedback.dart';
import 'package:petmagic_mobile/core/performance/decoded_image_cache_budget.dart';
import 'package:petmagic_mobile/core/performance/template_media_cache.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/pets/application/pets_contract.dart';
import 'package:petmagic_mobile/features/profile/application/profile_controller.dart';
import 'package:petmagic_mobile/shared/auth/auth_required_sheet.dart';
import 'package:petmagic_mobile/features/templates/application/template_generation_contract.dart';
import 'package:petmagic_mobile/features/templates/application/template_catalog_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_generation_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_entitlement_provider.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_feed_playback_manager.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_preview_page.dart';
import 'package:petmagic_mobile/features/templates/application/templates_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_card.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_flow_sheets.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_type_filters.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/create_with_pet_block.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/pet_generation_launch_sheet.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/random_template_sheet.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/templates_search_and_fab.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/templates_top_bar.dart';
import 'package:petmagic_mobile/features/wallet/application/wallet_controller.dart';
import 'package:petmagic_mobile/shared/loading/magic_loading_screen.dart';
import 'package:petmagic_mobile/shared/navigation/app_navigation_context.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_navigation_layout.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_action_sheet.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_async_state_view.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_haptics.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_toast.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_unavailable_view.dart';

part 'templates_page_feed.part.dart';
part 'templates_page_feed_slivers.part.dart';
part 'templates_page_generation_flow.part.dart';
part 'templates_page_pet_photo_picker.part.dart';
part 'templates_page_lifecycle.part.dart';
part 'templates_page_template_actions.part.dart';
part 'templates_page_view.part.dart';

class TemplatesPage extends ConsumerStatefulWidget {
  const TemplatesPage({this.initialPetId, this.initialPetPhotoId, super.key});

  final String? initialPetId;
  final String? initialPetPhotoId;

  static const routePath = '/templates';
  static const petIdQueryParam = 'petId';
  static const petPhotoIdQueryParam = 'petPhotoId';

  static String location({String? petId, String? petPhotoId}) {
    final queryParameters = <String, String>{
      if (petId != null && petId.trim().isNotEmpty) petIdQueryParam: petId,
      if (petPhotoId != null && petPhotoId.trim().isNotEmpty)
        petPhotoIdQueryParam: petPhotoId,
    };

    if (queryParameters.isEmpty) {
      return routePath;
    }

    return Uri(path: routePath, queryParameters: queryParameters).toString();
  }

  @override
  ConsumerState<TemplatesPage> createState() => _TemplatesPageState();
}

class _TemplatesPageState extends ConsumerState<TemplatesPage> {
  static const _refreshCooldown = Duration(seconds: 45);
  static const _gridCacheExtent = 400.0;

  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final _imagePicker = ImagePicker();
  TemplatesController? _visibleTemplatesController;
  ProviderSubscription<TemplatesState>? _templatesSubscription;
  TemplatesRepository? _activeRandomTemplateRepository;
  Timer? _searchDebounce;
  DateTime? _lastRefreshAt;
  bool _disposed = false;
  bool _isRandomTemplateLoading = false;
  bool _isAppResumed = true;
  bool _isPetPhotoPickerActive = false;
  bool? _isTabActive;
  bool _templatesScreenVisible = false;
  bool _shouldRefreshAccessOnReconnect = false;
  Future<void>? _walletAccessRefreshInFlight;
  Future<void>? _profileAccessRefreshInFlight;
  DateTime? _lastScrollSampleAt;
  double? _lastScrollSampleOffset;
  final Set<String> _trackedTemplateOfTheDayViews = <String>{};

  void _setPageState(VoidCallback update) {
    if (mounted) {
      setState(update);
      return;
    }

    update();
  }

  @override
  void initState() {
    super.initState();
    _templatesSubscription = ref.listenManual<TemplatesState>(
      templatesControllerProvider,
      (_, _) => _syncVisibleTemplatesController(),
    );
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
    _scrollController.addListener(_handleScroll);
    _runAfterBuild(() {
      if (!mounted) {
        return;
      }
      _refreshAccessForAuthenticatedUser();
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
    _templatesSubscription?.close();
    _setStoredTemplatesScreenVisible(false);
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    _cancelPendingSearchDebounce();
    _cancelPendingRandomTemplateRequest(clearLoadingState: false);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  late final WidgetsBindingObserver _lifecycleObserver =
      _TemplatesLifecycleObserver(
        onStateChanged: _handleLifecycleState,
        onMemoryPressure: _handleMemoryPressure,
      );

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
      ref
          .read(templateFeedPlaybackManagerProvider)
          .disposeAll(reason: 'templates_app_background');
      _setTemplatesScreenVisible(false);
    });
  }

  void _handleMemoryPressure() {
    trimDecodedImageCache();
    ref
        .read(templateFeedPlaybackManagerProvider)
        .disposeAll(reason: 'templates_memory_pressure');
    unawaited(
      TemplateMediaCache.clearAll().catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        AppLogger.warn(
          feature: 'Templates',
          operation: 'memory_pressure_cache_trim',
          message: 'Template media cache trim failed after memory pressure.',
          error: error,
          stackTrace: stackTrace,
        );
      }),
    );
  }

  void _handleScreenBecameVisible({required bool fromAppResume}) {
    _setTemplatesScreenVisible(true);
    _refreshAccessForAuthenticatedUser(forceRefresh: fromAppResume);

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
        ref
            .read(templateFeedPlaybackManagerProvider)
            .disposeAll(reason: 'templates_tab_hidden');
        _setTemplatesScreenVisible(false);
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

  void _refreshAccessForAuthenticatedUser({bool forceRefresh = false}) {
    if (!ref.read(networkStatusControllerProvider).hasInternet) {
      _shouldRefreshAccessOnReconnect = true;
      return;
    }

    _shouldRefreshAccessOnReconnect = false;
    _refreshWalletAccessForAuthenticatedUser(forceRefresh: forceRefresh);
    _refreshProfileAccessForAuthenticatedUser();
  }

  void _refreshWalletAccessForAuthenticatedUser({bool forceRefresh = false}) {
    final launchState = ref.read(appLaunchControllerProvider);
    final walletState = ref.read(walletControllerProvider);
    final hasHydratedWallet =
        walletState.wallet != null && walletState.hasCompletedFullLoad;
    if (!launchState.isAuthenticated ||
        (!hasHydratedWallet &&
            (walletState.isLoading || walletState.isRefreshing)) ||
        _walletAccessRefreshInFlight != null) {
      return;
    }

    final Future<void> refresh;
    if (hasHydratedWallet) {
      refresh = ref
          .read(walletControllerProvider.notifier)
          .syncSnapshot(forceRefresh: forceRefresh);
    } else {
      refresh = ref.read(walletControllerProvider.notifier).load();
    }

    _walletAccessRefreshInFlight = refresh;
    unawaited(
      refresh.whenComplete(() {
        if (identical(_walletAccessRefreshInFlight, refresh)) {
          _walletAccessRefreshInFlight = null;
        }
      }),
    );
  }

  void _setTemplatesScreenVisible(bool visible) {
    final controller = ref.read(templatesControllerProvider.notifier);
    final controllerChanged = !identical(
      _visibleTemplatesController,
      controller,
    );
    if (!controllerChanged && _templatesScreenVisible == visible) {
      return;
    }

    _templatesScreenVisible = visible;
    if (controllerChanged) {
      _visibleTemplatesController?.setScreenVisible(false);
      _visibleTemplatesController = controller;
    }

    controller.setScreenVisible(visible);
  }

  void _syncVisibleTemplatesController() {
    final controller = ref.read(templatesControllerProvider.notifier);
    if (!identical(_visibleTemplatesController, controller)) {
      _visibleTemplatesController?.setScreenVisible(false);
      _visibleTemplatesController = controller;
      controller.setScreenVisible(_templatesScreenVisible);
    }
  }

  void _setStoredTemplatesScreenVisible(bool visible) {
    if (_templatesScreenVisible == visible) {
      return;
    }

    _templatesScreenVisible = visible;
    _visibleTemplatesController?.setScreenVisible(visible);
  }

  void _refreshProfileAccessForAuthenticatedUser() {
    final launchState = ref.read(appLaunchControllerProvider);
    final profileState = ref.read(profileControllerProvider);
    if (!launchState.isAuthenticated ||
        profileState.profile != null ||
        _profileAccessRefreshInFlight != null) {
      return;
    }

    final Future<void> refresh;
    try {
      refresh = ref.read(profileControllerProvider.notifier).initialize();
    } catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'Templates',
        operation: 'profile_access_preload',
        message: 'Profile access preload could not start.',
        error: error,
        stackTrace: stackTrace,
      );
      return;
    }

    _profileAccessRefreshInFlight = refresh;
    unawaited(
      refresh
          .catchError((Object error, StackTrace stackTrace) {
            AppLogger.warn(
              feature: 'Templates',
              operation: 'profile_access_preload',
              message: 'Profile access preload failed.',
              error: error,
              stackTrace: stackTrace,
            );
          })
          .whenComplete(() {
            if (identical(_profileAccessRefreshInFlight, refresh)) {
              _profileAccessRefreshInFlight = null;
            }
          }),
    );
  }

  void _runAfterBuild(VoidCallback action) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Riverpod's WidgetRef is backed by this element's BuildContext. During
      // route/provider-scope replacement the element can become unmounted
      // before State.dispose() has completed, so State.mounted/_disposed alone
      // are not a sufficient guard for deferred ref.read calls.
      if (_disposed || !mounted || !context.mounted) {
        return;
      }
      action();
    });
  }

  @override
  Widget build(BuildContext context) => _buildTemplatesPage(context);
}
