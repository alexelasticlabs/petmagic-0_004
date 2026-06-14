import 'package:flutter/material.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/shared/widgets/shimmer_box.dart';

class PetMagicImageState extends StatelessWidget {
  const PetMagicImageState({
    required this.child,
    this.isLoading = false,
    this.errorTitle,
    this.retryLabel,
    this.onRetry,
    this.icon,
    super.key,
  });

  final Widget child;
  final bool isLoading;
  final String? errorTitle;
  final String? retryLabel;
  final VoidCallback? onRetry;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    if (errorTitle != null) {
      return PetMagicImageError(
        title: errorTitle!,
        retryLabel: retryLabel,
        onRetry: onRetry,
        icon: icon,
      );
    }

    if (isLoading) {
      return const PetMagicImageSkeleton();
    }

    return child;
  }
}

class PetMagicImageSkeleton extends StatelessWidget {
  const PetMagicImageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return ShimmerBox(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colors.surfaceStrong.withValues(alpha: 0.92),
              colors.accentSoft.withValues(alpha: 0.42),
              colors.surface.withValues(alpha: 0.88),
            ],
            stops: const [0, 0.52, 1],
          ),
        ),
        child: Center(
          child: Icon(
            Icons.auto_awesome_rounded,
            color: colors.textMuted.withValues(alpha: 0.55),
            size: 22,
          ),
        ),
      ),
    );
  }
}

class PetMagicImageError extends StatelessWidget {
  const PetMagicImageError({
    required this.title,
    this.retryLabel,
    this.onRetry,
    this.icon,
    super.key,
  });

  final String title;
  final String? retryLabel;
  final VoidCallback? onRetry;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.surfaceStrong.withValues(alpha: 0.92),
            colors.surface.withValues(alpha: 0.92),
          ],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon ?? Icons.broken_image_outlined,
                color: colors.textMuted,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.textSoft,
                  fontSize: 12.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (onRetry != null && retryLabel != null) ...[
                const SizedBox(height: 6),
                TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: Text(retryLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
