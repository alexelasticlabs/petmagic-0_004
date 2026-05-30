part of 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    this.repliedMessage,
    this.onOpenImage,
    this.onOpenVideo,
    this.onRetryAttachment,
    this.onReplyToMessage,
    this.onJumpToMessage,
    this.isHighlighted = false,
  });

  final SupportChatMessage message;
  final SupportChatMessage? repliedMessage;
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
        : message.attachmentFileName?.trim();
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
                            onTap: () =>
                                _openAttachment(primaryAttachment?.fileUrl),
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
                                                message.attachmentFileSizeBytes,
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

  Future<void> _openAttachment(String? value) async {
    final uri = value == null ? null : Uri.tryParse(value);
    if (uri == null) {
      return;
    }

    await launchUrl(uri, mode: LaunchMode.externalApplication);
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
      return _NetworkImageAttachmentPreview(
        imageUrl: attachment.fileUrl,
        maxBubbleWidth: maxBubbleWidth,
        onTap: onOpenImage == null
            ? null
            : () => onOpenImage!(
                imageUrl: attachment.fileUrl,
                fileName: fileName,
              ),
      );
    }

    return _NetworkVideoAttachmentPreview(
      videoUrl: attachment.fileUrl,
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

class _MessageBubbleReplyPreview extends StatelessWidget {
  const _MessageBubbleReplyPreview({
    required this.isFromAdmin,
    required this.replyPreview,
    required this.mediaAttachment,
    required this.onTap,
  });

  final bool isFromAdmin;
  final String replyPreview;
  final SupportChatAttachment? mediaAttachment;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final text = AppLocalizations.of(context);
    final accentColor = isFromAdmin
        ? colors.accent
        : Colors.white.withValues(alpha: 0.92);
    final previewColor = isFromAdmin
        ? colors.textMuted
        : Colors.white.withValues(alpha: 0.84);

    return Material(
      color: isFromAdmin
          ? colors.surface.withValues(alpha: 0.74)
          : Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 9, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 38,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              if (mediaAttachment != null) ...[
                _MessageReplyAttachmentThumbnail(attachment: mediaAttachment!),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      text.supportChatReplyLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      replyPreview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: previewColor,
                        fontSize: 13,
                        height: 1.3,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageReplyAttachmentThumbnail extends StatelessWidget {
  const _MessageReplyAttachmentThumbnail({required this.attachment});

  final SupportChatAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final canShowImage =
        attachment.isImage &&
        !attachment.isDeleted &&
        attachment.fileUrl.trim().isNotEmpty;
    return ClipRRect(
      borderRadius: BorderRadius.circular(7),
      child: SizedBox(
        width: 40,
        height: 40,
        child: canShowImage
            ? Image.network(
                attachment.fileUrl,
                fit: BoxFit.cover,
                cacheWidth: 720,
                errorBuilder: (context, error, stackTrace) {
                  return ColoredBox(
                    color: colors.surface,
                    child: Icon(
                      Icons.broken_image_outlined,
                      size: 14,
                      color: colors.textMuted,
                    ),
                  );
                },
              )
            : ColoredBox(
                color: colors.surface.withValues(alpha: 0.84),
                child: Icon(
                  attachment.isVideo
                      ? Icons.videocam_outlined
                      : Icons.insert_drive_file_outlined,
                  size: 14,
                  color: colors.textMuted,
                ),
              ),
      ),
    );
  }
}

class _MessageMetaFooter extends StatelessWidget {
  const _MessageMetaFooter({
    required this.timeLabel,
    required this.showDeliveryStatus,
    required this.message,
    required this.timeColor,
    this.compact = false,
  });

  final String timeLabel;
  final bool showDeliveryStatus;
  final SupportChatMessage message;
  final Color timeColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          timeLabel,
          style: TextStyle(
            color: timeColor,
            fontSize: compact ? 10.5 : 11.2,
            fontWeight: FontWeight.w600,
            height: 1.1,
          ),
        ),
        if (showDeliveryStatus) ...[
          const SizedBox(width: 4),
          _MessageDeliveryStatusIcon(
            message: message,
            compact: compact,
            tintColor: timeColor,
          ),
        ],
      ],
    );

    if (!compact) {
      return content;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(999),
      ),
      child: content,
    );
  }
}

class _MediaWithOverlayMeta extends StatelessWidget {
  const _MediaWithOverlayMeta({
    required this.child,
    required this.meta,
    required this.borderRadius,
  });

  final Widget child;
  final Widget meta;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Stack(
        children: [
          child,
          Positioned(right: 6, bottom: 6, child: meta),
        ],
      ),
    );
  }
}

class _MessageDeliveryStatusIcon extends StatelessWidget {
  const _MessageDeliveryStatusIcon({
    required this.message,
    this.compact = false,
    this.tintColor,
  });

  final SupportChatMessage message;
  final bool compact;
  final Color? tintColor;

  @override
  Widget build(BuildContext context) {
    final iconColor =
        tintColor ?? (compact ? Colors.white.withValues(alpha: 0.88) : null);
    final composerTone = _supportComposerSendGreen(context);
    final iconSize = compact ? 12.2 : 13.0;
    Widget statusIcon;
    if (message.isAttachmentUploading) {
      statusIcon = SizedBox(
        key: const ValueKey<String>('uploading'),
        width: compact ? 11.5 : 12,
        height: compact ? 11.5 : 12,
        child: CircularProgressIndicator(
          strokeWidth: compact ? 1.6 : 1.8,
          valueColor: AlwaysStoppedAnimation<Color>(
            iconColor ?? Colors.white70,
          ),
        ),
      );
    } else if (message.isAttachmentFailed) {
      statusIcon = Icon(
        key: const ValueKey<String>('failed'),
        Icons.error_outline_rounded,
        size: compact ? 12 : 12.5,
        color: const Color(0xFFFF6B6B),
      );
    } else if (message.isRead) {
      statusIcon = Icon(
        key: const ValueKey<String>('read'),
        Icons.done_all_rounded,
        size: iconSize,
        color: iconColor ?? composerTone,
      );
    } else {
      statusIcon = Icon(
        key: const ValueKey<String>('sent'),
        Icons.check_rounded,
        size: iconSize,
        color: iconColor ?? Colors.white.withValues(alpha: 0.78),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeOutCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: animation, child: child),
        );
      },
      child: statusIcon,
    );
  }
}

class _MessageMediaGroupGrid extends StatelessWidget {
  const _MessageMediaGroupGrid({
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
    final tiles = attachments
        .take(_supportMediaGroupVisibleCellCount)
        .toList(growable: false);
    if (tiles.isEmpty) {
      return const SizedBox.shrink();
    }

    const spacing = 1.5;
    final width = maxBubbleWidth;
    final overflowCount =
        attachments.length > _supportMediaGroupVisibleCellCount
        ? attachments.length - (_supportMediaGroupVisibleCellCount - 1)
        : 0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: width,
        child: _buildLayout(
          tiles: tiles,
          width: width,
          spacing: spacing,
          overflowCount: overflowCount,
        ),
      ),
    );
  }

  Widget _buildLayout({
    required List<SupportChatAttachment> tiles,
    required double width,
    required double spacing,
    required int overflowCount,
  }) {
    final count = attachments.length;
    if (count == 1) {
      return _tile(tiles.first, width: width, height: math.min(width, 260.0));
    }

    if (count == 2) {
      final tileWidth = (width - spacing) / 2;
      return Row(
        children: [
          _tile(tiles[0], width: tileWidth, height: tileWidth),
          SizedBox(width: spacing),
          _tile(tiles[1], width: tileWidth, height: tileWidth),
        ],
      );
    }

    if (count == 3) {
      final sideWidth = (width - spacing) / 2;
      final height = math.min(width * 0.78, 258.0);
      final smallHeight = (height - spacing) / 2;
      return SizedBox(
        height: height,
        child: Row(
          children: [
            _tile(tiles[0], width: sideWidth, height: height),
            SizedBox(width: spacing),
            Column(
              children: [
                _tile(tiles[1], width: sideWidth, height: smallHeight),
                SizedBox(height: spacing),
                _tile(tiles[2], width: sideWidth, height: smallHeight),
              ],
            ),
          ],
        ),
      );
    }

    if (count == 4) {
      return _twoColumnRows(
        tiles: tiles,
        width: width,
        spacing: spacing,
        rows: 2,
      );
    }

    if (count == 5) {
      final rowHeight = math.min((width - spacing) / 2, 108.0);
      return Column(
        children: [
          _twoColumnRows(
            tiles: tiles.take(4).toList(growable: false),
            width: width,
            spacing: spacing,
            rows: 2,
            tileHeight: rowHeight,
          ),
          SizedBox(height: spacing),
          _tile(tiles[4], width: width, height: rowHeight),
        ],
      );
    }

    return _twoColumnRows(
      tiles: tiles,
      width: width,
      spacing: spacing,
      rows: 3,
      tileHeight: math.min((width - (spacing * 2)) / 3, 104.0),
      overflowCount: overflowCount,
    );
  }

  Widget _twoColumnRows({
    required List<SupportChatAttachment> tiles,
    required double width,
    required double spacing,
    required int rows,
    double? tileHeight,
    int overflowCount = 0,
  }) {
    final tileWidth = (width - spacing) / 2;
    final resolvedTileHeight = tileHeight ?? tileWidth;
    return Column(
      children: [
        for (var row = 0; row < rows; row++) ...[
          if (row > 0) SizedBox(height: spacing),
          Row(
            children: [
              for (var column = 0; column < 2; column++) ...[
                if (column > 0) SizedBox(width: spacing),
                _tile(
                  tiles[(row * 2) + column],
                  width: tileWidth,
                  height: resolvedTileHeight,
                  overlayLabel:
                      overflowCount > 0 && row == rows - 1 && column == 1
                      ? '+$overflowCount'
                      : null,
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _tile(
    SupportChatAttachment attachment, {
    required double width,
    required double height,
    String? overlayLabel,
  }) {
    return _MessageMediaGroupTile(
      attachment: attachment,
      width: width,
      height: height,
      borderRadius: BorderRadius.zero,
      overlayLabel: overlayLabel,
      onTap: () async {
        if (attachment.isImage) {
          await onOpenImage?.call(
            imageUrl: attachment.fileUrl,
            fileName: attachment.fileName,
          );
          return;
        }

        if (attachment.isVideo) {
          await onOpenVideo?.call(
            videoUrl: attachment.fileUrl,
            fileName: attachment.fileName,
          );
        }
      },
    );
  }
}

class _MessageMediaGroupTile extends StatelessWidget {
  const _MessageMediaGroupTile({
    required this.attachment,
    required this.width,
    required this.height,
    required this.borderRadius,
    required this.onTap,
    this.overlayLabel,
  });

  final SupportChatAttachment attachment;
  final double width;
  final double height;
  final BorderRadius borderRadius;
  final VoidCallback onTap;
  final String? overlayLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final canTap =
        !attachment.isDeleted && (attachment.isImage || attachment.isVideo);
    return InkWell(
      onTap: canTap ? onTap : null,
      borderRadius: borderRadius,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (attachment.isDeleted)
                _DeletedAttachmentTileBackground(
                  isVideo: attachment.isVideo,
                  compact: true,
                )
              else if (attachment.isImage)
                Image.network(
                  attachment.fileUrl,
                  fit: BoxFit.cover,
                  cacheWidth: 512,
                  errorBuilder: (context, error, stackTrace) {
                    return ColoredBox(
                      color: colors.surface,
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: colors.textMuted,
                        size: 20,
                      ),
                    );
                  },
                )
              else if (attachment.isVideo)
                ColoredBox(
                  color: Colors.black.withValues(alpha: 0.72),
                  child: const Center(
                    child: Icon(
                      Icons.play_circle_fill_rounded,
                      size: 34,
                      color: Colors.white,
                    ),
                  ),
                )
              else
                ColoredBox(
                  color: colors.surface,
                  child: Icon(
                    Icons.insert_drive_file_outlined,
                    color: colors.textMuted,
                    size: 22,
                  ),
                ),
              if (attachment.isVideo && !attachment.isDeleted) ...[
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.55),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.58),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _formatDurationLabel(attachment.durationSeconds),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
              if (overlayLabel != null)
                ColoredBox(
                  color: Colors.black.withValues(alpha: 0.54),
                  child: Center(
                    child: Text(
                      overlayLabel!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatDurationLabel(double? value) {
  if (value == null || value <= 0) {
    return '0:00';
  }

  final totalSeconds = value.round();
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

class _DeletedAttachmentPlaceholder extends StatelessWidget {
  const _DeletedAttachmentPlaceholder({
    required this.isVideo,
    required this.maxBubbleWidth,
  });

  final bool isVideo;
  final double maxBubbleWidth;

  @override
  Widget build(BuildContext context) {
    final size = _resolveMediaPreviewSize(
      maxWidth: maxBubbleWidth,
      aspectRatio: 1,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: _DeletedAttachmentTileBackground(isVideo: isVideo),
      ),
    );
  }
}

class _DeletedAttachmentTileBackground extends StatelessWidget {
  const _DeletedAttachmentTileBackground({
    required this.isVideo,
    this.compact = false,
  });

  final bool isVideo;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final text = AppLocalizations.of(context);
    return ColoredBox(
      color: colors.surface,
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isVideo
                    ? Icons.videocam_off_rounded
                    : Icons.image_not_supported_outlined,
                size: compact ? 16 : 24,
                color: colors.textMuted,
              ),
              SizedBox(height: compact ? 3 : 6),
              Text(
                text.supportChatAttachmentExpiredPlaceholder,
                textAlign: TextAlign.center,
                maxLines: compact ? 2 : 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: compact ? 9 : 11,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NetworkImageAttachmentPreview extends StatefulWidget {
  const _NetworkImageAttachmentPreview({
    required this.imageUrl,
    required this.maxBubbleWidth,
    required this.onTap,
  });

  final String imageUrl;
  final double maxBubbleWidth;
  final VoidCallback? onTap;

  @override
  State<_NetworkImageAttachmentPreview> createState() =>
      _NetworkImageAttachmentPreviewState();
}

class _NetworkImageAttachmentPreviewState
    extends State<_NetworkImageAttachmentPreview> {
  ImageStream? _imageStream;
  ImageStreamListener? _imageStreamListener;
  double? _aspectRatio;

  @override
  void initState() {
    super.initState();
    _resolveAspectRatio();
  }

  @override
  void didUpdateWidget(covariant _NetworkImageAttachmentPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _detachImageListener();
      _aspectRatio = null;
      _resolveAspectRatio();
    }
  }

  @override
  void dispose() {
    _detachImageListener();
    super.dispose();
  }

  void _resolveAspectRatio() {
    final provider = NetworkImage(widget.imageUrl);
    final stream = provider.resolve(const ImageConfiguration());
    _imageStream = stream;
    _imageStreamListener = ImageStreamListener((image, _) {
      if (!mounted) {
        return;
      }

      final width = image.image.width.toDouble();
      final height = image.image.height.toDouble();
      if (width <= 0 || height <= 0) {
        return;
      }

      setState(() {
        _aspectRatio = width / height;
      });
    });
    stream.addListener(_imageStreamListener!);
  }

  void _detachImageListener() {
    final listener = _imageStreamListener;
    final stream = _imageStream;
    if (listener != null && stream != null) {
      stream.removeListener(listener);
    }
    _imageStream = null;
    _imageStreamListener = null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final size = _resolveMediaPreviewSize(
      maxWidth: widget.maxBubbleWidth,
      aspectRatio: _aspectRatio ?? 1,
    );

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: widget.onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: Image.network(
            widget.imageUrl,
            fit: BoxFit.cover,
            cacheWidth: 720,
            errorBuilder: (context, error, stackTrace) {
              return ColoredBox(
                color: colors.surface,
                child: Icon(
                  Icons.broken_image_outlined,
                  color: colors.textMuted,
                  size: 24,
                ),
              );
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) {
                return child;
              }

              return ColoredBox(
                color: colors.surface,
                child: const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NetworkVideoAttachmentPreview extends StatefulWidget {
  const _NetworkVideoAttachmentPreview({
    required this.videoUrl,
    required this.maxBubbleWidth,
    required this.onTap,
  });

  final String videoUrl;
  final double maxBubbleWidth;
  final VoidCallback? onTap;

  @override
  State<_NetworkVideoAttachmentPreview> createState() =>
      _NetworkVideoAttachmentPreviewState();
}

class _NetworkVideoAttachmentPreviewState
    extends State<_NetworkVideoAttachmentPreview> {
  VideoPlayerController? _controller;
  bool _failedToLoad = false;
  bool _hasPreviewSlot = false;

  @override
  void initState() {
    super.initState();
    _tryInitializePreview();
  }

  @override
  void didUpdateWidget(covariant _NetworkVideoAttachmentPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      final previous = _controller;
      _controller = null;
      _failedToLoad = false;
      _releasePreviewSlot();
      unawaited(previous?.dispose());
      _tryInitializePreview();
    }
  }

  @override
  void dispose() {
    _releasePreviewSlot();
    unawaited(_controller?.dispose());
    super.dispose();
  }

  void _tryInitializePreview() {
    _hasPreviewSlot = MediaLifecyclePolicy.tryAcquireVideoPreviewSlot();
    if (!_hasPreviewSlot) {
      return;
    }
    _initialize();
  }

  void _releasePreviewSlot() {
    if (!_hasPreviewSlot) {
      return;
    }
    _hasPreviewSlot = false;
    MediaLifecyclePolicy.releaseVideoPreviewSlot();
  }

  Future<void> _initialize() async {
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
    );
    _controller = controller;
    try {
      await controller.initialize();
      await controller.pause();
      await controller.seekTo(Duration.zero);
      if (!mounted || _controller != controller) {
        await controller.dispose();
        return;
      }
      setState(() {});
    } on Object {
      await controller.dispose();
      _releasePreviewSlot();
      if (!mounted) {
        return;
      }
      setState(() {
        _controller = null;
        _failedToLoad = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    if (!_hasPreviewSlot) {
      final size = _resolveMediaPreviewSize(
        maxWidth: widget.maxBubbleWidth,
        aspectRatio: 16 / 9,
      );
      return InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: widget.onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: colors.surfaceStrong),
                Container(color: Colors.black.withValues(alpha: 0.18)),
                const Center(
                  child: Icon(
                    Icons.play_circle_fill_rounded,
                    size: 42,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final controller = _controller;
    final aspectRatio = controller?.value.isInitialized == true
        ? controller!.value.aspectRatio
        : (16 / 9);
    final size = _resolveMediaPreviewSize(
      maxWidth: widget.maxBubbleWidth,
      aspectRatio: aspectRatio,
    );

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: widget.onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_failedToLoad)
                ColoredBox(
                  color: colors.surface,
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: colors.textMuted,
                    size: 24,
                  ),
                )
              else if (controller == null || !controller.value.isInitialized)
                ColoredBox(
                  color: colors.surface,
                  child: const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: controller.value.size.width,
                    height: controller.value.size.height,
                    child: VideoPlayer(controller),
                  ),
                ),
              Container(color: Colors.black.withValues(alpha: 0.18)),
              const Center(
                child: Icon(
                  Icons.play_circle_fill_rounded,
                  size: 42,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

({double width, double height}) _resolveMediaPreviewSize({
  required double maxWidth,
  required double aspectRatio,
}) {
  final safeAspect = aspectRatio.isFinite && aspectRatio > 0 ? aspectRatio : 1;
  const minHeight = 104.0;
  const maxHeight = 260.0;

  final width = maxWidth;
  var height = width / safeAspect;

  height = height.clamp(minHeight, maxHeight).toDouble();
  return (width: width, height: height);
}

class _AttachmentStatusRow extends StatelessWidget {
  const _AttachmentStatusRow({
    required this.status,
    required this.isFromAdmin,
    required this.isRetryEnabled,
    required this.onRetryAttachment,
  });

  final String status;
  final bool isFromAdmin;
  final bool isRetryEnabled;
  final VoidCallback? onRetryAttachment;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final text = AppLocalizations.of(context);
    final normalized = status.toLowerCase();
    const warningColor = Color(0xFFE7A126);

    final ({Color color, IconData icon, String label}) descriptor =
        switch (normalized) {
          'failed' => (
            color: colors.danger,
            icon: Icons.error_rounded,
            label: text.supportChatAttachmentStatusFailed,
          ),
          'retry' => (
            color: warningColor,
            icon: Icons.refresh_rounded,
            label: text.supportChatAttachmentStatusRetry,
          ),
          _ => (
            color: colors.textMuted,
            icon: Icons.error_outline_rounded,
            label: text.supportChatAttachmentStatusFailed,
          ),
        };

    final textColor = isFromAdmin
        ? descriptor.color
        : Colors.white.withValues(alpha: 0.92);

    return Row(
      children: [
        Icon(descriptor.icon, size: 13, color: textColor),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            descriptor.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textColor,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (isRetryEnabled && !isFromAdmin)
          TextButton.icon(
            onPressed: onRetryAttachment,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              minimumSize: const Size(0, 0),
              foregroundColor: textColor,
            ),
            icon: const Icon(Icons.refresh_rounded, size: 12),
            label: Text(
              text.retryAction,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

class _SupportAvatar extends StatelessWidget {
  const _SupportAvatar({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final avatarTone = _supportSecondaryGreen(context);
    final initial = label.trim().isEmpty ? 'P' : label.trim().substring(0, 1);

    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.surfaceStrong,
        border: Border.all(color: colors.border),
      ),
      child: Center(
        child: Text(
          initial.toUpperCase(),
          style: TextStyle(
            color: avatarTone,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
