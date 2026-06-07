part of 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';

class _SupportReplyComposerPreview extends StatelessWidget {
  const _SupportReplyComposerPreview({
    required this.message,
    required this.onClear,
  });

  final SupportChatMessage message;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final text = AppLocalizations.of(context);
    final preview = message.replyToPreview?.trim().isNotEmpty == true
        ? message.replyToPreview!.trim()
        : _resolveReplyComposerPreviewText(text, message);
    final primaryAttachment = message.primaryAttachment;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(9, 7, 3, 7),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 38,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 1, right: 7),
            child: Icon(Icons.reply_rounded, size: 18, color: colors.accent),
          ),
          if (primaryAttachment != null) ...[
            _ReplyAttachmentLeading(
              attachment: primaryAttachment,
              fallbackLabel: _resolveReplyAttachmentLabel(
                text,
                primaryAttachment,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  text.supportChatReplyToPrefix,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.accent,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 13,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            splashRadius: 14,
            constraints: const BoxConstraints.tightFor(width: 34, height: 34),
            onPressed: onClear,
            icon: Icon(Icons.close_rounded, size: 15, color: colors.textMuted),
          ),
        ],
      ),
    );
  }

  String _resolveReplyComposerPreviewText(
    AppLocalizations text,
    SupportChatMessage message,
  ) {
    if (message.body.trim().isNotEmpty) {
      return message.body.trim();
    }

    if (message.hasMediaGroup) {
      return text.supportChatPhotoAttachedLabel;
    }

    final primaryAttachment = message.primaryAttachment;
    if (primaryAttachment == null) {
      return text.supportChatReplyOriginalUnavailable;
    }

    if (primaryAttachment.isVideo) {
      return text.supportChatVideoLabel;
    }

    if (primaryAttachment.isImage) {
      return text.supportChatPhotoAttachedLabel;
    }

    return primaryAttachment.fileName.trim().isNotEmpty
        ? primaryAttachment.fileName.trim()
        : text.supportChatFileFallbackLabel;
  }

  String _resolveReplyAttachmentLabel(
    AppLocalizations text,
    SupportChatAttachment attachment,
  ) {
    if (attachment.isVideo) {
      return text.supportChatVideoLabel;
    }
    if (attachment.isImage) {
      return text.supportChatPhotoAttachedLabel;
    }
    return text.supportChatFileFallbackLabel;
  }
}

class _ReplyAttachmentLeading extends StatelessWidget {
  const _ReplyAttachmentLeading({
    required this.attachment,
    required this.fallbackLabel,
  });

  final SupportChatAttachment attachment;
  final String fallbackLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final showImageThumb =
        attachment.isImage &&
        !attachment.isDeleted &&
        attachment.fileUrl.trim().isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 40,
        height: 40,
        child: showImageThumb
            ? CachedNetworkImage(
                imageUrl: attachment.fileUrl,
                fit: BoxFit.cover,
                memCacheWidth: _supportReplyThumbnailCacheWidth,
                maxWidthDiskCache: _supportReplyThumbnailCacheWidth,
                filterQuality: FilterQuality.medium,
                placeholder: (context, url) => _ReplyAttachmentLeadingFallback(
                  icon: Icons.image_outlined,
                  label: fallbackLabel,
                ),
                errorWidget: (context, url, error) =>
                    _ReplyAttachmentLeadingFallback(
                      icon: Icons.broken_image_outlined,
                      label: fallbackLabel,
                    ),
              )
            : _ReplyAttachmentLeadingFallback(
                icon: attachment.isVideo
                    ? Icons.videocam_outlined
                    : Icons.insert_drive_file_outlined,
                label: fallbackLabel,
                backgroundColor: colors.surfaceStrong,
                foregroundColor: colors.textMuted,
              ),
      ),
    );
  }
}

class _ReplyAttachmentLeadingFallback extends StatelessWidget {
  const _ReplyAttachmentLeadingFallback({
    required this.icon,
    required this.label,
    this.backgroundColor,
    this.foregroundColor,
  });

  final IconData icon;
  final String label;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final resolvedBackground = backgroundColor ?? colors.surface;
    final resolvedForeground = foregroundColor ?? colors.textMuted;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: resolvedBackground,
        border: Border.all(color: colors.border.withValues(alpha: 0.9)),
      ),
      child: Tooltip(
        message: label,
        child: Icon(icon, size: 16, color: resolvedForeground),
      ),
    );
  }
}

class _PendingAttachmentPreviewList extends StatelessWidget {
  const _PendingAttachmentPreviewList({
    required this.attachments,
    required this.onRemove,
  });

  final List<_PendingSupportAttachment> attachments;
  final ValueChanged<int>? onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final text = AppLocalizations.of(context);

    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: attachments.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final attachment = attachments[index];
          return SizedBox(
            width: 78,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: 66,
                        height: 66,
                        child: attachment.isVideo
                            ? ColoredBox(
                                color: colors.surface,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Center(
                                      child: Icon(
                                        Icons.videocam_outlined,
                                        color: colors.textMuted,
                                        size: 22,
                                      ),
                                    ),
                                    const Center(
                                      child: Icon(
                                        Icons.play_circle_fill_rounded,
                                        color: Colors.white,
                                        size: 26,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Image.file(
                                File(attachment.filePath),
                                fit: BoxFit.cover,
                                cacheWidth:
                                    _supportComposerAttachmentPreviewCacheExtent,
                                cacheHeight:
                                    _supportComposerAttachmentPreviewCacheExtent,
                                filterQuality: FilterQuality.medium,
                                errorBuilder: (context, error, stackTrace) {
                                  return ColoredBox(
                                    color: colors.surface,
                                    child: Center(
                                      child: Icon(
                                        Icons.broken_image_outlined,
                                        color: colors.textMuted,
                                        size: 20,
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                    Positioned(
                      top: -7,
                      right: -7,
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.62),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: onRemove == null
                              ? null
                              : () => onRemove!(index),
                          child: const SizedBox(
                            width: 24,
                            height: 24,
                            child: Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  attachment.isVideo
                      ? text.supportChatVideoAttachedLabel
                      : text.supportChatPhotoAttachedLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
