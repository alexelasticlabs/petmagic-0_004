part of 'profile_surface_widgets.dart';

class ProfileMessageCard extends StatelessWidget {
  const ProfileMessageCard({
    required this.message,
    required this.tone,
    super.key,
  });

  final String message;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tone.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Text(
          message,
          style: TextStyle(
            color: colors.textStrong,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class ProfileAvatarBadge extends StatelessWidget {
  const ProfileAvatarBadge({
    required this.imageUrl,
    required this.fallbackLabel,
    this.size = 92,
    this.bottomBadge,
    this.onTap,
    this.showEditOverlay = false,
    super.key,
  });

  final String? imageUrl;
  final String fallbackLabel;
  final double size;
  final Widget? bottomBadge;
  final VoidCallback? onTap;
  final bool showEditOverlay;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final initials = fallbackLabel.trim().isNotEmpty
        ? fallbackLabel.trim().substring(0, 1).toUpperCase()
        : '?';
    final avatarCacheSize = (size * MediaQuery.devicePixelRatioOf(context))
        .round();
    final safeImageUrl = parseSafeProfileAvatarUri(imageUrl)?.toString();

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: Ink(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.surfaceStrong,
                  border: Border.all(color: colors.border),
                ),
                child: ClipOval(
                  child: safeImageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: safeImageUrl,
                          cacheKey: persistentSafeProfileAvatarUrl(
                            safeImageUrl,
                          ),
                          width: size,
                          height: size,
                          fit: BoxFit.cover,
                          memCacheWidth: avatarCacheSize,
                          memCacheHeight: avatarCacheSize,
                          maxWidthDiskCache: avatarCacheSize,
                          maxHeightDiskCache: avatarCacheSize,
                          placeholder: (ctx, url) => const SizedBox.shrink(),
                          errorWidget: (ctx, url, err) => Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: colors.textMuted,
                              size: size * 0.38,
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            initials,
                            style: TextStyle(
                              color: colors.textStrong,
                              fontSize: size * 0.34,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ),
          if (showEditOverlay)
            Positioned(
              right: size * 0.08,
              bottom: size * 0.08,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.surfaceStrong.withValues(alpha: 0.92),
                    border: Border.all(
                      color: colors.backgroundTop.withValues(alpha: 0.9),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colors.shadow.withValues(alpha: 0.22),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(size * 0.08),
                    child: Icon(
                      Icons.photo_camera_rounded,
                      color: colors.textStrong,
                      size: size * 0.18,
                    ),
                  ),
                ),
              ),
            ),
          if (!showEditOverlay && bottomBadge != null)
            Positioned(right: 0, bottom: 0, child: bottomBadge!),
        ],
      ),
    );
  }
}
