part of 'templates_discovery_page.dart';

class _DiscoverySearchHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _DiscoverySearchHeaderDelegate({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  double get minExtent => 62;

  @override
  double get maxExtent => 62;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final colors = context.petMagicColors;
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            colors.backgroundTop.withValues(alpha: 0.94),
            colors.backgroundBottom,
          ),
          boxShadow: overlapsContent
              ? [
                  BoxShadow(
                    color: colors.shadow.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            PetMagicSpacing.sm,
            7,
            PetMagicSpacing.sm,
            7,
          ),
          child: Semantics(
            container: true,
            button: true,
            label: label,
            onTap: onPressed,
            child: ExcludeSemantics(
              child: PetMagicInteractiveSurface(
                key: const ValueKey('discovery-search-launcher'),
                onTap: onPressed,
                borderRadius: BorderRadius.circular(PetMagicRadii.pill),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surfaceGlass,
                    borderRadius: BorderRadius.circular(PetMagicRadii.pill),
                    border: Border.all(color: colors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 17),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search_rounded,
                          color: colors.textSoft,
                          size: 20,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: colors.textSoft,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: colors.accent,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _DiscoverySearchHeaderDelegate oldDelegate) =>
      oldDelegate.label != label || oldDelegate.onPressed != onPressed;
}

class _DiscoveryStateView extends StatelessWidget {
  const _DiscoveryStateView({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    required this.bottomInset,
    this.unavailableKind,
  });

  final AppUnavailableKind? unavailableKind;
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final unavailable = unavailableKind;
    if (unavailable != null) {
      return PetMagicUnavailableView(
        kind: unavailable,
        onRetry: onAction,
        padding: EdgeInsets.fromLTRB(28, 36, 28, bottomInset),
      );
    }

    return PetMagicAsyncStateView(
      icon: icon,
      title: title,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
      padding: EdgeInsets.fromLTRB(28, 36, 28, bottomInset),
    );
  }
}
