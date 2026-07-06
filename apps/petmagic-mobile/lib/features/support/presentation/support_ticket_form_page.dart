import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/errors/auth_feedback_mapper.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/core/permissions/media_permission_feedback.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/premium/presentation/premium_controller.dart';
import 'package:petmagic_mobile/features/profile/presentation/widgets/auth_required_sheet.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_surface_widgets.dart';
import 'package:petmagic_mobile/features/support/data/support_chat_repository.dart';
import 'package:petmagic_mobile/features/support/presentation/support_assistant_scenarios.dart';
import 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_history_controller.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_controller.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_modal_sheet.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_toast.dart';
import 'package:petmagic_mobile/shared/widgets/protected_auth_gate.dart';

part 'support_ticket_form_content.part.dart';

class SupportTicketFormPage extends ConsumerStatefulWidget {
  const SupportTicketFormPage({
    required this.scenario,
    @visibleForTesting this.initialAttachments = const [],
    super.key,
  });

  static const routePath = '/profile/support/ticket';
  static const scenarioQueryParam = 'scenario';

  final String scenario;
  final List<XFile> initialAttachments;

  static String location(String scenario) {
    final normalizedScenario = normalizeSupportScenarioQuery(scenario);
    if (normalizedScenario == null) {
      return routePath;
    }

    return '$routePath?$scenarioQueryParam=${Uri.encodeQueryComponent(normalizedScenario)}';
  }

  @override
  ConsumerState<SupportTicketFormPage> createState() =>
      _SupportTicketFormPageState();
}

class _SupportTicketFormPageState extends ConsumerState<SupportTicketFormPage> {
  static const _maxAttachmentCount = 5;

  final TextEditingController _descriptionController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  void _showToast(
    String message, {
    PetMagicToastTone tone = PetMagicToastTone.info,
  }) {
    PetMagicToast.show(context, message: message, tone: tone);
  }

  List<XFile> _attachments = const [];
  bool _isSubmitting = false;
  bool _isPickingAttachment = false;
  CancelToken? _submitCancelToken;
  ProviderSubscription<AppLaunchState>? _launchSubscription;
  bool _wasAuthenticated = false;
  bool _hasScheduledSupportContextPreload = false;

  void _logSupportTicketFailure(
    String stage,
    Object error,
    StackTrace stackTrace, {
    Map<String, Object?> context = const {},
  }) {
    final payload = <String, Object>{'stage': stage};
    for (final entry in context.entries) {
      final value = entry.value;
      if (value != null) {
        payload[entry.key] = value.toString();
      }
    }

    AppLogger.warn(
      feature: 'Support.TicketForm',
      operation: stage,
      message: 'Support ticket step failed',
      context: payload,
      error: error,
      stackTrace: stackTrace,
    );
  }

  @override
  void initState() {
    super.initState();
    _attachments = List<XFile>.unmodifiable(widget.initialAttachments);
    _launchSubscription = ref.listenManual<AppLaunchState>(
      appLaunchControllerProvider,
      (_, next) => _handleLaunchState(next),
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _launchSubscription?.close();
    _cancelSubmit();
    _descriptionController.dispose();
    super.dispose();
  }

  void _handleLaunchState(AppLaunchState launchState) {
    if (launchState.isAuthenticated && !_wasAuthenticated) {
      _wasAuthenticated = true;
      _scheduleSupportContextPreload();
      return;
    }

    if (!launchState.isAuthenticated && _wasAuthenticated) {
      _wasAuthenticated = false;
      _hasScheduledSupportContextPreload = false;
      _cancelSubmit();
      return;
    }

    _wasAuthenticated = launchState.isAuthenticated;
  }

  void _scheduleSupportContextPreload() {
    if (_hasScheduledSupportContextPreload) {
      return;
    }

    _hasScheduledSupportContextPreload = true;
    unawaited(
      Future.microtask(() async {
        if (!mounted) {
          return;
        }
        await _preloadSupportContext();
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = ref.watch(
      appLaunchControllerProvider.select((launch) => launch.isAuthenticated),
    );
    final text = AppLocalizations.of(context);
    final scenarioData = buildSupportAssistantScenario(widget.scenario, text);

    ref.listen<NetworkStatusState>(networkStatusControllerProvider, (
      previous,
      next,
    ) {
      if (previous?.hasInternet != false || !next.hasInternet) {
        return;
      }
      if (!ref.read(appLaunchControllerProvider).isAuthenticated) {
        return;
      }

      unawaited(_preloadSupportContext());
    });

    if (!isAuthenticated) {
      return ProfileScreenBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: ProtectedAuthGate(
              subtitle: text.authRequiredMessage,
              onSignIn: () => showAuthRequiredSheet(
                context,
                redirectPath: SupportTicketFormPage.location(widget.scenario),
              ),
            ),
          ),
        ),
      );
    }

    final generationId = ref.watch(
      generationHistoryControllerProvider.select(
        (state) => state.items.isEmpty ? null : state.items.first.generationId,
      ),
    );
    final paymentId = ref.watch(
      walletControllerProvider.select(
        (state) =>
            state.purchases.isEmpty ? null : state.purchases.first.orderId,
      ),
    );
    final subscriptionLabel = ref.watch(
      premiumControllerProvider.select(
        (state) => _resolveSubscriptionLabel(text, state),
      ),
    );

    return _SupportTicketFormContent(
      scenarioData: scenarioData,
      generationId: generationId,
      paymentId: paymentId,
      subscriptionLabel: subscriptionLabel,
      descriptionController: _descriptionController,
      attachments: _attachments,
      isSubmitting: _isSubmitting,
      isPickingAttachment: _isPickingAttachment,
      onAddAttachment: _showAttachmentOptions,
      onRemoveAttachment: (index) {
        setState(() {
          _attachments = [
            ..._attachments.take(index),
            ..._attachments.skip(index + 1),
          ];
        });
      },
      onSubmit: () => _submit(
        scenario: scenarioData.key,
        relatedGenerationId: _asGuidOrNull(generationId),
        relatedPaymentId: _asGuidOrNull(paymentId),
      ),
    );
  }

  Future<void> _showAttachmentOptions() async {
    if (_isPickingAttachment) {
      return;
    }

    if (_attachments.length >= _maxAttachmentCount) {
      final text = AppLocalizations.of(context);
      _showToast(
        text.supportChatTooManyAttachmentsError,
        tone: PetMagicToastTone.warning,
      );
      return;
    }

    final action = await showPetMagicModalBottomSheet<_AttachmentSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext, bottomInset) {
        final text = AppLocalizations.of(sheetContext);
        final colors = sheetContext.petMagicColors;
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset),
            child: Material(
              color: colors.surfaceStrong,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
                side: BorderSide(color: colors.border.withValues(alpha: 0.9)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.border.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        text.supportChatAddPhotoTitle,
                        style: TextStyle(
                          color: colors.textStrong,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.photo_camera_outlined,
                      color: colors.textStrong,
                    ),
                    title: Text(
                      text.supportChatTakePhotoAction,
                      style: TextStyle(color: colors.textStrong),
                    ),
                    onTap: () => Navigator.of(
                      sheetContext,
                    ).pop(_AttachmentSource.camera),
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.photo_library_outlined,
                      color: colors.textStrong,
                    ),
                    title: Text(
                      text.supportChatChooseGalleryAction,
                      style: TextStyle(color: colors.textStrong),
                    ),
                    onTap: () => Navigator.of(
                      sheetContext,
                    ).pop(_AttachmentSource.gallery),
                  ),
                  ListTile(
                    leading: Icon(Icons.close_rounded, color: colors.textMuted),
                    title: Text(
                      text.walletRedeemCancelAction,
                      style: TextStyle(color: colors.textSoft),
                    ),
                    onTap: () => Navigator.of(sheetContext).pop(),
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case _AttachmentSource.camera:
        await _pickFromCamera();
      case _AttachmentSource.gallery:
        await _pickFromGallery();
    }
  }

  Future<void> _pickFromCamera() async {
    await _runAttachmentPickerSession(() async {
      final permissionFeedback = await ref
          .read(mediaPermissionFeedbackCoordinatorProvider)
          .request(context, MediaPermissionFlow.cameraPhoto);
      if (!mounted || !permissionFeedback.granted) {
        if (mounted) {
          ref
              .read(mediaPermissionFeedbackCoordinatorProvider)
              .show(context, permissionFeedback);
        }
        return;
      }

      final picked = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 92,
        maxWidth: 1800,
      );
      if (picked == null || !mounted) {
        return;
      }

      final valid = await _validatePickedImage(picked);
      if (valid == null || !mounted) {
        return;
      }

      setState(() {
        _attachments = [..._attachments, valid];
      });
    });
  }

  Future<void> _pickFromGallery() async {
    await _runAttachmentPickerSession(() async {
      final permissionFeedback = await ref
          .read(mediaPermissionFeedbackCoordinatorProvider)
          .request(context, MediaPermissionFlow.galleryPhoto);
      if (!mounted || !permissionFeedback.granted) {
        if (mounted) {
          ref
              .read(mediaPermissionFeedbackCoordinatorProvider)
              .show(context, permissionFeedback);
        }
        return;
      }

      final remainingSlots = _maxAttachmentCount - _attachments.length;
      final pickedImages = await _imagePicker.pickMultiImage(
        imageQuality: 92,
        maxWidth: 1800,
      );

      if (pickedImages.isEmpty || !mounted) {
        return;
      }

      final next = <XFile>[];
      for (final image in pickedImages.take(remainingSlots)) {
        final valid = await _validatePickedImage(image);
        if (valid != null) {
          next.add(valid);
        }
      }

      if (!mounted || next.isEmpty) {
        return;
      }

      setState(() {
        _attachments = [..._attachments, ...next];
      });
    });
  }

  Future<void> _runAttachmentPickerSession(
    Future<void> Function() action,
  ) async {
    if (_isPickingAttachment) {
      return;
    }

    setState(() {
      _isPickingAttachment = true;
    });
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() {
          _isPickingAttachment = false;
        });
      } else {
        _isPickingAttachment = false;
      }
    }
  }

  Future<XFile?> _validatePickedImage(XFile picked) async {
    final type = _resolveContentTypeForUpload(picked.path).toLowerCase();
    if (type != 'image/jpeg' && type != 'image/png' && type != 'image/webp') {
      _showToast(
        _mapSupportError(
          AppLocalizations.of(context),
          'support.attachment_content_type_not_allowed',
        ),
        tone: PetMagicToastTone.warning,
      );
      return null;
    }

    return picked;
  }

  Future<void> _submit({
    required String scenario,
    String? relatedGenerationId,
    String? relatedPaymentId,
  }) async {
    if (_isSubmitting) {
      return;
    }

    final text = AppLocalizations.of(context);
    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      _showToast(
        text.supportTicketFormDescriptionHint,
        tone: PetMagicToastTone.warning,
      );
      return;
    }

    if (!ref.read(networkStatusControllerProvider).hasInternet) {
      _showToast(
        text.globalOfflineBannerMessage,
        tone: PetMagicToastTone.warning,
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final submitCancelToken = CancelToken();
    _submitCancelToken = submitCancelToken;

    try {
      final attachments = List<XFile>.unmodifiable(_attachments);
      final repository = ref.read(supportChatRepositoryProvider);
      final localeTag = Localizations.localeOf(context).toLanguageTag();
      final conversation = await repository.openConversation(
        initialMessage: description,
        source: 'MobileAssistant',
        assistantScenario: scenario,
        relatedGenerationId: relatedGenerationId,
        relatedPaymentId: relatedPaymentId,
        cancelToken: submitCancelToken,
      );

      if (!mounted) {
        return;
      }

      for (final file in attachments) {
        if (!mounted) {
          return;
        }

        await repository.sendAttachment(
          conversationId: conversation.conversationId,
          filePath: file.path,
          fileName: file.name,
          contentType: _resolveContentTypeForUpload(file.path),
          localeTag: localeTag,
          cancelToken: submitCancelToken,
        );

        if (!mounted) {
          return;
        }
      }

      if (!mounted) {
        return;
      }

      _showToast(
        text.supportTicketFormSuccessMessage,
        tone: PetMagicToastTone.success,
      );
      context.go(SupportChatPage.routePath);
    } catch (error, stackTrace) {
      if (!mounted) {
        return;
      }

      _logSupportTicketFailure(
        'submit_ticket',
        error,
        stackTrace,
        context: {
          'scenario': scenario,
          'attachments_count': _attachments.length,
        },
      );
      if (!mounted) {
        return;
      }
      _showToast(
        text.supportTicketFormErrorMessage,
        tone: PetMagicToastTone.warning,
      );
    } finally {
      if (identical(_submitCancelToken, submitCancelToken)) {
        _submitCancelToken = null;
      }
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _cancelSubmit() {
    final cancelToken = _submitCancelToken;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('support_ticket_disposed');
    }
    _submitCancelToken = null;
  }

  String _resolveContentTypeForUpload(String path) {
    final normalized = path.toLowerCase();
    if (normalized.endsWith('.png')) {
      return 'image/png';
    }
    if (normalized.endsWith('.webp')) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }

  String? _asGuidOrNull(String? raw) {
    if (raw == null) {
      return null;
    }

    final value = raw.trim();
    final guidPattern = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    );
    return guidPattern.hasMatch(value) ? value : null;
  }

  String _mapSupportError(AppLocalizations text, String code) {
    final authMessage = mapCommonAuthFeedbackMessage(text, code);
    if (authMessage != null) {
      return authMessage;
    }

    final normalized = code.toLowerCase();
    if (normalized.contains('attachment_file_too_large')) {
      return text.supportChatAttachmentTooLargeError;
    }
    if (normalized.contains('attachment_file_required') ||
        normalized.contains('attachment_file_name_required') ||
        normalized.contains('attachment_file_name_too_long') ||
        normalized.contains('attachment_content_type_too_long')) {
      return text.supportChatAttachmentUnavailableError;
    }
    if (normalized.contains('attachment_content_type_not_allowed')) {
      return text.supportChatAttachmentUnavailableError;
    }
    return text.supportChatUnavailableError;
  }

  Future<void> _preloadSupportContext() async {
    if (!mounted) {
      return;
    }

    if (!ref.read(appLaunchControllerProvider).isAuthenticated) {
      return;
    }

    if (!ref.read(networkStatusControllerProvider).hasInternet) {
      return;
    }

    final preloadTasks = <Future<void>>[];

    final generationState = ref.read(generationHistoryControllerProvider);
    if (_shouldPreloadGenerationContext(generationState)) {
      preloadTasks.add(
        _preloadContextStep(
          'preload_generation_context',
          () => ref.read(generationHistoryControllerProvider.notifier).load(),
        ),
      );
    }

    final walletState = ref.read(walletControllerProvider);
    if (_shouldPreloadWalletContext(walletState)) {
      preloadTasks.add(
        _preloadContextStep(
          'preload_wallet_context',
          () => ref.read(walletControllerProvider.notifier).load(),
        ),
      );
    }

    final premiumState = ref.read(premiumControllerProvider);
    if (_shouldPreloadPremiumContext(premiumState)) {
      preloadTasks.add(
        _preloadContextStep(
          'preload_premium_context',
          () => ref.read(premiumControllerProvider.notifier).load(),
        ),
      );
    }

    if (preloadTasks.isEmpty) {
      return;
    }

    await Future.wait<void>(preloadTasks);
  }

  bool _shouldPreloadGenerationContext(GenerationHistoryState state) {
    if (state.isLoading) {
      return false;
    }

    return state.items.isEmpty && state.cachedItemsByFilter.isEmpty;
  }

  bool _shouldPreloadWalletContext(WalletState state) {
    if (state.isLoading || state.isRefreshing) {
      return false;
    }

    if (state.hasCompletedFullLoad) {
      return false;
    }

    return state.wallet == null || state.purchases.isEmpty;
  }

  bool _shouldPreloadPremiumContext(PremiumState state) {
    if (state.isLoading) {
      return false;
    }

    return state.status == null;
  }

  String? _resolveSubscriptionLabel(AppLocalizations text, PremiumState state) {
    final status = state.status;
    if (status?.isPremium != true) {
      return null;
    }

    final planName = status?.planName?.trim();
    if (planName != null && planName.isNotEmpty) {
      return planName;
    }

    return text.premiumLabel;
  }

  Future<void> _preloadContextStep(
    String stage,
    Future<void> Function() load,
  ) async {
    if (!mounted) {
      return;
    }

    try {
      await load();
    } catch (error, stackTrace) {
      if (!mounted) {
        return;
      }
      _logSupportTicketFailure(stage, error, stackTrace);
    }
  }
}

enum _AttachmentSource { camera, gallery }
