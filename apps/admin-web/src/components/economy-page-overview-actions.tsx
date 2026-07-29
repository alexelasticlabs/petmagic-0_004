"use client";

import { CancelCircleIcon, DollarIcon, RefreshIcon } from "@/components/admin/admin-icons";
import { AdminContextBar, AdminSummaryChips } from "@/components/admin/admin-primitives";
import { type EconomyPageText } from "@/components/economy-page.content";
import styles from "@/components/economy-page.module.css";
import { Button } from "@/components/ui/button";
import { type EconomyReconciliationRun } from "@/lib/api-client";
import { formatDateTime } from "@/lib/format-date-time";
import { type Locale } from "@/lib/i18n";

type EconomyPageOverviewActionsProps = {
  locale: Locale;
  text: EconomyPageText;
  isRefreshing: boolean;
  isReconciliationPending: boolean;
  lastReconciliation: EconomyReconciliationRun | null;
  onRefresh: () => void;
  onOpenIncidents: () => void;
  onOpenPaymentRoutes: () => void;
  onRunReconciliation: () => void;
};

export function EconomyPageOverviewActions({
  locale,
  text,
  isRefreshing,
  isReconciliationPending,
  lastReconciliation,
  onRefresh,
  onOpenIncidents,
  onOpenPaymentRoutes,
  onRunReconciliation,
}: EconomyPageOverviewActionsProps) {
  return (
    <div className={styles.overviewActionSurface}>
      <AdminContextBar
        label={text.quickActionsTitle}
        metaItems={
          lastReconciliation
            ? [
                `${text.reconciliationCompletedLabel}: ${formatDateTime(
                  lastReconciliation.completedAtUtc,
                  locale
                )}`,
              ]
            : []
        }
        actions={
          <div className={styles.overviewQuickActionList}>
            <Button
              type="button"
              variant="secondary"
              size="sm"
              className={styles.quickActionButton}
              disabled={isRefreshing}
              onClick={onRefresh}
            >
              <RefreshIcon className={styles.quickActionIcon} />
              <span>{isRefreshing ? text.refreshingAction : text.refreshAction}</span>
            </Button>
            <Button
              type="button"
              variant="secondary"
              size="sm"
              className={styles.quickActionButton}
              onClick={onOpenIncidents}
            >
              <CancelCircleIcon className={styles.quickActionIcon} />
              <span>{text.openIncidentsAction}</span>
            </Button>
            <Button
              type="button"
              variant="secondary"
              size="sm"
              className={styles.quickActionButton}
              onClick={onOpenPaymentRoutes}
            >
              <DollarIcon className={styles.quickActionIcon} />
              <span>{text.configurePaymentsAction}</span>
            </Button>
            <Button
              type="button"
              variant="primary"
              size="sm"
              className={styles.quickActionButton}
              disabled={isReconciliationPending}
              onClick={onRunReconciliation}
            >
              <RefreshIcon className={styles.quickActionIcon} />
              <span>
                {isReconciliationPending
                  ? text.reconciliationRunningAction
                  : text.runReconciliationAction}
              </span>
            </Button>
          </div>
        }
      />
      {lastReconciliation ? (
        <AdminSummaryChips
          className={styles.reconciliationSummary}
          items={[
            `${text.reconciliationChecksLabel}: ${lastReconciliation.checksRun}`,
            `${text.reconciliationAutoFixesLabel}: ${lastReconciliation.autoFixesApplied}`,
            `${text.reconciliationIncidentsLabel}: ${lastReconciliation.incidentsCreated}`,
            `${text.reconciliationUpdatedLabel}: ${lastReconciliation.incidentsUpdated}`,
            `${text.reconciliationResolvedLabel}: ${lastReconciliation.incidentsResolved}`,
            `${text.reconciliationReviewLabel}: ${lastReconciliation.manualReviewRequired}`,
          ]}
        />
      ) : null}
    </div>
  );
}
