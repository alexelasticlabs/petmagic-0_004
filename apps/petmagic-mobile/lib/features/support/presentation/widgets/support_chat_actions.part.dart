part of 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';

extension _SupportChatPageActions on _SupportChatPageState {
  Future<void> _pickCameraPhotoAttachmentImpl() async {
    await _runAttachmentPickerSession(() async {
      if (!_canAddMoreAttachments()) {
        return null;
      }

      final text = AppLocalizations.of(context);
      final permissionFeedback = await ref
          .read(mediaPermissionFeedbackCoordinatorProvider)
          .requestWithText(
            text,
            permission: AppPermissionType.camera,
            flow: MediaPermissionFlow.cameraPhoto,
          );
      if (!mounted || !permissionFeedback.granted) {
        if (mounted) {
          ref
              .read(mediaPermissionFeedbackCoordinatorProvider)
              .show(context, permissionFeedback);
        }
        return null;
      }

      final picked = await _runExternalMediaPicker(
        () => _imagePicker.pickImage(
          source: ImageSource.camera,
          imageQuality: 92,
          maxWidth: 1800,
        ),
      );
      if (picked == null || !mounted) {
        return null;
      }

      final attachment = await _validatePickedAttachmentImpl(picked);
      if (attachment == null || !mounted) {
        return null;
      }

      _applyState(() {
        _pendingAttachments = [..._pendingAttachments, attachment];
      });
      return null;
    });
  }

  Future<void> _pickCameraVideoAttachmentImpl() async {
    await _runAttachmentPickerSession(() async {
      if (!_canAddMoreAttachments()) {
        return null;
      }

      final text = AppLocalizations.of(context);
      final cameraFeedback = await ref
          .read(mediaPermissionFeedbackCoordinatorProvider)
          .requestWithText(
            text,
            permission: AppPermissionType.camera,
            flow: MediaPermissionFlow.cameraVideo,
          );
      if (!mounted || !cameraFeedback.granted) {
        if (mounted) {
          ref
              .read(mediaPermissionFeedbackCoordinatorProvider)
              .show(context, cameraFeedback);
        }
        return null;
      }

      final microphoneFeedback = await ref
          .read(mediaPermissionFeedbackCoordinatorProvider)
          .requestWithText(
            text,
            permission: AppPermissionType.microphone,
            flow: MediaPermissionFlow.microphoneVideo,
          );
      if (!mounted || !microphoneFeedback.granted) {
        if (mounted) {
          ref
              .read(mediaPermissionFeedbackCoordinatorProvider)
              .show(context, microphoneFeedback);
        }
        return null;
      }

      final picked = await _runExternalMediaPicker(
        () => _imagePicker.pickVideo(
          source: ImageSource.camera,
          maxDuration: _supportAttachmentVideoMaxDuration,
        ),
      );
      if (picked == null || !mounted) {
        return null;
      }

      final attachment = await _validatePickedAttachmentImpl(picked);
      if (attachment == null || !mounted) {
        return null;
      }

      _applyState(() {
        _pendingAttachments = [..._pendingAttachments, attachment];
      });
      return null;
    });
  }

  Future<void> _pickCameraMediaFromTileImpl() async {
    final action = await showModalBottomSheet<_SupportAttachmentQuickAction>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) {
        final colors = context.petMagicColors;
        final bottomInset = petMagicScrollableBottomInset(dialogContext);
        final text = AppLocalizations.of(dialogContext);
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
              child: Wrap(
                children: [
                  ListTile(
                    leading: const Icon(Icons.photo_camera_outlined),
                    title: Text(text.supportChatTakePhotoAction),
                    onTap: () => Navigator.of(
                      dialogContext,
                    ).pop(_SupportAttachmentQuickAction.camera),
                  ),
                  ListTile(
                    leading: const Icon(Icons.videocam_outlined),
                    title: Text(text.supportChatRecordVideoAction),
                    onTap: () => Navigator.of(
                      dialogContext,
                    ).pop(_SupportAttachmentQuickAction.video),
                  ),
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

    if (action == _SupportAttachmentQuickAction.camera) {
      await _pickCameraPhotoAttachmentImpl();
      return;
    }

    if (action == _SupportAttachmentQuickAction.video) {
      await _pickCameraVideoAttachmentImpl();
    }
  }

  Future<void> _pickFileAttachmentsImpl() async {
    await _runAttachmentPickerSession(() async {
      if (!_canAddMoreAttachments()) {
        return null;
      }

      final permissionGranted = await _requestMixedMediaGalleryPermission();
      if (!permissionGranted) {
        return null;
      }

      final remainingSlots =
          _supportAttachmentMaxCount - _pendingAttachments.length;
      final pickedFiles = await _runExternalMediaPicker(
        () async => remainingSlots == 1
            ? [?(await _imagePicker.pickMedia(imageQuality: 92))]
            : await _imagePicker.pickMultipleMedia(
                imageQuality: 92,
                limit: remainingSlots,
              ),
      );
      if (pickedFiles.isEmpty || !mounted) {
        return null;
      }
      if (pickedFiles.length > remainingSlots) {
        _showSupportToast(
          AppLocalizations.of(context).supportChatTooManyAttachmentsError,
          tone: PetMagicToastTone.warning,
        );
      }

      final nextAttachments = <_PendingSupportAttachment>[];
      for (final file in pickedFiles.take(remainingSlots)) {
        final attachment = await _validateAttachmentCandidateImpl(
          filePath: file.path,
          fileName: file.name,
        );
        if (attachment != null) {
          nextAttachments.add(attachment);
        }

        if (!mounted) {
          return null;
        }
      }

      if (nextAttachments.isEmpty) {
        return null;
      }

      _applyState(() {
        _pendingAttachments = [..._pendingAttachments, ...nextAttachments];
      });
      return null;
    });
  }

  Future<bool> _requestMixedMediaGalleryPermission() async {
    final photosFeedback = await ref
        .read(mediaPermissionFeedbackCoordinatorProvider)
        .requestPermission(
          context,
          permission: AppPermissionType.photos,
          flow: MediaPermissionFlow.mediaLibrary,
        );
    if (!mounted || !photosFeedback.granted) {
      if (mounted) {
        ref
            .read(mediaPermissionFeedbackCoordinatorProvider)
            .show(context, photosFeedback);
      }
      return false;
    }

    if (!Platform.isAndroid) {
      return true;
    }

    final videosFeedback = await ref
        .read(mediaPermissionFeedbackCoordinatorProvider)
        .requestPermission(
          context,
          permission: AppPermissionType.videos,
          flow: MediaPermissionFlow.mediaLibrary,
        );
    if (!mounted || !videosFeedback.granted) {
      if (mounted) {
        ref
            .read(mediaPermissionFeedbackCoordinatorProvider)
            .show(context, videosFeedback);
      }
      return false;
    }

    return true;
  }

  bool _canAddMoreAttachments() {
    if (_pendingAttachments.length < _supportAttachmentMaxCount) {
      return true;
    }

    _showSupportToast(
      AppLocalizations.of(context).supportChatTooManyAttachmentsError,
      tone: PetMagicToastTone.warning,
    );
    return false;
  }

  Future<_PendingSupportAttachment?> _validatePickedAttachmentImpl(
    XFile picked,
  ) async {
    return _validateAttachmentCandidateImpl(
      filePath: picked.path,
      fileName: picked.name,
    );
  }

  Future<_PendingSupportAttachment?> _validateAttachmentCandidateImpl({
    required String filePath,
    required String fileName,
    Duration? videoDuration,
    String? sourceAssetId,
  }) async {
    final contentType = _controller.resolveContentTypeForUpload(filePath);
    int fileSizeBytes = 0;
    try {
      fileSizeBytes = await File(filePath).length();
    } on Exception {
      // If file size cannot be resolved on this platform, rely on backend validation.
    }
    if (!mounted) {
      return null;
    }

    var resolvedVideoDuration = videoDuration;
    final isVideoCandidate = SupportAttachmentValidation.videoMimeTypes
        .contains(contentType.toLowerCase());
    if (isVideoCandidate && resolvedVideoDuration == null) {
      resolvedVideoDuration = await _resolveVideoDurationFromFileImpl(filePath);
      if (!mounted) {
        return null;
      }
    }

    final validationResult = SupportAttachmentValidation.validate(
      contentType: contentType,
      // Large still-decodable images may be reduced before upload; videos keep strict local limits.
      fileSizeBytes: isVideoCandidate ? fileSizeBytes : 0,
      imageMaxBytes: _supportAttachmentImageMaxFileSizeBytes,
      videoMaxBytes: _supportAttachmentVideoMaxFileSizeBytes,
      videoMaxDuration: _supportAttachmentVideoMaxDuration,
      videoDuration: resolvedVideoDuration,
    );

    if (!validationResult.isAllowed) {
      _showAttachmentValidationErrorImpl(validationResult.error);
      return null;
    }

    return _PendingSupportAttachment(
      filePath: filePath,
      fileName: fileName,
      contentType: contentType,
      isVideo: validationResult.isVideo,
      sourceAssetId: sourceAssetId,
    );
  }

  Future<Duration?> _resolveVideoDurationFromFileImpl(String filePath) async {
    final controller = VideoPlayerController.file(File(filePath));
    try {
      await controller.initialize();
      return controller.value.duration;
    } on Exception {
      return null;
    } finally {
      await controller.dispose();
    }
  }

  void _showAttachmentValidationErrorImpl(
    SupportAttachmentValidationError? error,
  ) {
    if (!mounted || error == null) {
      return;
    }

    final text = AppLocalizations.of(context);
    final message = switch (error) {
      SupportAttachmentValidationError.unsupportedFormat =>
        text.supportChatAttachmentUnsupportedFormatError,
      SupportAttachmentValidationError.fileTooLarge =>
        text.supportChatAttachmentTooLargeError,
      SupportAttachmentValidationError.videoTooLong =>
        text.supportChatAttachmentVideoTooLongError,
    };
    _showSupportToast(message, tone: PetMagicToastTone.warning);
  }

  Future<void> _showAttachmentOptionsImpl() async {
    if (ref.read(supportChatControllerProvider).isSending) {
      return;
    }

    FocusScope.of(context).unfocus();
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final action = await showModalBottomSheet<_SupportAttachmentQuickAction>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (sheetContext) {
        final keyboardInset = MediaQuery.viewInsetsOf(sheetContext).bottom;
        return AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.only(bottom: keyboardInset),
          child: DraggableScrollableSheet(
            expand: false,
            minChildSize: 0.45,
            initialChildSize: 0.52,
            maxChildSize: 0.98,
            snap: true,
            snapSizes: const [0.52, 0.98],
            builder: (context, scrollController) {
              return _SupportAttachmentPickerSheet(
                scrollController: scrollController,
                selectedAssetIds: _pendingAttachments
                    .map((attachment) => attachment.sourceAssetId)
                    .whereType<String>()
                    .toSet(),
                selectedAssetOrderById: {
                  for (
                    var index = 0;
                    index < _pendingAttachments.length;
                    index++
                  )
                    if (_pendingAttachments[index].sourceAssetId != null)
                      _pendingAttachments[index].sourceAssetId!: index + 1,
                },
                onSendSelected: (assets, caption) =>
                    _sendSelectedAssetsFromPickerImpl(
                      assets: assets,
                      localeTag: localeTag,
                      caption: caption,
                    ),
              );
            },
          ),
        );
      },
    );

    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case _SupportAttachmentQuickAction.camera:
        await _pickCameraMediaFromTileImpl();
        return;
      case _SupportAttachmentQuickAction.files:
        await _pickFileAttachmentsImpl();
        return;
      case _SupportAttachmentQuickAction.video:
        return;
    }
  }

  Future<void> _sendCurrentMessageImpl(String localeTag) async {
    if (_hasPendingAttachment) {
      await _sendPendingAttachmentsImpl(localeTag);
      return;
    }

    final body = _messageController.text;
    final wasSent = await _controller.sendMessage(
      body,
      localeTag: localeTag,
      replyToMessageId: _replyToMessage?.messageId,
      relatedGenerationId: widget.relatedGenerationId,
    );
    if (!mounted || !wasSent) {
      return;
    }

    if (body.trim().isNotEmpty) {
      _messageController.clear();
    }
    _applyState(() {
      _replyToMessage = null;
    });
  }

  Future<void> _sendPendingAttachmentsImpl(String localeTag) async {
    final pendingAttachments = [..._pendingAttachments];
    if (pendingAttachments.isEmpty) {
      return;
    }

    final body = _messageController.text;
    final wasSent = await _controller.sendAttachments(
      attachments: pendingAttachments
          .map(
            (attachment) => SupportChatUploadAttachment(
              filePath: attachment.filePath,
              fileName: attachment.fileName,
              contentType: attachment.contentType,
            ),
          )
          .toList(growable: false),
      localeTag: localeTag,
      body: body,
      replyToMessageId: _replyToMessage?.messageId,
    );
    if (!mounted || !wasSent) {
      return;
    }

    _messageController.clear();
    _applyState(() {
      _pendingAttachments = const [];
      _replyToMessage = null;
    });
  }

  Future<bool> _sendSelectedAssetsFromPickerImpl({
    required List<AssetEntity> assets,
    required String localeTag,
    required String caption,
  }) async {
    if (assets.isEmpty) {
      return false;
    }

    final nextAttachments = <_PendingSupportAttachment>[];
    for (final asset in assets.take(_supportAttachmentMaxCount)) {
      final file = await asset.file;
      if (file == null) {
        continue;
      }

      final attachment = await _validateAttachmentCandidateImpl(
        filePath: file.path,
        fileName: asset.title ?? file.uri.pathSegments.last,
        videoDuration: asset.type == AssetType.video
            ? asset.videoDuration
            : null,
        sourceAssetId: asset.id,
      );
      if (attachment != null) {
        nextAttachments.add(attachment);
      }

      if (!mounted) {
        return false;
      }
    }

    if (nextAttachments.isEmpty) {
      return false;
    }

    final composerBody = _messageController.text.trim();
    final captionBody = caption.trim();
    final body = captionBody.isNotEmpty ? captionBody : composerBody;
    final wasSent = await _controller.sendAttachments(
      attachments: nextAttachments
          .map(
            (attachment) => SupportChatUploadAttachment(
              filePath: attachment.filePath,
              fileName: attachment.fileName,
              contentType: attachment.contentType,
            ),
          )
          .toList(growable: false),
      localeTag: localeTag,
      body: body,
      replyToMessageId: _replyToMessage?.messageId,
    );
    if (!mounted || !wasSent) {
      return false;
    }

    _messageController.clear();
    _applyState(() {
      _pendingAttachments = const [];
      _replyToMessage = null;
    });
    return true;
  }

  void _removePendingAttachmentImpl(int index) {
    if (index < 0 || index >= _pendingAttachments.length) {
      return;
    }

    _applyState(() {
      _pendingAttachments = [
        for (var i = 0; i < _pendingAttachments.length; i++)
          if (i != index) _pendingAttachments[i],
      ];
    });
  }

  Future<void> _retryAttachmentForMessageImpl(
    SupportChatMessage message,
  ) async {
    if (message.messageId.isEmpty || !message.canRetryAttachment) {
      return;
    }

    final pickedFile = await _runExternalMediaPicker(
      () => _imagePicker.pickMedia(imageQuality: 92),
    );
    if (pickedFile == null || !mounted) {
      return;
    }
    final attachment = await _validateAttachmentCandidateImpl(
      filePath: pickedFile.path,
      fileName: pickedFile.name,
    );
    if (attachment == null) {
      return;
    }

    await _controller.retryAttachment(
      messageId: message.messageId,
      filePath: attachment.filePath,
      fileName: attachment.fileName,
      contentType: attachment.contentType,
    );
  }

  Future<void> _openImageFullscreenImpl({
    required String imageUrl,
    String? fileName,
  }) async {
    final safeUri = parseSafeSupportExternalUri(imageUrl);
    if (safeUri == null) {
      if (mounted) {
        _showSupportToast(
          AppLocalizations.of(context).supportChatUnavailableError,
          tone: PetMagicToastTone.warning,
        );
      }
      return;
    }

    final safeImageUrl = safeUri.toString();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _SupportImagePreviewDialog(
          imageUrl: safeImageUrl,
          fileName: fileName,
          onSaveImage: () => _saveImageToDeviceImpl(
            imageUrl: safeImageUrl,
            fileName: fileName,
          ),
          onShareImage: () =>
              _shareImageImpl(imageUrl: safeImageUrl, fileName: fileName),
          onOpenOriginal: () => _openAttachmentExternallyImpl(safeImageUrl),
        );
      },
    );
  }

  Future<void> _openVideoFullscreenImpl({
    required String videoUrl,
    String? fileName,
  }) async {
    final safeUri = parseSafeSupportExternalUri(videoUrl);
    if (safeUri == null) {
      if (mounted) {
        _showSupportToast(
          AppLocalizations.of(context).supportChatUnavailableError,
          tone: PetMagicToastTone.warning,
        );
      }
      return;
    }

    final safeVideoUrl = safeUri.toString();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _SupportVideoPreviewDialog(
          videoUrl: safeVideoUrl,
          fileName: fileName,
          onOpenOriginal: () => _openAttachmentExternallyImpl(safeVideoUrl),
        );
      },
    );
  }

  String _formatDayLabelImpl(DateTime value) {
    final localValue = value.toLocal();
    final localNow = DateTime.now();
    if (_isSameDayImpl(localValue, localNow)) {
      return AppLocalizations.of(context).supportChatTodayLabel;
    }

    return DateFormat('MMM d').format(localValue);
  }

  bool _isSameDayImpl(DateTime left, DateTime right) {
    final localLeft = left.toLocal();
    final localRight = right.toLocal();
    return localLeft.year == localRight.year &&
        localLeft.month == localRight.month &&
        localLeft.day == localRight.day;
  }
}
