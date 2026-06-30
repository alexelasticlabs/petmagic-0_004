import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/config/app_config.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/network/network_status_controller.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/gamification/presentation/achievements_page_state.dart';
import 'package:petmagic_mobile/features/gamification/presentation/gamification_providers.dart';
import 'package:petmagic_mobile/features/gamification/presentation/gamification_text_mapper.dart';
import 'package:petmagic_mobile/features/gamification/presentation/widgets/achievement_card.dart';
import 'package:petmagic_mobile/features/gamification/presentation/widgets/achievements_empty_filter_state.dart';
import 'package:petmagic_mobile/features/gamification/presentation/widgets/achievements_filter_bar.dart';
import 'package:petmagic_mobile/features/gamification/presentation/widgets/achievements_next_milestone_card.dart';
import 'package:petmagic_mobile/features/gamification/presentation/widgets/achievements_overview_card.dart';
import 'package:petmagic_mobile/features/gamification/presentation/widgets/achievements_weekly_focus_section.dart';
import 'package:petmagic_mobile/features/profile/presentation/legal_acceptance_gate_page.dart';
import 'package:petmagic_mobile/shared/widgets/android_loopback_backend_hint.dart';
import 'package:petmagic_mobile/features/profile/presentation/widgets/auth_required_sheet.dart';
import 'package:petmagic_mobile/shared/widgets/protected_auth_gate.dart';
import 'package:petmagic_mobile/shared/widgets/petmagic_unavailable_view.dart';

class AchievementsPage extends ConsumerStatefulWidget {
  const AchievementsPage({super.key});

  static const routePath = '/profile/achievements';

  @override
  ConsumerState<AchievementsPage> createState() => _AchievementsPageState();
}

class _AchievementsPageState extends ConsumerState<AchievementsPage>
    with WidgetsBindingObserver {
  AchievementFilter _filter = AchievementFilter.all;
  String? _expandedAchievementKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!ref.read(appLaunchControllerProvider).isAuthenticated) {
      return;
    }

    _reloadAll();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!ref.read(appLaunchControllerProvider).isAuthenticated) {
      return;
    }

    if (state != AppLifecycleState.resumed) {
      return;
    }

    final achievements = ref.read(achievementsProvider);
    final hasInternet = ref.read(networkStatusControllerProvider).hasInternet;
    if (classifyAchievementsUnavailable(
          error: achievements.asError?.error,
          hasInternet: hasInternet,
        ) ==
        null) {
      return;
    }

    _reloadAll();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final text = AppLocalizations.of(context);
    final isAuthenticated = ref.watch(
      appLaunchControllerProvider.select((launch) => launch.isAuthenticated),
    );
    if (!isAuthenticated) {
      return Scaffold(
        appBar: AppBar(title: Text(text.gamificationAchievementsTitle)),
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [colors.backgroundTop, colors.backgroundBottom],
            ),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ProtectedAuthGate(
                subtitle: text.authRequiredMessage,
                onSignIn: () => showAuthRequiredSheet(
                  context,
                  redirectPath: AchievementsPage.routePath,
                ),
              ),
            ),
          ),
        ),
      );
    }

    final achievementsAsync = ref.watch(achievementsProvider);
    final summaryAsync = ref.watch(gamificationSummaryProvider);
    final hasInternet = ref.watch(
      networkStatusControllerProvider.select((status) => status.hasInternet),
    );
    final rawError = achievementsAsync.asError?.error.toString();
    final unavailableKind = classifyAchievementsUnavailable(
      error: achievementsAsync.asError?.error,
      hasInternet: hasInternet,
    );
    final loopbackHintConfig = unavailableKind == null
        ? null
        : AppConfig.androidLoopbackBackendHintConfig();

    ref.listen<NetworkStatusState>(networkStatusControllerProvider, (
      previous,
      next,
    ) {
      if (previous?.hasInternet != false || !next.hasInternet) {
        return;
      }

      final currentAchievements = ref.read(achievementsProvider);
      if (classifyAchievementsUnavailable(
            error: currentAchievements.asError?.error,
            hasInternet: next.hasInternet,
          ) ==
          null) {
        return;
      }

      _reloadAll();
    });

    return Scaffold(
      appBar: AppBar(title: Text(text.gamificationAchievementsTitle)),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colors.backgroundTop, colors.backgroundBottom],
          ),
        ),
        child: achievementsAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator.adaptive()),
          error: (_, __) => unavailableKind != null
              ? PetMagicUnavailableView(
                  kind: unavailableKind,
                  onRetry: _reloadAll,
                  footer: loopbackHintConfig == null
                      ? null
                      : AndroidLoopbackBackendHint(config: loopbackHintConfig),
                )
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          mapAchievementsLoadMessage(rawError, text),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colors.textSoft),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed:
                              isAchievementsLegalAcceptanceFailure(rawError)
                              ? () => context.go(
                                  LegalAcceptanceGatePage.routePath,
                                )
                              : _reloadAll,
                          child: Text(
                            isAchievementsLegalAcceptanceFailure(rawError)
                                ? text.profileLegalAcceptAction
                                : text.retryAction,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          data: (achievements) {
            final summary = summaryAsync.asData?.value;
            final filtered = applyAchievementFilter(achievements, _filter);
            final unlocked = achievements
                .where((item) => item.isUnlocked)
                .length;
            final total = achievements.length;
            final nextAchievement = findNextAchievement(achievements);
            final activeChallenges = summary?.activeChallenges ?? const [];

            return RefreshIndicator.adaptive(
              onRefresh: _refreshAll,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: AchievementsOverviewCard(
                        unlocked: unlocked,
                        total: total,
                        streak: summary?.streak,
                        challengesCount: activeChallenges.length,
                      ),
                    ),
                  ),
                  if (summary?.streak != null || activeChallenges.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                        child: AchievementsWeeklyFocusSection(
                          streak: summary?.streak,
                          challenges: activeChallenges,
                        ),
                      ),
                    ),
                  if (nextAchievement != null &&
                      (_filter == AchievementFilter.all ||
                          _filter == AchievementFilter.inProgress))
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                        child: AchievementsNextMilestoneCard(
                          achievement: nextAchievement,
                          title: localizeAchievementTitle(
                            text,
                            nextAchievement.titleKey,
                          ),
                          description: localizeAchievementDescription(
                            text,
                            nextAchievement.descriptionKey,
                          ),
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                      child: AchievementsFilterBar(
                        selected: _filter,
                        onChanged: (filter) {
                          setState(() {
                            _filter = filter;
                            _expandedAchievementKey = null;
                          });
                        },
                      ),
                    ),
                  ),
                  if (filtered.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                        child: AchievementsEmptyFilterState(
                          message: text.gamificationNoAchievementsInFilter,
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final achievement = filtered[index];
                          final isExpanded =
                              _expandedAchievementKey == achievement.key;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: AchievementCard(
                              achievement: achievement,
                              title: localizeAchievementTitle(
                                text,
                                achievement.titleKey,
                              ),
                              description: localizeAchievementDescription(
                                text,
                                achievement.descriptionKey,
                              ),
                              expanded: isExpanded,
                              onTap: () {
                                setState(() {
                                  _expandedAchievementKey = isExpanded
                                      ? null
                                      : achievement.key;
                                });
                              },
                            ),
                          );
                        }, childCount: filtered.length),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _reloadAll() {
    if (!mounted || !ref.read(appLaunchControllerProvider).isAuthenticated) {
      return;
    }

    ref.invalidate(achievementsProvider);
    ref.invalidate(gamificationSummaryProvider);
  }

  Future<void> _refreshAll() async {
    if (!ref.read(appLaunchControllerProvider).isAuthenticated) {
      return;
    }

    _reloadAll();
    await ref.read(achievementsProvider.future);
    try {
      await ref.read(gamificationSummaryProvider.future);
    } catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'Gamification.Achievements',
        operation: 'refresh_summary',
        message: 'Achievements summary refresh failed',
        context: {'filter': _filter.name},
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
