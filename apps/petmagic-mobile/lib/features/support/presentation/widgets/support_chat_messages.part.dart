part of 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    this.repliedMessage,
    this.onOpenAttachment,
    this.onOpenImage,
    this.onOpenVideo,
    this.onRetryAttachment,
    this.onReplyToMessage,
    this.onJumpToMessage,
    this.isHighlighted = false,
  });

  final SupportChatMessage message;
  final SupportChatMessage? repliedMessage;
  final Future<void> Function(String value)? onOpenAttachment;
  final Future<void> Function({required String imageUrl, String? fileName})?
  onOpenImage;
  final Future<void> Function({required String videoUrl, String? fileName})?
  onOpenVideo;
  final VoidCallback? onRetryAttachment;
  final VoidCallback? onReplyToMessage;
  final ValueChanged<String>? onJumpToMessage;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final text = AppLocalizations.of(context);
    final primaryAttachment = message.primaryAttachment;
    final hasMediaGroup = message.hasMediaGroup;
    final hasImageAttachment = message.hasImageAttachment;
    final hasVideoAttachment = message.hasVideoAttachment;
    final hasRichMedia =
        hasImageAttachment || hasVideoAttachment || hasMediaGroup;
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final maxBubbleWidth = hasRichMedia
        ? math.min(viewportWidth * 0.78, 336.0)
        : math.min(viewportWidth * 0.74, 316.0);
    final senderLabel = _resolveAdminSenderLabel(text);
    final isBotMessage = message.isBotMessage;
    final hasFileAttachment =
        message.attachments.length == 1 &&
        message.hasAttachment &&
        !hasImageAttachment &&
        !hasVideoAttachment;
    final hasFailedAttachment =
        message.isAttachmentFailed && !message.hasAttachment;
    final attachmentFileName =
        primaryAttachment?.fileName.trim().isNotEmpty == true
        ? primaryAttachment!.fileName.trim()
        : message.attachmentDisplayFileName?.trim();
    final attachmentSizeBytes = message.attachmentDisplaySizeBytes;
    final normalizedBody = message.body.trim();
    final attachmentNames = <String>{
      for (final attachment in message.attachments)
        if (attachment.fileName.trim().isNotEmpty)
          attachment.fileName.trim().toLowerCase(),
      if (attachmentFileName?.isNotEmpty == true)
        attachmentFileName!.toLowerCase(),
    };
    final shouldShowBody =
        normalizedBody.isNotEmpty &&
        !attachmentNames.contains(normalizedBody.toLowerCase());
    final isMediaOnlyBubble =
        hasRichMedia &&
        !hasFileAttachment &&
        !hasFailedAttachment &&
        !shouldShowBody;
    final compactMediaBubble =
        hasRichMedia && !hasFileAttachment && !hasFailedAttachment;
    final horizontalBubblePadding = compactMediaBubble ? 2.0 : 12.0;
    final mediaContentWidth = maxBubbleWidth - (horizontalBubblePadding * 2);
    final userBubbleColor = _supportMessageGreen(context);
    final userBubbleBorderColor = _supportMessageGreenBorder(context);
    final bubbleColor = message.isFromAdmin
        ? (isBotMessage
              ? colors.surfaceStrong.withValues(alpha: 0.98)
              : colors.surfaceStrong.withValues(alpha: 0.95))
        : (isMediaOnlyBubble
              ? colors.surfaceStrong.withValues(alpha: 0.18)
              : userBubbleColor);
    final borderColor = message.isFromAdmin
        ? colors.border
        : (isMediaOnlyBubble
              ? colors.border.withValues(alpha: isLight ? 0.72 : 0.45)
              : userBubbleBorderColor);
    final alignment = message.isFromAdmin
        ? Alignment.centerLeft
        : Alignment.centerRight;
    final timeLabel = DateFormat(
      'HH:mm',
    ).format(message.createdAtUtc.toLocal());
    final textColor = message.isFromAdmin ? colors.textStrong : Colors.white;
    final metaColor = message.isFromAdmin
        ? colors.textMuted
        : Colors.white.withValues(alpha: 0.82);
    final attachmentUploadStatus = message.normalizedAttachmentUploadStatus;
    final shouldShowAttachmentStatus =
        attachmentUploadStatus != null &&
        {'failed', 'retry'}.contains(attachmentUploadStatus.toLowerCase());
    final replyToMessageId = message.replyToMessageId?.trim();
    final replyPreview = message.replyToPreview?.trim();
    final hasReplyPreview =
        (replyToMessageId?.isNotEmpty == true) ||
        (replyPreview?.isNotEmpty == true);
    final resolvedReplyPreview = replyPreview?.isNotEmpty == true
        ? replyPreview!
        : text.supportChatReplyOriginalUnavailable;
    final replyMediaAttachment = repliedMessage?.primaryAttachment;
    final containsDeletedMedia = message.attachments.any(
      (attachment) => attachment.isDeleted,
    );
    final showMetaAsOverlay =
        isMediaOnlyBubble &&
        !shouldShowAttachmentStatus &&
        !containsDeletedMedia;
    final bubbleRadius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(message.isFromAdmin ? 10 : 18),
      bottomRight: Radius.circular(message.isFromAdmin ? 18 : 10),
    );
    final effectiveBorderColor = isHighlighted
        ? colors.accent.withValues(alpha: 0.88)
        : borderColor;
    final bubbleShadow = <BoxShadow>[
      BoxShadow(
        color: colors.shadow.withValues(alpha: isMediaOnlyBubble ? 0.16 : 0.22),
        blurRadius: isMediaOnlyBubble ? 6 : 9,
        offset: const Offset(0, 3),
      ),
      if (isHighlighted)
        BoxShadow(
          color: colors.accent.withValues(alpha: 0.22),
          blurRadius: 16,
          spreadRadius: 1,
        ),
    ];

    return Align(
      alignment: alignment,
      child: Row(
        mainAxisAlignment: message.isFromAdmin
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (message.isFromAdmin) ...[
            _SupportAvatar(label: senderLabel),
            const SizedBox(width: 8),
          ],
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxBubbleWidth),
            child: GestureDetector(
              onLongPress: onReplyToMessage,
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: bubbleRadius,
                  border: Border.all(color: effectiveBorderColor),
                  boxShadow: bubbleShadow.isEmpty ? null : bubbleShadow,
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalBubblePadding,
                    compactMediaBubble ? 2 : 9,
                    horizontalBubblePadding,
                    compactMediaBubble ? 2 : 7,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hasReplyPreview) ...[
                        _MessageBubbleReplyPreview(
                          isFromAdmin: message.isFromAdmin,
                          replyPreview: resolvedReplyPreview,
                          mediaAttachment: replyMediaAttachment,
                          onTap: replyToMessageId?.isNotEmpty == true
                              ? () => onJumpToMessage?.call(replyToMessageId!)
                              : null,
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (message.isFromAdmin) ...[
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                senderLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: metaColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (isBotMessage) ...[
                              const SizedBox(width: 6),
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.accent.withValues(
                                      alpha: 0.14,
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: colors.accent.withValues(
                                        alpha: 0.26,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    text.supportChatAssistantBadge,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: colors.accent,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                      ],
                      if (hasMediaGroup)
                        shouldShowBody
                            ? _MediaWithCaptionBubble(
                                media: _MediaGroupBubble(
                                  attachments: message.attachments,
                                  maxBubbleWidth: mediaContentWidth,
                                  onOpenImage: onOpenImage,
                                  onOpenVideo: onOpenVideo,
                                ),
                                caption: message.body,
                                textColor: textColor,
                                width: mediaContentWidth,
                              )
                            : _MediaOnlyBubble(
                                media: _MediaGroupBubble(
                                  attachments: message.attachments,
                                  maxBubbleWidth: mediaContentWidth,
                                  onOpenImage: onOpenImage,
                                  onOpenVideo: onOpenVideo,
                                ),
                                meta: showMetaAsOverlay
                                    ? _MessageMetaFooter(
                                        timeLabel: timeLabel,
                                        showDeliveryStatus:
                                            !message.isFromAdmin,
                                        message: message,
                                        timeColor: Colors.white.withValues(
                                          alpha: 0.92,
                                        ),
                                        compact: true,
                                      )
                                    : null,
                                borderRadius: 14,
                              ),
                      if (!hasMediaGroup &&
                          (hasImageAttachment || hasVideoAttachment) &&
                          primaryAttachment != null)
                        shouldShowBody
                            ? _MediaWithCaptionBubble(
                                media: _SingleMediaBubble(
                                  attachment: primaryAttachment,
                                  maxBubbleWidth: mediaContentWidth,
                                  onOpenImage: onOpenImage,
                                  onOpenVideo: onOpenVideo,
                                  fileName: attachmentFileName,
                                ),
                                caption: message.body,
                                textColor: textColor,
                                width: mediaContentWidth,
                              )
                            : _MediaOnlyBubble(
                                media: _SingleMediaBubble(
                                  attachment: primaryAttachment,
                                  maxBubbleWidth: mediaContentWidth,
                                  onOpenImage: onOpenImage,
                                  onOpenVideo: onOpenVideo,
                                  fileName: attachmentFileName,
                                ),
                                meta: showMetaAsOverlay
                                    ? _MessageMetaFooter(
                                        timeLabel: timeLabel,
                                        showDeliveryStatus:
                                            !message.isFromAdmin,
                                        message: message,
                                        timeColor: Colors.white.withValues(
                                          alpha: 0.92,
                                        ),
                                        compact: true,
                                      )
                                    : null,
                                borderRadius: 16,
                              ),
                      if (hasFailedAttachment) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: colors.danger.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: colors.danger.withValues(alpha: 0.45),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                size: 16,
                                color: colors.danger,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  attachmentFileName?.isNotEmpty == true
                                      ? attachmentFileName!
                                      : text.supportChatImageUploadFailedLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (shouldShowBody) const SizedBox(height: 6),
                      ],
                      if (hasFileAttachment) ...[
                        if (primaryAttachment?.isDeleted == true)
                          _DeletedAttachmentPlaceholder(
                            isVideo: false,
                            maxBubbleWidth: maxBubbleWidth,
                          )
                        else
                          InkWell(
                            onTap: onOpenAttachment == null
                                ? null
                                : () => onOpenAttachment!(
                                    primaryAttachment!.fileUrl,
                                  ),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 11,
                              ),
                              decoration: BoxDecoration(
                                color: colors.surface.withValues(alpha: 0.62),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: colors.border.withValues(alpha: 0.92),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.insert_drive_file_outlined,
                                    size: 18,
                                    color: metaColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          attachmentFileName ?? message.body,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: textColor,
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _formatAttachmentSize(
                                            context,
                                            primaryAttachment?.sizeBytes ??
                                                attachmentSizeBytes,
                                          ),
                                          style: TextStyle(
                                            color: metaColor,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (shouldShowBody) const SizedBox(height: 6),
                      ],
                      if (shouldShowBody && !hasRichMedia)
                        _TextMessageBubble(
                          text: message.body,
                          color: textColor,
                        ),
                      if (shouldShowAttachmentStatus) ...[
                        const SizedBox(height: 6),
                        _AttachmentStatusRow(
                          status: attachmentUploadStatus,
                          isFromAdmin: message.isFromAdmin,
                          isRetryEnabled:
                              message.canRetryAttachment &&
                              onRetryAttachment != null,
                          onRetryAttachment: onRetryAttachment,
                        ),
                      ],
                      if (!showMetaAsOverlay) ...[
                        SizedBox(height: shouldShowBody ? 6 : 4),
                        Align(
                          alignment: Alignment.centerRight,
                          child: _MessageMetaFooter(
                            timeLabel: timeLabel,
                            showDeliveryStatus: !message.isFromAdmin,
                            message: message,
                            timeColor: metaColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _resolveAdminSenderLabel(AppLocalizations text) {
    if (message.isBotMessage) {
      return text.supportChatTeamTitle;
    }

    final displayName = message.senderDisplayName.trim();
    if (displayName.isEmpty) {
      return text.supportChatTeamTitle;
    }

    final normalized = displayName.toLowerCase();
    if (normalized.contains('admin')) {
      return text.supportChatTeamTitle;
    }

    return displayName;
  }

  String _formatAttachmentSize(BuildContext context, int? bytes) {
    if (bytes == null || bytes <= 0) {
      return AppLocalizations.of(context).supportChatFileFallbackLabel;
    }

    if (bytes < 1024) {
      return '$bytes B';
    }

    final kilobytes = bytes / 1024;
    if (kilobytes < 1024) {
      return '${kilobytes.toStringAsFixed(1)} KB';
    }

    return '${(kilobytes / 1024).toStringAsFixed(1)} MB';
  }
}

class _TextMessageBubble extends StatelessWidget {
  const _TextMessageBubble({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 15,
        height: 1.38,
        fontWeight: FontWeight.w400,
      ),
    );
  }
}

class _MediaOnlyBubble extends StatelessWidget {
  const _MediaOnlyBubble({
    required this.media,
    required this.borderRadius,
    this.meta,
  });

  final Widget media;
  final Widget? meta;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final overlayMeta = meta;
    return overlayMeta == null
        ? media
        : _MediaWithOverlayMeta(
            borderRadius: borderRadius,
            meta: overlayMeta,
            child: media,
          );
  }
}

class _MediaWithCaptionBubble extends StatelessWidget {
  const _MediaWithCaptionBubble({
    required this.media,
    required this.caption,
    required this.textColor,
    required this.width,
  });

  final Widget media;
  final String caption;
  final Color textColor;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          media,
          const SizedBox(height: 7),
          _TextMessageBubble(text: caption, color: textColor),
        ],
      ),
    );
  }
}

class _SingleMediaBubble extends StatelessWidget {
  const _SingleMediaBubble({
    required this.attachment,
    required this.maxBubbleWidth,
    required this.onOpenImage,
    required this.onOpenVideo,
    required this.fileName,
  });

  final SupportChatAttachment attachment;
  final double maxBubbleWidth;
  final Future<void> Function({required String imageUrl, String? fileName})?
  onOpenImage;
  final Future<void> Function({required String videoUrl, String? fileName})?
  onOpenVideo;
  final String? fileName;

  @override
  Widget build(BuildContext context) {
    if (attachment.isDeleted) {
      return _DeletedAttachmentPlaceholder(
        isVideo: attachment.isVideo,
        maxBubbleWidth: maxBubbleWidth,
      );
    }

    if (attachment.isImage) {
      final safeUri = parseSafeSupportExternalUri(attachment.fileUrl);
      if (safeUri == null) {
        return _UnsupportedAttachmentPlaceholder(
          isVideo: false,
          maxBubbleWidth: maxBubbleWidth,
        );
      }

      return _NetworkImageAttachmentPreview(
        imageUrl: safeUri.toString(),
        maxBubbleWidth: maxBubbleWidth,
        onTap: onOpenImage == null
            ? null
            : () => onOpenImage!(
                imageUrl: attachment.fileUrl,
                fileName: fileName,
              ),
      );
    }

    final safeUri = parseSafeSupportExternalUri(attachment.fileUrl);
    if (safeUri == null) {
      return _UnsupportedAttachmentPlaceholder(
        isVideo: true,
        maxBubbleWidth: maxBubbleWidth,
      );
    }

    return _NetworkVideoAttachmentPreview(
      videoUrl: safeUri.toString(),
      maxBubbleWidth: maxBubbleWidth,
      onTap: onOpenVideo == null
          ? null
          : () =>
                onOpenVideo!(videoUrl: attachment.fileUrl, fileName: fileName),
    );
  }
}

class _MediaGroupBubble extends StatelessWidget {
  const _MediaGroupBubble({
    required this.attachments,
    required this.maxBubbleWidth,
    required this.onOpenImage,
    required this.onOpenVideo,
  });

  final List<SupportChatAttachment> attachments;
  final double maxBubbleWidth;
  final Future<void> Function({required String imageUrl, String? fileName})?
  onOpenImage;
  final Future<void> Function({required String videoUrl, String? fileName})?
  onOpenVideo;

  @override
  Widget build(BuildContext context) {
    return _MessageMediaGroupGrid(
      attachments: attachments,
      maxBubbleWidth: maxBubbleWidth,
      onOpenImage: onOpenImage,
      onOpenVideo: onOpenVideo,
    );
  }
}
