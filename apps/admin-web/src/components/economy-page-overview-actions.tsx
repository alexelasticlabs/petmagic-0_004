"use client";

import { CancelCircleIcon, DollarIcon, RefreshIcon } from "@/components/admin/admin-icons";
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
    <section className={styles.overviewQuickActions} aria-labelledby="economy-quick-actions-title">
      <div className={styles.overviewQuickActionsCopy}>
        <h3 id="economy-quick-actions-title">{text.quickActionsTitle}</h3>
        {lastReconciliation ? (
          <p>
            {text.reconciliationCompletedLabel}:{" "}
            {formatDateTime(lastReconciliation.completedAtUtc, locale)}
          </p>
        ) : null}
      </div>
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
      {lastReconciliation ? (
        <dl className={styles.reconciliationResult} aria-live="polite">
          <div>
            <dt>{text.reconciliationChecksLabel}</dt>
            <dd>{lastReconciliation.checksRun}</dd>
          </div>
          <div>
            <dt>{text.reconciliationAutoFixesLabel}</dt>
            <dd>{lastReconciliation.autoFixesApplied}</dd>
          </div>
          <div>
            <dt>{text.reconciliationIncidentsLabel}</dt>
            <dd>{lastReconciliation.incidentsCreated}</dd>
          </div>
          <div>
            <dt>{text.reconciliationUpdatedLabel}</dt>
            <dd>{lastReconciliation.incidentsUpdated}</dd>
          </div>
          <div>
            <dt>{text.reconciliationResolvedLabel}</dt>
            <dd>{lastReconciliation.incidentsResolved}</dd>
          </div>
          <div>
            <dt>{text.reconciliationReviewLabel}</dt>
            <dd>{lastReconciliation.manualReviewRequired}</dd>
          </div>
        </dl>
      ) : null}
    </section>
  );
}
