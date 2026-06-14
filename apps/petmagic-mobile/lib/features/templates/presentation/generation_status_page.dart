import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/performance/media_lifecycle_policy.dart';
import 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';
import 'package:petmagic_mobile/features/templates/data/generation_gallery_store.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_history_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/mappers/generation_status_mappers.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_page.dart';
import 'package:petmagic_mobile/shared/files/device_file_saver.dart';
import 'package:petmagic_mobile/shared/files/file_name_sanitizer.dart';
import 'package:petmagic_mobile/shared/files/media_share_save.dart';
import 'package:petmagic_mobile/shared/navigation/external_url_policy.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_modal_sheet.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_shell.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_haptics.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_toast.dart';
import 'package:video_player/video_player.dart';

part 'generation_status_page_common_sections.dart';
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
    required CancelToken cancelToken,
  }) {
    final safeUri = parseSafeGenerationMediaUri(mediaUrl);
    if (safeUri == null) {
      throw const AppException('generation.media_url_untrusted');
    }

    return saveRemoteMediaToGallery(
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
    required CancelToken cancelToken,
  }) {
    final safeUri = parseSafeGenerationMediaUri(mediaUrl);
    if (safeUri == null) {
      throw const AppException('generation.media_url_untrusted');
    }

    return shareRemoteMediaFile(
      mediaUrl: safeUri.toString(),
      fileName: fileName,
      title: title,
      cancelToken: cancelToken,
    );
  }
}

class GenerationStatusPage extends ConsumerStatefulWidget {
  const GenerationStatusPage({required this.generationId, super.key});

  static const routePrefix = '/generations';

  final String generationId;

  @override
  ConsumerState<GenerationStatusPage> createState() =>
      _GenerationStatusPageState();
}

class _GenerationStatusPageState extends ConsumerState<GenerationStatusPage>
    with WidgetsBindingObserver {
  Timer? _pollTimer;
  TemplateGenerationResult? _generation;
  bool _isLoading = true;
  bool _isSubmittingFeedback = false;
  bool _isDeleting = false;
  bool _isMediaActionInFlight = false;
  String? _errorMessage;
  bool _isPollInFlight = false;
  CancelToken? _activeLoadCancelToken;
  CancelToken? _activeMediaActionCancelToken;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
    _startPolling();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
      unawaited(_load(silent: true));
      return;
    }

    _stopPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPolling();
    _cancelActiveLoad();
    _cancelActiveMediaAction();
    super.dispose();
  }

  @override
  void deactivate() {
    _stopPolling();
    _cancelActiveLoad();
    _cancelActiveMediaAction();
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _startPolling();
    unawaited(_load(silent: true));
  }

  void _startPolling() {
    if (_pollTimer != null) {
      return;
    }

    _scheduleNextPoll();
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _scheduleNextPoll() {
    if (!mounted || _generation?.isTerminal == true) {
      _stopPolling();
      return;
    }

    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) {
      _stopPolling();
      return;
    }

    _stopPolling();
    _pollTimer = Timer(const Duration(seconds: 3), () {
      unawaited(_handlePollTick());
    });
  }

  Future<void> _handlePollTick() async {
    _pollTimer = null;

    if (!mounted || _generation?.isTerminal == true) {
      return;
    }

    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) {
      _scheduleNextPoll();
      return;
    }

    if (_isPollInFlight) {
      _scheduleNextPoll();
      return;
    }

    _isPollInFlight = true;
    try {
      await _load(silent: true);
    } finally {
      _isPollInFlight = false;
      _scheduleNextPoll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final generation = _generation;
    final bottomInset = petMagicBottomNavInset(
      context,
      extraSpacing: kPetMagicBottomContentInsetRelaxed,
    );

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
          child: RefreshIndicator.adaptive(
            color: colors.accent,
            onRefresh: () async {
              await PetMagicHaptics.medium();
              await _load();
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: EdgeInsets.fromLTRB(18, 12, 18, bottomInset),
              children: [
                _Header(
                  title:
                      generation?.templateTitle ?? text.generationStatusTitle,
                  subtitle: generation == null
                      ? null
                      : '${typeLabel(text, generation)} • ${generation.tokenCost} PawSpark',
                  onBack: () => context.go('/creations'),
                  onMenu: generation == null
                      ? null
                      : () => _openActionsSheet(generation),
                ),
                const SizedBox(height: 18),
                if (_isLoading && generation == null)
                  const _LoadingCard()
                else if (_errorMessage != null && generation == null)
                  _ErrorCard(
                    message: _statusLoadErrorText(text, _errorMessage!),
                    onRetry: () => _load(),
                  )
                else if (generation != null) ...[
                  _StatusHero(generation: generation),
                  const SizedBox(height: 14),
                  if (generation.isCompleted) ...[
                    _ResultCard(
                      generation: generation,
                      onOpenViewer: () => _openFullscreenPreview(generation),
                    ),
                    const SizedBox(height: 10),
                    _ReadyActionsRow(
                      onSave: _isMediaActionInFlight
                          ? null
                          : () => unawaited(_saveToGallery(generation)),
                      onShare: _isMediaActionInFlight
                          ? null
                          : () => unawaited(_shareResult(generation)),
                    ),
                    const SizedBox(height: 10),
                    _DetailsCard(
                      title: text.generationStatusDetailsTitle,
                      rows: [
                        (
                          text.templateFlowTemplateLabel,
                          generation.templateTitle ??
                              text.generationStatusUntitledFallback,
                        ),
                        (
                          text.generationStatusCreatedLabel,
                          formatGenerationDateTime(
                            generation.completedAtUtc ??
                                generation.updatedAtUtc,
                          ),
                        ),
                        (
                          text.generationStatusTypeLabel,
                          typeLabel(text, generation),
                        ),
                        (
                          text.templateFlowCostLabel,
                          '${generation.tokenCost} PawSpark',
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _FeedbackCard(
                      isSubmitting: _isSubmittingFeedback,
                      title: text.generationStatusFeedbackTitle,
                      excellentLabel: text.generationStatusFeedbackExcellent,
                      okayLabel: text.generationStatusFeedbackOkay,
                      badLabel: text.generationStatusFeedbackBad,
                      onRatingSelected: _handleRatingSelected,
                    ),
                  ] else if (generation.isFailed) ...[
                    _FailureCard(generation: generation),
                    const SizedBox(height: 14),
                    _FailedActions(
                      onPickAnotherPhoto: () =>
                          context.go(TemplatesPage.routePath),
                      onRetry: _retrySoon,
                      onSupport: () => context.push(SupportChatPage.routePath),
                    ),
                    const SizedBox(height: 14),
                    _DetailsCard(
                      title: text.generationStatusDetailsTitle,
                      rows: [
                        (
                          text.templateFlowTemplateLabel,
                          generation.templateTitle ??
                              text.generationStatusUntitledFallback,
                        ),
                        (
                          text.generationStatusTypeLabel,
                          typeLabel(text, generation),
                        ),
                        (
                          text.generationStatusAttemptLabel,
                          '${generation.attemptCount}',
                        ),
                        (
                          text.templateFlowCostLabel,
                          '${generation.tokenCost} PawSpark',
                        ),
                      ],
                    ),
                  ] else ...[
                    _StageCard(generation: generation),
                    const SizedBox(height: 14),
                    _BackgroundHintCard(generation: generation),
                    const SizedBox(height: 14),
                    _ActiveActions(
                      onContinue: () => context.go('/templates'),
                      onCancel: _cancelSoon,
                    ),
                    const SizedBox(height: 14),
                    _DetailsCard(
                      title: text.generationStatusDetailsTitle,
                      rows: [
                        (
                          text.templateFlowTemplateLabel,
                          generation.templateTitle ??
                              text.generationStatusUntitledFallback,
                        ),
                        (
                          text.generationStatusStartedLabel,
                          formatGenerationDateTime(generation.createdAtUtc),
                        ),
                        (
                          text.generationStatusTypeLabel,
                          typeLabel(text, generation),
                        ),
                        (
                          text.templateFlowCostLabel,
                          '${generation.tokenCost} PawSpark',
                        ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openActionsSheet(TemplateGenerationResult generation) async {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final bottomInset = petMagicScrollableBottomInset(sheetContext);
        final maxSheetHeight = MediaQuery.sizeOf(sheetContext).height * 0.8;
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, 0, 12, bottomInset),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: colors.border.withValues(alpha: 0.85),
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.shadow.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxSheetHeight),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (generation.isCompleted) ...[
                          _StatusSheetActionTile(
                            icon: Icons.link_rounded,
                            label: text.generationStatusCopyLinkAction,
                            onTap: () {
                              Navigator.of(sheetContext).pop();
                              unawaited(_copyResultLink(generation));
                            },
                          ),
                          _StatusSheetActionTile(
                            icon: Icons.delete_outline_rounded,
                            label: text.generationStatusDeleteAction,
                            onTap: _isDeleting
                                ? null
                                : () {
                                    Navigator.of(sheetContext).pop();
                                    unawaited(_deleteGeneration(generation));
                                  },
                            isDestructive: true,
                          ),
                          _StatusSheetActionTile(
                            icon: Icons.flag_outlined,
                            label: text.generationStatusReportProblemAction,
                            onTap: () {
                              Navigator.of(sheetContext).pop();
                              context.push(SupportChatPage.routePath);
                            },
                          ),
                        ] else if (generation.isFailed) ...[
                          _StatusSheetActionTile(
                            icon: Icons.image_search_rounded,
                            label: text.generationStatusPickAnotherPhotoAction,
                            onTap: () {
                              Navigator.of(sheetContext).pop();
                              context.go(TemplatesPage.routePath);
                            },
                          ),
                          _StatusSheetActionTile(
                            icon: Icons.refresh_rounded,
                            label: text.generationStatusRetryAction,
                            onTap: () {
                              Navigator.of(sheetContext).pop();
                              _retrySoon();
                            },
                          ),
                          _StatusSheetActionTile(
                            icon: Icons.support_agent_rounded,
                            label: text.generationStatusContactSupportAction,
                            onTap: () {
                              Navigator.of(sheetContext).pop();
                              context.push(SupportChatPage.routePath);
                            },
                          ),
                        ] else ...[
                          _StatusSheetActionTile(
                            icon: Icons.photo_library_outlined,
                            label: text.generationStatusOpenGalleryAction,
                            onTap: () {
                              Navigator.of(sheetContext).pop();
                              context.go('/creations');
                            },
                          ),
                          _StatusSheetActionTile(
                            icon: Icons.close_rounded,
                            label: text.generationStatusCancelGenerationAction,
                            onTap: () {
                              Navigator.of(sheetContext).pop();
                              _cancelSoon();
                            },
                            isDestructive: true,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveToGallery(TemplateGenerationResult generation) async {
    final mediaActionCancelToken = _startMediaAction();
    if (mediaActionCancelToken == null) {
      return;
    }

    final text = AppLocalizations.of(context);
    final outputUrl = generation.outputUrl;
    if (outputUrl == null || outputUrl.isEmpty) {
      _showInfo(text.generationStatusResultUnavailableForSave);
      _completeMediaAction(mediaActionCancelToken);
      return;
    }

    final fileName = _buildOutputFileName(generation, outputUrl);

    try {
      final wasSaved = await ref
          .read(generationStatusMediaActionsProvider)
          .saveToGallery(
            mediaUrl: outputUrl,
            fileName: fileName,
            isVideo: isVideoGeneration(generation),
            albumName: 'PetMagic',
            cancelToken: mediaActionCancelToken,
          );

      if (!mounted) {
        return;
      }

      if (!wasSaved) {
        _showInfo(text.generationStatusFileSaveFailedMessage);
        return;
      }

      _showInfo(text.generationStatusSavedToGalleryMessage);
    } on DioException catch (error) {
      if (!mounted || CancelToken.isCancel(error)) {
        return;
      }

      _showInfo(text.generationStatusFileSaveFailedMessage);
    } on Object {
      if (!mounted) {
        return;
      }

      _showInfo(text.generationStatusFileSaveFailedMessage);
    } finally {
      _completeMediaAction(mediaActionCancelToken);
    }
  }

  Future<void> _deleteGeneration(TemplateGenerationResult generation) async {
    if (_isDeleting) {
      return;
    }

    final text = AppLocalizations.of(context);

    setState(() => _isDeleting = true);
    try {
      await ref
          .read(generationHistoryControllerProvider.notifier)
          .deleteGeneration(generation.generationId);

      if (!mounted) {
        return;
      }

      _showInfo(text.generationStatusDeletedMessage);
      context.go('/creations');
    } on Object {
      if (!mounted) {
        return;
      }

      _showInfo(text.generationStatusDeleteFailedMessage);
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  void _cancelSoon() {
    _showInfo(AppLocalizations.of(context).generationStatusCancelSoonMessage);
  }

  void _retrySoon() {
    _showInfo(AppLocalizations.of(context).generationStatusRetrySoonMessage);
    context.go(TemplatesPage.routePath);
  }

  Future<void> _shareResult(TemplateGenerationResult generation) async {
    final mediaActionCancelToken = _startMediaAction();
    if (mediaActionCancelToken == null) {
      return;
    }

    final text = AppLocalizations.of(context);
    final outputUrl = generation.outputUrl;
    if (outputUrl == null || outputUrl.isEmpty) {
      _showInfo(text.generationStatusResultUnavailableForShare);
      _completeMediaAction(mediaActionCancelToken);
      return;
    }

    try {
      await ref
          .read(generationStatusMediaActionsProvider)
          .share(
            mediaUrl: outputUrl,
            fileName: _buildOutputFileName(generation, outputUrl),
            title: generation.templateTitle ?? text.generationStatusResultTitle,
            cancelToken: mediaActionCancelToken,
          );
    } on DioException catch (error) {
      if (!mounted || CancelToken.isCancel(error)) {
        return;
      }

      _showInfo(text.generationStatusShareFailedMessage);
    } on Object {
      if (!mounted) {
        return;
      }

      _showInfo(text.generationStatusShareFailedMessage);
    } finally {
      _completeMediaAction(mediaActionCancelToken);
    }
  }

  CancelToken? _startMediaAction() {
    if (_activeMediaActionCancelToken != null) {
      return null;
    }

    _stopPolling();
    _cancelActiveLoad();
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
      _startPolling();
    } else {
      _isMediaActionInFlight = false;
    }
  }

  void _cancelActiveMediaAction() {
    final cancelToken = _activeMediaActionCancelToken;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('generation_status_media_action_cancelled');
    }
    _activeMediaActionCancelToken = null;
    _isMediaActionInFlight = false;
  }

  CancelToken _startLoadRequest() {
    _cancelActiveLoad();
    final cancelToken = CancelToken();
    _activeLoadCancelToken = cancelToken;
    return cancelToken;
  }

  void _completeLoadRequest(CancelToken cancelToken) {
    if (identical(_activeLoadCancelToken, cancelToken)) {
      _activeLoadCancelToken = null;
    }
  }

  void _cancelActiveLoad() {
    final cancelToken = _activeLoadCancelToken;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('generation_status_load_cancelled');
    }
    _activeLoadCancelToken = null;
  }

  Future<void> _copyResultLink(TemplateGenerationResult generation) async {
    final text = AppLocalizations.of(context);
    final outputUrl = generation.outputUrl;
    if (outputUrl == null || outputUrl.isEmpty) {
      _showInfo(text.generationStatusResultUnavailableForShare);
      return;
    }

    final safeUri = parseSafeGenerationMediaUri(outputUrl);
    if (safeUri == null) {
      _showInfo(text.generationStatusResultUnavailableForShare);
      return;
    }

    await Clipboard.setData(ClipboardData(text: safeUri.toString()));
    if (!mounted) {
      return;
    }

    _showInfo(text.generationStatusLinkCopiedMessage);
  }

  Future<void> _openFullscreenPreview(
    TemplateGenerationResult generation,
  ) async {
    final localOutputFile = _localMediaFile(generation.localOutputPath);
    if (localOutputFile != null) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _FullscreenResultViewer(
            generation: generation,
            mediaUrl: generation.outputUrl ?? '',
            localFilePath: localOutputFile.path,
          ),
        ),
      );
      return;
    }

    final outputUrl = generation.outputUrl;
    if (outputUrl == null || outputUrl.isEmpty) {
      _showInfo(AppLocalizations.of(context).templateFlowResultUnavailable);
      return;
    }

    final safeUri = parseSafeGenerationMediaUri(outputUrl);
    if (safeUri == null) {
      _showInfo(AppLocalizations.of(context).templateFlowResultUnavailable);
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _FullscreenResultViewer(
          generation: generation,
          mediaUrl: safeUri.toString(),
          localFilePath: null,
        ),
      ),
    );
  }

  void _showInfo(String message) {
    if (!mounted) {
      return;
    }

    PetMagicToast.show(context, message: message, tone: PetMagicToastTone.info);
  }

  String _buildOutputFileName(
    TemplateGenerationResult generation,
    String outputUrl,
  ) {
    final normalizedTitle = sanitizeFileName(
      generation.templateTitle,
      fallback: 'petmagic_result',
    );
    final extensionFromRemote = extensionFromUrl(outputUrl);
    final extension = extensionFromRemote.isEmpty
        ? _defaultOutputExtension(generation)
        : extensionFromRemote;
    return '${normalizedTitle}_${generation.generationId}.$extension';
  }

  String _defaultOutputExtension(TemplateGenerationResult generation) {
    return isVideoGeneration(generation) ? 'mp4' : 'jpg';
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    final repository = ref.read(templateGenerationRepositoryProvider);
    final loadCancelToken = _startLoadRequest();

    try {
      final previousGeneration = _generation;
      final fetchedGeneration = await repository.fetchGeneration(
        widget.generationId,
        cancelToken: loadCancelToken,
      );
      if (!mounted || loadCancelToken.isCancelled || _isMediaActionInFlight) {
        return;
      }

      final generation = _reuseCurrentLocalMedia(fetchedGeneration);
      if (!mounted) {
        return;
      }

      setState(() {
        _generation = generation;
        _isLoading = false;
        _errorMessage = null;
      });

      if (generation.isUnread) {
        unawaited(
          ref
              .read(generationHistoryControllerProvider.notifier)
              .markRead(generation.generationId),
        );
      }

      if (generation.isCompleted) {
        unawaited(_materializeLocalMediaAndRefresh(generation));
      }

      if (generation.isTerminal) {
        _stopPolling();

        final reachedTerminalNow = previousGeneration != null
            ? !previousGeneration.isTerminal
            : true;
        if (reachedTerminalNow) {
          unawaited(PetMagicHaptics.heavy());
        }
      }
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        return;
      }

      await _showCachedOrMappedLoadError(repository, error);
    } catch (error) {
      await _showCachedOrMappedLoadError(repository, error);
    } finally {
      _completeLoadRequest(loadCancelToken);
    }
  }

  Future<void> _showCachedOrMappedLoadError(
    TemplateGenerationRepository repository,
    Object error,
  ) async {
    final cachedGeneration = await repository.readCachedGeneration(
      widget.generationId,
    );
    if (!mounted) {
      return;
    }

    final localizedCachedGeneration = cachedGeneration == null
        ? null
        : _reuseCurrentLocalMedia(cachedGeneration);

    if (!mounted) {
      return;
    }

    if (localizedCachedGeneration != null) {
      setState(() {
        _generation = localizedCachedGeneration;
        _isLoading = false;
        _errorMessage = null;
      });
      if (localizedCachedGeneration.isCompleted) {
        unawaited(_materializeLocalMediaAndRefresh(localizedCachedGeneration));
      }
      return;
    }

    setState(() {
      _isLoading = false;
      _errorMessage = _mapStatusLoadError(error);
    });
  }

  TemplateGenerationResult _reuseCurrentLocalMedia(
    TemplateGenerationResult generation,
  ) {
    final current = _generation;
    if (current == null || current.generationId != generation.generationId) {
      return generation;
    }

    return generation.copyWith(
      localPreviewPath: current.localPreviewPath,
      localOutputPath: current.localOutputPath,
      isLocalMediaReady: current.isLocalMediaReady,
    );
  }

  Future<void> _materializeLocalMediaAndRefresh(
    TemplateGenerationResult generation,
  ) async {
    final localRecord = await ref
        .read(generationGalleryStoreProvider)
        .materializeGenerationMedia(generation);
    if (!mounted || localRecord == null || localRecord.isDeletedLocally) {
      return;
    }

    final current = _generation;
    if (current == null || current.generationId != generation.generationId) {
      return;
    }

    setState(() {
      _generation = current.copyWith(
        localPreviewPath: localRecord.previewLocalPath,
        localOutputPath: localRecord.outputLocalPath,
        isLocalMediaReady: localRecord.isDownloadComplete,
      );
    });
  }

  Future<void> _handleRatingSelected(int rating) async {
    final generation = _generation;
    if (generation == null) {
      return;
    }

    if (rating > 1) {
      await _submitFeedback(generation, rating, const [], null);
      return;
    }

    final result = await showPetMagicModalBottomSheet<_FeedbackResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context, bottomInset) => Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: const _NegativeFeedbackSheet(),
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    await _submitFeedback(generation, rating, result.reasons, result.comment);
  }

  Future<void> _submitFeedback(
    TemplateGenerationResult generation,
    int rating,
    List<String> reasons,
    String? comment,
  ) async {
    if (!mounted) {
      return;
    }

    setState(() => _isSubmittingFeedback = true);
    try {
      await ref
          .read(generationHistoryControllerProvider.notifier)
          .submitFeedback(
            generationId: generation.generationId,
            rating: rating,
            selectedReasons: reasons,
            comment: comment,
          );
      if (!mounted) {
        return;
      }

      PetMagicToast.show(
        context,
        message: AppLocalizations.of(
          context,
        ).generationStatusFeedbackThanksMessage,
        tone: PetMagicToastTone.success,
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmittingFeedback = false);
      }
    }
  }
}

String _mapStatusLoadError(Object error) {
  if (error is AppException) {
    if (error.statusCode == 401) {
      return 'auth.sign_in_required';
    }
    if (error.statusCode == 402) {
      return 'templates.insufficient_balance';
    }

    final message = error.message.trim();
    if (message == 'templates.connection_timeout' ||
        message == 'templates.server_timeout' ||
        message == 'templates.request_failed' ||
        message == 'templates.generation_failed') {
      return message;
    }
  }

  return 'templates.generation_failed';
}

String _statusLoadErrorText(AppLocalizations text, String raw) {
  return switch (raw) {
    'auth.sign_in_required' => text.authSignInRequired,
    'templates.insufficient_balance' =>
      text.templateFlowInsufficientBalanceTitle,
    'templates.connection_timeout' => text.templateFlowNetworkError,
    'templates.server_timeout' => text.templateFlowServerError,
    'templates.request_failed' => text.templatesRequestFailedError,
    _ => text.templateFlowStartFailedError,
  };
}

class _StatusSheetActionTile extends StatelessWidget {
  const _StatusSheetActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final tone = isDestructive ? colors.danger : colors.accent;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.border.withValues(alpha: 0.75)),
              color: colors.surfaceStrong.withValues(alpha: 0.72),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: tone.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: tone),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: colors.textStrong,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
