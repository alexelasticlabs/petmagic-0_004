import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';

class ProfileScreenBackground extends StatelessWidget {
  const ProfileScreenBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Material(
      type: MaterialType.transparency,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colors.backgroundTop, colors.backgroundBottom],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              top: -100,
              left: -20,
              child: IgnorePointer(
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        colors.accent.withValues(alpha: 0.16),
                        colors.accent.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 180,
              right: -70,
              child: IgnorePointer(
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        colors.blue.withValues(alpha: 0.08),
                        colors.blue.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class ProfileGlassCard extends StatelessWidget {
  const ProfileGlassCard({required this.child, this.padding, super.key});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final borderRadius = BorderRadius.circular(24);

    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: isLight ? 0.28 : 1),
              blurRadius: isLight ? 22 : 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surfaceGlass.withValues(
                  alpha: isLight ? 0.98 : 1,
                ),
                borderRadius: borderRadius,
                border: Border.all(
                  color: colors.border.withValues(alpha: isLight ? 0.98 : 1),
                ),
              ),
              child: Padding(
                padding: padding ?? const EdgeInsets.all(16),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
                  child: imageUrl != null && imageUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl!,
                          width: size,
                          height: size,
                          fit: BoxFit.cover,
                          memCacheWidth: avatarCacheSize,
                          memCacheHeight: avatarCacheSize,
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

class ProfileStatusPill extends StatelessWidget {
  const ProfileStatusPill({
    required this.label,
    this.leading,
    this.backgroundColor,
    this.foregroundColor,
    super.key,
  });

  final String label;
  final IconData? leading;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final baseBg = backgroundColor ?? colors.accentSoft;
    final baseFg = foregroundColor ?? colors.textStrong;
    final bg = isLight
        ? Color.alphaBlend(Colors.white.withValues(alpha: 0.22), baseBg)
        : baseBg;
    final fg = isLight
        ? Color.alphaBlend(Colors.black.withValues(alpha: 0.24), baseFg)
        : baseFg;
    final borderColor = (foregroundColor ?? colors.border).withValues(
      alpha: foregroundColor != null ? (isLight ? 0.52 : 0.38) : 0.9,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: isLight ? 0.12 : 0.18),
            blurRadius: isLight ? 10 : 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final labelText = Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontSize: 11.8,
                fontWeight: FontWeight.w700,
              ),
            );

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null) ...[
                  Icon(leading, size: 13, color: fg),
                  const SizedBox(width: 6),
                ],
                if (constraints.hasBoundedWidth)
                  Flexible(child: labelText)
                else
                  labelText,
              ],
            );
          },
        ),
      ),
    );
  }
}

class ProfileStatTile extends StatelessWidget {
  const ProfileStatTile({
    required this.icon,
    required this.value,
    required this.label,
    this.highlight,
    super.key,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color? highlight;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final tone = highlight ?? colors.accent;

    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: tone, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: colors.textStrong,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textSoft,
              fontSize: 11,
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileSectionLabel extends StatelessWidget {
  const ProfileSectionLabel({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: colors.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class ProfileSettingsRow extends StatelessWidget {
  const ProfileSettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailingText,
    this.trailing,
    this.onTap,
    this.iconColor,
    this.isDestructive = false,
    this.showDivider = true,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? trailingText;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;
  final bool isDestructive;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final tone = isDestructive ? colors.danger : colors.textStrong;
    final iconTone =
        iconColor ?? (isDestructive ? colors.danger : colors.accent);
    final iconBackground = isDestructive
        ? colors.danger.withValues(alpha: isLight ? 0.12 : 0.14)
        : colors.surfaceStrong.withValues(alpha: isLight ? 0.52 : 0.58);
    final iconBorder = isDestructive
        ? colors.danger.withValues(alpha: isLight ? 0.22 : 0.3)
        : colors.border.withValues(alpha: isLight ? 0.85 : 0.78);
    final resolvedIconColor = isDestructive
        ? colors.danger
        : Color.alphaBlend(
            colors.textStrong.withValues(alpha: isLight ? 0.35 : 0.18),
            iconTone,
          );

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: iconBorder),
            ),
            child: Icon(icon, color: resolvedIconColor, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: tone,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isDestructive
                        ? colors.danger.withValues(alpha: 0.82)
                        : colors.textSoft,
                    fontSize: 12.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (trailing != null)
            Align(
              alignment: Alignment.centerRight,
              widthFactor: 1,
              child: trailing!,
            )
          else if (trailingText != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                trailingText!,
                style: TextStyle(
                  color: isDestructive ? colors.danger : colors.accent,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            Icon(
              Icons.chevron_right_rounded,
              color: isDestructive ? colors.danger : colors.textSoft,
              size: 24,
            ),
        ],
      ),
    );

    final row = onTap == null
        ? content
        : Material(
            color: Colors.transparent,
            child: InkWell(onTap: onTap, child: content),
          );

    return DecoratedBox(
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                bottom: BorderSide(
                  color: colors.border.withValues(alpha: 0.82),
                ),
              )
            : null,
      ),
      child: row,
    );
  }
}
