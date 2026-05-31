import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/permissions/app_permission_coordinator.dart';
import 'package:petmagic_mobile/features/premium/presentation/premium_controller.dart';
import 'package:petmagic_mobile/features/profile/presentation/profile_surface_widgets.dart';
import 'package:petmagic_mobile/features/support/data/support_chat_repository.dart';
import 'package:petmagic_mobile/features/support/presentation/support_assistant_scenarios.dart';
import 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';
import 'package:petmagic_mobile/features/templates/presentation/generation_history_controller.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_controller.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_modal_sheet.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_toast.dart';

class SupportTicketFormPage extends ConsumerStatefulWidget {
  const SupportTicketFormPage({required this.scenario, super.key});

  static const routePath = '/profile/support/ticket';

  final String scenario;

  @override
  ConsumerState<SupportTicketFormPage> createState() =>
      _SupportTicketFormPageState();
}

class _SupportTicketFormPageState extends ConsumerState<SupportTicketFormPage> {
  static const _maxAttachmentCount = 5;
  static const _maxAttachmentFileSizeBytes = 10 * 1024 * 1024;

  final TextEditingController _descriptionController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final AppPermissionCoordinator _permissionCoordinator =
      AppPermissionCoordinator();

  void _showToast(
    String message, {
    PetMagicToastTone tone = PetMagicToastTone.info,
  }) {
    PetMagicToast.show(context, message: message, tone: tone);
  }

  List<XFile> _attachments = const [];
  bool _isSubmitting = false;

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

    developer.Timeline.instantSync(
      'petmagic.support.ticket.error',
      arguments: payload,
    );
    developer.log(
      'SupportTicketForm::$stage failed',
      name: 'PetMagic.Support.TicketForm',
      error: error,
      stackTrace: stackTrace,
    );
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(generationHistoryControllerProvider.notifier).load();
      await ref.read(walletControllerProvider.notifier).load();
      await ref.read(premiumControllerProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final scenarioData = buildSupportAssistantScenario(widget.scenario, text);

    final generationState = ref.watch(generationHistoryControllerProvider);
    final walletState = ref.watch(walletControllerProvider);
    final premiumState = ref.watch(premiumControllerProvider);

    final generationId = generationState.items.isEmpty
        ? null
        : generationState.items.first.generationId;
    final paymentId = walletState.purchases.isEmpty
        ? null
        : walletState.purchases.first.orderId;
    final subscriptionLabel = premiumState.status?.isPremium == true
        ? premiumState.status?.status ?? 'Premium'
        : null;

    return ProfileScreenBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(text.supportTicketFormTitle),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ContextCard(
                  label: text.supportTicketFormTopicLabel,
                  value: scenarioData.topicLabel,
                ),
                if (generationId != null)
                  _ContextCard(
                    label: text.supportTicketFormRelatedGenerationLabel,
                    value: generationId,
                  ),
                if (paymentId != null)
                  _ContextCard(
                    label: text.supportTicketFormRelatedPaymentLabel,
                    value: paymentId,
                  ),
                if (subscriptionLabel != null)
                  _ContextCard(
                    label: text.supportTicketFormRelatedSubscriptionLabel,
                    value: subscriptionLabel,
                  ),
                const SizedBox(height: 10),
                Text(
                  text.supportTicketFormDescriptionLabel,
                  style: TextStyle(
                    color: colors.textStrong,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _descriptionController,
                  maxLines: 5,
                  minLines: 4,
                  style: TextStyle(color: colors.textStrong),
                  decoration: InputDecoration(
                    hintText: text.supportTicketFormDescriptionHint,
                    hintStyle: TextStyle(color: colors.textMuted),
                    filled: true,
                    fillColor: colors.surfaceStrong.withValues(alpha: 0.7),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: colors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: colors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: colors.accent),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      text.supportTicketFormAttachmentsLabel,
                      style: TextStyle(
                        color: colors.textStrong,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _isSubmitting ? null : _showAttachmentOptions,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: Text(text.supportTicketFormAddScreenshotAction),
                    ),
                  ],
                ),
                if (_attachments.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < _attachments.length; i++)
                        _AttachmentChip(
                          file: _attachments[i],
                          onRemove: _isSubmitting
                              ? null
                              : () {
                                  setState(() {
                                    _attachments = [
                                      ..._attachments.take(i),
                                      ..._attachments.skip(i + 1),
                                    ];
                                  });
                                },
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => _submit(
                            scenario: scenarioData.key,
                            relatedGenerationId: _asGuidOrNull(generationId),
                            relatedPaymentId: _asGuidOrNull(paymentId),
                          ),
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      _isSubmitting
                          ? text.supportTicketFormSubmittingLabel
                          : text.supportTicketFormSubmitAction,
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

  Future<void> _showAttachmentOptions() async {
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
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surfaceStrong,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: colors.border.withValues(alpha: 0.9)),
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
    final permission = await _permissionCoordinator.requestOnDemand(
      AppPermissionType.camera,
    );
    if (!permission.granted) {
      if (mounted) {
        final text = AppLocalizations.of(context);
        _showToast(
          text.supportChatCameraPermissionPhotoError,
          tone: PetMagicToastTone.warning,
        );
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
  }

  Future<void> _pickFromGallery() async {
    final permission = await _permissionCoordinator.requestOnDemand(
      AppPermissionType.photos,
    );
    if (!permission.granted) {
      if (mounted) {
        final text = AppLocalizations.of(context);
        _showToast(
          text.supportChatAttachmentNoGalleryAccessError,
          tone: PetMagicToastTone.warning,
        );
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

    try {
      final fileSizeBytes = await File(picked.path).length();
      if (!mounted) {
        return null;
      }

      if (fileSizeBytes > _maxAttachmentFileSizeBytes) {
        _showToast(
          _mapSupportError(
            AppLocalizations.of(context),
            'support.attachment_file_too_large',
          ),
          tone: PetMagicToastTone.warning,
        );
        return null;
      }
    } on Object {
      // If size cannot be resolved, backend validation will still guard limits.
    }

    return picked;
  }

  Future<void> _submit({
    required String scenario,
    String? relatedGenerationId,
    String? relatedPaymentId,
  }) async {
    final text = AppLocalizations.of(context);
    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      _showToast(
        text.supportTicketFormDescriptionHint,
        tone: PetMagicToastTone.warning,
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final repository = ref.read(supportChatRepositoryProvider);
      final localeTag = Localizations.localeOf(context).toLanguageTag();
      final conversation = await repository.openConversation(
        initialMessage: description,
        source: 'MobileAssistant',
        assistantScenario: scenario,
        relatedGenerationId: relatedGenerationId,
        relatedPaymentId: relatedPaymentId,
      );

      for (final file in _attachments) {
        await repository.sendAttachment(
          conversationId: conversation.conversationId,
          filePath: file.path,
          fileName: file.name,
          contentType: _resolveContentTypeForUpload(file.path),
          localeTag: localeTag,
        );
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
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
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
    final normalized = code.toLowerCase();
    if (normalized.contains('attachment_file_too_large')) {
      return text.supportChatAttachmentTooLargeError;
    }
    if (normalized.contains('attachment_content_type_not_allowed')) {
      return text.supportChatAttachmentUnavailableError;
    }
    return text.supportChatUnavailableError;
  }
}

enum _AttachmentSource { camera, gallery }

class _ContextCard extends StatelessWidget {
  const _ContextCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ProfileGlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: colors.textStrong,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentChip extends StatelessWidget {
  const _AttachmentChip({required this.file, this.onRemove});

  final XFile file;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceStrong.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_outlined, size: 16, color: colors.textSoft),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(
                file.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textSoft,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (onRemove != null) ...[
              const SizedBox(width: 6),
              InkWell(
                onTap: onRemove,
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: colors.textMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
