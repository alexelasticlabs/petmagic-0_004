import { type Dispatch, type SetStateAction } from "react";

import {
  AdminCard,
  AdminMetricStrip,
  adminTableStyles,
} from "@/components/admin/admin-primitives";
import { type EconomyPageText } from "@/components/economy-page.content";
import {
  ECONOMY_PACK_DISPLAY_NAME_MAX_LENGTH,
  ECONOMY_PACK_INTEGER_MAX_LENGTH,
  ECONOMY_PACK_PRICE_MAX_LENGTH,
  isPackDraftDirty,
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
  return (
    <AdminCard title={text.packsTitle} description={text.packsDescription}>
      <AdminMetricStrip
        items={packs.slice(0, 4).map((pack) => ({
          label: `${safeText(pack.code.toUpperCase(), 32)} • ${safeText(
            pack.currencyCode.toUpperCase(),
            12
          )}`,
          value: `${pack.totalSpark} ${text.tokensShort}`,
        }))}
        className={styles.metricStrip}
      />

      <TableOrEmpty hasItems={packs.length > 0} emptyTitle={text.noPacks}>
        <div className={adminTableStyles.tableWrap}>
          <table className={adminTableStyles.table}>
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
              {packs.map((pack) => {
                const draft = drafts[pack.packId] ?? toDraft(pack);
                const isSavingRow = savePackPending && savePackId === pack.packId;
                const isPackDraftLocked = savePackPending;
                const isSavePackDisabled = isPackDraftLocked || !isPackDraftDirty(pack, draft);

                return (
                  <tr key={pack.packId}>
                    <td>
                      <div className={styles.packMeta}>
                        <strong>{safeText(pack.code.toUpperCase(), 32)}</strong>
                        <span>{safeText(pack.currencyCode.toUpperCase(), 12)}</span>
                      </div>
                      <input
                        value={draft.displayName}
                        onChange={(event) =>
                          updateDraft(setDrafts, pack.packId, {
                            displayName: normalizeEconomyPackDisplayNameInput(event.target.value),
                          })
                        }
                        maxLength={ECONOMY_PACK_DISPLAY_NAME_MAX_LENGTH}
                        className={styles.input}
                        disabled={isPackDraftLocked}
                      />
                    </td>
                    <td>
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
                    </td>
                    <td>
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
                    </td>
                    <td>
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
                    </td>
                    <td>
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
                    </td>
                    <td>
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
                    </td>
                    <td>
                      <Button onClick={() => onSavePack(pack.packId)} disabled={isSavePackDisabled}>
                        {isSavingRow ? text.savingAction : text.saveAction}
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
