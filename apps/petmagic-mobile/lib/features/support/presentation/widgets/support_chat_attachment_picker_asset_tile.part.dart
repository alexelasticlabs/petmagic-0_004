part of 'package:petmagic_mobile/features/support/presentation/support_chat_page.dart';

class _SupportRecentAssetTile extends StatefulWidget {
  const _SupportRecentAssetTile({
    required this.asset,
    required this.selectedOrder,
    required this.onTap,
  });

  final AssetEntity asset;
  final int? selectedOrder;
  final VoidCallback onTap;

  @override
  State<_SupportRecentAssetTile> createState() =>
      _SupportRecentAssetTileState();
}

class _SupportRecentAssetTileState extends State<_SupportRecentAssetTile> {
  late Future<Uint8List?> _thumbnailFuture;

  @override
  void initState() {
    super.initState();
    _thumbnailFuture = widget.asset.thumbnailDataWithSize(
      const ThumbnailSize(300, 300),
      quality: 85,
    );
  }

  @override
  void didUpdateWidget(covariant _SupportRecentAssetTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.id != widget.asset.id) {
      _thumbnailFuture = widget.asset.thumbnailDataWithSize(
        const ThumbnailSize(300, 300),
        quality: 85,
      );
    }
  }

  String _formatDuration(Duration value) {
    final totalSeconds = value.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final isVideo = widget.asset.type == AssetType.video;
    final isSelected = widget.selectedOrder != null;
    return AnimatedScale(
      scale: isSelected ? 0.96 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: widget.onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              fit: StackFit.expand,
              children: [
                FutureBuilder<Uint8List?>(
                  future: _thumbnailFuture,
                  builder: (context, snapshot) {
                    final bytes = snapshot.data;
                    if (bytes == null) {
                      return ColoredBox(
                        color: colors.surface,
                        child: Center(
                          child: Icon(
                            isVideo
                                ? Icons.videocam_outlined
                                : Icons.image_not_supported_outlined,
                            color: colors.textMuted,
                          ),
                        ),
                      );
                    }
                    return Image.memory(
                      bytes,
                      fit: BoxFit.cover,
                      cacheWidth: _supportRecentMediaThumbnailCacheExtent,
                      cacheHeight: _supportRecentMediaThumbnailCacheExtent,
                      filterQuality: FilterQuality.medium,
                    );
                  },
                ),
                if (isVideo)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.12),
                            Colors.black.withValues(alpha: 0.42),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (isVideo)
                  const Center(
                    child: Icon(
                      Icons.play_circle_fill_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                if (isVideo)
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        child: Text(
                          _formatDuration(widget.asset.videoDuration),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 120),
                  opacity: isSelected ? 1 : 0,
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.35),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? _supportComposerSendGreen(context)
                          : Colors.black.withValues(alpha: 0.38),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    child: isSelected
                        ? Center(
                            child: Text(
                              '${widget.selectedOrder}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
