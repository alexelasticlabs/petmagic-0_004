"use client";

import {
  CalendarIcon,
  PromoCodeIcon,
  TrendUpIcon,
  UsersIcon,
} from "@/components/admin/admin-icons";
import { AdminKpiCard, AdminPage, AdminStateCard } from "@/components/admin/admin-primitives";
import { ConfirmationDialog } from "@/components/admin/confirmation-dialog";
import styles from "@/components/promo-codes-view.module.css";
import { Button } from "@/components/ui/button";
import { formatNumber, formatPromoDisplayText } from "@/components/promo-codes-view.helpers";
import type { PromoCodesViewText } from "@/components/promo-codes-view.content";
import { getAdminErrorMessage } from "@/lib/admin-error-message";
import type { AdminRedeemCode } from "@/lib/api-client";
import type { Locale } from "@/lib/i18n";

type PromoCodesChromeFeedback = {
  tone: "success" | "danger" | "info";
  message: string;
};

type PromoCodesMetrics = {
  totalCodes: number;
  activeCodes: number;
  totalUses: number;
  totalGranted: number;
  createdLast7d: number;
  activeTouchedLast7d: number;
  usesLast7d: number;
  grantedLast7d: number;
};

type PromoCodesLoadingStateProps = {
  title: string;
  description: string;
};

export function PromoCodesLoadingState({ title, description }: PromoCodesLoadingStateProps) {
  return (
    <AdminPage className={styles.page}>
      <AdminStateCard tone="info" title={title} description={description} />
    </AdminPage>
  );
}

type PromoCodesErrorStateProps = {
  title: string;
  description: string;
  refreshLabel: string;
  disabled: boolean;
  onRefresh: () => void;
};

export function PromoCodesErrorState({
  title,
  description,
  refreshLabel,
  disabled,
  onRefresh,
}: PromoCodesErrorStateProps) {
  return (
    <AdminPage className={styles.page}>
      <AdminStateCard
        tone="danger"
        title={title}
        description={description}
        action={
          <Button variant="secondary" disabled={disabled} onClick={onRefresh}>
            {refreshLabel}
          </Button>
        }
      />
    </AdminPage>
  );
}

type PromoCodesViewChromeProps = {
  feedback: PromoCodesChromeFeedback | null;
  locale: Locale;
  metrics: PromoCodesMetrics;
  promoText: PromoCodesViewText;
  title: string;
  subtitle: string;
  tokenUnit: string;
  metricsError: unknown;
  canManagePromoCodes: boolean;
  isPromoRefreshFetching: boolean;
  refreshLabel: string;
  metricsErrorTitle: string;
  lastSevenDaysLabel: string;
  onRefreshMetrics: () => void;
};

export function PromoCodesViewChrome({
  feedback,
  locale,
  metrics,
  promoText,
  title,
  subtitle,
  tokenUnit,
  metricsError,
  canManagePromoCodes,
  isPromoRefreshFetching,
  refreshLabel,
  metricsErrorTitle,
  lastSevenDaysLabel,
  onRefreshMetrics,
}: PromoCodesViewChromeProps) {
  const formatSevenDayDeltaValue = (value: number) => {
    const sign = value > 0 ? "+" : "";
    return `${sign}${formatNumber(value, locale)} ${lastSevenDaysLabel}`;
  };

  return (
    <>
      {feedback ? (
        <div
          className={`${styles.feedback} ${feedback.tone === "success" ? styles.feedbackSuccess : feedback.tone === "danger" ? styles.feedbackDanger : styles.feedbackInfo}`}
        >
          {feedback.message}
        </div>
      ) : null}

      <header className={styles.pageHeader}>
        <h1 className={styles.pageTitle}>{title}</h1>
        <p className={styles.pageSubtitle}>{subtitle}</p>
      </header>

      {metricsError ? (
        <AdminStateCard
          tone="warning"
          title={metricsErrorTitle}
          description={getAdminErrorMessage(metricsError, metricsErrorTitle)}
          action={
            <Button
              variant="secondary"
              disabled={!canManagePromoCodes || isPromoRefreshFetching}
              onClick={onRefreshMetrics}
            >
              {refreshLabel}
            </Button>
          }
        />
      ) : null}

      <div className={styles.kpiGrid}>
        <AdminKpiCard
          label={promoText.kpiCodesLabel}
          value={formatNumber(metrics.totalCodes, locale)}
          delta={formatSevenDayDeltaValue(metrics.createdLast7d)}
          hint={promoText.kpiFilteredListHint}
          tone="primary"
          icon={<PromoCodeIcon className={styles.kpiIcon} />}
        />
        <AdminKpiCard
          label={promoText.kpiActiveLabel}
          value={formatNumber(metrics.activeCodes, locale)}
          delta={formatSevenDayDeltaValue(metrics.activeTouchedLast7d)}
          hint={promoText.kpiFilteredListHint}
          tone="success"
          icon={<TrendUpIcon className={styles.kpiIcon} />}
        />
        <AdminKpiCard
          label={promoText.kpiUsesLabel}
          value={formatNumber(metrics.totalUses, locale)}
          delta={formatSevenDayDeltaValue(metrics.usesLast7d)}
          hint={promoText.kpiUsesHint}
          tone="info"
          icon={<UsersIcon className={styles.kpiIcon} />}
        />
        <AdminKpiCard
          label={promoText.kpiGrantedLabel}
          value={`${formatNumber(metrics.totalGranted, locale)} ${tokenUnit}`}
          delta={`${formatNumber(metrics.grantedLast7d, locale)} ${tokenUnit} ${lastSevenDaysLabel}`}
          hint={promoText.kpiGrantedHint}
          tone="warning"
          icon={<CalendarIcon className={styles.kpiIcon} />}
        />
      </div>
    </>
  );
}

type PromoCodesArchiveDialogProps = {
  archiveActionLabel: string;
  cancelLabel: string;
  archiveConfirmText: string;
  codePendingArchive: AdminRedeemCode | null;
  busyCodeId: string | null;
  isMutating: boolean;
  onCancel: () => void;
  onConfirm: () => void;
};

export function PromoCodesArchiveDialog({
  archiveActionLabel,
  cancelLabel,
  archiveConfirmText,
  codePendingArchive,
  busyCodeId,
  isMutating,
  onCancel,
  onConfirm,
}: PromoCodesArchiveDialogProps) {
  return (
    <ConfirmationDialog
      open={codePendingArchive !== null}
      title={archiveActionLabel}
      description={
        codePendingArchive
          ? `${formatPromoDisplayText(
              codePendingArchive.code || `${codePendingArchive.codePrefix}...`,
              80
            )}: ${archiveConfirmText}`
          : ""
      }
      confirmLabel={archiveActionLabel}
      cancelLabel={cancelLabel}
      isSubmitting={Boolean(codePendingArchive && busyCodeId === codePendingArchive.redeemCodeId)}
      onCancel={() => {
        if (!isMutating) {
          onCancel();
        }
      }}
      onConfirm={onConfirm}
    />
  );
}
