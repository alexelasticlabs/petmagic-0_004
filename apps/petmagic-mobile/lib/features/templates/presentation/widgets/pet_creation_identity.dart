import 'package:flutter/material.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_interactive_surface.dart';

import 'pet_shortcut_avatar.dart';

/// The pet remains the visual anchor from selection through creation.
class PetCreationIdentity extends StatelessWidget {
  const PetCreationIdentity({
    required this.name,
    required this.caption,
    this.avatarUrl,
    this.onPressed,
    this.selected = false,
    super.key,
  });

  final String name;
  final String caption;
  final String? avatarUrl;
  final VoidCallback? onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final radius = BorderRadius.circular(22);
    final content = Container(
      constraints: const BoxConstraints(minHeight: 82),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [
            Color.alphaBlend(
              colors.accent.withValues(alpha: selected ? 0.1 : 0.045),
              colors.surface,
            ),
            colors.surface,
          ],
        ),
        border: Border.all(
          color: selected
              ? colors.accent.withValues(alpha: 0.48)
              : colors.border,
        ),
      ),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colors.accent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: PetShortcutAvatar(avatarUrl: avatarUrl, size: 48),
                ),
                PositionedDirectional(
                  end: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: 13,
                      color: colors.goldInk,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  caption,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.accentInk,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.textStrong,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          if (onPressed != null) ...[
            const SizedBox(width: 8),
            Icon(Icons.unfold_more_rounded, color: colors.accentInk, size: 20),
          ],
        ],
      ),
    );
    if (onPressed == null) return content;
    return Semantics(
      button: true,
      selected: selected,
      label: '$caption, $name',
      onTap: onPressed,
      child: ExcludeSemantics(
        child: PetMagicInteractiveSurface(
          onTap: onPressed,
          borderRadius: radius,
          child: content,
        ),
      ),
    );
  }
}
