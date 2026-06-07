"use client";

import { type Dispatch, type FormEvent, type SetStateAction } from "react";

import { AdminCard } from "@/components/admin/admin-primitives";
import {
  PROMO_NUMERIC_FIELD_MAX_LENGTH,
  isPromoIntegerInput,
  normalizePromoIntegerInput,
  type PromoForm,
  type PromoFormMode,
} from "@/components/promo-codes-view.helpers";
import styles from "@/components/promo-codes-view.module.css";
import { Button } from "@/components/ui/button";
import { Select, type SelectOption } from "@/components/ui/select";
import { type AdminRedeemCode, type AdminRedeemRewardKind } from "@/lib/api-client";
import { getDictionary } from "@/lib/i18n";

type PromoCodesEditorDrawerProps = {
  isOpen: boolean;
  panelMode: PromoFormMode;
  text: ReturnType<typeof getDictionary>;
  form: PromoForm;
  setForm: Dispatch<SetStateAction<PromoForm>>;
  formStatusOptions: SelectOption[];
  selectedCode: AdminRedeemCode | null;
  isMutating: boolean;
  onSubmit: (event: FormEvent<HTMLFormElement>) => void;
  onClose: () => void;
  onReset: () => void;
  onGenerateCode: () => void;
  onToggleCodeState: (code: AdminRedeemCode) => void;
};

export function PromoCodesEditorDrawer({
  isOpen,
  panelMode,
  text,
  form,
  setForm,
  formStatusOptions,
  selectedCode,
  isMutating,
  onSubmit,
  onClose,
  onReset,
  onGenerateCode,
  onToggleCodeState,
}: PromoCodesEditorDrawerProps) {
  if (!isOpen) {
    return null;
  }

  const panelTitle =
    panelMode === "edit"
      ? text.promoCodesEditPanelTitle
      : panelMode === "duplicate"
        ? text.promoCodesDuplicatePanelTitle
        : text.promoCodesCreatePanelTitle;
  const isCodeInvalid = form.code.trim().length < 4 || form.code.trim().length > 48;
  const hasInvalidNumber =
    !isPromoIntegerInput(form.rewardValue, false) ||
    !isPromoIntegerInput(form.maxRedemptions, false) ||
    !isPromoIntegerInput(form.maxRedemptionsPerUser, false) ||
    !isPromoIntegerInput(form.minimumSuccessfulPurchases, true);
  const hasInvalidDateWindow =
    Boolean(form.startsAtUtc) &&
    Boolean(form.expiresAtUtc) &&
    new Date(form.startsAtUtc).getTime() > new Date(form.expiresAtUtc).getTime();
  const isSubmitDisabled = isMutating || isCodeInvalid || hasInvalidNumber || hasInvalidDateWindow;

  return (
    <div className={styles.drawerBackdrop} onClick={onClose}>
      <aside
        className={styles.editorDrawer}
        role="dialog"
        aria-modal="true"
        aria-label={panelTitle}
        onClick={(event) => event.stopPropagation()}
      >
        <AdminCard
          title={panelTitle}
          description={text.promoCodesFormCardDescription}
          className={styles.formCard}
        >
          <form className={styles.form} onSubmit={onSubmit}>
            <section className={styles.formSection}>
              <header className={styles.formSectionHeader}>
                <h3 className={styles.formSectionTitle}>{text.promoCodesSectionMainTitle}</h3>
              </header>

              <label className={styles.formField}>
                <span className={styles.fieldLabel}>{text.promoCodesCodeLabel}</span>
                <div className={styles.inlineField}>
                  <input
                    className={`${styles.input} ${styles.codeInput}`}
                    value={form.code}
                    required
                    minLength={4}
                    maxLength={48}
                    aria-invalid={isCodeInvalid}
                    onChange={(event) =>
                      setForm((current) => ({
                        ...current,
                        code: event.target.value.toUpperCase(),
                      }))
                    }
                    readOnly={panelMode === "edit"}
                  />
                  <Button
                    type="button"
                    variant="secondary"
                    size="sm"
                    onClick={onGenerateCode}
                    disabled={panelMode === "edit"}
                  >
                    {text.promoCodesGenerateCodeAction}
                  </Button>
                </div>
                <span className={styles.helperText}>{text.promoCodesCodeHelp}</span>
              </label>

              <label className={styles.formField}>
                <span className={styles.fieldLabel}>{text.promoCodesDescriptionLabel}</span>
                <input
                  className={styles.input}
                  placeholder={text.promoCodesDescriptionPlaceholder}
                  value={form.description}
                  maxLength={160}
                  onChange={(event) =>
                    setForm((current) => ({ ...current, description: event.target.value }))
                  }
                />
              </label>

              <label className={styles.formField}>
                <span className={styles.fieldLabel}>{text.promoCodesStatusFieldLabel}</span>
                <Select
                  value={form.isActive ? "active" : "paused"}
                  options={formStatusOptions}
                  onChange={(value) =>
                    setForm((current) => ({ ...current, isActive: value === "active" }))
                  }
                  ariaLabel={text.promoCodesStatusFieldLabel}
                  showSelectedDescription={false}
                />
              </label>
            </section>

            <section className={styles.formSection}>
              <header className={styles.formSectionHeader}>
                <h3 className={styles.formSectionTitle}>{text.promoCodesSectionRewardTitle}</h3>
              </header>

              <div className={styles.formGrid}>
                <label className={styles.formField}>
                  <span className={styles.fieldLabel}>{text.promoCodesRewardTypeLabel}</span>
                  <select
                    className={`${styles.input} ${styles.selectInput}`}
                    value={form.rewardKind}
                    onChange={(event) =>
                      setForm((current) => ({
                        ...current,
                        rewardKind: event.target.value as AdminRedeemRewardKind,
                      }))
                    }
                  >
                    <option value="spark">{text.promoCodesRewardTypeSparkOption}</option>
                    <option value="premium_days" disabled>
                      {text.promoCodesRewardTypePremiumOption}
                    </option>
                  </select>
                  <span className={styles.helperText}>{text.promoCodesRewardTypeHint}</span>
                </label>

                <label className={styles.formField}>
                  <span className={styles.fieldLabel}>{text.promoCodesRewardValueLabel}</span>
                  <input
                    className={styles.input}
                    type="text"
                    inputMode="numeric"
                    pattern="[0-9]*"
                    min={1}
                    required
                    maxLength={PROMO_NUMERIC_FIELD_MAX_LENGTH}
                    aria-invalid={!isPromoIntegerInput(form.rewardValue, false)}
                    value={form.rewardValue}
                    onChange={(event) =>
                      setForm((current) => ({
                        ...current,
                        rewardValue: normalizePromoIntegerInput(event.target.value),
                      }))
                    }
                  />
                  <div className={styles.quickChips}>
                    {[50, 100, 250, 500, 1000].map((v) => (
                      <button
                        key={v}
                        type="button"
                        className={`${styles.quickChip}${form.rewardValue === String(v) ? ` ${styles.quickChipActive}` : ""}`}
                        onClick={() =>
                          setForm((current) => ({ ...current, rewardValue: String(v) }))
                        }
                      >
                        {v}
                      </button>
                    ))}
                  </div>
                </label>
              </div>
            </section>

            <section className={styles.formSection}>
              <header className={styles.formSectionHeader}>
                <h3 className={styles.formSectionTitle}>{text.promoCodesSectionLimitsTitle}</h3>
              </header>

              <div className={styles.formGrid}>
                <label className={styles.formField}>
                  <span className={styles.fieldLabel}>{text.promoCodesLimitLabel}</span>
                  <input
                    className={styles.input}
                    type="text"
                    inputMode="numeric"
                    pattern="[0-9]*"
                    min={1}
                    required
                    maxLength={PROMO_NUMERIC_FIELD_MAX_LENGTH}
                    aria-invalid={!isPromoIntegerInput(form.maxRedemptions, false)}
                    value={form.maxRedemptions}
                    onChange={(event) =>
                      setForm((current) => ({
                        ...current,
                        maxRedemptions: normalizePromoIntegerInput(event.target.value),
                      }))
                    }
                  />
                  <div className={styles.quickChips}>
                    {[50, 100, 500, 1000].map((v) => (
                      <button
                        key={v}
                        type="button"
                        className={`${styles.quickChip}${form.maxRedemptions === String(v) ? ` ${styles.quickChipActive}` : ""}`}
                        onClick={() =>
                          setForm((current) => ({ ...current, maxRedemptions: String(v) }))
                        }
                      >
                        {v}
                      </button>
                    ))}
                  </div>
                </label>
                <label className={styles.formField}>
                  <span className={styles.fieldLabel}>{text.promoCodesPerUserLimitLabel}</span>
                  <input
                    className={styles.input}
                    type="text"
                    inputMode="numeric"
                    pattern="[0-9]*"
                    min={1}
                    required
                    maxLength={PROMO_NUMERIC_FIELD_MAX_LENGTH}
                    aria-invalid={!isPromoIntegerInput(form.maxRedemptionsPerUser, false)}
                    value={form.maxRedemptionsPerUser}
                    onChange={(event) =>
                      setForm((current) => ({
                        ...current,
                        maxRedemptionsPerUser: normalizePromoIntegerInput(event.target.value),
                      }))
                    }
                  />
                  <div className={styles.quickChips}>
                    {[1, 2, 3, 5].map((v) => (
                      <button
                        key={v}
                        type="button"
                        className={`${styles.quickChip}${form.maxRedemptionsPerUser === String(v) ? ` ${styles.quickChipActive}` : ""}`}
                        onClick={() =>
                          setForm((current) => ({ ...current, maxRedemptionsPerUser: String(v) }))
                        }
                      >
                        {v}
                      </button>
                    ))}
                  </div>
                </label>
              </div>
            </section>

            <section className={styles.formSection}>
              <header className={styles.formSectionHeader}>
                <h3 className={styles.formSectionTitle}>{text.promoCodesWindowLabel}</h3>
              </header>

              <div className={styles.formGrid}>
                <label className={styles.formField}>
                  <span className={styles.fieldLabel}>{text.promoCodesStartsLabel}</span>
                  <div className={styles.optionalDateControl}>
                    <input
                      className={styles.input}
                      type="datetime-local"
                      value={form.startsAtUtc}
                      aria-invalid={hasInvalidDateWindow}
                      onChange={(event) =>
                        setForm((current) => ({ ...current, startsAtUtc: event.target.value }))
                      }
                    />
                    <Button
                      type="button"
                      variant="ghost"
                      size="sm"
                      onClick={() =>
                        setForm((current) => ({
                          ...current,
                          startsAtUtc: current.startsAtUtc
                            ? ""
                            : new Date(
                                new Date().getTime() - new Date().getTimezoneOffset() * 60_000
                              )
                                .toISOString()
                                .slice(0, 16),
                        }))
                      }
                    >
                      {form.startsAtUtc ? text.resetForm : text.promoCodesPickDateAction}
                    </Button>
                  </div>
                  <span className={styles.helperText}>{text.promoCodesDatesOptionalHint}</span>
                </label>
                <label className={styles.formField}>
                  <span className={styles.fieldLabel}>{text.promoCodesExpiresLabel}</span>
                  <div className={styles.optionalDateControl}>
                    <input
                      className={styles.input}
                      type="datetime-local"
                      value={form.expiresAtUtc}
                      aria-invalid={hasInvalidDateWindow}
                      onChange={(event) =>
                        setForm((current) => ({ ...current, expiresAtUtc: event.target.value }))
                      }
                    />
                    <Button
                      type="button"
                      variant="ghost"
                      size="sm"
                      onClick={() =>
                        setForm((current) => ({
                          ...current,
                          expiresAtUtc: current.expiresAtUtc
                            ? ""
                            : new Date(
                                new Date().getTime() - new Date().getTimezoneOffset() * 60_000
                              )
                                .toISOString()
                                .slice(0, 16),
                        }))
                      }
                    >
                      {form.expiresAtUtc
                        ? text.promoCodesNoExpiryAction
                        : text.promoCodesPickDateAction}
                    </Button>
                  </div>
                  <span className={styles.helperText}>{text.promoCodesDatesOptionalHint}</span>
                </label>
              </div>
            </section>

            <section className={styles.formSection}>
              <header className={styles.formSectionHeader}>
                <h3 className={styles.formSectionTitle}>{text.promoCodesSectionCampaignTitle}</h3>
              </header>

              <div className={styles.formGrid}>
                <label className={styles.formField}>
                  <span className={styles.fieldLabel}>{text.promoCodesMinimumPurchasesLabel}</span>
                  <input
                    className={styles.input}
                    type="text"
                    inputMode="numeric"
                    pattern="[0-9]*"
                    min={0}
                    required
                    maxLength={PROMO_NUMERIC_FIELD_MAX_LENGTH}
                    aria-invalid={!isPromoIntegerInput(form.minimumSuccessfulPurchases, true)}
                    value={form.minimumSuccessfulPurchases}
                    onChange={(event) =>
                      setForm((current) => ({
                        ...current,
                        minimumSuccessfulPurchases: normalizePromoIntegerInput(event.target.value),
                      }))
                    }
                  />
                  <span className={styles.helperText}>{text.promoCodesMinimumPurchasesHint}</span>
                </label>
                <label className={styles.formField}>
                  <span className={styles.fieldLabel}>{text.promoCodesCampaignNameLabel}</span>
                  <input
                    className={styles.input}
                    placeholder={text.promoCodesCampaignNamePlaceholder}
                    value={form.campaignName}
                    maxLength={80}
                    onChange={(event) =>
                      setForm((current) => ({ ...current, campaignName: event.target.value }))
                    }
                  />
                </label>
                <label className={styles.formField}>
                  <span className={styles.fieldLabel}>{text.promoCodesCampaignChannelLabel}</span>
                  <input
                    className={styles.input}
                    placeholder={text.promoCodesCampaignChannelPlaceholder}
                    value={form.campaignChannel}
                    maxLength={80}
                    onChange={(event) =>
                      setForm((current) => ({
                        ...current,
                        campaignChannel: event.target.value,
                      }))
                    }
                  />
                </label>
              </div>
            </section>

            <div className={styles.formSummary} aria-label={text.promoCodesFormSummaryLabel}>
              <span className={styles.formSummaryItem}>
                🎁 <strong>{form.rewardValue || "—"}</strong>
                {" PawSpark"}
              </span>
              <span className={styles.formSummarySep} aria-hidden="true">
                ·
              </span>
              <span className={styles.formSummaryItem}>
                🔢 {text.promoCodesSummaryLimitLabel}{" "}
                <strong>{form.maxRedemptions || "—"}</strong>
                {" ("}
                <strong>{form.maxRedemptionsPerUser || "—"}</strong>
                {` ${text.promoCodesSummaryPerUserSuffix})`}
              </span>
              <span className={styles.formSummarySep} aria-hidden="true">
                ·
              </span>
              <span className={styles.formSummaryItem}>
                📅{" "}
                {form.expiresAtUtc
                  ? form.expiresAtUtc.replace("T", " ")
                  : text.promoCodesNoExpiryAction}
              </span>
            </div>

            <div className={styles.formActionsSticky}>
              {panelMode === "edit" && selectedCode ? (
                <Button
                  type="button"
                  variant="ghost"
                  className={styles.deactivateButton}
                  disabled={isMutating}
                  onClick={() => onToggleCodeState(selectedCode)}
                >
                  {selectedCode.isActive ? text.deactivate : text.activate}
                </Button>
              ) : (
                <span />
              )}

              <div className={styles.formActions}>
                <Button type="button" variant="secondary" onClick={onClose} disabled={isMutating}>
                  {text.editorCancel}
                </Button>
                <Button type="button" variant="secondary" onClick={onReset} disabled={isMutating}>
                  {text.resetForm}
                </Button>
                <Button variant="primary" type="submit" disabled={isSubmitDisabled}>
                  {panelMode === "edit"
                    ? text.promoCodesSaveUpdateAction
                    : text.promoCodesSaveCreateAction}
                </Button>
              </div>
            </div>
          </form>
        </AdminCard>
      </aside>
    </div>
  );
}
