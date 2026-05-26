import { type Dispatch, type ReactNode, type SetStateAction } from "react";

import {
  AdminCard,
  AdminMetricStrip,
  AdminStateCard,
  adminTableStyles,
} from "@/components/admin/admin-primitives";
import { type EconomyPageText } from "@/components/economy-page.content";
import {
  toSubscriptionPlanDraft,
  updateSubscriptionPlanDraft,
  type SubscriptionPlanDraft,
} from "@/components/economy-page.helpers";
import styles from "@/components/economy-page.module.css";
import { Button } from "@/components/ui/button";
import { type AdminSubscriptionPlan } from "@/lib/api-client";
import { type Locale } from "@/lib/i18n";

type EconomyPageSubscriptionPlansSectionProps = {
  locale: Locale;
  text: EconomyPageText;
  subscriptionPlans: AdminSubscriptionPlan[];
  planDrafts: Record<string, SubscriptionPlanDraft>;
  setPlanDrafts: Dispatch<SetStateAction<Record<string, SubscriptionPlanDraft>>>;
  savePlanPending: boolean;
  savePlanId?: string;
  onSavePlan: (planId: string) => void;
  humanizeBillingPeriod: (value: string, locale: Locale) => string;
};

function TableOrEmpty({
  hasItems,
  emptyTitle,
  children,
}: {
  hasItems: boolean;
  emptyTitle: string;
  children: ReactNode;
}) {
  if (!hasItems) {
    return <AdminStateCard tone="info" title={emptyTitle} />;
  }

  return <>{children}</>;
}

export function EconomyPageSubscriptionPlansSection({
  locale,
  text,
  subscriptionPlans,
  planDrafts,
  setPlanDrafts,
  savePlanPending,
  savePlanId,
  onSavePlan,
  humanizeBillingPeriod,
}: EconomyPageSubscriptionPlansSectionProps) {
  return (
    <AdminCard title={text.subscriptionPlansTitle} description={text.subscriptionPlansDescription}>
      <AdminMetricStrip
        items={subscriptionPlans.slice(0, 4).map((plan) => ({
          label: `${plan.name} • ${humanizeBillingPeriod(plan.billingPeriod, locale)}`,
          value: `${plan.monthlyTokenLimit} ${text.tokensShort}`,
        }))}
        className={styles.metricStrip}
      />

      <TableOrEmpty hasItems={subscriptionPlans.length > 0} emptyTitle={text.noSubscriptionPlans}>
        <div className={adminTableStyles.tableWrap}>
          <table className={adminTableStyles.table}>
            <thead>
              <tr>
                <th>{text.planColumn}</th>
                <th>{text.priceColumn}</th>
                <th>{text.billingColumn}</th>
                <th>{text.tokensColumn}</th>
                <th>{text.productIdsColumn}</th>
                <th>{text.statusColumn}</th>
                <th>{text.actionsColumn}</th>
              </tr>
            </thead>
            <tbody>
              {subscriptionPlans.map((plan) => {
                const draft = planDrafts[plan.planId] ?? toSubscriptionPlanDraft(plan);
                const isSavingPlan = savePlanPending && savePlanId === plan.planId;

                return (
                  <tr key={plan.planId}>
                    <td>
                      <div className={styles.packMeta}>
                        <strong>{plan.planId}</strong>
                        <span>{humanizeBillingPeriod(plan.billingPeriod, locale)}</span>
                      </div>
                      <input
                        value={draft.name}
                        onChange={(event) =>
                          updateSubscriptionPlanDraft(setPlanDrafts, plan.planId, {
                            name: event.target.value,
                          })
                        }
                        className={styles.input}
                      />
                    </td>
                    <td>
                      <div className={styles.windowFields}>
                        <input
                          value={draft.priceAmount}
                          onChange={(event) =>
                            updateSubscriptionPlanDraft(setPlanDrafts, plan.planId, {
                              priceAmount: event.target.value,
                            })
                          }
                          inputMode="decimal"
                          className={styles.input}
                        />
                        <input
                          value={draft.currencyCode}
                          onChange={(event) =>
                            updateSubscriptionPlanDraft(setPlanDrafts, plan.planId, {
                              currencyCode: event.target.value.toUpperCase(),
                            })
                          }
                          className={styles.input}
                          maxLength={3}
                        />
                      </div>
                    </td>
                    <td>
                      <div className={styles.windowFields}>
                        <span>{humanizeBillingPeriod(plan.billingPeriod, locale)}</span>
                        <label className={styles.field}>
                          <span>{text.sortColumn}</span>
                          <input
                            value={draft.displayOrder}
                            onChange={(event) =>
                              updateSubscriptionPlanDraft(setPlanDrafts, plan.planId, {
                                displayOrder: event.target.value,
                              })
                            }
                            inputMode="numeric"
                            className={styles.input}
                          />
                        </label>
                      </div>
                    </td>
                    <td>
                      <input
                        value={draft.monthlyTokenLimit}
                        onChange={(event) =>
                          updateSubscriptionPlanDraft(setPlanDrafts, plan.planId, {
                            monthlyTokenLimit: event.target.value,
                          })
                        }
                        inputMode="numeric"
                        className={styles.input}
                      />
                    </td>
                    <td>
                      <div className={styles.windowFields}>
                        <label className={styles.field}>
                          <span>{text.appleProductLabel}</span>
                          <input
                            value={draft.appleProductId}
                            onChange={(event) =>
                              updateSubscriptionPlanDraft(setPlanDrafts, plan.planId, {
                                appleProductId: event.target.value,
                              })
                            }
                            className={styles.input}
                          />
                        </label>
                        <label className={styles.field}>
                          <span>{text.googleProductLabel}</span>
                          <input
                            value={draft.googleProductId}
                            onChange={(event) =>
                              updateSubscriptionPlanDraft(setPlanDrafts, plan.planId, {
                                googleProductId: event.target.value,
                              })
                            }
                            className={styles.input}
                          />
                        </label>
                        <label className={styles.field}>
                          <span>{text.stripePriceLabel}</span>
                          <input
                            value={draft.stripePriceId}
                            onChange={(event) =>
                              updateSubscriptionPlanDraft(setPlanDrafts, plan.planId, {
                                stripePriceId: event.target.value,
                              })
                            }
                            className={styles.input}
                          />
                        </label>
                      </div>
                    </td>
                    <td>
                      <div className={styles.statusStack}>
                        <label className={styles.checkboxField}>
                          <input
                            type="checkbox"
                            checked={draft.isActive}
                            onChange={(event) =>
                              updateSubscriptionPlanDraft(setPlanDrafts, plan.planId, {
                                isActive: event.target.checked,
                              })
                            }
                          />
                          <span>{draft.isActive ? text.activeState : text.inactiveState}</span>
                        </label>
                        <label className={styles.checkboxField}>
                          <input
                            type="checkbox"
                            checked={draft.isRecommended}
                            onChange={(event) =>
                              updateSubscriptionPlanDraft(setPlanDrafts, plan.planId, {
                                isRecommended: event.target.checked,
                              })
                            }
                          />
                          <span>{text.recommendedState}</span>
                        </label>
                      </div>
                    </td>
                    <td>
                      <Button onClick={() => onSavePlan(plan.planId)} disabled={isSavingPlan}>
                        {isSavingPlan ? text.savingAction : text.saveAction}
                      </Button>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </TableOrEmpty>
    </AdminCard>
  );
}
