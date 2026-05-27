part of 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    this.onOpenImage,
    this.onRetryAttachment,
  });

  final SupportChatMessage message;
  final Future<void> Function({required String imageUrl, String? fileName})?
  onOpenImage;
  final VoidCallback? onRetryAttachment;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final text = AppLocalizations.of(context);
    final hasImageAttachment = message.hasImageAttachment;
    final maxBubbleWidth = hasImageAttachment
        ? math.min(MediaQuery.sizeOf(context).width * 0.52, 196.0)
        : math.min(MediaQuery.sizeOf(context).width * 0.68, 288.0);
    final attachmentCacheWidth =
        (maxBubbleWidth * MediaQuery.devicePixelRatioOf(context)).round();
    final attachmentCacheHeight = (attachmentCacheWidth / 1.05).round();
    final bubbleColor = message.isFromAdmin
        ? colors.surfaceStrong
        : _supportMessageGreen;
    final borderColor = message.isFromAdmin
        ? colors.border
        : _supportMessageGreenBorder;
    final alignment = message.isFromAdmin
        ? Alignment.centerLeft
        : Alignment.centerRight;
    final timeLabel = DateFormat(
      'HH:mm',
    ).format(message.createdAtUtc.toLocal());
    final textColor = message.isFromAdmin ? colors.textStrong : Colors.white;
    final metaColor = message.isFromAdmin
        ? colors.textMuted
        : Colors.white.withValues(alpha: 0.78);
    final deliveryLabel = message.isRead
        ? text.supportChatMessageRead
        : text.supportChatMessageDelivered;
    final attachmentUploadStatus = message.normalizedAttachmentUploadStatus;
    final hasFileAttachment = message.hasAttachment && !hasImageAttachment;
    final hasFailedAttachment =
        message.isAttachmentFailed && !message.hasAttachment;
    final attachmentFileName = message.attachmentFileName?.trim();
    final shouldShowBody =
        message.body.trim().isNotEmpty &&
        message.body.trim() != (attachmentFileName ?? '');
    final bubbleRadius = BorderRadius.only(
      topLeft: const Radius.circular(20),
      topRight: const Radius.circular(20),
      bottomLeft: Radius.circular(message.isFromAdmin ? 8 : 20),
      bottomRight: Radius.circular(message.isFromAdmin ? 20 : 8),
    );

    return Align(
      alignment: alignment,
      child: Row(
        mainAxisAlignment: message.isFromAdmin
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (message.isFromAdmin) ...[
            _SupportAvatar(label: message.senderDisplayName),
            const SizedBox(width: 8),
          ],
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxBubbleWidth),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: bubbleRadius,
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: colors.shadow.withValues(alpha: 0.22),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(13, 11, 13, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (message.isFromAdmin) ...[
                      Text(
                        message.senderDisplayName,
                        style: TextStyle(
                          color: metaColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    if (hasImageAttachment) ...[
                      InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: onOpenImage == null
                            ? null
                            : () => onOpenImage!(
                                imageUrl: message.attachmentUrl!,
                                fileName: attachmentFileName,
                              ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: Image.network(
                              message.attachmentUrl!,
                              fit: BoxFit.cover,
                              cacheWidth: attachmentCacheWidth,
                              cacheHeight: attachmentCacheHeight,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: colors.surface,
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    color: colors.textMuted,
                                    size: 24,
                                  ),
                                );
                              },
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                    if (loadingProgress == null) {
                                      return child;
                                    }

                                    return Container(
                                      color: colors.surface,
                                      alignment: Alignment.center,
                                      child: const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    );
                                  },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.image_outlined,
                            size: 13,
                            color: metaColor,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              text.supportChatPhotoAttachedLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: metaColor,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (shouldShowBody) const SizedBox(height: 8),
                    ],
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
                      if (shouldShowBody) const SizedBox(height: 8),
                    ],
                    if (hasFileAttachment) ...[
                      InkWell(
                        onTap: () => _openAttachment(message.attachmentUrl),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
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
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.insert_drive_file_outlined,
                                size: 18,
                                color: metaColor,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                      if (shouldShowBody) const SizedBox(height: 8),
                    ],
                    if (shouldShowBody)
                      Text(
                        message.body,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 13.5,
                          height: 1.34,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    if (attachmentUploadStatus != null) ...[
                      const SizedBox(height: 8),
                      _AttachmentStatusRow(
                        status: attachmentUploadStatus,
                        errorCode: message.attachmentUploadErrorCode,
                        isFromAdmin: message.isFromAdmin,
                        isRetryEnabled:
                            message.canRetryAttachment &&
                            onRetryAttachment != null,
                        onRetryAttachment: onRetryAttachment,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          timeLabel,
                          style: TextStyle(
                            color: metaColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (!message.isFromAdmin) ...[
                          const SizedBox(width: 4),
                          Text(
                            deliveryLabel,
                            style: TextStyle(
                              color: metaColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            message.isRead
                                ? Icons.done_all_rounded
                                : Icons.check_rounded,
                            size: 12,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ],
                      ],
                    ),
                  ],
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

class _AttachmentStatusRow extends StatelessWidget {
  const _AttachmentStatusRow({
    required this.status,
    required this.errorCode,
    required this.isFromAdmin,
    required this.isRetryEnabled,
    required this.onRetryAttachment,
  });

  final String status;
  final String? errorCode;
  final bool isFromAdmin;
  final bool isRetryEnabled;
  final VoidCallback? onRetryAttachment;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final text = AppLocalizations.of(context);
    final normalized = status.toLowerCase();
    const warningColor = Color(0xFFE7A126);
    const successColor = Color(0xFF37B16A);

    final ({Color color, IconData icon, String label}) descriptor =
        switch (normalized) {
          'uploading' => (
            color: warningColor,
            icon: Icons.cloud_upload_rounded,
            label: text.supportChatAttachmentStatusUploading,
          ),
          'uploaded' => (
            color: successColor,
            icon: Icons.check_circle_rounded,
            label: text.supportChatAttachmentStatusUploaded,
          ),
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
            icon: Icons.info_outline_rounded,
            label: status,
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
            errorCode?.isNotEmpty == true
                ? '${descriptor.label} (${errorCode!})'
                : descriptor.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textColor,
              fontSize: 10.5,
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

class _SupportSystemMessageCard extends StatelessWidget {
  const _SupportSystemMessageCard({
    required this.message,
    required this.createdAtUtc,
  });

  final String message;
  final DateTime createdAtUtc;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final text = AppLocalizations.of(context);
    final title = text.supportChatSystemNoticeTitle;
    final timeLabel = DateFormat('HH:mm').format(createdAtUtc.toLocal());

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceStrong.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border.withValues(alpha: 0.85)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: colors.textStrong,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                style: TextStyle(
                  color: colors.textSoft,
                  fontSize: 12,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  timeLabel,
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
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

class _SupportAvatar extends StatelessWidget {
  const _SupportAvatar({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
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
            color: _supportSecondaryGreen,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
