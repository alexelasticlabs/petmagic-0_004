import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:petmagic_mobile/core/operations/request_cancellation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/errors/auth_feedback_mapper.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/navigation/app_navigator.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/core/performance/media_lifecycle_policy.dart';
import 'package:petmagic_mobile/core/realtime/realtime_client.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/templates/application/generation_gallery_cache.dart';
import 'package:petmagic_mobile/features/templates/application/template_generation_contract.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/application/template_error_key_mapper.dart';
import 'package:petmagic_mobile/features/templates/presentation/mappers/generation_status_mappers.dart';
import 'package:petmagic_mobile/features/wallet/application/wallet_controller.dart';
import 'package:petmagic_mobile/shared/files/device_file_saver.dart';
import 'package:petmagic_mobile/shared/files/file_name_sanitizer.dart';
import 'package:petmagic_mobile/shared/files/media_share_save.dart';
import 'package:petmagic_mobile/shared/files/persistent_media_url.dart';
import 'package:petmagic_mobile/shared/navigation/external_url_policy.dart';
import 'package:petmagic_mobile/shared/navigation/app_navigation_context.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_modal_sheet.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_navigation_layout.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_haptics.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_toast.dart';
import 'package:video_player/video_player.dart';

part 'generation_status_page_common_sections.dart';
part 'generation_status_page_compare_viewer.part.dart';
part 'generation_status_page_feedback.part.dart';
part 'generation_status_page_feedback_reason_grid.part.dart';
part 'generation_status_page_feedback_actions.part.dart';
part 'generation_status_page_fullscreen_viewer.part.dart';
part 'generation_status_page_active_card.part.dart';
part 'generation_status_page_active_chrome.part.dart';
part 'generation_status_page_lifecycle.part.dart';
part 'generation_status_page_recovery.part.dart';
part 'generation_status_page_view.part.dart';
part 'generation_status_page_media_actions.part.dart';
part 'generation_status_page_actions_sheet.part.dart';
part 'generation_status_page_result_actions.part.dart';
part 'generation_status_page_result_action_copy.part.dart';
part 'generation_status_page_result_cards.part.dart';
part 'generation_status_page_recommendations.part.dart';
part 'generation_status_page_result_action_widgets.part.dart';
part 'generation_status_page_result_details.part.dart';
part 'generation_status_page_sections.dart';

final generationStatusMediaActionsProvider =
    Provider<GenerationStatusMediaActions>((ref) {
      return const GenerationStatusMediaActions();
    });

class GenerationStatusMediaActions {
  const GenerationStatusMediaActions();

  Future<bool> saveToGallery({
    required String mediaUrl,
    required String fileName,
    required bool isVideo,
    required String albumName,
    required RequestCancellation cancelToken,
    String? localPath,
  }) async {
    final usableLocalPath = await usableLocalMediaPath(localPath);
    if (usableLocalPath != null) {
      return await saveLocalMediaToGallery(
        filePath: usableLocalPath,
        fileName: fileName,
        isVideo: isVideo,
        albumName: albumName,
        cancelToken: cancelToken,
      );
    }

    final safeUri = parseSafeGenerationMediaUri(mediaUrl);
    if (safeUri == null) {
      throw const AppException('generation.media_url_untrusted');
    }

    return await saveRemoteMediaToGallery(
      mediaUrl: safeUri.toString(),
      fileName: fileName,
      isVideo: isVideo,
      albumName: albumName,
      cancelToken: cancelToken,
    );
  }

  Future<void> share({
    required String mediaUrl,
    required String fileName,
    required String title,
    required RequestCancellation cancelToken,
    String? shareText,
    String? localPath,
  }) async {
    final usableLocalPath = await usableLocalMediaPath(localPath);
    if (usableLocalPath != null) {
      await shareLocalMediaFile(
        filePath: usableLocalPath,
        fileName: fileName,
        title: title,
        text: shareText,
        cancelToken: cancelToken,
      );
      return;
    }

    final safeUri = parseSafeGenerationMediaUri(mediaUrl);
    if (safeUri == null) {
      throw const AppException('generation.media_url_untrusted');
    }

    await shareRemoteMediaFile(
      mediaUrl: safeUri.toString(),
      fileName: fileName,
      title: title,
      text: shareText,
      cancelToken: cancelToken,
    );
  }
}

class GenerationStatusPage extends ConsumerStatefulWidget {
  const GenerationStatusPage({
    required this.generationId,
    this.templateOfTheDay,
    super.key,
  });

  static const routePrefix = '/generations';
  static String routeFor(String generationId) =>
      '$routePrefix/${Uri.encodeComponent(generationId)}';

  final String generationId;
  final TemplateOfTheDayItem? templateOfTheDay;

  @override
  ConsumerState<GenerationStatusPage> createState() =>
      _GenerationStatusPageState();
}

class _GenerationStatusPageState extends ConsumerState<GenerationStatusPage>
    with WidgetsBindingObserver {
  Timer? _pollTimer;
  int _consecutivePollFailures = 0;
  TemplateGenerationResult? _generation;
  bool _isLoading = true;
  bool _isSubmittingFeedback = false;
  bool _hasSubmittedFeedback = false;
  bool _isDeleting = false;
  bool _isMediaActionInFlight = false;
  bool _isRemovingWatermark = false;
  bool _isGeneratingSimilar = false;
  bool _isCancellingGeneration = false;
  bool _canUsePrivateStatusApi = true;
  String? _errorMessage;
  bool _isPollInFlight = false;
  bool _isPageActive = true;
  CompatibleGenerationTemplates? _compatibleTemplates;
  bool _isLoadingCompatibleTemplates = false;
  RequestCancellation? _activeLoadCancelToken;
  RequestCancellation? _activeCompatibleTemplatesCancelToken;
  RequestCancellation? _activeMediaActionCancelToken;
  RequestCancellation? _activeGenerationCancelToken;
  RealtimeClient? _activeRealtimeClient;
  StreamSubscription<RealtimeEvent>? _realtimeSubscription;
  Future<void>? _realtimeConnectFuture;
  bool _isRealtimeConnected = false;
  GenerationGalleryCache? _activeGalleryStore;
  final Set<String> _recordedTemplateOfTheDayTerminalEvents = <String>{};
  final Set<String> _recordedFeedbackPromptEvents = <String>{};

  GenerationGalleryCache get _galleryStore {
    final store = ref.read(generationGalleryStoreProvider);
    _activeGalleryStore = store;
    return store;
  }

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
    _activeGalleryStore = ref.read(generationGalleryStoreProvider);
    _activeRealtimeClient = ref.read(realtimeClientProvider);
    _canUsePrivateStatusApi = _isLaunchAuthorized(
      ref.read(appLaunchControllerProvider),
    );
    WidgetsBinding.instance.addObserver(this);
    if (!_canUsePrivateStatusApi) {
      _isLoading = false;
      _errorMessage = 'auth.sign_in_required';
      return;
    }

    unawaited(_load());
    unawaited(_resumeRealtimeIfNeeded());
    _startPolling();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_canUsePrivateStatusApi) {
      _pauseRealtime();
      _stopPolling();
      _cancelActiveLoad();
      _cancelActiveCompatibleTemplatesLoad();
      _cancelActiveLocalMediaDownloads();
      return;
    }

    if (state == AppLifecycleState.resumed) {
      _isPageActive = true;
      if (!ref.read(networkStatusControllerProvider).hasInternet) {
        _pauseRealtime();
        _stopPolling();
        return;
      }
      unawaited(_resumeRealtimeIfNeeded());
      _startPolling();
      unawaited(_load(silent: true));
      return;
    }

    _isPageActive = false;
    _pauseRealtime();
    _stopPolling();
    _cancelActiveCompatibleTemplatesLoad();
    _cancelActiveLocalMediaDownloads();
  }

  @override
  void dispose() {
    _isPageActive = false;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_realtimeSubscription?.cancel());
    _realtimeSubscription = null;
    _pauseRealtime();
    _stopPolling();
    _cancelActiveLoad();
    _cancelActiveCompatibleTemplatesLoad();
    _cancelActiveMediaAction();
    _cancelActiveGenerationCancel();
    _cancelActiveLocalMediaDownloads();
    super.dispose();
  }

  @override
  void deactivate() {
    _isPageActive = false;
    _pauseRealtime();
    _stopPolling();
    _cancelActiveLoad();
    _cancelActiveCompatibleTemplatesLoad();
    _cancelActiveMediaAction();
    _cancelActiveGenerationCancel();
    _cancelActiveLocalMediaDownloads();
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _isPageActive = true;
    if (!_canUsePrivateStatusApi) {
      _pauseRealtime();
      _stopPolling();
      return;
    }

    if (!ref.read(networkStatusControllerProvider).hasInternet) {
      _pauseRealtime();
      _stopPolling();
      return;
    }
    unawaited(_resumeRealtimeIfNeeded());
    _startPolling();
    unawaited(_load(silent: true));
  }

  @override
  Widget build(BuildContext context) => _buildPage(context);

  bool _isLaunchAuthorized(AppLaunchState state) {
    return state.isLoading || state.isAuthenticated;
  }

  void _handleLaunchStateChanged(
    AppLaunchState? previous,
    AppLaunchState launchState,
  ) {
    final wasAuthenticated = previous?.isAuthenticated == true;
    final canUsePrivateApi = _isLaunchAuthorized(launchState);
    if (!wasAuthenticated && !launchState.isAuthenticated) {
      return;
    }

    if (_canUsePrivateStatusApi == canUsePrivateApi) {
      return;
    }

    _canUsePrivateStatusApi = canUsePrivateApi;
    if (!canUsePrivateApi) {
      _pauseRealtime();
      _stopPolling();
      _cancelActiveLoad();
      _cancelActiveCompatibleTemplatesLoad();
      _cancelActiveMediaAction();
      _cancelActiveGenerationCancel();
      _cancelActiveLocalMediaDownloads();
      _setPageState(() {
        _generation = null;
        _compatibleTemplates = null;
        _isLoadingCompatibleTemplates = false;
        _isLoading = false;
        _isSubmittingFeedback = false;
        _isDeleting = false;
        _isMediaActionInFlight = false;
        _isRemovingWatermark = false;
        _isGeneratingSimilar = false;
        _isCancellingGeneration = false;
        _errorMessage = 'auth.sign_in_required';
      });
      return;
    }

    if (!_isPageActive ||
        !ref.read(networkStatusControllerProvider).hasInternet) {
      return;
    }

    unawaited(_load());
    unawaited(_resumeRealtimeIfNeeded());
    _startPolling();
  }
}
