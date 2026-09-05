part of 'templates_discovery_page.dart';

class _DiscoverySearchHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _DiscoverySearchHeaderDelegate({
    required this.catalogLabel,
    required this.randomLabel,
    required this.onCatalogPressed,
    required this.onRandomPressed,
    required this.actionHeight,
    required this.searchEnabled,
  });

  final String catalogLabel;
  final String randomLabel;
  final VoidCallback onCatalogPressed;
  final VoidCallback? onRandomPressed;
  final double actionHeight;
  final bool searchEnabled;

  @override
  double get minExtent => actionHeight + 12;
  @override
  double get maxExtent => minExtent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final colors = context.petMagicColors;
    return AnimatedContainer(
      key: const ValueKey('discovery-toolbar-surface'),
      duration: discoveryMotionDuration(context, PetMagicMotion.fast),
      foregroundDecoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: overlapsContent
                ? colors.border.withValues(alpha: 0.65)
                : Colors.transparent,
          ),
        ),
      ),
      decoration: BoxDecoration(
        color: overlapsContent ? colors.backgroundTop : Colors.transparent,
        boxShadow: overlapsContent
            ? [
                BoxShadow(
                  color: colors.shadow.withValues(alpha: 0.055),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ]
            : const [],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: PetMagicSpacing.sm,
          vertical: 6,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Semantics(
                button: true,
                label: catalogLabel,
                onTap: onCatalogPressed,
                child: ExcludeSemantics(
                  child: PetMagicInteractiveSurface(
                    key: ValueKey(
                      searchEnabled
                          ? 'discovery-search-launcher'
                          : 'discovery-catalog-launcher',
                    ),
                    onTap: onCatalogPressed,
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: colors.surfaceGlass,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: colors.border),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            searchEnabled
                                ? Icons.search_rounded
                                : Icons.grid_view_rounded,
                            size: 19,
                            color: colors.accentInk,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              catalogLabel,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: colors.textStrong,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 19,
                            color: colors.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: randomLabel,
              excludeFromSemantics: true,
              child: Semantics(
                button: true,
                enabled: onRandomPressed != null,
                label: randomLabel,
                onTap: onRandomPressed,
                child: ExcludeSemantics(
                  child: PetMagicInteractiveSurface(
                    key: const ValueKey('discovery-random-launcher'),
                    onTap: onRandomPressed,
                    enabled: onRandomPressed != null,
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      width: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            colors.accent.withValues(alpha: 0.24),
                            colors.accent.withValues(alpha: 0.08),
                          ],
                        ),
                        border: Border.all(
                          color: colors.accent.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Icon(
                        Icons.shuffle_rounded,
                        color: colors.accentInk,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _DiscoverySearchHeaderDelegate oldDelegate) =>
      oldDelegate.catalogLabel != catalogLabel ||
      oldDelegate.randomLabel != randomLabel ||
      oldDelegate.actionHeight != actionHeight ||
      oldDelegate.searchEnabled != searchEnabled ||
      oldDelegate.onCatalogPressed != onCatalogPressed ||
      oldDelegate.onRandomPressed != onRandomPressed;
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
