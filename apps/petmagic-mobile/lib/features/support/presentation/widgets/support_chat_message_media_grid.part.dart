part of 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';

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
    final safeUri = parseSafeSupportExternalUri(attachment.fileUrl);
    final isTrustedRemoteMedia = safeUri != null;
    final canTap =
        !attachment.isDeleted &&
        isTrustedRemoteMedia &&
        (attachment.isImage || attachment.isVideo);
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
              else if ((attachment.isImage || attachment.isVideo) &&
                  !isTrustedRemoteMedia)
                _UnsupportedAttachmentTileBackground(
                  isVideo: attachment.isVideo,
                  compact: true,
                )
              else if (attachment.isImage)
                CachedNetworkImage(
                  imageUrl: safeUri!.toString(),
                  cacheKey: persistentSafeSupportMediaUrl(safeUri.toString()),
                  fit: BoxFit.cover,
                  memCacheWidth: 512,
                  placeholder: (context, url) {
                    return ColoredBox(color: colors.surface);
                  },
                  errorWidget: (context, url, error) {
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
