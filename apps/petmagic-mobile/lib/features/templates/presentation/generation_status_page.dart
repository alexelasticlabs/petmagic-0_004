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
import 'package:petmagic_mobile/core/errors/auth_feedback_mapper.dart';
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
part 'generation_status_page_compare_viewer.part.dart';
part 'generation_status_page_feedback.part.dart';
part 'generation_status_page_feedback_actions.part.dart';
part 'generation_status_page_fullscreen_viewer.part.dart';
part 'generation_status_page_active_card.part.dart';
part 'generation_status_page_active_chrome.part.dart';
part 'generation_status_page_lifecycle.part.dart';
part 'generation_status_page_media_actions.part.dart';
part 'generation_status_page_result_actions.part.dart';
part 'generation_status_page_result_sections.part.dart';
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
                      : '${typeLabel(text, generation)} • ${generation.tokenCost} ${text.walletBalanceUnit}',
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
                            Localizations.localeOf(context),
                          ),
                        ),
                        (
                          text.generationStatusTypeLabel,
                          typeLabel(text, generation),
                        ),
                        (
                          text.templateFlowCostLabel,
                          '${generation.tokenCost} ${text.walletBalanceUnit}',
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
                          '${generation.tokenCost} ${text.walletBalanceUnit}',
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
                          formatGenerationDateTime(
                            generation.createdAtUtc,
                            Localizations.localeOf(context),
                          ),
                        ),
                        (
                          text.generationStatusTypeLabel,
                          typeLabel(text, generation),
                        ),
                        (
                          text.templateFlowCostLabel,
                          '${generation.tokenCost} ${text.walletBalanceUnit}',
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
}
