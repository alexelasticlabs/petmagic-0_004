part of 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';

extension _SupportChatPageMessageActions on _SupportChatPageState {
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
      relatedGenerationId: SupportChatPage.normalizeRelatedGenerationIdQuery(
        widget.relatedGenerationId,
      ),
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
}
