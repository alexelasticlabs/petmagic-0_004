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
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/performance/media_lifecycle_policy.dart';
import 'package:petmagic_mobile/features/premium/presentation/premium_page.dart';
import 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';
import 'package:petmagic_mobile/features/templates/data/generation_gallery_store.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_history_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_result_input_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/mappers/generation_status_mappers.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_page.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_page.dart';
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
    required CancelToken cancelToken,
    String? localPath,
  }) async {
    final usableLocalPath = await usableLocalMediaPath(localPath);
    if (usableLocalPath != null) {
      await shareLocalMediaFile(
        filePath: usableLocalPath,
        fileName: fileName,
        title: title,
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
  TemplateGenerationResult? _generation;
  bool _isLoading = true;
  bool _isSubmittingFeedback = false;
  bool _isDeleting = false;
  bool _isMediaActionInFlight = false;
  bool _isRemovingWatermark = false;
  bool _isGeneratingSimilar = false;
  String? _errorMessage;
  bool _isPollInFlight = false;
  bool _isPageActive = true;
  CancelToken? _activeLoadCancelToken;
  CancelToken? _activeMediaActionCancelToken;
  late final GenerationGalleryStore _galleryStore;
  final Set<String> _recordedTemplateOfTheDayTerminalEvents = <String>{};
  final Set<String> _recordedFeedbackPromptEvents = <String>{};

  @override
  void initState() {
    super.initState();
    _galleryStore = ref.read(generationGalleryStoreProvider);
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
    _startPolling();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _isPageActive = true;
      _startPolling();
      unawaited(_load(silent: true));
      return;
    }

    _isPageActive = false;
    _stopPolling();
    _cancelActiveLocalMediaDownloads();
  }

  @override
  void dispose() {
    _isPageActive = false;
    WidgetsBinding.instance.removeObserver(this);
    _stopPolling();
    _cancelActiveLoad();
    _cancelActiveMediaAction();
    _cancelActiveLocalMediaDownloads();
    super.dispose();
  }

  @override
  void deactivate() {
    _isPageActive = false;
    _stopPolling();
    _cancelActiveLoad();
    _cancelActiveMediaAction();
    _cancelActiveLocalMediaDownloads();
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _isPageActive = true;
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
                  onBack: _handleBackNavigation,
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
                    if (!isVideoGeneration(generation) &&
                        generation.canCompareBeforeAfter) ...[
                      _CompareActionCard(
                        label: text.generationStatusCompareAction,
                        onTap: () => unawaited(_openCompareViewer(generation)),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (!isVideoGeneration(generation))
                      _ResultInputActions(
                        onCreateVideo:
                            (generation.outputUrl?.trim().isNotEmpty ?? false)
                            ? () => unawaited(
                                _openUseResultFlow(generation, true),
                              )
                            : null,
                        onUseAsInput:
                            (generation.outputUrl?.trim().isNotEmpty ?? false)
                            ? () => unawaited(
                                _openUseResultFlow(generation, false),
                              )
                            : null,
                        hasWatermark: generation.hasWatermark,
                        isWatermarkRemoved: generation.isWatermarkRemoved,
                        watermarkMessage: generation.watermarkMessage,
                      )
                    else
                      _ReadyActionsRow(
                        onGenerateSimilar: _canGenerateSimilar(generation)
                            ? () => unawaited(_generateSimilar(generation))
                            : null,
                        onUseAsInput:
                            !isVideoGeneration(generation) &&
                                (generation.outputUrl?.trim().isNotEmpty ??
                                    false)
                            ? () => unawaited(
                                _openUseResultFlow(generation, false),
                              )
                            : null,
                        onSave: _isMediaActionInFlight
                            ? null
                            : () => unawaited(_saveToGallery(generation)),
                        onShare: _isMediaActionInFlight
                            ? null
                            : () => unawaited(_shareResult(generation)),
                        hasWatermark: generation.hasWatermark,
                        isWatermarkRemoved: generation.isWatermarkRemoved,
                        canRemoveWatermark: generation.canRemoveWatermark,
                        watermarkMessage: generation.watermarkMessage,
                        removeWatermarkCostCredits:
                            generation.removeWatermarkCostCredits,
                        isRemovingWatermark: _isRemovingWatermark,
                        onRemoveWatermark: generation.canRemoveWatermark
                            ? () => unawaited(
                                _showRemoveWatermarkSheet(generation),
                              )
                            : null,
                        onUpgrade: () => context.push(PremiumPage.routePath),
                        isGeneratingSimilar: _isGeneratingSimilar,
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
                      onPickAnotherPhoto: () => context.go(
                        _templatesLocationForGeneration(generation),
                      ),
                      onRetry: () => _retrySoon(generation),
                      onSupport: () => context.push(SupportChatPage.routePath),
                    ),
                    const SizedBox(height: 14),
                    _FailedFeedbackCard(
                      isSubmitting: _isSubmittingFeedback,
                      onSubmit: (category) => unawaited(
                        _submitStructuredFeedback(
                          generation: generation,
                          type: 'GenerationFailure',
                          category: category,
                          rating: -1,
                          sourceScreen: 'generation_status_failed',
                        ),
                      ),
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
                    _ActiveGenerationCard(generation: generation),
                    const SizedBox(height: 14),
                    _ActiveActions(onContinue: () => context.go('/creations')),
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

  void _handleBackNavigation() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    context.go('/creations');
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
                            icon: Icons.download_rounded,
                            label: generation.isWatermarkRemoved
                                ? text.generationStatusDownloadWithoutWatermark
                                : generation.hasWatermark
                                ? text.generationStatusSaveWithWatermark
                                : text.generationStatusSaveAction,
                            onTap: _isMediaActionInFlight
                                ? null
                                : () {
                                    Navigator.of(sheetContext).pop();
                                    unawaited(_saveToGallery(generation));
                                  },
                          ),
                          _StatusSheetActionTile(
                            icon: Icons.share_rounded,
                            label: generation.hasWatermark
                                ? text.generationStatusShareWithWatermark
                                : text.supportChatShareAction,
                            onTap: _isMediaActionInFlight
                                ? null
                                : () {
                                    Navigator.of(sheetContext).pop();
                                    unawaited(_shareResult(generation));
                                  },
                          ),
                          if (generation.canRemoveWatermark) ...[
                            _StatusSheetActionTile(
                              icon: Icons.cleaning_services_rounded,
                              label: _isRemovingWatermark
                                  ? text.generationStatusRemovingWatermark
                                  : text.generationStatusRemoveWatermark,
                              onTap: _isRemovingWatermark
                                  ? null
                                  : () {
                                      Navigator.of(sheetContext).pop();
                                      unawaited(
                                        _showRemoveWatermarkSheet(generation),
                                      );
                                    },
                            ),
                            _StatusSheetActionTile(
                              icon: Icons.workspace_premium_rounded,
                              label: text.generationStatusUpgradePremium,
                              onTap: () {
                                Navigator.of(sheetContext).pop();
                                context.push(PremiumPage.routePath);
                              },
                            ),
                          ],
                          _StatusSheetActionTile(
                            icon: Icons.auto_awesome_rounded,
                            label: _similarActionLabel(text),
                            onTap: !_canGenerateSimilar(generation)
                                ? null
                                : () {
                                    Navigator.of(sheetContext).pop();
                                    unawaited(_generateSimilar(generation));
                                  },
                          ),
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
                              unawaited(_showReportProblemSheet(generation));
                            },
                          ),
                        ] else if (generation.isFailed) ...[
                          _StatusSheetActionTile(
                            icon: Icons.image_search_rounded,
                            label: text.generationStatusPickAnotherPhotoAction,
                            onTap: () {
                              Navigator.of(sheetContext).pop();
                              context.go(
                                _templatesLocationForGeneration(generation),
                              );
                            },
                          ),
                          _StatusSheetActionTile(
                            icon: Icons.refresh_rounded,
                            label: text.generationStatusRetryAction,
                            onTap: () {
                              Navigator.of(sheetContext).pop();
                              _retrySoon(generation);
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

    try {
      final localOutputPath = await usableLocalMediaPath(
        generation.localOutputPath,
      );
      if (!mounted) {
        return;
      }
      String safeOutputUrl = '';
      String fileName;
      if (localOutputPath == null) {
        final access = await ref
            .read(templateGenerationRepositoryProvider)
            .fetchDownloadUrl(
              generation.generationId,
              cancelToken: mediaActionCancelToken,
            );
        final outputUrl = access.mediaUrl;
        if (outputUrl.isEmpty) {
          _showInfo(text.generationStatusResultUnavailableForSave);
          return;
        }
        final safeOutputUri = parseSafeGenerationMediaUri(outputUrl);
        if (safeOutputUri == null) {
          _showInfo(text.generationStatusResultUnavailableForSave);
          return;
        }
        safeOutputUrl = safeOutputUri.toString();
        fileName = access.fileName.isEmpty
            ? _buildOutputFileName(generation, safeOutputUrl)
            : access.fileName;
      } else {
        final safeOutputUri = parseSafeGenerationMediaUri(generation.outputUrl);
        safeOutputUrl = safeOutputUri?.toString() ?? '';
        fileName = _buildOutputFileName(
          generation,
          safeOutputUrl.isEmpty ? localOutputPath : safeOutputUrl,
        );
      }

      final wasSaved = await ref
          .read(generationStatusMediaActionsProvider)
          .saveToGallery(
            mediaUrl: safeOutputUrl,
            fileName: fileName,
            isVideo: isVideoGeneration(generation),
            albumName: 'PetMagic',
            cancelToken: mediaActionCancelToken,
            localPath: localOutputPath,
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

  void _retrySoon(TemplateGenerationResult generation) {
    _showInfo(AppLocalizations.of(context).generationStatusRetrySoonMessage);
    context.go(_templatesLocationForGeneration(generation));
  }

  String _templatesLocationForGeneration(TemplateGenerationResult generation) {
    final petId = generation.petId?.trim();
    if (petId == null || petId.isEmpty) {
      return TemplatesPage.routePath;
    }

    final petPhotoId = generation.petPhotoId?.trim();
    return Uri(
      path: TemplatesPage.routePath,
      queryParameters: {
        'petId': petId,
        if (petPhotoId != null && petPhotoId.isNotEmpty)
          'petPhotoId': petPhotoId,
      },
    ).toString();
  }

  bool _canGenerateSimilar(TemplateGenerationResult generation) {
    return generation.isCompleted &&
        generation.supportsGenerateSimilar &&
        !generation.userMediaExpired &&
        !_isGeneratingSimilar;
  }

  Future<void> _generateSimilar(TemplateGenerationResult generation) async {
    if (!_canGenerateSimilar(generation)) {
      _showInfo(_sourceUnavailableMessage(AppLocalizations.of(context)));
      return;
    }

    final text = AppLocalizations.of(context);
    unawaited(
      _recordGenerateSimilarAnalytics(generation, 'generate_similar_clicked'),
    );
    if (isVideoGeneration(generation)) {
      final confirmed = await _showGenerateSimilarVideoSheet(generation);
      if (confirmed != true) {
        return;
      }
      unawaited(
        _recordGenerateSimilarAnalytics(
          generation,
          'generate_similar_confirmed',
        ),
      );
    } else {
      _showInfo(_generateSimilarImageCostMessage(text));
    }

    setState(() => _isGeneratingSimilar = true);
    _showInfo(_similarLoadingLabel(text));
    try {
      final next = await ref
          .read(templateGenerationRepositoryProvider)
          .generateSimilar(sourceGenerationId: generation.generationId);

      if (!mounted) {
        return;
      }

      context.go(GenerationStatusPage.routeFor(next.generationId));
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }
      _showInfo(_generateSimilarErrorMessage(text, error));
    } on Object {
      if (!mounted) {
        return;
      }
      _showInfo(_generateSimilarGenericErrorMessage(text));
    } finally {
      if (mounted) {
        setState(() => _isGeneratingSimilar = false);
      }
    }
  }

  Future<void> _recordGenerateSimilarAnalytics(
    TemplateGenerationResult generation,
    String eventType,
  ) async {
    try {
      await ref
          .read(templateGenerationRepositoryProvider)
          .recordAnalyticsEvent(
            templateId: generation.templateId,
            eventType: eventType,
            generationId: generation.generationId,
            metadata: {
              'sourceGenerationId': generation.generationId,
              'templateId': generation.templateId,
              'templateType': generation.templateType,
              'petId': generation.petId,
              'variationStrength': 'medium',
              'creditsCost': isVideoGeneration(generation) ? 5 : 1,
              'userPlan': generation.userPlan,
            },
          );
    } on Object {
      // Best-effort analytics must not block generation.
    }
  }

  Future<bool?> _showGenerateSimilarVideoSheet(
    TemplateGenerationResult generation,
  ) {
    final text = AppLocalizations.of(context);
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final colors = sheetContext.petMagicColors;
        final bottomInset = petMagicScrollableBottomInset(sheetContext);
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
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _similarActionLabel(text),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colors.textStrong,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _generateSimilarVideoCostMessage(text),
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: colors.textSoft),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => Navigator.of(sheetContext).pop(true),
                      child: Text(_generateSimilarConfirmLabel(text)),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => Navigator.of(sheetContext).pop(false),
                      child: Text(_cancelLabel(text)),
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

  Future<void> _openUseResultFlow(
    TemplateGenerationResult generation,
    bool createVideo,
  ) async {
    try {
      await ref
          .read(templateGenerationRepositoryProvider)
          .recordAnalyticsEvent(
            templateId: generation.templateId,
            eventType: createVideo
                ? 'create_video_clicked'
                : 'use_as_input_clicked',
            generationId: generation.generationId,
          );
    } on Object {
      // Best-effort analytics must not block navigation.
    }

    if (!mounted) {
      return;
    }
    context.push(GenerationResultInputPage.routeFor(generation.generationId));
  }

  Future<void> _shareResult(TemplateGenerationResult generation) async {
    final mediaActionCancelToken = _startMediaAction();
    if (mediaActionCancelToken == null) {
      return;
    }

    final text = AppLocalizations.of(context);

    try {
      final localOutputPath = await usableLocalMediaPath(
        generation.localOutputPath,
      );
      if (!mounted) {
        return;
      }
      String safeOutputUrl = '';
      String fileName;
      if (localOutputPath == null) {
        final access = await ref
            .read(templateGenerationRepositoryProvider)
            .fetchShareUrl(
              generation.generationId,
              cancelToken: mediaActionCancelToken,
            );
        final outputUrl = access.mediaUrl;
        if (outputUrl.isEmpty) {
          _showInfo(text.generationStatusResultUnavailableForShare);
          return;
        }
        final safeOutputUri = parseSafeGenerationMediaUri(outputUrl);
        if (safeOutputUri == null) {
          _showInfo(text.generationStatusResultUnavailableForShare);
          return;
        }
        safeOutputUrl = safeOutputUri.toString();
        fileName = access.fileName.isEmpty
            ? _buildOutputFileName(generation, safeOutputUrl)
            : access.fileName;
      } else {
        final safeOutputUri = parseSafeGenerationMediaUri(generation.outputUrl);
        safeOutputUrl = safeOutputUri?.toString() ?? '';
        fileName = _buildOutputFileName(
          generation,
          safeOutputUrl.isEmpty ? localOutputPath : safeOutputUrl,
        );
      }

      await ref
          .read(generationStatusMediaActionsProvider)
          .share(
            mediaUrl: safeOutputUrl,
            fileName: fileName,
            title: generation.templateTitle ?? text.generationStatusResultTitle,
            cancelToken: mediaActionCancelToken,
            localPath: localOutputPath,
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

  Future<void> _showRemoveWatermarkSheet(
    TemplateGenerationResult generation,
  ) async {
    final text = AppLocalizations.of(context);
    unawaited(_recordWatermarkAnalytics(generation, 'remove_clicked'));
    unawaited(_recordWatermarkAnalytics(generation, 'paywall_viewed'));
    final action = await showModalBottomSheet<_RemoveWatermarkAction>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final colors = sheetContext.petMagicColors;
        final bottomInset = petMagicScrollableBottomInset(sheetContext);
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
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      text.generationStatusRemoveWatermarkSheetTitle,
                      style: Theme.of(sheetContext).textTheme.titleMedium
                          ?.copyWith(
                            color: colors.textStrong,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      text.generationStatusRemoveWatermarkSheetBody(
                        generation.removeWatermarkCostCredits,
                      ),
                      style: Theme.of(sheetContext).textTheme.bodyMedium
                          ?.copyWith(color: colors.textSoft, height: 1.35),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(
                        sheetContext,
                      ).pop(_RemoveWatermarkAction.credit),
                      icon: const Icon(Icons.bolt_rounded, size: 18),
                      label: Text(
                        text.generationStatusRemoveWatermarkUseCredit(
                          generation.removeWatermarkCostCredits,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(
                        sheetContext,
                      ).pop(_RemoveWatermarkAction.premium),
                      icon: const Icon(
                        Icons.workspace_premium_rounded,
                        size: 18,
                      ),
                      label: Text(text.generationStatusUpgradePremium),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) {
      return;
    }

    if (action == _RemoveWatermarkAction.premium) {
      context.push(PremiumPage.routePath);
      return;
    }

    await _removeWatermark(generation);
  }

  Future<void> _removeWatermark(TemplateGenerationResult generation) async {
    if (_isRemovingWatermark) {
      return;
    }

    final text = AppLocalizations.of(context);
    setState(() => _isRemovingWatermark = true);
    try {
      final result = await ref
          .read(templateGenerationRepositoryProvider)
          .removeWatermark(generation.generationId);
      if (!mounted) {
        return;
      }

      _showInfo(
        result.watermarkRemoved
            ? text.generationStatusWatermarkRemoved
            : text.generationStatusRemoveWatermarkFailed,
      );
      await _load(silent: true);
    } on DioException catch (error) {
      if (!mounted || CancelToken.isCancel(error)) {
        return;
      }

      if (error.response?.statusCode == 402) {
        await _showWatermarkNoCreditsSheet();
      } else {
        _showInfo(text.generationStatusRemoveWatermarkFailed);
      }
    } on Object {
      if (!mounted) {
        return;
      }

      _showInfo(text.generationStatusRemoveWatermarkFailed);
    } finally {
      if (mounted) {
        setState(() => _isRemovingWatermark = false);
      }
    }
  }

  Future<void> _showWatermarkNoCreditsSheet() async {
    final text = AppLocalizations.of(context);
    final action = await showModalBottomSheet<_RemoveWatermarkAction>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final colors = sheetContext.petMagicColors;
        final bottomInset = petMagicScrollableBottomInset(sheetContext);
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
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      text.generationStatusRemoveWatermarkSheetTitle,
                      style: Theme.of(sheetContext).textTheme.titleMedium
                          ?.copyWith(
                            color: colors.textStrong,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      text.generationStatusRemoveWatermarkNoCredits,
                      style: Theme.of(sheetContext).textTheme.bodyMedium
                          ?.copyWith(color: colors.textSoft, height: 1.35),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(
                        sheetContext,
                      ).pop(_RemoveWatermarkAction.credits),
                      icon: const Icon(Icons.account_balance_wallet_rounded),
                      label: Text(text.walletBuySparkTitle),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(
                        sheetContext,
                      ).pop(_RemoveWatermarkAction.premium),
                      icon: const Icon(Icons.workspace_premium_rounded),
                      label: Text(text.generationStatusUpgradePremium),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) {
      return;
    }

    if (action == _RemoveWatermarkAction.credits) {
      context.push(WalletPage.routePath);
      return;
    }

    context.push(PremiumPage.routePath);
  }

  Future<void> _recordWatermarkAnalytics(
    TemplateGenerationResult generation,
    String eventType, {
    String? unlockMethod,
    int? creditsSpent,
  }) async {
    try {
      await ref
          .read(templateGenerationRepositoryProvider)
          .recordAnalyticsEvent(
            templateId: generation.templateId,
            eventType: eventType,
            generationId: generation.generationId,
            metadata: {
              'generationId': generation.generationId,
              'templateId': generation.templateId,
              'mediaType': isVideoGeneration(generation) ? 'video' : 'image',
              'userPlan': generation.userPlan,
              'unlockMethod': ?unlockMethod,
              'creditsSpent': ?creditsSpent,
            },
          );
    } catch (_) {
      // Analytics is best-effort and must not block result actions.
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

  void _cancelActiveLocalMediaDownloads() {
    unawaited(_galleryStore.cancelActiveDownloads());
  }

  bool _canApplyLocalMediaSync() {
    if (!mounted || !_isPageActive) {
      return false;
    }

    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    return lifecycleState == null ||
        lifecycleState == AppLifecycleState.resumed;
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

  Future<void> _openCompareViewer(TemplateGenerationResult generation) async {
    final text = AppLocalizations.of(context);
    final beforeUrl = generation.inputPreviewUrl?.trim();
    if (beforeUrl == null || beforeUrl.isEmpty) {
      _showInfo(text.generationStatusCompareBeforeUnavailable);
      return;
    }

    final afterUrl = generation.resultPreviewUrl?.trim();
    if (afterUrl == null || afterUrl.isEmpty) {
      _showInfo(text.generationStatusCompareResultUnavailable);
      return;
    }

    final safeBeforeUri = parseSafeGenerationMediaUri(beforeUrl);
    final safeAfterUri = parseSafeGenerationMediaUri(afterUrl);
    if (safeBeforeUri == null || safeAfterUri == null) {
      _showInfo(text.generationStatusCompareOpenFailed);
      return;
    }

    await _recordCompareAnalytics(generation, 'compare_clicked');
    if (!mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _BeforeAfterCompareViewer(
          generation: generation,
          beforeUrl: safeBeforeUri.toString(),
          afterUrl: safeAfterUri.toString(),
          onViewed: () => _recordCompareAnalytics(generation, 'compare_viewed'),
          onSliderMoved: () =>
              _recordCompareAnalytics(generation, 'compare_slider_moved'),
          onClosed: () => _recordCompareAnalytics(generation, 'compare_closed'),
          onShare: () async {
            await _recordCompareAnalytics(generation, 'compare_share_clicked');
            await _shareResult(generation);
          },
        ),
      ),
    );
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

  Future<void> _recordCompareAnalytics(
    TemplateGenerationResult generation,
    String eventType,
  ) async {
    try {
      await ref
          .read(templateGenerationRepositoryProvider)
          .recordAnalyticsEvent(
            templateId: generation.templateId,
            eventType: eventType,
            generationId: generation.generationId,
            metadata: {
              'generationId': generation.generationId,
              'templateId': generation.templateId,
              'petId': generation.petId,
              'inputSourceType': generation.inputSourceType,
              'userPlan': generation.userPlan,
              'hasWatermark': generation.hasWatermark,
            },
          );
    } on Object {
      // Best-effort analytics must not block compare interactions.
    }
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
    final normalizedGenerationId = sanitizeFileName(
      generation.generationId,
      fallback: 'generation',
    );
    final extensionFromRemote = extensionFromUrl(outputUrl);
    final extension = extensionFromRemote.isEmpty
        ? _defaultOutputExtension(generation)
        : extensionFromRemote;
    return '${normalizedTitle}_$normalizedGenerationId.$extension';
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

      unawaited(
        ref
            .read(generationHistoryControllerProvider.notifier)
            .mergeFetchedGeneration(generation),
      );

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
        unawaited(_recordFeedbackPromptViewed(generation));
      }

      if (generation.isTerminal) {
        _stopPolling();
        unawaited(_recordTemplateOfTheDayTerminalAnalytics(generation));

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
      if (localizedCachedGeneration.isTerminal) {
        unawaited(
          _recordTemplateOfTheDayTerminalAnalytics(localizedCachedGeneration),
        );
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

    if (current.outputUrl != generation.outputUrl) {
      return generation.copyWith(
        clearLocalPreviewPath: true,
        clearLocalOutputPath: true,
        isLocalMediaReady: false,
      );
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
    final localRecord = await _galleryStore.materializeGenerationMedia(
      generation,
    );
    if (!_canApplyLocalMediaSync() ||
        localRecord == null ||
        localRecord.isDeletedLocally) {
      return;
    }

    final current = _generation;
    if (current == null || current.generationId != generation.generationId) {
      return;
    }

    final localizedGeneration = current.copyWith(
      localPreviewPath: localRecord.previewLocalPath,
      localOutputPath: localRecord.outputLocalPath,
      isLocalMediaReady: localRecord.isDownloadComplete,
    );
    setState(() {
      _generation = localizedGeneration;
    });
    unawaited(
      ref
          .read(generationHistoryControllerProvider.notifier)
          .mergeFetchedGeneration(localizedGeneration),
    );
  }

  Future<void> _handleRatingSelected(int rating) async {
    final generation = _generation;
    if (generation == null) {
      return;
    }

    unawaited(_recordFeedbackRatingSelected(generation, rating));

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
    } on Object {
      unawaited(_recordFeedbackSubmitFailed(generation));
      rethrow;
    } finally {
      if (mounted) {
        setState(() => _isSubmittingFeedback = false);
      }
    }
  }

  Future<void> _submitStructuredFeedback({
    required TemplateGenerationResult generation,
    required String type,
    required String category,
    required String sourceScreen,
    int? rating,
    String? message,
  }) async {
    if (!mounted || _isSubmittingFeedback) {
      return;
    }

    setState(() => _isSubmittingFeedback = true);
    try {
      await ref
          .read(templateGenerationRepositoryProvider)
          .submitFeedback(
            type: type,
            category: category,
            rating: rating,
            message: message,
            generationId: generation.generationId,
            templateId: generation.templateId,
            petId: generation.petId,
            sourceScreen: sourceScreen,
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
    } on Object {
      unawaited(_recordFeedbackSubmitFailed(generation));
      rethrow;
    } finally {
      if (mounted) {
        setState(() => _isSubmittingFeedback = false);
      }
    }
  }

  Future<void> _showReportProblemSheet(
    TemplateGenerationResult generation,
  ) async {
    unawaited(
      ref
          .read(templateGenerationRepositoryProvider)
          .recordAnalyticsEvent(
            templateId: generation.templateId,
            eventType: 'feedback_report_clicked',
            generationId: generation.generationId,
          ),
    );

    final feedbackText = _feedbackText(context);
    final result = await showPetMagicModalBottomSheet<_FeedbackResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context, bottomInset) => Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: _ProblemFeedbackSheet(
          title: feedbackText.reportTitle,
          reasons: feedbackText.reportReasons,
        ),
      ),
    );

    if (!mounted || result == null || result.reasons.isEmpty) {
      return;
    }

    final category = result.reasons.first;
    await _submitStructuredFeedback(
      generation: generation,
      type: category == 'payment' ? 'PaymentIssue' : 'BugReport',
      category: category,
      rating: -1,
      message: result.comment,
      sourceScreen: 'generation_result_report',
    );
  }

  Future<void> _recordFeedbackPromptViewed(
    TemplateGenerationResult generation,
  ) async {
    final key = '${generation.generationId}:feedback_prompt_viewed';
    if (!_recordedFeedbackPromptEvents.add(key)) {
      return;
    }

    try {
      await ref
          .read(templateGenerationRepositoryProvider)
          .recordAnalyticsEvent(
            templateId: generation.templateId,
            eventType: 'feedback_prompt_viewed',
            generationId: generation.generationId,
            metadata: {
              'feedbackType': 'GenerationResult',
              'templateId': generation.templateId,
              'generationId': generation.generationId,
              'platform': Theme.of(context).platform.name,
              'userPlan': generation.userPlan,
            },
          );
    } on Object {
      // Best-effort analytics must not block the result screen.
    }
  }

  Future<void> _recordFeedbackRatingSelected(
    TemplateGenerationResult generation,
    int rating,
  ) async {
    try {
      await ref
          .read(templateGenerationRepositoryProvider)
          .recordAnalyticsEvent(
            templateId: generation.templateId,
            eventType: 'feedback_rating_selected',
            generationId: generation.generationId,
            metadata: {
              'feedbackType': 'GenerationResult',
              'category': rating == 3
                  ? 'good'
                  : rating == 2
                  ? 'okay'
                  : 'bad',
              'rating': rating == 3
                  ? 1
                  : rating == 2
                  ? 0
                  : -1,
              'templateId': generation.templateId,
              'generationId': generation.generationId,
              'platform': Theme.of(context).platform.name,
              'userPlan': generation.userPlan,
            },
          );
    } on Object {
      // Best-effort analytics must not block feedback.
    }
  }

  Future<void> _recordFeedbackSubmitFailed(
    TemplateGenerationResult generation,
  ) async {
    try {
      await ref
          .read(templateGenerationRepositoryProvider)
          .recordAnalyticsEvent(
            templateId: generation.templateId,
            eventType: 'feedback_submit_failed',
            generationId: generation.generationId,
            metadata: {
              'feedbackType': 'GenerationResult',
              'templateId': generation.templateId,
              'generationId': generation.generationId,
              'platform': Theme.of(context).platform.name,
              'userPlan': generation.userPlan,
            },
          );
    } on Object {
      // Best-effort analytics must not block feedback error handling.
    }
  }

  Future<void> _recordTemplateOfTheDayTerminalAnalytics(
    TemplateGenerationResult generation,
  ) async {
    final featured = widget.templateOfTheDay;
    if (featured == null || !generation.isTerminal) {
      return;
    }

    final eventType = generation.isCompleted
        ? 'generation_completed'
        : generation.isFailed
        ? 'generation_failed'
        : null;
    if (eventType == null) {
      return;
    }

    final key = '${generation.generationId}:$eventType';
    if (!_recordedTemplateOfTheDayTerminalEvents.add(key)) {
      return;
    }

    try {
      await ref
          .read(templateGenerationRepositoryProvider)
          .recordAnalyticsEvent(
            templateId: featured.templateId,
            eventType: eventType,
            generationId: generation.generationId,
            metadata: <String, Object?>{
              'templateId': featured.templateId,
              'type': featured.templateType.apiValue.toLowerCase(),
              'source': featured.source,
              'isPremium': featured.isPremium,
              'userPlan': generation.userPlan,
              'date': _templateOfTheDayDateValue(featured),
              'screen': 'generation_status',
              if (generation.failureCode != null &&
                  generation.failureCode!.isNotEmpty)
                'failureCode': generation.failureCode,
            },
          );
    } catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'Templates.TemplateOfTheDay',
        operation: 'generation_status_analytics',
        message:
            'Could not record Template of the Day terminal analytics event.',
        error: error,
        stackTrace: stackTrace,
        context: <String, Object?>{
          'eventType': eventType,
          'templateId': featured.templateId,
          'generationId': generation.generationId,
        },
      );
    }
  }
}

enum _RemoveWatermarkAction { credit, credits, premium }

String _generateSimilarImageCostMessage(AppLocalizations text) =>
    text.localeName.startsWith('ru') ? 'Стоимость: 1 credit' : 'Cost: 1 credit';

String _generateSimilarVideoCostMessage(AppLocalizations text) =>
    text.localeName.startsWith('ru')
    ? 'Стоимость: 5 credits'
    : 'Cost: 5 credits';

String _generateSimilarConfirmLabel(AppLocalizations text) =>
    text.localeName.startsWith('ru') ? 'Генерировать' : 'Generate';

String _cancelLabel(AppLocalizations text) =>
    text.localeName.startsWith('ru') ? 'Отмена' : 'Cancel';

String _sourceUnavailableMessage(AppLocalizations text) =>
    text.localeName.startsWith('ru')
    ? 'Исходный файл недоступен.'
    : 'Source file is unavailable.';

String _templateOfTheDayDateValue(TemplateOfTheDayItem featured) {
  final date = featured.date.toUtc();
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String _insufficientCreditsMessage(AppLocalizations text) =>
    text.localeName.startsWith('ru')
    ? 'Недостаточно credits.'
    : 'Not enough credits.';

String _generateSimilarGenericErrorMessage(AppLocalizations text) =>
    text.localeName.startsWith('ru')
    ? 'Не удалось сгенерировать. Попробуйте ещё раз.'
    : 'Could not generate. Please try again.';

String _generateSimilarErrorMessage(AppLocalizations text, AppException error) {
  final message = error.message.toLowerCase();
  if (error.statusCode == 402 || message.contains('insufficient')) {
    return _insufficientCreditsMessage(text);
  }

  if (message.contains('source_media_unavailable') ||
      message.contains('generation_result_input_unavailable') ||
      message.contains('unavailable')) {
    return _sourceUnavailableMessage(text);
  }

  return _generateSimilarGenericErrorMessage(text);
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
