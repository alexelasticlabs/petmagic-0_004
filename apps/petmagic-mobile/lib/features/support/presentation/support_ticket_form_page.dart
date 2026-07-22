import 'dart:async';
import 'package:petmagic_mobile/core/operations/request_cancellation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/core/navigation/app_navigator.dart';
import 'package:petmagic_mobile/core/permissions/media_permission_feedback.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/premium/application/premium_controller.dart';
import 'package:petmagic_mobile/shared/auth/auth_required_sheet.dart';
import 'package:petmagic_mobile/shared/profile/profile_surface_widgets.dart';
import 'package:petmagic_mobile/features/support/application/support_contract.dart';
import 'package:petmagic_mobile/features/support/presentation/support_assistant_scenarios.dart';
import 'package:petmagic_mobile/features/support/presentation/support_ticket_context_preloader.dart';
import 'package:petmagic_mobile/features/support/presentation/support_ticket_form_policy.dart';
import 'package:petmagic_mobile/features/support/presentation/widgets/support_ticket_attachment_source_sheet.dart';
import 'package:petmagic_mobile/features/templates/application/template_generation_contract.dart';
import 'package:petmagic_mobile/features/wallet/application/wallet_controller.dart';
import 'package:petmagic_mobile/shared/navigation/app_navigation_context.dart';
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
  RequestCancellation? _submitCancelToken;
  ProviderSubscription<AppLaunchState>? _launchSubscription;
  bool _wasAuthenticated = false;
  bool _hasScheduledSupportContextPreload = false;

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
        (state) => resolveSupportTicketSubscriptionLabel(text, state),
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
        relatedGenerationId: supportTicketGuidOrNull(generationId),
        relatedPaymentId: supportTicketGuidOrNull(paymentId),
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

    final action = await showSupportTicketAttachmentSourceSheet(context);
    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case SupportTicketAttachmentSource.camera:
        await _pickFromCamera();
      case SupportTicketAttachmentSource.gallery:
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
    final type = resolveSupportTicketContentType(picked.path).toLowerCase();
    if (type != 'image/jpeg' && type != 'image/png' && type != 'image/webp') {
      _showToast(
        mapSupportTicketError(
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

    final submitCancelToken = RequestCancellation();
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
          contentType: resolveSupportTicketContentType(file.path),
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
      context.appNavigator.go(const SupportChatDestination());
    } catch (error, stackTrace) {
      if (!mounted) {
        return;
      }

      logSupportTicketFailure(
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

  Future<void> _preloadSupportContext() {
    return const SupportTicketContextPreloader().preload(
      ref: ref,
      isActive: () => mounted,
      onFailure: (stage, error, stackTrace) =>
          logSupportTicketFailure(stage, error, stackTrace),
    );
  }
}
