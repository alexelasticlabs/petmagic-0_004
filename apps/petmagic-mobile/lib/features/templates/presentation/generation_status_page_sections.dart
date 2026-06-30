part of 'generation_status_page.dart';

const int _resultCardImageCacheWidth = 1080;
const int _resultFullscreenImageCacheWidth = 1440;
const int _beforeAfterCompareImageCacheWidth = 1024;

File? _localMediaFile(String? path) {
  final normalized = path?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }

  final file = File(normalized);
  if (!file.existsSync()) {
    return null;
  }
  return file;
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.onBack,
    this.subtitle,
    this.onMenu,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onBack;
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
          color: colors.textStrong,
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colors.textStrong,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (onMenu != null)
          IconButton(
            onPressed: onMenu,
            icon: const Icon(Icons.more_vert_rounded),
            color: colors.textStrong,
          ),
      ],
    );
  }
}

class _StatusHero extends StatelessWidget {
  const _StatusHero({required this.generation});

  final TemplateGenerationResult generation;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final progress = generation.effectiveProgressPercent;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                generationStatusIcon(generation),
                color: generationStatusColor(colors, generation),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  generation.templateTitle ?? text.generationStatusResultTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.textStrong,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            statusTitle(text, generation),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: generation.isCompleted
                  ? colors.accent
                  : generation.isFailed
                  ? colors.danger
                  : colors.textSoft,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          if (!generation.isTerminal) ...[
            Row(
              children: [
                SizedBox(
                  width: 84,
                  height: 84,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: progress / 100,
                        strokeWidth: 7,
                        color: generationStatusColor(colors, generation),
                        backgroundColor: colors.border.withValues(alpha: 0.6),
                      ),
                      Center(
                        child: Text(
                          '$progress%',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: colors.textStrong,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    etaLabel(text, generation),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.textSoft,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              text.generationStatusNonTerminalHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.textMuted,
                height: 1.35,
              ),
            ),
          ] else if (generation.isCompleted) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colors.accent.withValues(alpha: 0.14),
                    colors.accent.withValues(alpha: 0.04),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: colors.accent.withValues(alpha: 0.28),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    color: colors.accent,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      terminalHint(text, generation),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textSoft,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Text(
              terminalHint(text, generation),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.textMuted,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
