part of 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';

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
    final safeUri = canShowImage
        ? parseSafeSupportExternalUri(attachment.fileUrl)
        : null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(7),
      child: SizedBox(
        width: 40,
        height: 40,
        child: safeUri != null
            ? CachedNetworkImage(
                imageUrl: safeUri.toString(),
                cacheKey: persistentSafeSupportMediaUrl(safeUri.toString()),
                fit: BoxFit.cover,
                memCacheWidth: _supportReplyThumbnailCacheWidth,
                maxWidthDiskCache: _supportReplyThumbnailCacheWidth,
                filterQuality: FilterQuality.medium,
                placeholder: (context, url) {
                  return ColoredBox(color: colors.surface);
                },
                errorWidget: (context, url, error) {
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
