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
        ? summaryAsync.error.toString()
        : achievementsAsync.hasError
        ? achievementsAsync.error.toString()
        : null;
    final unavailableKind = classifyAchievementsUnavailable(
      error: rawError,
      hasInternet: hasInternet,
    );
    final statusMessage = switch (unavailableKind) {
      AppUnavailableKind.offline => text.appUnavailableOfflineTitle,
      AppUnavailableKind.serverUnavailable => text.appUnavailableServerTitle,
      null when rawError != null => mapAchievementsLoadMessage(rawError, text),
      null => null,
    };

    void openAchievements() => context.push(AchievementsPage.routePath);
    void retry() {
      ref.invalidate(gamificationSummaryProvider);
      ref.invalidate(achievementsProvider);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GamificationHighlightsCard(
          summary: summary,
          unlockedAchievementsCount: achievements
              ?.where((achievement) => achievement.isUnlocked)
              .length,
          totalAchievementsCount: achievements?.length,
          onStreakTap: openAchievements,
          onAchievementsTap: openAchievements,
          onPetTap: () => context.push(MyPetsPage.routePath),
        ),
        if (statusMessage != null) ...[
          const SizedBox(height: 10),
          ProfileGlassCard(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
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
          ),
        ],
      ],
    );
  }
}
