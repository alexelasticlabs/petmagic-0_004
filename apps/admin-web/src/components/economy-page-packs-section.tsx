import {
  type Dispatch,
  type KeyboardEvent,
  type SetStateAction,
  useMemo,
  useRef,
  useState,
} from "react";

import { AdminCard, AdminMetricStrip, adminTableStyles } from "@/components/admin/admin-primitives";
import { type EconomyPageText } from "@/components/economy-page.content";
import {
  ECONOMY_PACK_DISPLAY_NAME_MAX_LENGTH,
  ECONOMY_PACK_INTEGER_MAX_LENGTH,
  ECONOMY_PACK_PRICE_MAX_LENGTH,
  isPackDraftDirty,
  isPackDraftInvalid,
  normalizeEconomyIntegerInput,
  normalizeEconomyPackDisplayNameInput,
  normalizeEconomyPriceInput,
  toDraft,
  updateDraft,
  type PackDraft,
} from "@/components/economy-page.helpers";
import styles from "@/components/economy-page.module.css";
import { TableOrEmpty, safeText } from "@/components/economy-page.shared";
import { Button } from "@/components/ui/button";
import { type AdminCurrencyPack } from "@/lib/api-client";

type EconomyPagePacksSectionProps = {
  text: EconomyPageText;
  packs: AdminCurrencyPack[];
  drafts: Record<string, PackDraft>;
  setDrafts: Dispatch<SetStateAction<Record<string, PackDraft>>>;
  savePackPending: boolean;
  savePackId?: string;
  onSavePack: (packId: string) => void;
};

export function EconomyPagePacksSection({
  text,
  packs,
  drafts,
  setDrafts,
  savePackPending,
  savePackId,
  onSavePack,
}: EconomyPagePacksSectionProps) {
  const [selectedCurrency, setSelectedCurrency] = useState("all");
  const [editingPackId, setEditingPackId] = useState<string | null>(null);
  const currencyTabRefs = useRef<Array<HTMLButtonElement | null>>([]);
  const currencyCodes = useMemo(
    () => [...new Set(packs.map((pack) => pack.currencyCode.toUpperCase()))].sort(),
    [packs]
  );
  const effectiveCurrency = currencyCodes.includes(selectedCurrency) ? selectedCurrency : "all";
  const currencyTabs = ["all", ...currencyCodes];
  const visiblePacks =
    effectiveCurrency === "all"
      ? packs
      : packs.filter((pack) => pack.currencyCode.toUpperCase() === effectiveCurrency);

  function handleCurrencyTabKeyDown(event: KeyboardEvent<HTMLButtonElement>, currentIndex: number) {
    let nextIndex: number | null = null;

    switch (event.key) {
      case "ArrowRight":
      case "ArrowDown":
        nextIndex = (currentIndex + 1) % currencyTabs.length;
        break;
      case "ArrowLeft":
      case "ArrowUp":
        nextIndex = (currentIndex - 1 + currencyTabs.length) % currencyTabs.length;
        break;
      case "Home":
        nextIndex = 0;
        break;
      case "End":
        nextIndex = currencyTabs.length - 1;
        break;
      default:
        return;
    }

    event.preventDefault();
    const nextCurrency = currencyTabs[nextIndex] ?? "all";
    setSelectedCurrency(nextCurrency);
    queueMicrotask(() => currencyTabRefs.current[nextIndex]?.focus());
  }

  return (
    <AdminCard title={text.packsTitle} description={text.packsDescription}>
      <div className={styles.catalogToolbar}>
        <span>{text.catalogCurrencyLabel}</span>
        <div className={styles.currencyTabs} role="tablist" aria-label={text.catalogCurrencyLabel}>
          {currencyTabs.map((currencyCode, index) => (
            <button
              ref={(element) => {
                currencyTabRefs.current[index] = element;
              }}
              key={currencyCode}
              type="button"
              id={`economy-currency-tab-${currencyCode}`}
              className={styles.currencyTab}
              data-active={effectiveCurrency === currencyCode || undefined}
              role="tab"
              aria-controls="economy-packs-panel"
              aria-selected={effectiveCurrency === currencyCode}
              tabIndex={effectiveCurrency === currencyCode ? 0 : -1}
              onClick={() => setSelectedCurrency(currencyCode)}
              onKeyDown={(event) => handleCurrencyTabKeyDown(event, index)}
            >
              {currencyCode === "all" ? text.allCurrenciesLabel : currencyCode}
            </button>
          ))}
        </div>
      </div>
      <div
        id="economy-packs-panel"
        role="tabpanel"
        aria-labelledby={`economy-currency-tab-${effectiveCurrency}`}
      >
        <AdminMetricStrip
          items={visiblePacks.slice(0, 4).map((pack) => ({
            label: `${safeText(pack.code.toUpperCase(), 32)} • ${safeText(
              pack.currencyCode.toUpperCase(),
              12
            )}`,
            value: `${pack.totalSpark} ${text.tokensShort}`,
          }))}
          className={styles.metricStrip}
        />

        <TableOrEmpty hasItems={visiblePacks.length > 0} emptyTitle={text.noPacks}>
          <div className={adminTableStyles.tableWrap}>
            <table className={`${adminTableStyles.table} ${styles.wideTable}`}>
              <thead>
                <tr>
                  <th>{text.packColumn}</th>
                  <th>{text.priceColumn}</th>
                  <th>{text.grantedColumn}</th>
                  <th>{text.bonusColumn}</th>
                  <th>{text.sortColumn}</th>
                  <th>{text.activeColumn}</th>
                  <th>{text.actionsColumn}</th>
                </tr>
              </thead>
              <tbody>
                {visiblePacks.map((pack) => {
                  const draft = drafts[pack.packId] ?? toDraft(pack);
                  const isSavingRow = savePackPending && savePackId === pack.packId;
                  const isPackDraftDirtyState = isPackDraftDirty(pack, draft);
                  const isPackDraftInvalidState = isPackDraftInvalid(draft);
                  const isPackEditorOpen = editingPackId === pack.packId;
                  const isPackDraftLocked = isSavingRow;
                  const hasInvalidDirtyPackDraft = isPackDraftDirtyState && isPackDraftInvalidState;
                  const isSavePackDisabled =
                    savePackPending || !isPackDraftDirtyState || isPackDraftInvalidState;

                  return (
                    <tr key={pack.packId}>
                      <td>
                        <div className={styles.packMeta}>
                          <strong>{safeText(pack.code.toUpperCase(), 32)}</strong>
                          <span>{safeText(pack.currencyCode.toUpperCase(), 12)}</span>
                          <span
                            className={styles.packState}
                            data-dirty={isPackDraftDirtyState || undefined}
                          >
                            {isPackDraftDirtyState
                              ? text.unsavedChangesLabel
                              : text.savedStateLabel}
                          </span>
                        </div>
                        {isPackEditorOpen ? (
                          <label className={styles.field}>
                            <span>{text.packColumn}</span>
                            <input
                              value={draft.displayName}
                              onChange={(event) =>
                                updateDraft(setDrafts, pack.packId, {
                                  displayName: normalizeEconomyPackDisplayNameInput(
                                    event.target.value
                                  ),
                                })
                              }
                              maxLength={ECONOMY_PACK_DISPLAY_NAME_MAX_LENGTH}
                              className={styles.input}
                              disabled={isPackDraftLocked}
                            />
                          </label>
                        ) : (
                          <span className={styles.mutedText}>
                            {safeText(draft.displayName, 80)}
                          </span>
                        )}
                      </td>
                      <td>
                        {isPackEditorOpen ? (
                          <label className={styles.field}>
                            <span>{text.priceColumn}</span>
                            <input
                              value={draft.priceAmount}
                              onChange={(event) =>
                                updateDraft(setDrafts, pack.packId, {
                                  priceAmount: normalizeEconomyPriceInput(event.target.value),
                                })
                              }
                              maxLength={ECONOMY_PACK_PRICE_MAX_LENGTH}
                              inputMode="decimal"
                              className={styles.input}
                              disabled={isPackDraftLocked}
                            />
                          </label>
                        ) : (
                          <span className={styles.mutedText}>
                            {safeText(draft.priceAmount, 32)}{" "}
                            {safeText(pack.currencyCode.toUpperCase(), 12)}
                          </span>
                        )}
                      </td>
                      <td>
                        {isPackEditorOpen ? (
                          <label className={styles.field}>
                            <span>{text.grantedColumn}</span>
                            <input
                              value={draft.grantedSpark}
                              onChange={(event) =>
                                updateDraft(setDrafts, pack.packId, {
                                  grantedSpark: normalizeEconomyIntegerInput(event.target.value),
                                })
                              }
                              maxLength={ECONOMY_PACK_INTEGER_MAX_LENGTH}
                              inputMode="numeric"
                              className={styles.input}
                              disabled={isPackDraftLocked}
                            />
                          </label>
                        ) : (
                          <span className={styles.mutedText}>
                            {safeText(draft.grantedSpark, 32)}
                          </span>
                        )}
                      </td>
                      <td>
                        {isPackEditorOpen ? (
                          <label className={styles.field}>
                            <span>{text.bonusColumn}</span>
                            <input
                              value={draft.bonusSpark}
                              onChange={(event) =>
                                updateDraft(setDrafts, pack.packId, {
                                  bonusSpark: normalizeEconomyIntegerInput(event.target.value),
                                })
                              }
                              maxLength={ECONOMY_PACK_INTEGER_MAX_LENGTH}
                              inputMode="numeric"
                              className={styles.input}
                              disabled={isPackDraftLocked}
                            />
                          </label>
                        ) : (
                          <span className={styles.mutedText}>{safeText(draft.bonusSpark, 32)}</span>
                        )}
                      </td>
                      <td>
                        {isPackEditorOpen ? (
                          <label className={styles.field}>
                            <span>{text.sortColumn}</span>
                            <input
                              value={draft.sortOrder}
                              onChange={(event) =>
                                updateDraft(setDrafts, pack.packId, {
                                  sortOrder: normalizeEconomyIntegerInput(event.target.value),
                                })
                              }
                              maxLength={ECONOMY_PACK_INTEGER_MAX_LENGTH}
                              inputMode="numeric"
                              className={styles.input}
                              disabled={isPackDraftLocked}
                            />
                          </label>
                        ) : (
                          <span className={styles.mutedText}>{safeText(draft.sortOrder, 32)}</span>
                        )}
                      </td>
                      <td>
                        {isPackEditorOpen ? (
                          <label className={styles.checkboxField}>
                            <input
                              type="checkbox"
                              checked={draft.isActive}
                              onChange={(event) =>
                                updateDraft(setDrafts, pack.packId, {
                                  isActive: event.target.checked,
                                })
                              }
                              disabled={isPackDraftLocked}
                            />
                            <span>{draft.isActive ? text.activeState : text.inactiveState}</span>
                          </label>
                        ) : (
                          <span className={styles.mutedText}>
                            {draft.isActive ? text.activeState : text.inactiveState}
                          </span>
                        )}
                      </td>
                      <td>
                        <div className={styles.tableActions}>
                          {isPackEditorOpen ? (
                            <>
                              <Button
                                onClick={() => onSavePack(pack.packId)}
                                disabled={isSavePackDisabled}
                              >
                                {isSavingRow ? text.savingAction : text.saveAction}
                              </Button>
                              <button
                                type="button"
                                className={styles.pagerButton}
                                onClick={() => setEditingPackId(null)}
                              >
                                {text.collapseEditorAction}
                              </button>
                            </>
                          ) : (
                            <Button onClick={() => setEditingPackId(pack.packId)}>
                              {text.editAction}
                            </Button>
                          )}
                        </div>
                        {hasInvalidDirtyPackDraft ? (
                          <p className={styles.validationMessage} aria-live="polite">
                            {text.invalidPackNumbers}
                          </p>
                        ) : null}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </TableOrEmpty>
      </div>
    </AdminCard>
  );
}
