part of '../support_chat_page.dart';

extension _SupportChatPageActions on _SupportChatPageState {
  Future<void> _pickCameraAttachmentImpl() async {
    if (!_canAddMoreAttachments()) {
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

    final attachment = await _validatePickedImageAttachmentImpl(picked);
    if (attachment == null || !mounted) {
      return;
    }

    _applyState(() {
      _pendingAttachments = [..._pendingAttachments, attachment];
    });
  }

  Future<void> _pickGalleryAttachmentsImpl() async {
    if (!_canAddMoreAttachments()) {
      return;
    }

    final remainingSlots =
        _supportAttachmentMaxCount - _pendingAttachments.length;
    final pickedImages = await _imagePicker.pickMultiImage(
      imageQuality: 92,
      maxWidth: 1800,
    );
    if (pickedImages.isEmpty || !mounted) {
      return;
    }

    final nextAttachments = <_PendingSupportAttachment>[];
    for (final picked in pickedImages.take(remainingSlots)) {
      final attachment = await _validatePickedImageAttachmentImpl(picked);
      if (attachment != null) {
        nextAttachments.add(attachment);
      }

      if (!mounted) {
        return;
      }
    }

    if (nextAttachments.isEmpty) {
      return;
    }

    _applyState(() {
      _pendingAttachments = [..._pendingAttachments, ...nextAttachments];
    });
  }

  bool _canAddMoreAttachments() {
    if (_pendingAttachments.length < _supportAttachmentMaxCount) {
      return true;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context).supportChatTooManyAttachmentsError,
        ),
      ),
    );
    return false;
  }

  Future<_PendingSupportAttachment?> _validatePickedImageAttachmentImpl(
    XFile picked,
  ) async {
    final contentType = _controller.resolveContentTypeForUpload(picked.path);
    final normalizedType = contentType.toLowerCase();
    if (normalizedType != 'image/jpeg' &&
        normalizedType != 'image/png' &&
        normalizedType != 'image/webp') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _mapSupportError(
              AppLocalizations.of(context),
              'support.attachment_content_type_not_allowed',
            ),
          ),
        ),
      );
      return null;
    }

    try {
      final fileSizeBytes = await File(picked.path).length();
      if (!mounted) {
        return null;
      }

      if (fileSizeBytes > _supportAttachmentMaxFileSizeBytes) {
        final text = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _mapSupportError(text, 'support.attachment_file_too_large'),
            ),
          ),
        );
        return null;
      }
    } on Object {
      // If file size cannot be resolved on this platform, rely on backend validation.
    }

    return _PendingSupportAttachment(
      filePath: picked.path,
      fileName: picked.name,
      contentType: contentType,
    );
  }

  Future<void> _showAttachmentOptionsImpl() async {
    if (ref.read(supportChatControllerProvider).isSending) {
      return;
    }

    final action = await showPetMagicModalBottomSheet<_SupportAttachmentAction>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext, bottomInset) {
        final colors = sheetContext.petMagicColors;
        final text = AppLocalizations.of(sheetContext);
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surfaceStrong,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: colors.border.withValues(alpha: 0.85),
                ),
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
                    leading: const Icon(
                      Icons.photo_camera_outlined,
                      color: _supportComposerIconColor,
                    ),
                    title: Text(
                      text.supportChatTakePhotoAction,
                      style: TextStyle(color: colors.textStrong),
                    ),
                    onTap: () => Navigator.of(
                      sheetContext,
                    ).pop(_SupportAttachmentAction.camera),
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.photo_library_outlined,
                      color: _supportComposerIconColor,
                    ),
                    title: Text(
                      text.supportChatChooseGalleryAction,
                      style: TextStyle(color: colors.textStrong),
                    ),
                    onTap: () => Navigator.of(
                      sheetContext,
                    ).pop(_SupportAttachmentAction.gallery),
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
      case _SupportAttachmentAction.camera:
        await _pickCameraAttachmentImpl();
      case _SupportAttachmentAction.gallery:
        await _pickGalleryAttachmentsImpl();
    }
  }

  Future<void> _sendCurrentMessageImpl(String localeTag) async {
    if (_hasPendingAttachment) {
      await _sendPendingAttachmentsImpl(localeTag);
      return;
    }

    final body = _messageController.text;
    await _controller.sendMessage(body, localeTag: localeTag);
    if (!mounted) {
      return;
    }

    if (body.trim().isNotEmpty) {
      _messageController.clear();
    }
  }

  Future<void> _sendPendingAttachmentsImpl(String localeTag) async {
    final pendingAttachments = [..._pendingAttachments];
    if (pendingAttachments.isEmpty) {
      return;
    }

    final body = _messageController.text;
    for (var index = 0; index < pendingAttachments.length; index++) {
      final pendingAttachment = pendingAttachments[index];
      await _controller.sendAttachment(
        filePath: pendingAttachment.filePath,
        fileName: pendingAttachment.fileName,
        contentType: pendingAttachment.contentType,
        localeTag: localeTag,
        body: index == 0 ? body : null,
        attachmentBatchIndex: index + 1,
        attachmentBatchTotal: pendingAttachments.length,
      );

      if (!mounted) {
        return;
      }

      final errorValue = ref.read(supportChatControllerProvider).errorMessage;
      final isTransportFailure =
          errorValue?.contains('support.unavailable') == true ||
          errorValue?.contains('support.request_failed') == true;
      if (isTransportFailure) {
        return;
      }
    }

    _messageController.clear();
    _applyState(() {
      _pendingAttachments = const [];
    });
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

    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
      maxWidth: 1800,
    );
    if (picked == null || !mounted) {
      return;
    }

    await _controller.retryAttachment(
      messageId: message.messageId,
      filePath: picked.path,
      fileName: picked.name,
      contentType: _controller.resolveContentTypeForUpload(picked.path),
    );
  }

  Future<void> _openImageFullscreenImpl({
    required String imageUrl,
    String? fileName,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _SupportImagePreviewDialog(
          imageUrl: imageUrl,
          fileName: fileName,
          onSaveImage: () =>
              _saveImageToDeviceImpl(imageUrl: imageUrl, fileName: fileName),
          onShareImage: () =>
              _shareImageImpl(imageUrl: imageUrl, fileName: fileName),
          onOpenOriginal: () => _openAttachmentExternallyImpl(imageUrl),
        );
      },
    );
  }

  Future<void> _openAttachmentExternallyImpl(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null) {
      return;
    }

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _saveImageToDeviceImpl({
    required String imageUrl,
    String? fileName,
  }) async {
    final text = AppLocalizations.of(context);
    try {
      final bytes = await _downloadImageBytesImpl(imageUrl);
      final safeFileName = _safeImageFileNameImpl(fileName);
      final wasSaved = await saveBytesToDevice(
        bytes: bytes,
        dialogTitle: text.supportChatSaveImageAction,
        fileName: safeFileName,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      );

      if (!wasSaved) {
        return;
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text.supportChatImageSavedMessage)),
      );
    } on Object {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text.supportChatSaveImageFailedError)),
      );
    }
  }

  Future<void> _shareImageImpl({
    required String imageUrl,
    String? fileName,
  }) async {
    final text = AppLocalizations.of(context);
    try {
      final bytes = await _downloadImageBytesImpl(imageUrl);
      final tempFileName = _safeImageFileNameImpl(fileName);
      final tempFile = File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}petmagic_$tempFileName',
      );
      await tempFile.writeAsBytes(bytes, flush: true);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(tempFile.path)],
          title: fileName ?? text.supportChatImageLabel,
          text: fileName ?? text.supportChatImageLabel,
        ),
      );
    } on Object {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text.supportChatShareImageFailedError)),
      );
    }
  }

  Future<List<int>> _downloadImageBytesImpl(String imageUrl) async {
    return downloadFileBytes(imageUrl);
  }

  String _safeImageFileNameImpl(String? value) {
    final fallback =
        'support-image-${DateTime.now().millisecondsSinceEpoch}.jpg';
    return sanitizeFileName(value, fallback: fallback);
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
