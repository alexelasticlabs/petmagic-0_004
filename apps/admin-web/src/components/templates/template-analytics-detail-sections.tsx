"use client";

import { ChartIcon, TableIcon } from "@/components/admin/admin-icons";
import styles from "@/components/templates/template-analytics-page.module.css";
import {
  formatAnalyticsValue,
  formatDateTime,
  formatFailureCode,
  formatJobStatus,
  formatModelSummary,
  formatRangeDuration,
  formatTokens,
  getJobStatusClassName,
  shortenId,
} from "@/components/templates/template-analytics-utils";
import {
  TEMPLATE_FEEDBACK_SEARCH_MAX_LENGTH,
  type AdminTemplateFailureBreakdownItem,
  type AdminTemplateFeedbackItem,
  type AdminTemplateRecentGeneration,
} from "@/lib/api-client";
import type { Locale } from "@/lib/i18n";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

type RecentRunsMode = "latest" | "all" | "failed";
type FeedbackFilterKey = "all" | "complaint" | "feedback";

type RecentRunsText = {
  recentRunsTitle: string;
  recentRunsAllHint: string;
  failedRunsHint: string;
  recentRunsHint: string;
  recentRunsLatest: string;
  recentRunsLoading: string;
  recentRunsAll: string;
  recentRunsFailed: string;
  generationIdHeader: string;
  userHeader: string;
  recentCreated: string;
  recentStatus: string;
  recentTokens: string;
  recentDuration: string;
  recentModels: string;
  recentOutput: string;
  failureCodeHeader: string;
  failureReasonHeader: string;
  openOutput: string;
  outputAvailable: string;
  noOutput: string;
  failedRunsEmpty: string;
  recentRunsEmpty: string;
  recentRunsExpandError: string;
  unknownFailure: string;
};

type FailureBreakdownText = {
  failureBreakdownTitle: string;
  failureBreakdownHint: string;
  failuresEmpty: string;
  lastFailure: string;
  unknownFailure: string;
};

type FeedbackText = {
  feedbackTitle: string;
  feedbackHint: string;
  feedbackFilterLabel: string;
  feedbackSearchPlaceholder: string;
  feedbackSearchLabel: string;
  feedbackLoading: string;
  feedbackFilteredEmpty: string;
  feedbackEmpty: string;
  feedbackTypeComplaint: string;
  feedbackTypeFeedback: string;
  feedbackMessageMissing: string;
  feedbackSourceLabel: string;
  feedbackDeviceLabel: string;
  feedbackCountryLabel: string;
  userHeader: string;
  generationIdHeader: string;
};

export function TemplateAnalyticsRecentRunsSection({
  canLoadRecentRuns,
  canShowFailedRecentRuns,
  canShowRecentRunModes,
  error,
  isLoading,
  items,
  locale,
  mode,
  onModeChange,
  text,
}: {
  canLoadRecentRuns: boolean;
  canShowFailedRecentRuns: boolean;
  canShowRecentRunModes: boolean;
  error: string | null;
  isLoading: boolean;
  items: readonly AdminTemplateRecentGeneration[];
  locale: Locale;
  mode: RecentRunsMode;
  onModeChange: (mode: RecentRunsMode) => void;
  text: RecentRunsText;
}) {
  return (
    <section className={`${styles.sectionCard} ${styles.sectionCardWide}`}>
      <div className={styles.sectionHeaderRow}>
        <div className={styles.sectionHeader}>
          <h2 className={styles.sectionTitleWithIcon}>
            <TableIcon className={styles.sectionTitleIcon} />
            <span>{text.recentRunsTitle}</span>
          </h2>
          <p>
            {mode === "all"
              ? text.recentRunsAllHint
              : mode === "failed"
                ? text.failedRunsHint
                : text.recentRunsHint}
          </p>
        </div>

        {canShowRecentRunModes ? (
          <div className={styles.chartTabs} aria-label={text.recentRunsTitle}>
            <button
              type="button"
              className={mode === "latest" ? styles.chartTabActive : styles.chartTab}
              onClick={() => onModeChange("latest")}
              disabled={mode === "latest" || isLoading || !canLoadRecentRuns}
            >
              <span>{text.recentRunsLatest}</span>
            </button>
            <button
              type="button"
              className={mode === "all" ? styles.chartTabActive : styles.chartTab}
              onClick={() => onModeChange("all")}
              disabled={mode === "all" || isLoading || !canLoadRecentRuns}
            >
              <span>{isLoading ? text.recentRunsLoading : text.recentRunsAll}</span>
            </button>
            {canShowFailedRecentRuns ? (
              <button
                type="button"
                className={mode === "failed" ? styles.chartTabActive : styles.chartTab}
                onClick={() => onModeChange("failed")}
                disabled={mode === "failed" || isLoading || !canLoadRecentRuns}
              >
                <span>{text.recentRunsFailed}</span>
              </button>
            ) : null}
          </div>
        ) : null}
      </div>
      {error ? <p className={styles.emptyState}>{error}</p> : null}
      <RecentRunsTable locale={locale} items={items} text={text} mode={mode} />
    </section>
  );
}

export function TemplateAnalyticsFailureBreakdownSection({
  items,
  locale,
  text,
}: {
  items: readonly AdminTemplateFailureBreakdownItem[];
  locale: Locale;
  text: FailureBreakdownText;
}) {
  return (
    <section className={styles.sectionCard}>
      <div className={styles.sectionHeader}>
        <h2 className={styles.sectionTitleWithIcon}>
          <ChartIcon className={styles.sectionTitleIcon} />
          <span>{text.failureBreakdownTitle}</span>
        </h2>
        <p>{text.failureBreakdownHint}</p>
      </div>
      <FailureBreakdownList locale={locale} items={items} text={text} />
    </section>
  );
}

export function TemplateAnalyticsFeedbackSection({
  error,
  feedbackFilter,
  feedbackOptions,
  feedbackSearch,
  isLoading,
  items,
  locale,
  onFeedbackFilterChange,
  onFeedbackSearchChange,
  text,
}: {
  error: string | null;
  feedbackFilter: FeedbackFilterKey;
  feedbackOptions: Array<{ key: FeedbackFilterKey; label: string }>;
  feedbackSearch: string;
  isLoading: boolean;
  items: readonly AdminTemplateFeedbackItem[];
  locale: Locale;
  onFeedbackFilterChange: (value: FeedbackFilterKey) => void;
  onFeedbackSearchChange: (value: string) => void;
  text: FeedbackText;
}) {
  const hasActiveFilter = feedbackFilter !== "all" || feedbackSearch.trim().length > 0;

  return (
    <section className={styles.sectionCard}>
      <div className={styles.sectionHeaderRow}>
        <div className={styles.sectionHeader}>
          <h2 className={styles.sectionTitleWithIcon}>
            <ChartIcon className={styles.sectionTitleIcon} />
            <span>{text.feedbackTitle}</span>
          </h2>
          <p>{text.feedbackHint}</p>
        </div>
        <div className={styles.feedbackToolbar}>
          <div className={styles.chartTabs} aria-label={text.feedbackFilterLabel}>
            {feedbackOptions.map((option) => (
              <button
                key={option.key}
                type="button"
                className={feedbackFilter === option.key ? styles.chartTabActive : styles.chartTab}
                onClick={() => onFeedbackFilterChange(option.key)}
              >
                <span>{option.label}</span>
              </button>
            ))}
          </div>
          <input
            type="search"
            value={feedbackSearch}
            onChange={(event) =>
              onFeedbackSearchChange(
                event.target.value.slice(0, TEMPLATE_FEEDBACK_SEARCH_MAX_LENGTH)
              )
            }
            maxLength={TEMPLATE_FEEDBACK_SEARCH_MAX_LENGTH}
            className={styles.feedbackSearchInput}
            placeholder={text.feedbackSearchPlaceholder}
            aria-label={text.feedbackSearchLabel}
          />
        </div>
      </div>
      {error ? <p className={styles.emptyState}>{error}</p> : null}
      <FeedbackList
        locale={locale}
        items={items}
        text={text}
        isLoading={isLoading}
        hasActiveFilter={hasActiveFilter}
      />
    </section>
  );
}

function RecentRunsTable({
  locale,
  items,
  text,
  mode,
}: {
  locale: Locale;
  items: readonly AdminTemplateRecentGeneration[];
  text: RecentRunsText;
  mode: RecentRunsMode;
}) {
  const isRu = locale === "ru";
  const hasFailureDetails = items.some(
    (item) => item.status === "Failed" || Boolean(item.failureCode)
  );

  if (!items.length) {
    return (
      <p className={styles.emptyState}>
        {mode === "failed" ? text.failedRunsEmpty : text.recentRunsEmpty}
      </p>
    );
  }

  return (
    <div className={styles.tableWrap}>
      <table className={styles.recentTable}>
        <thead>
          <tr>
            <th>{text.generationIdHeader}</th>
            <th>{text.userHeader}</th>
            <th>{text.recentCreated}</th>
            <th>{text.recentStatus}</th>
            <th>{text.recentTokens}</th>
            <th>{text.recentDuration}</th>
            <th>{text.recentModels}</th>
            {hasFailureDetails ? <th>{text.failureCodeHeader}</th> : null}
            <th>{text.recentOutput}</th>
          </tr>
        </thead>
        <tbody>
          {items.map((item) => (
            <tr key={item.generationId}>
              <td>
                <span className={styles.monoCell}>{shortenId(item.generationId)}</span>
              </td>
              <td>
                <span className={styles.monoCell}>{shortenId(item.userId)}</span>
              </td>
              <td>{formatDateTime(item.createdAtUtc, locale)}</td>
              <td>
                <span
                  className={`${styles.statusChip} ${styles[getJobStatusClassName(item.status)]}`}
                >
                  {formatJobStatus(item.status, isRu)}
                </span>
              </td>
              <td>{formatTokens(item.tokenCost, isRu)}</td>
              <td>{formatRangeDuration(item.startedAtUtc, item.completedAtUtc, isRu)}</td>
              <td>{formatModelSummary(item.usedPreprocessingModel, item.usedKlingModel)}</td>
              {hasFailureDetails ? (
                <td>
                  {item.failureCode ? (
                    <span className={styles.failureCodeCell}>
                      {formatFailureCode(item.failureCode, text.unknownFailure)}
                    </span>
                  ) : (
                    <span className={styles.mutedCell}>-</span>
                  )}
                </td>
              ) : null}
              <td>
                {item.outputUrl ? (
                  <span className={styles.mutedCell}>{text.outputAvailable}</span>
                ) : (
                  <span className={styles.mutedCell}>{text.noOutput}</span>
                )}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function FailureBreakdownList({
  locale,
  items,
  text,
}: {
  locale: Locale;
  items: readonly AdminTemplateFailureBreakdownItem[];
  text: FailureBreakdownText;
}) {
  if (!items.length) {
    return <p className={styles.emptyState}>{text.failuresEmpty}</p>;
  }

  return (
    <div className={styles.failureList}>
      {items.map((item) => (
        <div key={item.failureCode} className={styles.failureItem}>
          <strong>{formatFailureCode(item.failureCode, text.unknownFailure)}</strong>
          <span>{item.count}</span>
          <p>
            {text.lastFailure}: {formatDateTime(item.lastOccurredAtUtc, locale)}
          </p>
        </div>
      ))}
    </div>
  );
}

function FeedbackList({
  locale,
  items,
  text,
  isLoading,
  hasActiveFilter,
}: {
  locale: Locale;
  items: readonly AdminTemplateFeedbackItem[];
  text: FeedbackText;
  isLoading: boolean;
  hasActiveFilter: boolean;
}) {
  if (isLoading) {
    return <p className={styles.emptyState}>{text.feedbackLoading}</p>;
  }

  if (!items.length) {
    return (
      <p className={styles.emptyState}>
        {hasActiveFilter ? text.feedbackFilteredEmpty : text.feedbackEmpty}
      </p>
    );
  }

  const isRu = locale === "ru";

  return (
    <div className={styles.feedbackList}>
      {items.map((item) => (
        <article key={item.eventId} className={styles.feedbackItem}>
          <div className={styles.feedbackHeader}>
            <span
              className={`${styles.statusChip} ${styles[item.eventType === "complaint" ? "statusChip_danger" : "statusChip_info"]}`}
            >
              {item.eventType === "complaint"
                ? text.feedbackTypeComplaint
                : text.feedbackTypeFeedback}
            </span>
            <strong>{formatDateTime(item.createdAtUtc, locale)}</strong>
          </div>
          <p className={styles.feedbackMessage}>
            {item.feedbackMessage?.trim()
              ? sanitizeSensitiveText(item.feedbackMessage, 240)
              : text.feedbackMessageMissing}
          </p>
          <div className={styles.feedbackMeta}>
            <span>
              {text.feedbackSourceLabel}: {formatAnalyticsValue(item.source)}
            </span>
            <span>
              {text.feedbackDeviceLabel}: {formatAnalyticsValue(item.deviceClass)}
            </span>
            <span>
              {text.feedbackCountryLabel}: {formatAnalyticsValue(item.countryCode)}
            </span>
            <span>
              {text.userHeader}: {item.userId ? shortenId(item.userId) : isRu ? "анон" : "guest"}
            </span>
            {item.generationId ? (
              <span>
                {text.generationIdHeader}: {shortenId(item.generationId)}
              </span>
            ) : null}
          </div>
        </article>
      ))}
    </div>
  );
}
