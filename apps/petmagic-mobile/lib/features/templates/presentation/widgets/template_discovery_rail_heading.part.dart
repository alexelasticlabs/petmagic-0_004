part of 'template_discovery_rail.dart';

class _DiscoverySectionHeading extends StatelessWidget {
  const _DiscoverySectionHeading({
    required this.category,
    required this.moreLabel,
    required this.onMorePressed,
  });
  final String category;
  final String moreLabel;
  final VoidCallback onMorePressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: PetMagicSpacing.sm),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compactAction =
              constraints.maxWidth < 336 ||
              MediaQuery.textScalerOf(context).scale(13) > 16;
          final actionLabel = '$moreLabel: $category';
          return Row(
            children: [
              if (compactAction)
                Container(
                  width: 3,
                  height: 20,
                  decoration: BoxDecoration(
                    color: DiscoveryCollectionStyle.of(context, category).ink,
                    borderRadius: BorderRadius.circular(2),
                  ),
                )
              else
                DiscoveryCollectionMark(category: category),
              const SizedBox(width: 8),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Tooltip(
                    message: category,
                    excludeFromSemantics: true,
                    child: Text(
                      category,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colors.textStrong,
                        fontSize: 17,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ),
              ),
              Semantics(
                container: true,
                button: true,
                label: actionLabel,
                onTap: onMorePressed,
                child: ExcludeSemantics(
                  child: Tooltip(
                    message: actionLabel,
                    child: compactAction
                        ? IconButton(
                            key: ValueKey('discovery-more-$category'),
                            onPressed: onMorePressed,
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
                            ),
                            icon: Icon(
                              Icons.arrow_forward_rounded,
                              size: 20,
                              color: colors.accentInk,
                            ),
                          )
                        : TextButton(
                            key: ValueKey('discovery-more-$category'),
                            onPressed: onMorePressed,
                            style: TextButton.styleFrom(
                              foregroundColor: colors.accentInk,
                              minimumSize: const Size(48, 48),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(moreLabel),
                                const SizedBox(width: 2),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
