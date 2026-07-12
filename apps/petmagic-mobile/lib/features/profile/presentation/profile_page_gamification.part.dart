part of 'profile_page.dart';

class _GamificationHighlightsWrapper extends ConsumerWidget {
  const _GamificationHighlightsWrapper();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final summaryAsync = ref.watch(gamificationSummaryProvider);
    final achievementsAsync = ref.watch(achievementsProvider);
    final hasInternet = ref.watch(
      networkStatusControllerProvider.select((status) => status.hasInternet),
    );
    final summary = summaryAsync.asData?.value;
    final achievements = achievementsAsync.asData?.value;
    final rawError = summaryAsync.hasError
        ? achievementsErrorMessage(summaryAsync.error)
        : achievementsAsync.hasError
        ? achievementsErrorMessage(achievementsAsync.error)
        : null;
    final unavailableKind = classifyAchievementsUnavailable(
      error: rawError,
      hasInternet: hasInternet,
    );
    final loopbackHintConfig = unavailableKind == null
        ? null
        : AppConfig.androidLoopbackBackendHintConfig();
    final statusMessage = switch (unavailableKind) {
      AppUnavailableKind.offline => text.appUnavailableOfflineTitle,
      AppUnavailableKind.serverUnavailable => text.appUnavailableServerTitle,
      null when rawError != null =>
        mapCommonAuthFeedbackMessage(text, rawError) ??
            text.gamificationLoadFailed,
      null => null,
    };

    void reloadPreview() {
      ref.invalidate(gamificationSummaryProvider);
      ref.invalidate(achievementsProvider);
    }

    void openAchievements() =>
        context.appNavigator.push(const AchievementsDestination());

    void retry() => reloadPreview();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GamificationHighlightsCard(
          summary: summary,
          unlockedAchievementsCount: achievements
              ?.where((achievement) => achievement.isUnlocked)
              .length,
          totalAchievementsCount: achievements?.length,
          onOpenHub: openAchievements,
          onPetTap: () => context.appNavigator.push(const PetsDestination()),
        ),
        if (statusMessage != null) ...[
          const SizedBox(height: 10),
          ProfileGlassCard(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        statusMessage,
                        style: TextStyle(
                          color: colors.textSoft,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    TextButton.icon(
                      onPressed: retry,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: Text(text.retryAction),
                    ),
                  ],
                ),
                if (loopbackHintConfig != null) ...[
                  const SizedBox(height: 10),
                  AndroidLoopbackBackendHint(
                    config: loopbackHintConfig,
                    compact: true,
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
