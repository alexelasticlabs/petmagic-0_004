import { type Dispatch, type SetStateAction, useState } from "react";

import { AdminCard, AdminMetricStrip } from "@/components/admin/admin-primitives";
import { type EconomyPageText } from "@/components/economy-page.content";
import {
  ECONOMY_PACK_INTEGER_MAX_LENGTH,
  ECONOMY_PACK_PRICE_MAX_LENGTH,
  ECONOMY_PLAN_NAME_MAX_LENGTH,
  ECONOMY_PLAN_PRODUCT_ID_MAX_LENGTH,
  isSubscriptionPlanDraftDirty,
  isSubscriptionPlanDraftInvalid,
  normalizeEconomyCurrencyInput,
  normalizeEconomyIntegerInput,
  normalizeEconomyPlanNameInput,
  normalizeEconomyPlanProductIdInput,
  normalizeEconomyPriceInput,
  toSubscriptionPlanDraft,
  updateSubscriptionPlanDraft,
  type SubscriptionPlanDraft,
} from "@/components/economy-page.helpers";
import styles from "@/components/economy-page.module.css";
import { safeText, TableOrEmpty } from "@/components/economy-page.shared";
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
  const [editingPlanId, setEditingPlanId] = useState<string | null>(null);
  const editingPlan = subscriptionPlans.find((plan) => plan.planId === editingPlanId);

  return (
    <AdminCard title={text.subscriptionPlansTitle} description={text.subscriptionPlansDescription}>
      <AdminMetricStrip
        items={subscriptionPlans.slice(0, 4).map((plan) => ({
          label: `${safeText(plan.name, 80)} • ${humanizeBillingPeriod(plan.billingPeriod, locale)}`,
          value: `${plan.monthlyTokenLimit} ${text.tokensShort}`,
        }))}
        className={styles.metricStrip}
      />

      <TableOrEmpty hasItems={subscriptionPlans.length > 0} emptyTitle={text.noSubscriptionPlans}>
        <ul className={styles.planSummaryList} aria-label={text.subscriptionPlansTitle}>
          {subscriptionPlans.map((plan) => {
            const draft = planDrafts[plan.planId] ?? toSubscriptionPlanDraft(plan);
            const isPlanDraftDirty = isSubscriptionPlanDraftDirty(plan, draft);
            const isPlanEditorOpen = editingPlanId === plan.planId;
            const editorId = `economy-plan-editor-${plan.planId}`;

            return (
              <li
                key={plan.planId}
                className={styles.planSummaryItem}
                data-selected={isPlanEditorOpen || undefined}
              >
                <div className={styles.planSummaryIdentity}>
                  <strong title={safeText(draft.name, 80)}>{safeText(draft.name, 80)}</strong>
                  <span title={safeText(plan.planId, 48)}>
                    {humanizeBillingPeriod(plan.billingPeriod, locale)} ·{" "}
                    {safeText(plan.planId, 48)}
                  </span>
                </div>

                <div className={styles.planSummaryValue}>
                  <strong>
                    {safeText(draft.priceAmount, 32)}{" "}
                    {safeText(draft.currencyCode.toUpperCase(), 12)}
                  </strong>
                  <span>
                    {safeText(draft.monthlyTokenLimit, 32)} {text.tokensShort}
                  </span>
                </div>

                <div className={`${styles.flagList} ${styles.planSummaryFlags}`}>
                  <span>{draft.isActive ? text.activeState : text.inactiveState}</span>
                  {draft.isRecommended ? <span>{text.recommendedState}</span> : null}
                  {isPlanDraftDirty ? (
                    <span className={styles.planSummaryDirty}>{text.unsavedChangesLabel}</span>
                  ) : null}
                </div>

                <Button
                  aria-controls={editorId}
                  aria-expanded={isPlanEditorOpen}
                  disabled={savePlanPending}
                  onClick={() =>
                    setEditingPlanId((currentPlanId) =>
                      currentPlanId === plan.planId ? null : plan.planId
                    )
                  }
                >
                  {text.editAction}
                </Button>
              </li>
            );
          })}
        </ul>

        {editingPlan ? (
          <SubscriptionPlanEditor
            editorId={`economy-plan-editor-${editingPlan.planId}`}
            locale={locale}
            text={text}
            plan={editingPlan}
            draft={planDrafts[editingPlan.planId] ?? toSubscriptionPlanDraft(editingPlan)}
            setPlanDrafts={setPlanDrafts}
            savePlanPending={savePlanPending}
            savePlanId={savePlanId}
            onSavePlan={onSavePlan}
            onClose={() => setEditingPlanId(null)}
            humanizeBillingPeriod={humanizeBillingPeriod}
          />
        ) : null}
      </TableOrEmpty>
    </AdminCard>
  );
}

type SubscriptionPlanEditorProps = {
  editorId: string;
  locale: Locale;
  text: EconomyPageText;
  plan: AdminSubscriptionPlan;
  draft: SubscriptionPlanDraft;
  setPlanDrafts: Dispatch<SetStateAction<Record<string, SubscriptionPlanDraft>>>;
  savePlanPending: boolean;
  savePlanId?: string;
  onSavePlan: (planId: string) => void;
  onClose: () => void;
  humanizeBillingPeriod: (value: string, locale: Locale) => string;
};

function SubscriptionPlanEditor({
  editorId,
  locale,
  text,
  plan,
  draft,
  setPlanDrafts,
  savePlanPending,
  savePlanId,
  onSavePlan,
  onClose,
  humanizeBillingPeriod,
}: SubscriptionPlanEditorProps) {
  const isSavingPlan = savePlanPending && savePlanId === plan.planId;
  const isPlanDraftLocked = savePlanPending;
  const isPlanDraftDirty = isSubscriptionPlanDraftDirty(plan, draft);
  const isPlanDraftInvalid = isSubscriptionPlanDraftInvalid(draft);
  const hasInvalidDirtyPlanDraft = isPlanDraftDirty && isPlanDraftInvalid;
  const isSavePlanDisabled = isPlanDraftLocked || !isPlanDraftDirty || isPlanDraftInvalid;

  return (
    <section className={styles.planEditor} id={editorId} aria-labelledby={`${editorId}-title`}>
      <div className={styles.planEditorHeader}>
        <div className={styles.packMeta}>
          <h3 id={`${editorId}-title`}>{`${text.editAction}: ${safeText(draft.name, 80)}`}</h3>
          <span>
            {humanizeBillingPeriod(plan.billingPeriod, locale)} · {safeText(plan.planId, 48)}
          </span>
        </div>
        <button
          type="button"
          className={styles.pagerButton}
          disabled={isPlanDraftLocked}
          onClick={onClose}
        >
          {text.collapseEditorAction}
        </button>
      </div>

      <form
        className={styles.planEditorForm}
        onSubmit={(event) => {
          event.preventDefault();
          if (!isSavePlanDisabled) {
            onSavePlan(plan.planId);
          }
        }}
      >
        <div className={styles.planEditorFields}>
          <label className={styles.field}>
            <span>{text.planColumn}</span>
            <input
              value={draft.name}
              onChange={(event) =>
                updateSubscriptionPlanDraft(setPlanDrafts, plan.planId, {
                  name: normalizeEconomyPlanNameInput(event.target.value),
                })
              }
              maxLength={ECONOMY_PLAN_NAME_MAX_LENGTH}
              className={styles.input}
              disabled={isPlanDraftLocked}
            />
          </label>
          <label className={styles.field}>
            <span>{text.priceColumn}</span>
            <input
              value={draft.priceAmount}
              onChange={(event) =>
                updateSubscriptionPlanDraft(setPlanDrafts, plan.planId, {
                  priceAmount: normalizeEconomyPriceInput(event.target.value),
                })
              }
              maxLength={ECONOMY_PACK_PRICE_MAX_LENGTH}
              inputMode="decimal"
              className={styles.input}
              disabled={isPlanDraftLocked}
            />
          </label>
          <label className={styles.field}>
            <span>{text.currencyLabel}</span>
            <input
              value={draft.currencyCode}
              onChange={(event) =>
                updateSubscriptionPlanDraft(setPlanDrafts, plan.planId, {
                  currencyCode: normalizeEconomyCurrencyInput(event.target.value),
                })
              }
              maxLength={3}
              className={styles.input}
              disabled={isPlanDraftLocked}
            />
          </label>
          <label className={styles.field}>
            <span>{text.tokensColumn}</span>
            <input
              value={draft.monthlyTokenLimit}
              onChange={(event) =>
                updateSubscriptionPlanDraft(setPlanDrafts, plan.planId, {
                  monthlyTokenLimit: normalizeEconomyIntegerInput(event.target.value),
                })
              }
              maxLength={ECONOMY_PACK_INTEGER_MAX_LENGTH}
              inputMode="numeric"
              className={styles.input}
              disabled={isPlanDraftLocked}
            />
          </label>
          <label className={styles.field}>
            <span>{text.sortColumn}</span>
            <input
              value={draft.displayOrder}
              onChange={(event) =>
                updateSubscriptionPlanDraft(setPlanDrafts, plan.planId, {
                  displayOrder: normalizeEconomyIntegerInput(event.target.value),
                })
              }
              maxLength={ECONOMY_PACK_INTEGER_MAX_LENGTH}
              inputMode="numeric"
              className={styles.input}
              disabled={isPlanDraftLocked}
            />
          </label>
        </div>

        <div className={styles.planEditorProductFields}>
          <label className={styles.field}>
            <span>{text.appleProductLabel}</span>
            <input
              value={draft.appleProductId}
              onChange={(event) =>
                updateSubscriptionPlanDraft(setPlanDrafts, plan.planId, {
                  appleProductId: normalizeEconomyPlanProductIdInput(event.target.value),
                })
              }
              maxLength={ECONOMY_PLAN_PRODUCT_ID_MAX_LENGTH}
              className={styles.input}
              disabled={isPlanDraftLocked}
            />
          </label>
          <label className={styles.field}>
            <span>{text.googleProductLabel}</span>
            <input
              value={draft.googleProductId}
              onChange={(event) =>
                updateSubscriptionPlanDraft(setPlanDrafts, plan.planId, {
                  googleProductId: normalizeEconomyPlanProductIdInput(event.target.value),
                })
              }
              maxLength={ECONOMY_PLAN_PRODUCT_ID_MAX_LENGTH}
              className={styles.input}
              disabled={isPlanDraftLocked}
            />
          </label>
          <label className={styles.field}>
            <span>{text.stripePriceLabel}</span>
            <input
              value={draft.stripePriceId}
              onChange={(event) =>
                updateSubscriptionPlanDraft(setPlanDrafts, plan.planId, {
                  stripePriceId: normalizeEconomyPlanProductIdInput(event.target.value),
                })
              }
              maxLength={ECONOMY_PLAN_PRODUCT_ID_MAX_LENGTH}
              className={styles.input}
              disabled={isPlanDraftLocked}
            />
          </label>
        </div>

        <div className={styles.planEditorStatus}>
          <label className={styles.checkboxField}>
            <input
              type="checkbox"
              checked={draft.isActive}
              onChange={(event) =>
                updateSubscriptionPlanDraft(setPlanDrafts, plan.planId, {
                  isActive: event.target.checked,
                })
              }
              disabled={isPlanDraftLocked}
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
              disabled={isPlanDraftLocked}
            />
            <span>{text.recommendedState}</span>
          </label>
        </div>

        <div className={styles.planEditorActions}>
          <Button type="submit" disabled={isSavePlanDisabled}>
            {isSavingPlan ? text.savingAction : text.saveAction}
          </Button>
          <button
            type="button"
            className={styles.pagerButton}
            disabled={isPlanDraftLocked}
            onClick={onClose}
          >
            {text.collapseEditorAction}
          </button>
        </div>

        {hasInvalidDirtyPlanDraft ? (
          <p className={styles.validationMessage} aria-live="polite">
            {text.invalidPlanNumbers}
          </p>
        ) : null}
      </form>
    </section>
  );
}
