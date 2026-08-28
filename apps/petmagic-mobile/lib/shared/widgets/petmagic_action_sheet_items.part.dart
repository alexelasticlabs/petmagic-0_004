part of 'petmagic_action_sheet.dart';

class PetMagicActionSheetItem extends StatelessWidget {
  const PetMagicActionSheetItem({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.semanticLabel,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String semanticLabel;
  final VoidCallback onTap;
  final bool enabled;

  @override
  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final enabled = this.enabled;

    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 76),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Opacity(
                    opacity: enabled ? 1 : 0.5,
                    child: PetMagicActionIconContainer(icon: icon),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: colors.textStrong.withValues(
                                  alpha: enabled ? 1 : 0.5,
                                ),
                                fontSize: 17.5,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: colors.textSoft.withValues(
                                  alpha: enabled ? 1 : 0.5,
                                ),
                                fontSize: 14.5,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: colors.textMuted.withValues(
                      alpha: enabled ? 0.72 : 0.34,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PetMagicActionIconContainer extends StatelessWidget {
  const PetMagicActionIconContainer({super.key, required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: colors.surfaceStrong.withValues(alpha: 0.58),
      ),
      child: Icon(icon, size: 23, color: colors.accent),
    );
  }
}
