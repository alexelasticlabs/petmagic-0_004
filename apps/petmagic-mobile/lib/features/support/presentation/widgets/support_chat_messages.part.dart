part of 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    this.onOpenImage,
    this.onOpenVideo,
    this.onRetryAttachment,
  });

  final SupportChatMessage message;
  final Future<void> Function({required String imageUrl, String? fileName})?
  onOpenImage;
  final Future<void> Function({required String videoUrl, String? fileName})?
  onOpenVideo;
  final VoidCallback? onRetryAttachment;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final text = AppLocalizations.of(context);
    final hasImageAttachment = message.hasImageAttachment;
    final hasVideoAttachment = message.hasVideoAttachment;
    final maxBubbleWidth = hasImageAttachment || hasVideoAttachment
        ? math.min(MediaQuery.sizeOf(context).width * 0.62, 228.0)
        : math.min(MediaQuery.sizeOf(context).width * 0.68, 288.0);
    final senderLabel = _resolveAdminSenderLabel(text);
    final isBotMessage = message.isBotMessage;
    final bubbleColor = message.isFromAdmin
        ? (isBotMessage
              ? colors.surfaceStrong.withValues(alpha: 0.92)
              : colors.surfaceStrong)
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
    final hasFileAttachment =
        message.hasAttachment && !hasImageAttachment && !hasVideoAttachment;
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
            _SupportAvatar(label: senderLabel),
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
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
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
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colors.accent.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: colors.accent.withValues(alpha: 0.26),
                                ),
                              ),
                              child: Text(
                                text.supportChatAssistantBadge,
                                style: TextStyle(
                                  color: colors.accent,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    if (hasImageAttachment) ...[
                      _NetworkImageAttachmentPreview(
                        imageUrl: message.attachmentUrl!,
                        maxBubbleWidth: maxBubbleWidth,
                        onTap: onOpenImage == null
                            ? null
                            : () => onOpenImage!(
                                imageUrl: message.attachmentUrl!,
                                fileName: attachmentFileName,
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
                    if (hasVideoAttachment) ...[
                      _NetworkVideoAttachmentPreview(
                        videoUrl: message.attachmentUrl!,
                        maxBubbleWidth: maxBubbleWidth,
                        onTap: onOpenVideo == null
                            ? null
                            : () => onOpenVideo!(
                                videoUrl: message.attachmentUrl!,
                                fileName: attachmentFileName,
                              ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.play_circle_outline_rounded,
                            size: 13,
                            color: metaColor,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              text.supportChatVideoAttachedLabel,
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
      borderRadius: BorderRadius.circular(14),
      onTap: widget.onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: Image.network(
            widget.imageUrl,
            fit: BoxFit.cover,
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

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didUpdateWidget(covariant _NetworkVideoAttachmentPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      final previous = _controller;
      _controller = null;
      _failedToLoad = false;
      unawaited(previous?.dispose());
      _initialize();
    }
  }

  @override
  void dispose() {
    unawaited(_controller?.dispose());
    super.dispose();
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
    final controller = _controller;
    final aspectRatio = controller?.value.isInitialized == true
        ? controller!.value.aspectRatio
        : (16 / 9);
    final size = _resolveMediaPreviewSize(
      maxWidth: widget.maxBubbleWidth,
      aspectRatio: aspectRatio,
    );

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: widget.onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
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
  const minHeight = 92.0;
  const maxHeight = 232.0;
  const minWidth = 128.0;

  var width = maxWidth;
  var height = width / safeAspect;

  if (height > maxHeight) {
    height = maxHeight;
    width = height * safeAspect;
  }

  if (height < minHeight) {
    height = minHeight;
    width = height * safeAspect;
  }

  if (width > maxWidth) {
    width = maxWidth;
    height = width / safeAspect;
  }

  if (width < minWidth) {
    width = minWidth;
    height = width / safeAspect;
  }

  height = height.clamp(minHeight, maxHeight).toDouble();
  return (width: width, height: height);
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
    final timeLabel = DateFormat('HH:mm').format(createdAtUtc.toLocal());

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceStrong.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: colors.border.withValues(alpha: 0.72)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            timeLabel,
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
