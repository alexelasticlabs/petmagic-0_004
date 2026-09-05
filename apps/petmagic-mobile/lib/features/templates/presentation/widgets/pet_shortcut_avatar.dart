import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/features/pets/application/pets_contract.dart';
import 'package:petmagic_mobile/shared/files/persistent_media_url.dart';

class PetShortcutAvatar extends StatelessWidget {
  const PetShortcutAvatar({
    super.key,
    this.avatarUrl,
    this.icon,
    this.size = 26,
  });

  final String? avatarUrl;
  final IconData? icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final iconData = icon ?? Icons.pets_rounded;
    final url = normalizePetMediaUrl(avatarUrl);
    final cacheWidth = (size * MediaQuery.devicePixelRatioOf(context))
        .ceil()
        .clamp(64, 192);

    if (url != null && url.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: url,
          cacheKey: persistentSafeProfileAvatarUrl(url),
          width: size,
          height: size,
          fit: BoxFit.cover,
          memCacheWidth: cacheWidth,
          maxWidthDiskCache: cacheWidth,
          filterQuality: FilterQuality.medium,
          placeholder: (_, _) =>
              _PetShortcutIcon(iconData: iconData, size: size),
          errorWidget: (_, _, _) =>
              _PetShortcutIcon(iconData: iconData, size: size),
        ),
      );
    }

    return _PetShortcutIcon(
      iconData: iconData,
      color: colors.accentInk,
      size: size,
    );
  }
}

class _PetShortcutIcon extends StatelessWidget {
  const _PetShortcutIcon({required this.iconData, this.color, this.size = 26});

  final IconData iconData;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return Container(
      height: size,
      width: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Icon(
        iconData,
        size: size <= 28 ? 15 : 20,
        color: color ?? colors.textStrong,
      ),
    );
  }
}
