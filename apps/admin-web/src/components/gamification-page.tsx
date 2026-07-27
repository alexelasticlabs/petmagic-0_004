"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { type FormEvent, useEffect, useMemo, useState } from "react";

import { AdminEntityLink } from "@/components/admin/admin-entity-link";
import { AdminPage, AdminStateCard } from "@/components/admin/admin-primitives";
import { ConfirmationDialog } from "@/components/admin/confirmation-dialog";
import { getGamificationText } from "@/components/gamification-page.content";
import {
  GAMIFICATION_RESET_REASON_MAX_LENGTH,
  calculateGamificationCompletionRate,
  validateGamificationResetReason,
} from "@/components/gamification-page.helpers";
import styles from "@/components/gamification-page.module.css";
import { Button } from "@/components/ui/button";
import { getAdminErrorMessage } from "@/lib/admin-error-message";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
  fetchAdminGamificationAchievements,
  fetchAdminGamificationChallenges,
  fetchAdminGamificationDashboardMetrics,
  fetchAdminUserGamificationOverview,
  fetchUsers,
  resetAdminUserGamificationStreak,
  type UserListItem,
} from "@/lib/api-client";
import { type Locale } from "@/lib/i18n";

type GamificationPageProps = {
  locale: Locale;
};

type MetricIconName = "users" | "streak" | "achievement" | "challenge";

function MetricIcon({ name }: { name: MetricIconName }) {
  if (name === "users") {
    return (
      <svg viewBox="0 0 24 24" aria-hidden="true">
        <path
          d="M16 20v-1.5A3.5 3.5 0 0 0 12.5 15h-5A3.5 3.5 0 0 0 4 18.5V20M10 11a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7Zm7.5.5a3 3 0 0 0 0-5.5M18 15a3.5 3.5 0 0 1 2 3.16V20"
          fill="none"
          stroke="currentColor"
          strokeLinecap="round"
          strokeLinejoin="round"
          strokeWidth="1.7"
        />
      </svg>
    );
  }

  if (name === "streak") {
    return (
      <svg viewBox="0 0 24 24" aria-hidden="true">
        <path
          d="M13.4 3.2c.5 3-1.6 4.2-2.2 6.1-.4 1.3.2 2.4 1.3 2.9-.2-2.1 1-3.3 2.2-4.3 2.7 2.2 4.3 4.8 3.2 8.1a6.1 6.1 0 0 1-11.7-.1C5 12.2 7.5 9.3 9.7 7.2c.2 1.7.9 2.5 1.6 2.9"
          fill="none"
          stroke="currentColor"
          strokeLinecap="round"
          strokeLinejoin="round"
          strokeWidth="1.7"
        />
      </svg>
    );
  }

  if (name === "achievement") {
    return (
      <svg viewBox="0 0 24 24" aria-hidden="true">
        <path
          d="M8 4h8v3.5a4 4 0 0 1-8 0V4Zm0 1H5v2a4 4 0 0 0 3.7 4M16 5h3v2a4 4 0 0 1-3.7 4M12 12v4m-3 4h6m-5-4h4v4h-4v-4Z"
          fill="none"
          stroke="currentColor"
          strokeLinecap="round"
          strokeLinejoin="round"
          strokeWidth="1.7"
        />
      </svg>
    );
  }

  return (
    <svg viewBox="0 0 24 24" aria-hidden="true">
      <path
        d="M6 21V4m0 1h10l-2 3 2 3H6m4 10h7"
        fill="none"
        stroke="currentColor"
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth="1.7"
      />
    </svg>
  );
}

function formatNumber(value: number | undefined, locale: Locale) {
  if (value === undefined) {
    return "—";
  }

  return new Intl.NumberFormat(locale === "ru" ? "ru-BY" : "en-US").format(value);
}

function formatDateTime(value: string | null | undefined, locale: Locale, includeTime = true) {
  if (!value) {
    return "—";
  }

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return "—";
  }

  return new Intl.DateTimeFormat(locale === "ru" ? "ru-BY" : "en-US", {
    dateStyle: "medium",
    ...(includeTime ? { timeStyle: "short" as const } : {}),
    ...(!includeTime ? { timeZone: "UTC" } : {}),
  }).format(date);
}

function formatHistoryKind(kind: string, text: ReturnType<typeof getGamificationText>): string {
  if (kind === "achievement_reward") {
    return text.historyAchievementLabel;
  }

  if (kind === "challenge_reward") {
    return text.historyChallengeLabel;
  }

  return text.historyStreakLabel;
}

function formatHistoryStatus(status: string, text: ReturnType<typeof getGamificationText>): string {
  const labels: Record<string, string> = {
    credited: text.historyCreditedLabel,
    pending: text.historyPendingLabel,
    no_reward: text.historyNoRewardLabel,
    in_progress: text.historyInProgressLabel,
    recorded: text.historyRecordedLabel,
  };

  return labels[status] ?? status;
}

export function GamificationPage({ locale }: GamificationPageProps) {
  const text = getGamificationText(locale);
  const queryClient = useQueryClient();
  const [userSearchInput, setUserSearchInput] = useState("");
  const [userSearchTerm, setUserSearchTerm] = useState("");
  const [selectedUserId, setSelectedUserId] = useState<string | null>(null);
  const [selectedUser, setSelectedUser] = useState<UserListItem | null>(null);
  const [userIdError, setUserIdError] = useState<string | null>(null);
  const [resetReason, setResetReason] = useState("");
  const [isResetDialogOpen, setIsResetDialogOpen] = useState(false);
  const [feedback, setFeedback] = useState<{
    tone: "success" | "danger";
    message: string;
  } | null>(null);

  const metricsQuery = useQuery({
    queryKey: adminQueryKeys.gamificationDashboardMetrics,
    queryFn: ({ signal }) => fetchAdminGamificationDashboardMetrics(signal),
    staleTime: 60_000,
  });
  const challengesQuery = useQuery({
    queryKey: adminQueryKeys.gamificationChallenges,
    queryFn: ({ signal }) => fetchAdminGamificationChallenges(signal),
    staleTime: 60_000,
  });
  const achievementsQuery = useQuery({
    queryKey: adminQueryKeys.gamificationAchievements,
    queryFn: ({ signal }) => fetchAdminGamificationAchievements(signal),
    staleTime: 60_000,
  });
  const userOverviewQuery = useQuery({
    queryKey: selectedUserId
      ? adminQueryKeys.gamificationUser(selectedUserId)
      : adminQueryKeys.gamificationUserDisabled,
    queryFn: ({ signal }) => fetchAdminUserGamificationOverview(selectedUserId ?? "", signal),
    enabled: Boolean(selectedUserId),
    retry: false,
  });
  const userSearchQueryParams = useMemo(
    () => ({
      search: userSearchTerm,
      skip: 0,
      take: 8,
      sort: "last_activity_desc",
    }),
    [userSearchTerm]
  );
  const userSearchQuery = useQuery({
    queryKey: adminQueryKeys.users({
      scope: "gamification-user-search",
      ...userSearchQueryParams,
    }),
    queryFn: ({ signal }) => fetchUsers(userSearchQueryParams, signal),
    enabled: userSearchTerm.length >= 2,
    retry: 1,
    staleTime: 30_000,
  });

  const challenges = useMemo(
    () =>
      [...(challengesQuery.data ?? [])].sort(
        (left, right) =>
          left.sortOrder - right.sortOrder || left.titleKey.localeCompare(right.titleKey, locale)
      ),
    [challengesQuery.data, locale]
  );
  const achievements = useMemo(
    () =>
      [...(achievementsQuery.data ?? [])].sort(
        (left, right) =>
          left.sortOrder - right.sortOrder || left.key.localeCompare(right.key, locale)
      ),
    [achievementsQuery.data, locale]
  );

  const resetReasonValidation = validateGamificationResetReason(resetReason);
  const isBaseFetching =
    metricsQuery.isFetching || challengesQuery.isFetching || achievementsQuery.isFetching;
  const hasPartialError =
    metricsQuery.isError || challengesQuery.isError || achievementsQuery.isError;

  useEffect(() => {
    if (!feedback) {
      return;
    }

    const timeoutId = window.setTimeout(() => setFeedback(null), 6000);
    return () => window.clearTimeout(timeoutId);
  }, [feedback]);

  const resetStreakMutation = useMutation<
    void,
    Error,
    {
      userId: string;
      reason: string;
    }
  >({
    mutationFn: ({ userId, reason }) => resetAdminUserGamificationStreak(userId, reason),
    onSuccess: async (_result, variables) => {
      setIsResetDialogOpen(false);
      setResetReason("");
      setFeedback({ tone: "success", message: text.resetSuccess });
      await Promise.all([
        queryClient.invalidateQueries({
          queryKey: adminQueryKeys.gamificationUser(variables.userId),
        }),
        queryClient.invalidateQueries({
          queryKey: adminQueryKeys.gamificationDashboardMetrics,
        }),
      ]);
    },
    onError: () => {
      setIsResetDialogOpen(false);
      setFeedback({ tone: "danger", message: text.resetError });
    },
  });

  function refreshBaseData() {
    if (isBaseFetching) {
      return;
    }

    void Promise.all([
      metricsQuery.refetch(),
      challengesQuery.refetch(),
      achievementsQuery.refetch(),
    ]);
  }

  function handleUserLookup(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const normalizedSearch = userSearchInput.trim().slice(0, 120);

    if (normalizedSearch.length < 2) {
      setUserIdError(text.invalidUserId);
      return;
    }

    setUserIdError(null);
    setFeedback(null);
    if (normalizedSearch === userSearchTerm) {
      void userSearchQuery.refetch();
      return;
    }

    setUserSearchTerm(normalizedSearch);
  }

  function selectUser(user: UserListItem) {
    setSelectedUser(user);
    setSelectedUserId(user.userId);
    setResetReason("");
    setIsResetDialogOpen(false);
    setFeedback(null);
  }

  function openResetDialog() {
    if (!selectedUserId || resetReasonValidation.error || resetStreakMutation.isPending) {
      return;
    }

    setIsResetDialogOpen(true);
  }

  function confirmReset() {
    if (!selectedUserId || resetReasonValidation.error || resetStreakMutation.isPending) {
      return;
    }

    resetStreakMutation.mutate({
      userId: selectedUserId,
      reason: resetReasonValidation.normalizedReason,
    });
  }

  const metrics = metricsQuery.data;
  const userOverview = userOverviewQuery.data;
  const isMetricsInitialLoading = metricsQuery.isPending && !metrics;
  const isChallengesInitialLoading = challengesQuery.isPending && !challengesQuery.data;
  const isAchievementsInitialLoading = achievementsQuery.isPending && !achievementsQuery.data;
  const reasonError =
    resetReasonValidation.error === "required"
      ? text.reasonRequired
      : resetReasonValidation.error === "too_long"
        ? text.reasonTooLong
        : null;

  return (
    <AdminPage className={styles.page}>
      <section className={styles.intro} aria-labelledby="gamification-workspace-title">
        <div className={styles.introCopy}>
          <p className={styles.eyebrow}>{text.workspaceEyebrow}</p>
          <h2 id="gamification-workspace-title" className={styles.panelTitle}>
            {text.workspaceTitle}
          </h2>
          <p className={styles.description}>{text.description}</p>
        </div>
        <div className={styles.introActions}>
          <span className={styles.updated}>
            {text.lastUpdatedLabel}: {formatDateTime(metrics?.generatedAtUtc, locale)}
          </span>
          <Button
            type="button"
            variant="secondary"
            disabled={isBaseFetching}
            onClick={refreshBaseData}
          >
            {isBaseFetching ? text.refreshingAction : text.refreshAction}
          </Button>
        </div>
      </section>

      {feedback ? <AdminStateCard tone={feedback.tone} title={feedback.message} /> : null}
      {hasPartialError ? (
        <AdminStateCard
          tone="warning"
          title={text.partialErrorTitle}
          description={text.errorDescription}
          action={
            <Button
              type="button"
              variant="secondary"
              disabled={isBaseFetching}
              onClick={refreshBaseData}
            >
              {text.retryAction}
            </Button>
          }
        />
      ) : null}

      {isMetricsInitialLoading ? (
        <AdminStateCard
          tone="info"
          title={text.loadingTitle}
          description={text.loadingDescription}
        />
      ) : (
        <section className={styles.metricsGrid} aria-label={text.metricsRegionLabel}>
          <article className={styles.metricCard} data-tone="info">
            <div className={styles.metricCopy}>
              <span className={styles.metricLabel}>{text.usersWithProgressLabel}</span>
              <strong className={styles.metricValue}>
                {formatNumber(metrics?.totalUsersWithProgress, locale)}
              </strong>
              <span className={styles.metricHint}>
                {text.usersWithProgressHint}: {formatNumber(metrics?.totalPetsTracked, locale)}
              </span>
            </div>
            <span className={styles.metricIcon}>
              <MetricIcon name="users" />
            </span>
          </article>

          <article className={styles.metricCard} data-tone="warning">
            <div className={styles.metricCopy}>
              <span className={styles.metricLabel}>{text.activeStreaksLabel}</span>
              <strong className={styles.metricValue}>
                {formatNumber(metrics?.usersWithActiveStreak, locale)}
              </strong>
              <span className={styles.metricHint}>{text.activeStreaksHint}</span>
            </div>
            <span className={styles.metricIcon}>
              <MetricIcon name="streak" />
            </span>
          </article>

          <article className={styles.metricCard} data-tone="success">
            <div className={styles.metricCopy}>
              <span className={styles.metricLabel}>{text.achievementsUnlockedLabel}</span>
              <strong className={styles.metricValue}>
                {formatNumber(metrics?.totalAchievementsUnlocked, locale)}
              </strong>
              <span className={styles.metricHint}>
                {text.achievementDefinitionsHint}:{" "}
                {formatNumber(metrics?.totalAchievementDefinitions, locale)}
              </span>
            </div>
            <span className={styles.metricIcon}>
              <MetricIcon name="achievement" />
            </span>
          </article>

          <article className={styles.metricCard}>
            <div className={styles.metricCopy}>
              <span className={styles.metricLabel}>{text.challengeCompletionsLabel}</span>
              <strong className={styles.metricValue}>
                {formatNumber(metrics?.currentWeekChallengeCompletions, locale)}
              </strong>
              <span className={styles.metricHint}>
                {text.challengeParticipantsHint}:{" "}
                {formatNumber(metrics?.currentWeekChallengeParticipants, locale)}
              </span>
            </div>
            <span className={styles.metricIcon}>
              <MetricIcon name="challenge" />
            </span>
          </article>
        </section>
      )}

      <div className={styles.workspaceGrid}>
        <section
          className={`${styles.panel} ${styles.challenges}`}
          aria-labelledby="gamification-challenges-title"
        >
          <header className={styles.panelHeader}>
            <div className={styles.panelTitleGroup}>
              <h2 id="gamification-challenges-title" className={styles.panelTitle}>
                {text.challengesTitle}
              </h2>
              <p className={styles.panelDescription}>{text.challengesDescription}</p>
            </div>
            <span className={styles.countBadge} aria-label={text.challengesTitle}>
              {formatNumber(challenges.length, locale)}
            </span>
          </header>

          {isChallengesInitialLoading ? (
            <AdminStateCard
              tone="info"
              title={text.loadingTitle}
              description={text.loadingDescription}
            />
          ) : challengesQuery.isError && !challengesQuery.data ? (
            <AdminStateCard
              tone="danger"
              title={text.errorTitle}
              description={getAdminErrorMessage(challengesQuery.error, text.errorDescription)}
              action={
                <Button
                  type="button"
                  variant="secondary"
                  disabled={challengesQuery.isFetching}
                  onClick={() => void challengesQuery.refetch()}
                >
                  {text.retryAction}
                </Button>
              }
            />
          ) : challenges.length === 0 ? (
            <div className={styles.emptyState}>
              <strong>{text.noChallengesTitle}</strong>
              <p>{text.noChallengesDescription}</p>
            </div>
          ) : (
            <div className={styles.tableContainer}>
              <div
                className={styles.tableWrap}
                role="region"
                aria-label={`${text.challengesTitle}. ${text.tableScrollHint}`}
                aria-describedby="gamification-challenges-table-scroll-hint"
                tabIndex={0}
              >
                <table className={styles.table}>
                  <thead>
                    <tr>
                      <th scope="col">{text.challengeColumn}</th>
                      <th scope="col">{text.targetColumn}</th>
                      <th scope="col">{text.participantsColumn}</th>
                      <th scope="col">{text.completedColumn}</th>
                      <th scope="col">{text.completionColumn}</th>
                    </tr>
                  </thead>
                  <tbody>
                    {challenges.map((challenge) => {
                      const completionRate = calculateGamificationCompletionRate(
                        challenge.completedCount,
                        challenge.participantCount
                      );

                      return (
                        <tr key={challenge.id}>
                          <td>
                            <div className={styles.entityCell}>
                              <span className={styles.entityTitle}>
                                <span aria-hidden="true">{challenge.iconEmoji ?? "✦"}</span>
                                {challenge.titleKey}
                              </span>
                              <span className={styles.entityKey}>
                                {challenge.challengeType} ·{" "}
                                {formatDateTime(challenge.weekStartDate, locale, false)} ·{" "}
                                {text.versionLabel} {challenge.definitionVersion ?? 1}
                              </span>
                            </div>
                          </td>
                          <td className={styles.numeric}>
                            {formatNumber(challenge.targetValue, locale)}
                          </td>
                          <td className={styles.numeric}>
                            {formatNumber(challenge.participantCount, locale)}
                          </td>
                          <td className={styles.numeric}>
                            {formatNumber(challenge.completedCount, locale)}
                          </td>
                          <td>
                            <div className={styles.progressCell}>
                              <div className={styles.progressMeta}>
                                <span>
                                  {challenge.completedCount}/{challenge.participantCount}
                                </span>
                                <strong>{completionRate}%</strong>
                              </div>
                              <div
                                className={styles.progressTrack}
                                role="progressbar"
                                aria-label={`${text.completionColumn}: ${completionRate}%`}
                                aria-valuemin={0}
                                aria-valuemax={100}
                                aria-valuenow={completionRate}
                              >
                                <div
                                  className={styles.progressValue}
                                  style={{ width: `${completionRate}%` }}
                                />
                              </div>
                            </div>
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
              <p id="gamification-challenges-table-scroll-hint" className={styles.tableScrollHint}>
                <span aria-hidden="true">↔</span>
                {text.tableScrollHint}
              </p>
            </div>
          )}
        </section>

        <aside
          className={`${styles.panel} ${styles.diagnostics}`}
          aria-labelledby="gamification-diagnostics-title"
        >
          <header className={styles.panelHeader}>
            <div className={styles.panelTitleGroup}>
              <h2 id="gamification-diagnostics-title" className={styles.panelTitle}>
                {text.diagnosticsTitle}
              </h2>
              <p className={styles.panelDescription}>{text.diagnosticsDescription}</p>
            </div>
          </header>

          <form className={styles.lookupForm} onSubmit={handleUserLookup} noValidate>
            <label htmlFor="gamification-user-search" className={styles.fieldLabel}>
              {text.userIdLabel}
            </label>
            <div className={styles.lookupControls}>
              <input
                id="gamification-user-search"
                className={styles.input}
                type="search"
                inputMode="text"
                autoComplete="off"
                spellCheck={false}
                value={userSearchInput}
                placeholder={text.userIdPlaceholder}
                aria-invalid={Boolean(userIdError)}
                aria-describedby={userIdError ? "gamification-user-search-error" : undefined}
                onChange={(event) => {
                  setUserSearchInput(event.target.value.slice(0, 120));
                  if (userIdError) {
                    setUserIdError(null);
                  }
                }}
              />
              <Button type="submit" variant="primary" disabled={userSearchQuery.isFetching}>
                {userSearchQuery.isFetching ? text.searchingAction : text.searchAction}
              </Button>
            </div>
            {userIdError ? (
              <p id="gamification-user-search-error" className={styles.fieldError} role="alert">
                {userIdError}
              </p>
            ) : null}
          </form>

          {userSearchTerm ? (
            userSearchQuery.isPending ? (
              <div className={styles.lookupPlaceholder}>{text.searchingAction}</div>
            ) : userSearchQuery.isError ? (
              <AdminStateCard
                tone="danger"
                title={text.lookupError}
                action={
                  <Button
                    type="button"
                    variant="secondary"
                    disabled={userSearchQuery.isFetching}
                    onClick={() => void userSearchQuery.refetch()}
                  >
                    {text.retryAction}
                  </Button>
                }
              />
            ) : userSearchQuery.data?.items.length ? (
              <div className={styles.userSearchResults} aria-label={text.userIdLabel}>
                {userSearchQuery.data.items.map((user) => (
                  <div
                    key={user.userId}
                    className={styles.userSearchResult}
                    data-selected={user.userId === selectedUserId}
                  >
                    <button
                      type="button"
                      className={styles.userSearchSelect}
                      onClick={() => selectUser(user)}
                    >
                      <strong>{user.displayName?.trim() || user.email}</strong>
                      <span>{user.email}</span>
                    </button>
                    <AdminEntityLink
                      href={`/${locale}/users/${user.userId}`}
                      label={text.openUser360Action}
                      ariaLabel={`${text.openUser360Action}: ${user.displayName?.trim() || user.email}`}
                    />
                  </div>
                ))}
              </div>
            ) : (
              <div className={styles.lookupPlaceholder}>{text.noUsersFound}</div>
            )
          ) : null}

          {!selectedUserId ? (
            <div className={styles.lookupPlaceholder}>{text.lookupPrompt}</div>
          ) : userOverviewQuery.isPending ? (
            <AdminStateCard
              tone="info"
              title={text.loadingTitle}
              description={text.loadingDescription}
            />
          ) : userOverviewQuery.isError ? (
            <AdminStateCard
              tone="danger"
              title={text.errorTitle}
              description={getAdminErrorMessage(userOverviewQuery.error, text.lookupError)}
              action={
                <Button
                  type="button"
                  variant="secondary"
                  disabled={userOverviewQuery.isFetching}
                  onClick={() => void userOverviewQuery.refetch()}
                >
                  {text.retryAction}
                </Button>
              }
            />
          ) : userOverview ? (
            <div className={styles.userOverview}>
              <AdminEntityLink
                href={`/${locale}/users/${userOverview.userId}`}
                label={
                  selectedUser?.displayName?.trim() || selectedUser?.email || text.openUser360Action
                }
                secondaryLabel={userOverview.userId}
                ariaLabel={text.openUser360Action}
              />

              <div className={styles.summaryGrid}>
                <div className={styles.summaryItem}>
                  <span>{text.petsLabel}</span>
                  <strong>{formatNumber(userOverview.pets.length, locale)}</strong>
                </div>
                <div className={styles.summaryItem}>
                  <span>{text.userAchievementsLabel}</span>
                  <strong>
                    {formatNumber(
                      userOverview.achievements.filter((item) => item.isUnlocked).length,
                      locale
                    )}
                  </strong>
                </div>
                <div className={styles.summaryItem}>
                  <span>{text.userChallengesLabel}</span>
                  <strong>{formatNumber(userOverview.currentChallenges.length, locale)}</strong>
                </div>
              </div>

              <section className={styles.historyCard} aria-labelledby="gamification-history-title">
                <div className={styles.historyHeader}>
                  <div>
                    <h3 id="gamification-history-title">{text.historyTitle}</h3>
                    <p>{text.historyDescription}</p>
                  </div>
                </div>
                {userOverview.history?.length ? (
                  <ol className={styles.historyList}>
                    {userOverview.history.map((item) => (
                      <li key={item.eventId} className={styles.historyItem}>
                        <div className={styles.historyCopy}>
                          <strong>
                            {formatHistoryKind(item.kind, text)} · {item.label}
                          </strong>
                          <span>{formatDateTime(item.occurredAtUtc, locale)}</span>
                        </div>
                        <div className={styles.historyMeta}>
                          <span className={styles.badge}>
                            {formatHistoryStatus(item.status, text)}
                          </span>
                          {item.rewardSpark > 0 ? (
                            <span>
                              {item.rewardSpark} {text.sparkUnit}
                            </span>
                          ) : null}
                          <span>
                            {text.versionLabel} {item.definitionVersion}
                          </span>
                        </div>
                      </li>
                    ))}
                  </ol>
                ) : (
                  <p className={styles.lookupPlaceholder}>{text.noHistory}</p>
                )}
              </section>

              {userOverview.streak ? (
                <section className={styles.streakCard} aria-labelledby="user-streak-title">
                  <div className={styles.streakHeader}>
                    <h3 id="user-streak-title">{text.streakTitle}</h3>
                    <span className={styles.badge} data-tone="warning">
                      {userOverview.streak.currentStreak} {text.dayUnit}
                    </span>
                  </div>
                  <dl className={styles.streakGrid}>
                    <div className={styles.streakMetric}>
                      <dt>{text.currentStreakLabel}</dt>
                      <dd>{formatNumber(userOverview.streak.currentStreak, locale)}</dd>
                    </div>
                    <div className={styles.streakMetric}>
                      <dt>{text.longestStreakLabel}</dt>
                      <dd>{formatNumber(userOverview.streak.longestStreak, locale)}</dd>
                    </div>
                    <div className={styles.streakMetric}>
                      <dt>{text.freezesLabel}</dt>
                      <dd>{formatNumber(userOverview.streak.freezesAvailable, locale)}</dd>
                    </div>
                  </dl>
                  <p className={styles.streakMeta}>
                    {text.lastActiveLabel}:{" "}
                    {formatDateTime(userOverview.streak.lastActiveDate, locale, false)}
                  </p>
                  <div className={styles.reasonField}>
                    <label htmlFor="gamification-reset-reason" className={styles.fieldLabel}>
                      {text.reasonLabel}
                    </label>
                    <textarea
                      id="gamification-reset-reason"
                      className={styles.textarea}
                      value={resetReason}
                      maxLength={GAMIFICATION_RESET_REASON_MAX_LENGTH + 1}
                      disabled={resetStreakMutation.isPending}
                      placeholder={text.reasonPlaceholder}
                      aria-invalid={Boolean(reasonError)}
                      aria-describedby="gamification-reset-reason-meta"
                      onChange={(event) => setResetReason(event.target.value)}
                    />
                    <div id="gamification-reset-reason-meta" className={styles.reasonMeta}>
                      <span className={reasonError ? styles.fieldError : undefined}>
                        {reasonError ?? text.reasonHint}
                      </span>
                      <span
                        className={styles.reasonCounter}
                        data-invalid={resetReason.length > GAMIFICATION_RESET_REASON_MAX_LENGTH}
                      >
                        {resetReason.length}/{GAMIFICATION_RESET_REASON_MAX_LENGTH}
                      </span>
                    </div>
                  </div>
                  <Button
                    type="button"
                    variant="danger"
                    size="sm"
                    disabled={Boolean(resetReasonValidation.error) || resetStreakMutation.isPending}
                    onClick={openResetDialog}
                  >
                    {text.resetStreakAction}
                  </Button>
                </section>
              ) : (
                <div className={styles.emptyState}>
                  <strong>{text.noStreakLabel}</strong>
                  <p>{text.diagnosticsEmptyStreakDescription}</p>
                </div>
              )}
            </div>
          ) : null}
        </aside>

        <section
          className={`${styles.panel} ${styles.achievements}`}
          aria-labelledby="gamification-achievements-title"
        >
          <header className={styles.panelHeader}>
            <div className={styles.panelTitleGroup}>
              <h2 id="gamification-achievements-title" className={styles.panelTitle}>
                {text.achievementsTitle}
              </h2>
              <p className={styles.panelDescription}>{text.achievementsDescription}</p>
            </div>
            <span className={styles.countBadge} aria-label={text.achievementsTitle}>
              {formatNumber(achievements.length, locale)}
            </span>
          </header>

          {isAchievementsInitialLoading ? (
            <AdminStateCard
              tone="info"
              title={text.loadingTitle}
              description={text.loadingDescription}
            />
          ) : achievementsQuery.isError && !achievementsQuery.data ? (
            <AdminStateCard
              tone="danger"
              title={text.errorTitle}
              description={getAdminErrorMessage(achievementsQuery.error, text.errorDescription)}
              action={
                <Button
                  type="button"
                  variant="secondary"
                  disabled={achievementsQuery.isFetching}
                  onClick={() => void achievementsQuery.refetch()}
                >
                  {text.retryAction}
                </Button>
              }
            />
          ) : achievements.length === 0 ? (
            <div className={styles.emptyState}>
              <strong>{text.noAchievementsTitle}</strong>
              <p>{text.noAchievementsDescription}</p>
            </div>
          ) : (
            <div className={styles.tableContainer}>
              <div
                className={styles.tableWrap}
                role="region"
                aria-label={`${text.achievementsTitle}. ${text.tableScrollHint}`}
                aria-describedby="gamification-achievements-table-scroll-hint"
                tabIndex={0}
              >
                <table className={`${styles.table} ${styles.achievementTable}`}>
                  <thead>
                    <tr>
                      <th scope="col">{text.achievementColumn}</th>
                      <th scope="col">{text.categoryColumn}</th>
                      <th scope="col">{text.rarityColumn}</th>
                      <th scope="col">{text.requirementColumn}</th>
                      <th scope="col">{text.rewardColumn}</th>
                      <th scope="col">{text.unlockedColumn}</th>
                    </tr>
                  </thead>
                  <tbody>
                    {achievements.map((achievement) => (
                      <tr key={achievement.key}>
                        <td>
                          <div className={styles.entityCell}>
                            <span className={styles.entityTitle}>
                              <span aria-hidden="true">{achievement.iconEmoji ?? "✦"}</span>
                              {achievement.titleKey}
                            </span>
                            <span className={styles.entityKey}>
                              {achievement.key} · {text.versionLabel} {achievement.version ?? 1}
                            </span>
                          </div>
                        </td>
                        <td>
                          <span className={styles.badge}>{achievement.category}</span>
                        </td>
                        <td>
                          <div className={styles.badgeRow}>
                            <span className={styles.badge}>{achievement.rarity}</span>
                            {achievement.isSecret ? (
                              <span className={styles.badge} data-tone="warning">
                                {text.secretLabel}
                              </span>
                            ) : null}
                          </div>
                        </td>
                        <td>
                          <div className={styles.entityCell}>
                            <span className={styles.mono}>{achievement.requirementType}</span>
                            <span className={styles.numeric}>
                              {formatNumber(achievement.requirementValue, locale)}
                            </span>
                          </div>
                        </td>
                        <td className={styles.numeric}>
                          {formatNumber(achievement.rewardSpark, locale)} {text.sparkUnit}
                        </td>
                        <td className={styles.numeric}>
                          {formatNumber(achievement.unlockedUsersCount, locale)}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
              <p
                id="gamification-achievements-table-scroll-hint"
                className={styles.tableScrollHint}
              >
                <span aria-hidden="true">↔</span>
                {text.tableScrollHint}
              </p>
            </div>
          )}
        </section>
      </div>

      <ConfirmationDialog
        open={isResetDialogOpen}
        title={text.resetDialogTitle}
        description={text.resetDialogDescription}
        confirmLabel={text.confirmResetAction}
        cancelLabel={text.cancelAction}
        confirmDisabled={Boolean(resetReasonValidation.error)}
        isSubmitting={resetStreakMutation.isPending}
        tone="danger"
        onCancel={() => {
          if (!resetStreakMutation.isPending) {
            setIsResetDialogOpen(false);
          }
        }}
        onConfirm={confirmReset}
      >
        <p className={styles.dialogReason}>
          <strong>{text.dialogReasonLabel}:</strong> {resetReasonValidation.normalizedReason}
        </p>
      </ConfirmationDialog>
    </AdminPage>
  );
}
