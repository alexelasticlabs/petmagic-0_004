"use client";

import { AdminCard, AdminStatusBadge } from "@/components/admin/admin-primitives";
import {
  formatDateTime,
  formatPromoDisplayText,
  formatRewardValue,
  getUserLabels,
} from "@/components/promo-codes-view.helpers";
import styles from "@/components/promo-codes-view.module.css";
import { Button } from "@/components/ui/button";
import {
  type AdminRedeemCode,
  type AdminRedeemCodeRedemption,
  type AdminUserDetail,
} from "@/lib/api-client";
import { getDictionary, type Locale } from "@/lib/i18n";

type PromoCodeActivationsCardProps = {
  text: ReturnType<typeof getDictionary>;
  locale: Locale;
  selectedCode: AdminRedeemCode | null;
  selectedStatusLabel?: string;
  activationsIsLoading: boolean;
  activationsIsError: boolean;
  activationsIsFetching: boolean;
  redemptionsForView: AdminRedeemCodeRedemption[];
  selectedUsersById: Map<string, AdminUserDetail>;
  hasAnyRedemptions: boolean;
  showAllActivations: boolean;
  canExpandActivations: boolean;
  canGoToPreviousActivationsPage: boolean;
  canGoToNextActivationsPage: boolean;
  onRefetchActivations: () => Promise<unknown>;
  onShowAllActivations: () => void;
  onPreviousActivationsPage: () => void;
  onNextActivationsPage: () => void;
  onShowLatestActivations: () => void;
};

export function PromoCodeActivationsCard({
  text,
  locale,
  selectedCode,
  selectedStatusLabel,
  activationsIsLoading,
  activationsIsError,
  activationsIsFetching,
  redemptionsForView,
  selectedUsersById,
  hasAnyRedemptions,
  showAllActivations,
  canExpandActivations,
  canGoToPreviousActivationsPage,
  canGoToNextActivationsPage,
  onRefetchActivations,
  onShowAllActivations,
  onPreviousActivationsPage,
  onNextActivationsPage,
  onShowLatestActivations,
}: PromoCodeActivationsCardProps) {
  return (
    <AdminCard
      title={text.promoCodesRecentUsageTitle}
      description={
        selectedCode
          ? `${formatPromoDisplayText(selectedCode.code || `${selectedCode.codePrefix}...`, 80)} · ${selectedStatusLabel ?? ""}`
          : text.promoCodesNoCodeSelectedDescription
      }
      className={styles.usageCard}
    >
      {!selectedCode ? (
        <div className={styles.usageEmpty}>
          <strong>{text.promoCodesNoCodeSelectedTitle}</strong>
          <span>{text.promoCodesNoCodeSelectedDescription}</span>
        </div>
      ) : activationsIsLoading ? (
        <div className={styles.usageEmpty}>
          <strong>{text.promoCodesRecentUsageTitle}</strong>
          <span>{text.promoCodesActivationsLoading}</span>
        </div>
      ) : !hasAnyRedemptions ? (
        <div className={styles.usageEmpty}>
          <strong>{text.promoCodesRecentUsageTitle}</strong>
          <span>{text.promoCodesRecentUsageEmpty}</span>
        </div>
      ) : activationsIsError ? (
        <div className={styles.usageWarning}>
          <span>{text.promoCodesActivationsError}</span>
          <Button
            variant="secondary"
            size="sm"
            disabled={activationsIsFetching}
            onClick={() => void onRefetchActivations()}
          >
            {text.promoCodesRefreshAction}
          </Button>
        </div>
      ) : (
        <>
          <div className={styles.usageTableWrap}>
            <table className={styles.usageTable}>
              <thead>
                <tr>
                  <th>{text.promoCodesActivationUserColumn}</th>
                  <th>{text.promoCodesActivationDateColumn}</th>
                  <th>{text.promoCodesActivationRewardColumn}</th>
                  <th>{text.promoCodesActivationStatusColumn}</th>
                </tr>
              </thead>
              <tbody>
                {redemptionsForView.map((redemption) => {
                  const labels = getUserLabels(
                    redemption.userId,
                    selectedUsersById.get(redemption.userId)
                  );

                  return (
                    <tr key={redemption.redemptionId}>
                      <td>
                        <div className={styles.codeCell}>
                          <strong>{labels.primary}</strong>
                          <span className={styles.codeMeta}>{labels.secondary}</span>
                        </div>
                      </td>
                      <td>{formatDateTime(redemption.redeemedAtUtc, locale)}</td>
                      <td>
                        {formatRewardValue(redemption.rewardValue, redemption.rewardKind, text)}
                      </td>
                      <td>
                        <AdminStatusBadge color="var(--success)">
                          {text.promoCodesActivationStatusSuccess}
                        </AdminStatusBadge>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>

          <div className={styles.usageActions}>
            {canExpandActivations ? (
              <Button variant="secondary" size="sm" onClick={onShowAllActivations}>
                {text.promoCodesViewAllActivationsAction}
              </Button>
            ) : null}

            {showAllActivations ? (
              <>
                <Button
                  variant="secondary"
                  size="sm"
                  onClick={onPreviousActivationsPage}
                  disabled={!canGoToPreviousActivationsPage || activationsIsFetching}
                >
                  {text.promoCodesPreviousAction}
                </Button>
                <Button
                  variant="secondary"
                  size="sm"
                  onClick={onNextActivationsPage}
                  disabled={!canGoToNextActivationsPage || activationsIsFetching}
                >
                  {text.promoCodesNextAction}
                </Button>
              </>
            ) : null}

            {showAllActivations ? (
              <Button variant="ghost" size="sm" onClick={onShowLatestActivations}>
                {text.promoCodesShowLatestActivationsAction}
              </Button>
            ) : null}
          </div>
        </>
      )}
    </AdminCard>
  );
}
