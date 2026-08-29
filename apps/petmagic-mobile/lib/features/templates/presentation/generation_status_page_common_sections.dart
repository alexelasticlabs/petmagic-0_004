part of 'generation_status_page.dart';

class _FeedbackResult {
  const _FeedbackResult(this.reasons, this.comment);

  final List<String> reasons;
  final String? comment;
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return _Panel(
      child: Center(
        child: CircularProgressIndicator.adaptive(
          valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(message, style: TextStyle(color: colors.textSoft)),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: Text(text.retryAction)),
        ],
      ),
    );
  }
}

class _MediaPlaceholder extends StatelessWidget {
  const _MediaPlaceholder({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return ColoredBox(
      color: colors.surfaceStrong,
      child: Center(
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colors.textMuted,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceGlass,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.border.withValues(alpha: 0.7)),
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class _CompareActionCard extends StatelessWidget {
  const _CompareActionCard({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return Center(
      child: TextButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.compare_rounded, size: 18),
        label: Text(label),
        style: TextButton.styleFrom(
          foregroundColor: colors.textSoft,
          textStyle: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _TechnicalDetailsAction extends StatelessWidget {
  const _TechnicalDetailsAction({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    return Column(
      children: [
        Divider(color: colors.border.withValues(alpha: 0.62)),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.tune_rounded, size: 17),
            label: Text(text.generationStatusTechnicalDetailsAction),
            style: TextButton.styleFrom(foregroundColor: colors.textMuted),
          ),
        ),
      ],
    );
  }
}
