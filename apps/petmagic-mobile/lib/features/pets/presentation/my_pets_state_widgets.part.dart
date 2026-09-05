part of 'my_pets_page.dart';

class _PetAvatar extends StatelessWidget {
  const _PetAvatar({required this.url, required this.name, required this.size});

  final String? url;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final imageUrl = normalizePetMediaUrl(url);
    if (imageUrl == null) {
      return CircleAvatar(
        radius: size / 2,
        child: Text(name.isEmpty ? '?' : name.characters.first),
      );
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        cacheKey: persistentSafeProfileAvatarUrl(imageUrl),
        width: size,
        height: size,
        fit: BoxFit.cover,
        memCacheWidth: _petAvatarMemCacheWidth,
        maxWidthDiskCache: _petAvatarMemCacheWidth,
        placeholder: (_, _) => CircleAvatar(
          radius: size / 2,
          child: const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator.adaptive(strokeWidth: 2),
          ),
        ),
        errorWidget: (_, _, _) => CircleAvatar(
          radius: size / 2,
          child: const Icon(Icons.pets_rounded),
        ),
      ),
    );
  }
}

class _StateView extends StatelessWidget {
  const _StateView({
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.actionIcon,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? actionIcon;

  @override
  Widget build(BuildContext context) {
    return PetMagicAsyncStateView(
      icon: Icons.pets_rounded,
      title: title,
      message: subtitle ?? '',
      actionLabel: actionLabel,
      actionIcon: actionIcon,
      onAction: onAction,
    );
  }
}

class _PetSectionEmpty extends StatelessWidget {
  const _PetSectionEmpty({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 18,
            color: colors.textMuted.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.textMuted,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({
    required this.label,
    required this.retryLabel,
    required this.onRetry,
  });

  final String label;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        TextButton(onPressed: onRetry, child: Text(retryLabel)),
      ],
    );
  }
}
