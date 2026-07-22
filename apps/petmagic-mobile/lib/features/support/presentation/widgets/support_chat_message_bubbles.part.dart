part of 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';

String _resolveSupportAdminSenderLabel(
  AppLocalizations text,
  SupportChatMessage message,
) {
  if (message.isBotMessage) {
    return text.supportChatTeamTitle;
  }

  final displayName = message.senderDisplayName.trim();
  if (displayName.isEmpty) {
    return text.supportChatTeamTitle;
  }

  if (displayName.toLowerCase().contains('admin')) {
    return text.supportChatTeamTitle;
  }

  return displayName;
}

String _formatSupportAttachmentSize(BuildContext context, int? bytes) {
  if (bytes == null || bytes <= 0) {
    return AppLocalizations.of(context).supportChatFileFallbackLabel;
  }

  if (bytes < 1024) {
    return '$bytes B';
  }

  final localeTag = Localizations.localeOf(context).toLanguageTag();
  final compactDecimal = NumberFormat.decimalPatternDigits(
    locale: localeTag,
    decimalDigits: 1,
  );
  final kilobytes = bytes / 1024;
  if (kilobytes < 1024) {
    return '${compactDecimal.format(kilobytes)} KB';
  }

  return '${compactDecimal.format(kilobytes / 1024)} MB';
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
