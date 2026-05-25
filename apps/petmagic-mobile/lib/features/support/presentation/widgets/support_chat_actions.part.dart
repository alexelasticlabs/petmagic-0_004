part of '../support_chat_page.dart';

extension _SupportChatPageActions on _SupportChatPageState {
  Future<void> _pickImageAttachmentImpl() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
      maxWidth: 1800,
    );
    if (picked == null || !mounted) {
      return;
    }

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
      return;
    }

    try {
      final fileSizeBytes = await File(picked.path).length();
      if (!mounted) {
        return;
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
        return;
      }
    } on Object {
      // If file size cannot be resolved on this platform, rely on backend validation.
    }

    _applyState(() {
      _pendingAttachment = _PendingSupportAttachment(
        filePath: picked.path,
        fileName: picked.name,
        contentType: contentType,
      );
    });
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
                  ListTile(
                    leading: const Icon(
                      Icons.photo_library_outlined,
                      color: _supportComposerIconColor,
                    ),
                    title: Text(
                      text.imageLabel,
                      style: TextStyle(color: colors.textStrong),
                    ),
                    onTap: () => Navigator.of(
                      sheetContext,
                    ).pop(_SupportAttachmentAction.gallery),
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
      case _SupportAttachmentAction.gallery:
        await _pickImageAttachmentImpl();
    }
  }

  Future<void> _sendCurrentMessageImpl(String localeTag) async {
    if (_hasPendingAttachment) {
      await _sendPendingAttachmentImpl(localeTag);
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

  Future<void> _sendPendingAttachmentImpl(String localeTag) async {
    final pendingAttachment = _pendingAttachment;
    if (pendingAttachment == null) {
      return;
    }

    final previousConversation = ref
        .read(supportChatControllerProvider)
        .conversation;
    final previousMessageCount = previousConversation?.messages.length ?? 0;

    final wasSent = await _controller.sendAttachment(
      filePath: pendingAttachment.filePath,
      fileName: pendingAttachment.fileName,
      contentType: pendingAttachment.contentType,
      localeTag: localeTag,
      body: _messageController.text,
    );

    if (!mounted) {
      return;
    }

    final currentState = ref.read(supportChatControllerProvider);
    final currentConversation = currentState.conversation;
    final latestMessage = currentConversation?.messages.isNotEmpty == true
        ? currentConversation!.messages.last
        : null;

    final attachmentResultPersisted =
        (currentConversation?.messages.length ?? 0) > previousMessageCount &&
        latestMessage != null &&
        latestMessage.attachmentFileName == pendingAttachment.fileName &&
        (latestMessage.isAttachmentUploaded ||
            latestMessage.isAttachmentFailed);

    final errorValue = ref.read(supportChatControllerProvider).errorMessage;
    final isTransportFailure =
        errorValue?.contains('support.unavailable') == true ||
        errorValue?.contains('support.request_failed') == true;

    if (wasSent || attachmentResultPersisted || !isTransportFailure) {
      _messageController.clear();
      _applyState(() {
        _pendingAttachment = null;
      });
    }
  }

  void _removePendingAttachmentImpl() {
    _applyState(() {
      _pendingAttachment = null;
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
      final targetPath = await FilePicker.platform.saveFile(
        dialogTitle: text.supportChatSaveImageAction,
        fileName: safeFileName,
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      );

      if (targetPath == null || targetPath.trim().isEmpty) {
        return;
      }

      await File(targetPath).writeAsBytes(bytes, flush: true);
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
    final response = await Dio().get<List<int>>(
      imageUrl,
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data ?? const <int>[];
  }

  String _safeImageFileNameImpl(String? value) {
    final fallback =
        'support-image-${DateTime.now().millisecondsSinceEpoch}.jpg';
    final candidate = value?.trim();
    if (candidate == null || candidate.isEmpty) {
      return fallback;
    }

    return candidate.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
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
