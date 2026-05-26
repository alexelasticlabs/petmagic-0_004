import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';
import 'package:petmagic_mobile/features/templates/data/template_generation_repository.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_history_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/mappers/generation_status_mappers.dart';
import 'package:petmagic_mobile/features/templates/presentation/templates_page.dart';
import 'package:petmagic_mobile/shared/files/device_file_saver.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_modal_sheet.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_shell.dart';
import 'package:share_plus/share_plus.dart';

part 'generation_status_page_sections.dart';
part 'generation_status_page_common_sections.dart';

class GenerationStatusPage extends ConsumerStatefulWidget {
  const GenerationStatusPage({required this.generationId, super.key});

  static const routePrefix = '/generations';

  final String generationId;

  @override
  ConsumerState<GenerationStatusPage> createState() =>
      _GenerationStatusPageState();
}

class _GenerationStatusPageState extends ConsumerState<GenerationStatusPage> {
  Timer? _pollTimer;
  TemplateGenerationResult? _generation;
  bool _isLoading = true;
  bool _isSubmittingFeedback = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_generation?.isTerminal == true) {
        _pollTimer?.cancel();
        return;
      }
      unawaited(_load(silent: true));
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
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
            onRefresh: () => _load(),
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
                  _ErrorCard(message: _errorMessage!, onRetry: () => _load())
                else if (generation != null) ...[
                  _StatusHero(generation: generation),
                  const SizedBox(height: 14),
                  if (generation.isCompleted) ...[
                    _ResultCard(generation: generation),
                    const SizedBox(height: 14),
                    _ReadyActionsRow(
                      onSave: () => unawaited(_saveToDevice(generation)),
                      onShare: () => _shareResult(generation),
                      onDelete: _deleteSoon,
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
                    const SizedBox(height: 14),
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
                      onSupport: () => context.go(SupportChatPage.routePath),
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
      showDragHandle: true,
      backgroundColor: colors.surface,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (generation.isCompleted) ...[
                ListTile(
                  leading: const Icon(Icons.download_rounded),
                  title: Text(text.generationStatusSaveAction),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    unawaited(_saveToDevice(generation));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.share_rounded),
                  title: Text(text.supportChatShareAction),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _shareResult(generation);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded),
                  title: Text(text.generationStatusDeleteAction),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _deleteSoon();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.flag_outlined),
                  title: Text(text.generationStatusReportProblemAction),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    context.go(SupportChatPage.routePath);
                  },
                ),
              ] else if (generation.isFailed) ...[
                ListTile(
                  leading: const Icon(Icons.image_search_rounded),
                  title: Text(text.generationStatusPickAnotherPhotoAction),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    context.go(TemplatesPage.routePath);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.refresh_rounded),
                  title: Text(text.generationStatusRetryAction),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _retrySoon();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.support_agent_rounded),
                  title: Text(text.generationStatusContactSupportAction),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    context.go(SupportChatPage.routePath);
                  },
                ),
              ] else ...[
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: Text(text.generationStatusOpenGalleryAction),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    context.go('/creations');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.close_rounded),
                  title: Text(text.generationStatusCancelGenerationAction),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _cancelSoon();
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveToDevice(TemplateGenerationResult generation) async {
    final text = AppLocalizations.of(context);
    final outputUrl = generation.outputUrl;
    if (outputUrl == null || outputUrl.isEmpty) {
      _showInfo(text.generationStatusResultUnavailableForSave);
      return;
    }

    final fileName = _buildOutputFileName(generation, outputUrl);
    final extension = extractFileExtension(fileName);
    final allowedExtensions = extension == null ? null : <String>[extension];

    try {
      final bytes = await downloadFileBytes(outputUrl);
      final wasSaved = await saveBytesToDevice(
        bytes: bytes,
        dialogTitle: text.generationStatusSaveFileDialogTitle,
        fileName: fileName,
        allowedExtensions: allowedExtensions,
      );

      if (!mounted) {
        return;
      }

      if (!wasSaved) {
        return;
      }

      _showInfo(text.generationStatusFileSavedMessage);
    } on Object {
      if (!mounted) {
        return;
      }

      _showInfo(text.generationStatusFileSaveFailedMessage);
    }
  }

  void _deleteSoon() {
    _showInfo(AppLocalizations.of(context).generationStatusDeleteSoonMessage);
  }

  void _cancelSoon() {
    _showInfo(AppLocalizations.of(context).generationStatusCancelSoonMessage);
  }

  void _retrySoon() {
    _showInfo(AppLocalizations.of(context).generationStatusRetrySoonMessage);
    context.go(TemplatesPage.routePath);
  }

  void _shareResult(TemplateGenerationResult generation) {
    final text = AppLocalizations.of(context);
    final outputUrl = generation.outputUrl;
    if (outputUrl == null || outputUrl.isEmpty) {
      _showInfo(text.generationStatusResultUnavailableForShare);
      return;
    }

    SharePlus.instance.share(ShareParams(text: outputUrl));
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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

    try {
      final generation = await ref
          .read(templateGenerationRepositoryProvider)
          .fetchGeneration(widget.generationId);
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

      if (generation.isTerminal) {
        _pollTimer?.cancel();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = error.toString();
      });
    }
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

    if (result == null) {
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).generationStatusFeedbackThanksMessage,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmittingFeedback = false);
      }
    }
  }
}
