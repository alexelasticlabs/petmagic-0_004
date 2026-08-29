"use client";

import { AdminStateCard } from "@/components/admin/admin-primitives";
import { Button } from "@/components/ui/button";
import { Select } from "@/components/ui/select";
import type { UsersManagementPageText } from "@/components/users-management-page.content";
import styles from "@/components/users-management-page.module.css";
import type { RangeDays } from "@/components/users-management-page.types";

type UsersManagementAccessStateProps = {
  ui: UsersManagementPageText;
};

export function UsersManagementAccessState({ ui }: UsersManagementAccessStateProps) {
  return (
    <AdminStateCard
      tone="info"
      title={ui.accessRestrictedTitle}
      description={ui.accessRestrictedDescription}
    />
  );
}

type UsersManagementLoadingStateProps = {
  ui: UsersManagementPageText;
};

export function UsersManagementLoadingState({ ui }: UsersManagementLoadingStateProps) {
  return (
    <AdminStateCard tone="info" title={ui.loadingTitle} description={ui.loadingDescription}>
      <div className={styles.skeletonStack} aria-busy="true" aria-live="polite">
        {Array.from({ length: 8 }).map((_, index) => (
          <div key={index} className={styles.skeletonLine} />
        ))}
      </div>
    </AdminStateCard>
  );
}

type UsersManagementSummaryGridProps = {
  blockedUsersValue: string;
  newUsersValue: string;
  premiumUsersValue: string;
  rangeDays: RangeDays;
  setRangeDays: (value: RangeDays) => void;
  totalUsersValue: string;
  activeUsersValue: string;
  applyQuickFilter: (filter: "all" | "active" | "premium" | "attention" | "new") => void;
  isMetricsError: boolean;
  isMetricsFetching: boolean;
  refreshMetrics: () => Promise<void>;
  ui: UsersManagementPageText;
};

export function UsersManagementSummaryGrid({
  blockedUsersValue,
  newUsersValue,
  premiumUsersValue,
  rangeDays,
  setRangeDays,
  totalUsersValue,
  activeUsersValue,
  applyQuickFilter,
  isMetricsError,
  isMetricsFetching,
  refreshMetrics,
  ui,
}: UsersManagementSummaryGridProps) {
  const periodLabel = rangeDays === 7 ? ui.period7 : rangeDays === 90 ? ui.period90 : ui.period30;

  const items = [
    ["all", ui.summaryTotal, totalUsersValue],
    ["active", ui.summaryActive, activeUsersValue],
    ["premium", ui.summaryPremium, premiumUsersValue],
    ["attention", ui.summaryAttention, blockedUsersValue],
    ["new", ui.summaryNewForPeriod.replace("{period}", ui.period7), newUsersValue],
  ] as const;
  return (
    <div className={styles.summarySection}>
      <div className={styles.summaryHeader}>
        <span className={styles.summaryTitle}>{ui.summaryTitle}</span>
        <div className={styles.summaryPeriodControl}>
          <span>{ui.periodLabel}</span>
          <div className={styles.summaryPeriodSelect}>
            <Select
              value={String(rangeDays)}
              ariaLabel={ui.periodLabel}
              showSelectedDescription={false}
              options={[
                { value: "7", label: ui.period7 },
                { value: "30", label: ui.period30 },
                { value: "90", label: ui.period90 },
              ]}
              onChange={(value) => setRangeDays(Number.parseInt(value, 10) as RangeDays)}
            />
          </div>
        </div>
      </div>
      <div className={styles.summaryGrid} aria-label={ui.summaryTitle}>
        {items.map(([filter, label, value]) => (
          <button key={filter} type="button" onClick={() => applyQuickFilter(filter)}>
            <span>{label}</span>
            <strong>{value}</strong>
          </button>
        ))}
      </div>
      {isMetricsError ? (
        <AdminStateCard
          tone="warning"
          className={styles.summaryError}
          title={ui.summaryUnavailable}
          action={
            <Button
              variant="secondary"
              size="sm"
              disabled={isMetricsFetching}
              onClick={() => void refreshMetrics().catch(() => undefined)}
            >
              {ui.summaryRetry}
            </Button>
          }
        />
      ) : null}
    </div>
  );
}
