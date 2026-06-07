import { type Dispatch, type ReactNode, type SetStateAction, useState } from "react";

import { AdminCard, AdminStateCard, adminTableStyles } from "@/components/admin/admin-primitives";
import { ConfirmationDialog } from "@/components/admin/confirmation-dialog";
import { type EconomyPageText } from "@/components/economy-page.content";
import {
  ECONOMY_PROVIDER_BONUS_PERCENT_MAX_LENGTH,
  ECONOMY_PROVIDER_CODE_MAX_LENGTH,
  ECONOMY_PROVIDER_LABEL_MAX_LENGTH,
  ECONOMY_PROVIDER_MESSAGE_MAX_LENGTH,
  ECONOMY_PROVIDER_REGION_MAX_LENGTH,
  ECONOMY_PROVIDER_VERSION_MAX_LENGTH,
  normalizeEconomyPercentInput,
  toProviderConfigDraft,
  updateProviderConfigDraft,
  type ProviderConfigCreateDraft,
  type ProviderConfigDraft,
  type ProviderConfigMatchDraft,
} from "@/components/economy-page.helpers";
import styles from "@/components/economy-page.module.css";
import { Button } from "@/components/ui/button";
import {
  type AdminPaymentProviderConfiguration,
  type AdminPaymentProviderConfigurationMatch,
} from "@/lib/api-client";
import { type Locale } from "@/lib/i18n";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

type EconomyPageProviderConfigsSectionProps = {
  locale: Locale;
  text: EconomyPageText;
  providerConfigs: AdminPaymentProviderConfiguration[];
  providerConfigDrafts: Record<string, ProviderConfigDraft>;
  createProviderDraft: ProviderConfigCreateDraft;
  setCreateProviderDraft: Dispatch<SetStateAction<ProviderConfigCreateDraft>>;
  matchDraft: ProviderConfigMatchDraft;
  setMatchDraft: Dispatch<SetStateAction<ProviderConfigMatchDraft>>;
  matchResult: AdminPaymentProviderConfigurationMatch | null;
  setProviderConfigDrafts: Dispatch<SetStateAction<Record<string, ProviderConfigDraft>>>;
  cloneRegionDrafts: Record<string, string>;
  setCloneRegionDrafts: Dispatch<SetStateAction<Record<string, string>>>;
  saveProviderConfigPending: boolean;
  saveProviderConfigId?: string;
  createProviderConfigPending: boolean;
  testProviderConfigPending: boolean;
  cloneProviderConfigPending: boolean;
  cloneProviderConfigId?: string;
  deleteProviderConfigPending: boolean;
  deleteProviderConfigId?: string;
  onSaveProviderConfig: (configurationId: string) => void;
  onCreateProviderConfig: () => void;
  onTestProviderConfig: () => void;
  onCloneProviderConfig: (payload: { configurationId: string; region: string }) => void;
  onDeleteProviderConfig: (configurationId: string) => Promise<boolean>;
  humanizeProvider: (value: string, locale: Locale) => string;
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

export function EconomyPageProviderConfigsSection({
  locale,
  text,
  providerConfigs,
  providerConfigDrafts,
  createProviderDraft,
  setCreateProviderDraft,
  matchDraft,
  setMatchDraft,
  matchResult,
  setProviderConfigDrafts,
  cloneRegionDrafts,
  setCloneRegionDrafts,
  saveProviderConfigPending,
  saveProviderConfigId,
  createProviderConfigPending,
  testProviderConfigPending,
  cloneProviderConfigPending,
  cloneProviderConfigId,
  deleteProviderConfigPending,
  deleteProviderConfigId,
  onSaveProviderConfig,
  onCreateProviderConfig,
  onTestProviderConfig,
  onCloneProviderConfig,
  onDeleteProviderConfig,
  humanizeProvider,
}: EconomyPageProviderConfigsSectionProps) {
  const [configurationPendingDeleteId, setConfigurationPendingDeleteId] = useState<string | null>(
    null
  );
  const configurationPendingDelete = configurationPendingDeleteId
    ? providerConfigs.find((config) => config.configurationId === configurationPendingDeleteId)
    : null;
  const isCreateProviderConfigInvalid =
    !createProviderDraft.provider.trim() ||
    !createProviderDraft.platform.trim() ||
    !createProviderDraft.region.trim() ||
    !createProviderDraft.mode.trim() ||
    !createProviderDraft.allowedFromAppVersion.trim() ||
    !createProviderDraft.bonusTokensPercent.trim();
  const isProviderConfigMatchInvalid =
    !matchDraft.provider.trim() ||
    !matchDraft.platform.trim() ||
    !matchDraft.country.trim() ||
    !matchDraft.appVersion.trim();
  const requestCreateProviderConfig = () => {
    if (createProviderConfigPending || isCreateProviderConfigInvalid) {
      return;
    }

    onCreateProviderConfig();
  };
  const requestTestProviderConfig = () => {
    if (testProviderConfigPending || isProviderConfigMatchInvalid) {
      return;
    }

    onTestProviderConfig();
  };

  return (
    <AdminCard title={text.providerConfigsTitle} description={text.providerConfigsDescription}>
      <div className={styles.redeemGrid}>
        <div className={styles.redeemForm}>
          <strong>{text.providerConfigCreateTitle}</strong>
          <div className={styles.formRow}>
            <label className={styles.field}>
              <span>{text.providerColumn}</span>
              <input
                value={createProviderDraft.provider}
                onChange={(event) =>
                  setCreateProviderDraft((current) => ({
                    ...current,
                    provider: normalizeProviderCodeInput(event.target.value),
                  }))
                }
                className={styles.input}
                placeholder="stripe"
                maxLength={ECONOMY_PROVIDER_CODE_MAX_LENGTH}
              />
            </label>
            <label className={styles.field}>
              <span>{text.platformColumn}</span>
              <input
                value={createProviderDraft.platform}
                onChange={(event) =>
                  setCreateProviderDraft((current) => ({
                    ...current,
                    platform: normalizeProviderCodeInput(event.target.value),
                  }))
                }
                className={styles.input}
                placeholder="web"
                maxLength={ECONOMY_PROVIDER_CODE_MAX_LENGTH}
              />
            </label>
            <label className={styles.field}>
              <span>{text.regionColumn}</span>
              <input
                value={createProviderDraft.region}
                onChange={(event) =>
                  setCreateProviderDraft((current) => ({
                    ...current,
                    region: normalizeProviderRegionInput(event.target.value),
                  }))
                }
                className={styles.input}
                placeholder="US"
                maxLength={ECONOMY_PROVIDER_REGION_MAX_LENGTH}
              />
            </label>
            <label className={styles.field}>
              <span>{text.modeColumn}</span>
              <input
                value={createProviderDraft.mode}
                onChange={(event) =>
                  setCreateProviderDraft((current) => ({
                    ...current,
                    mode: normalizeProviderCodeInput(event.target.value),
                  }))
                }
                className={styles.input}
                placeholder="live"
                maxLength={ECONOMY_PROVIDER_CODE_MAX_LENGTH}
              />
            </label>
          </div>

          <div className={styles.formRow}>
            <label className={styles.field}>
              <span>{text.minVersionLabel}</span>
              <input
                value={createProviderDraft.allowedFromAppVersion}
                onChange={(event) =>
                  setCreateProviderDraft((current) => ({
                    ...current,
                    allowedFromAppVersion: normalizeProviderVersionInput(event.target.value),
                  }))
                }
                className={styles.input}
                maxLength={ECONOMY_PROVIDER_VERSION_MAX_LENGTH}
              />
            </label>
            <label className={styles.field}>
              <span>{text.bonusPercentLabel}</span>
              <input
                type="text"
                inputMode="numeric"
                pattern="[0-9]*"
                value={createProviderDraft.bonusTokensPercent}
                onChange={(event) =>
                  setCreateProviderDraft((current) => ({
                    ...current,
                    bonusTokensPercent: normalizeEconomyPercentInput(event.target.value),
                  }))
                }
                className={styles.input}
                maxLength={ECONOMY_PROVIDER_BONUS_PERCENT_MAX_LENGTH}
              />
            </label>
          </div>

          <div className={styles.flagList}>
            <label className={styles.checkboxField}>
              <input
                type="checkbox"
                checked={createProviderDraft.isEnabled}
                onChange={(event) =>
                  setCreateProviderDraft((current) => ({
                    ...current,
                    isEnabled: event.target.checked,
                  }))
                }
              />
              <span>{text.activeState}</span>
            </label>
            <label className={styles.checkboxField}>
              <input
                type="checkbox"
                checked={createProviderDraft.externalCheckoutAllowed}
                onChange={(event) =>
                  setCreateProviderDraft((current) => ({
                    ...current,
                    externalCheckoutAllowed: event.target.checked,
                  }))
                }
              />
              <span>{text.externalCheckoutFlag}</span>
            </label>
            <label className={styles.checkboxField}>
              <input
                type="checkbox"
                checked={createProviderDraft.isRecommended}
                onChange={(event) =>
                  setCreateProviderDraft((current) => ({
                    ...current,
                    isRecommended: event.target.checked,
                  }))
                }
              />
              <span>{text.recommendedFlag}</span>
            </label>
            <label className={styles.checkboxField}>
              <input
                type="checkbox"
                checked={createProviderDraft.isSelectedByDefault}
                onChange={(event) =>
                  setCreateProviderDraft((current) => ({
                    ...current,
                    isSelectedByDefault: event.target.checked,
                  }))
                }
              />
              <span>{text.defaultFlag}</span>
            </label>
          </div>

          <Button
            onClick={requestCreateProviderConfig}
            disabled={createProviderConfigPending || isCreateProviderConfigInvalid}
          >
            {createProviderConfigPending ? text.savingAction : text.providerConfigCreateAction}
          </Button>
        </div>

        <div className={styles.redeemForm}>
          <strong>{text.providerConfigTestTitle}</strong>
          <div className={styles.formRow}>
            <label className={styles.field}>
              <span>{text.providerColumn}</span>
              <input
                value={matchDraft.provider}
                onChange={(event) =>
                  setMatchDraft((current) => ({
                    ...current,
                    provider: normalizeProviderCodeInput(event.target.value),
                  }))
                }
                className={styles.input}
                placeholder="stripe"
                maxLength={ECONOMY_PROVIDER_CODE_MAX_LENGTH}
              />
            </label>
            <label className={styles.field}>
              <span>{text.platformColumn}</span>
              <input
                value={matchDraft.platform}
                onChange={(event) =>
                  setMatchDraft((current) => ({
                    ...current,
                    platform: normalizeProviderCodeInput(event.target.value),
                  }))
                }
                className={styles.input}
                placeholder="ios"
                maxLength={ECONOMY_PROVIDER_CODE_MAX_LENGTH}
              />
            </label>
            <label className={styles.field}>
              <span>{text.regionColumn}</span>
              <input
                value={matchDraft.country}
                onChange={(event) =>
                  setMatchDraft((current) => ({
                    ...current,
                    country: normalizeProviderRegionInput(event.target.value),
                  }))
                }
                className={styles.input}
                placeholder="DE"
                maxLength={ECONOMY_PROVIDER_REGION_MAX_LENGTH}
              />
            </label>
            <label className={styles.field}>
              <span>{text.minVersionLabel}</span>
              <input
                value={matchDraft.appVersion}
                onChange={(event) =>
                  setMatchDraft((current) => ({
                    ...current,
                    appVersion: normalizeProviderVersionInput(event.target.value),
                  }))
                }
                className={styles.input}
                placeholder="1.0.0"
                maxLength={ECONOMY_PROVIDER_VERSION_MAX_LENGTH}
              />
            </label>
          </div>

          <Button
            onClick={requestTestProviderConfig}
            disabled={testProviderConfigPending || isProviderConfigMatchInvalid}
          >
            {testProviderConfigPending ? text.savingAction : text.providerConfigTestAction}
          </Button>

          {matchResult ? (
            <AdminStateCard
              tone={matchResult.allowedForCheckout ? "success" : "warning"}
              title={`${safeText(matchResult.decisionCode, 80)}: ${safeText(matchResult.decisionMessage, 180)}`}
              description={
                matchResult.matchedConfiguration
                  ? `${text.providerConfigMatchLabel}: ${humanizeProvider(matchResult.matchedConfiguration.provider, locale)}/${safeText(matchResult.matchedConfiguration.platform, 48)}/${safeText(matchResult.matchedConfiguration.region, 48)} (${safeText(matchResult.matchedConfiguration.mode, 48)})`
                  : text.providerConfigNoMatchLabel
              }
            />
          ) : null}
        </div>
      </div>

      <TableOrEmpty hasItems={providerConfigs.length > 0} emptyTitle={text.noProviderConfigs}>
        <div className={adminTableStyles.tableWrap}>
          <table className={adminTableStyles.table}>
            <thead>
              <tr>
                <th>{text.providerColumn}</th>
                <th>{text.platformColumn}</th>
                <th>{text.regionColumn}</th>
                <th>{text.statusColumn}</th>
                <th>{text.flagsColumn}</th>
                <th>{text.modeColumn}</th>
                <th>{text.actionsColumn}</th>
              </tr>
            </thead>
            <tbody>
              {providerConfigs.map((config) => {
                const draft =
                  providerConfigDrafts[config.configurationId] ?? toProviderConfigDraft(config);
                const isSavingConfig =
                  saveProviderConfigPending && saveProviderConfigId === config.configurationId;
                const isProviderConfigInvalid = isPaymentRouteDraftInvalid(draft);

                return (
                  <tr key={config.configurationId}>
                    <td>{humanizeProvider(config.provider, locale)}</td>
                    <td>{safeText(config.platform, 48)}</td>
                    <td>
                      <input
                        value={draft.region}
                        onChange={(event) =>
                          updateProviderConfigDraft(
                            setProviderConfigDrafts,
                            config.configurationId,
                            {
                              region: normalizeProviderRegionInput(event.target.value),
                            }
                          )
                        }
                        className={styles.input}
                        maxLength={ECONOMY_PROVIDER_REGION_MAX_LENGTH}
                      />
                    </td>
                    <td>
                      <label className={styles.checkboxField}>
                        <input
                          type="checkbox"
                          checked={draft.isEnabled}
                          onChange={(event) =>
                            updateProviderConfigDraft(
                              setProviderConfigDrafts,
                              config.configurationId,
                              {
                                isEnabled: event.target.checked,
                              }
                            )
                          }
                        />
                        <span>{draft.isEnabled ? text.activeState : text.inactiveState}</span>
                      </label>
                    </td>
                    <td>
                      <div className={styles.windowFields}>
                        <label className={styles.checkboxField}>
                          <input
                            type="checkbox"
                            checked={draft.externalCheckoutAllowed}
                            onChange={(event) =>
                              updateProviderConfigDraft(
                                setProviderConfigDrafts,
                                config.configurationId,
                                { externalCheckoutAllowed: event.target.checked }
                              )
                            }
                          />
                          <span>{text.externalCheckoutFlag}</span>
                        </label>
                        <label className={styles.checkboxField}>
                          <input
                            type="checkbox"
                            checked={draft.isRecommended}
                            onChange={(event) =>
                              updateProviderConfigDraft(
                                setProviderConfigDrafts,
                                config.configurationId,
                                {
                                  isRecommended: event.target.checked,
                                }
                              )
                            }
                          />
                          <span>{text.recommendedFlag}</span>
                        </label>
                        <label className={styles.checkboxField}>
                          <input
                            type="checkbox"
                            checked={draft.isSelectedByDefault}
                            onChange={(event) =>
                              updateProviderConfigDraft(
                                setProviderConfigDrafts,
                                config.configurationId,
                                { isSelectedByDefault: event.target.checked }
                              )
                            }
                          />
                          <span>{text.defaultFlag}</span>
                        </label>
                        <label className={styles.checkboxField}>
                          <input
                            type="checkbox"
                            checked={draft.requiresExternalWarning}
                            onChange={(event) =>
                              updateProviderConfigDraft(
                                setProviderConfigDrafts,
                                config.configurationId,
                                { requiresExternalWarning: event.target.checked }
                              )
                            }
                          />
                          <span>{text.externalWarningFlag}</span>
                        </label>
                        <label className={styles.checkboxField}>
                          <input
                            type="checkbox"
                            checked={draft.requiresStoreDisclosure}
                            onChange={(event) =>
                              updateProviderConfigDraft(
                                setProviderConfigDrafts,
                                config.configurationId,
                                { requiresStoreDisclosure: event.target.checked }
                              )
                            }
                          />
                          <span>{text.storeDisclosureFlag}</span>
                        </label>
                        <label className={styles.field}>
                          <span>{text.minVersionLabel}</span>
                          <input
                            value={draft.allowedFromAppVersion}
                            onChange={(event) =>
                              updateProviderConfigDraft(
                                setProviderConfigDrafts,
                                config.configurationId,
                                {
                                  allowedFromAppVersion: normalizeProviderVersionInput(
                                    event.target.value
                                  ),
                                }
                              )
                            }
                            className={styles.input}
                            maxLength={ECONOMY_PROVIDER_VERSION_MAX_LENGTH}
                          />
                        </label>
                        <label className={styles.field}>
                          <span>{text.bonusPercentLabel}</span>
                          <input
                            type="text"
                            inputMode="numeric"
                            pattern="[0-9]*"
                            value={draft.bonusTokensPercent}
                            onChange={(event) =>
                              updateProviderConfigDraft(
                                setProviderConfigDrafts,
                                config.configurationId,
                                {
                                  bonusTokensPercent: normalizeEconomyPercentInput(
                                    event.target.value
                                  ),
                                }
                              )
                            }
                            className={styles.input}
                            maxLength={ECONOMY_PROVIDER_BONUS_PERCENT_MAX_LENGTH}
                          />
                        </label>
                      </div>
                    </td>
                    <td>
                      <div className={styles.windowFields}>
                        <label className={styles.field}>
                          <span>{text.modeColumn}</span>
                          <input
                            value={draft.mode}
                            onChange={(event) =>
                              updateProviderConfigDraft(
                                setProviderConfigDrafts,
                                config.configurationId,
                                {
                                  mode: normalizeProviderCodeInput(event.target.value),
                                }
                              )
                            }
                            className={styles.input}
                            maxLength={ECONOMY_PROVIDER_CODE_MAX_LENGTH}
                          />
                        </label>
                        <label className={styles.field}>
                          <span>{text.displayLabelLabel}</span>
                          <input
                            value={draft.displayLabel}
                            onChange={(event) =>
                              updateProviderConfigDraft(
                                setProviderConfigDrafts,
                                config.configurationId,
                                {
                                  displayLabel: normalizeProviderLabelInput(event.target.value),
                                }
                              )
                            }
                            className={styles.input}
                            placeholder={humanizeProvider(config.provider, locale)}
                            maxLength={ECONOMY_PROVIDER_LABEL_MAX_LENGTH}
                          />
                        </label>
                        <label className={styles.field}>
                          <span>{text.displaySubtitleLabel}</span>
                          <input
                            value={draft.displaySubtitle}
                            onChange={(event) =>
                              updateProviderConfigDraft(
                                setProviderConfigDrafts,
                                config.configurationId,
                                {
                                  displaySubtitle: normalizeProviderLabelInput(
                                    event.target.value
                                  ),
                                }
                              )
                            }
                            className={styles.input}
                            placeholder={text.noDescription}
                            maxLength={ECONOMY_PROVIDER_LABEL_MAX_LENGTH}
                          />
                        </label>
                        <label className={styles.field}>
                          <span>{text.warningTitleLabel}</span>
                          <input
                            value={draft.warningTitle}
                            onChange={(event) =>
                              updateProviderConfigDraft(
                                setProviderConfigDrafts,
                                config.configurationId,
                                {
                                  warningTitle: normalizeProviderLabelInput(event.target.value),
                                }
                              )
                            }
                            className={styles.input}
                            placeholder={text.noDescription}
                            maxLength={ECONOMY_PROVIDER_LABEL_MAX_LENGTH}
                          />
                        </label>
                        <label className={styles.field}>
                          <span>{text.warningMessageLabel}</span>
                          <input
                            value={draft.warningMessage}
                            onChange={(event) =>
                              updateProviderConfigDraft(
                                setProviderConfigDrafts,
                                config.configurationId,
                                {
                                  warningMessage: normalizeProviderMessageInput(
                                    event.target.value
                                  ),
                                }
                              )
                            }
                            className={styles.input}
                            placeholder={text.noDescription}
                            maxLength={ECONOMY_PROVIDER_MESSAGE_MAX_LENGTH}
                          />
                        </label>
                        <label className={styles.field}>
                          <span>{text.notesLabel}</span>
                          <input
                            value={draft.notes}
                            onChange={(event) =>
                              updateProviderConfigDraft(
                                setProviderConfigDrafts,
                                config.configurationId,
                                {
                                  notes: normalizeProviderMessageInput(event.target.value),
                                }
                              )
                            }
                            className={styles.input}
                            placeholder={text.noDescription}
                            maxLength={ECONOMY_PROVIDER_MESSAGE_MAX_LENGTH}
                          />
                        </label>
                      </div>
                    </td>
                    <td>
                      <div className={styles.tableActions}>
                        <Button
                          onClick={() => {
                            if (saveProviderConfigPending || isProviderConfigInvalid) {
                              return;
                            }

                            onSaveProviderConfig(config.configurationId);
                          }}
                          disabled={saveProviderConfigPending || isProviderConfigInvalid}
                        >
                          {isSavingConfig ? text.savingAction : text.saveAction}
                        </Button>

                        <input
                          value={cloneRegionDrafts[config.configurationId] ?? ""}
                          onChange={(event) =>
                            setCloneRegionDrafts((current) => ({
                              ...current,
                              [config.configurationId]: normalizeProviderRegionInput(
                                event.target.value
                              ),
                            }))
                          }
                          className={styles.input}
                          placeholder={text.cloneRegionPlaceholder}
                          maxLength={ECONOMY_PROVIDER_REGION_MAX_LENGTH}
                        />

                        <Button
                          onClick={() => {
                            const cloneRegion = (cloneRegionDrafts[config.configurationId] ?? "")
                              .trim();
                            if (cloneProviderConfigPending || !cloneRegion) {
                              return;
                            }

                            onCloneProviderConfig({
                              configurationId: config.configurationId,
                              region: cloneRegion,
                            });
                          }}
                          disabled={
                            cloneProviderConfigPending ||
                            !(cloneRegionDrafts[config.configurationId] ?? "").trim()
                          }
                        >
                          {cloneProviderConfigPending &&
                          cloneProviderConfigId === config.configurationId
                            ? text.savingAction
                            : text.cloneAction}
                        </Button>

                        <Button
                          onClick={() => {
                            if (deleteProviderConfigPending) {
                              return;
                            }

                            setConfigurationPendingDeleteId(config.configurationId);
                          }}
                          disabled={deleteProviderConfigPending}
                          variant="danger"
                        >
                          {deleteProviderConfigPending &&
                          deleteProviderConfigId === config.configurationId
                            ? text.savingAction
                            : text.deleteAction}
                        </Button>
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </TableOrEmpty>
      <ConfirmationDialog
        open={configurationPendingDeleteId !== null}
        title={text.deleteAction}
        description={
          configurationPendingDelete
            ? `${humanizeProvider(configurationPendingDelete.provider, locale)} / ${safeText(configurationPendingDelete.region, 48)}: ${text.providerConfigDeleteConfirm}`
            : text.providerConfigDeleteConfirm
        }
        confirmLabel={text.deleteAction}
        cancelLabel={locale === "ru" ? "Отмена" : "Cancel"}
        isSubmitting={Boolean(
          configurationPendingDeleteId && deleteProviderConfigId === configurationPendingDeleteId
        )}
        onCancel={() => {
          if (!deleteProviderConfigPending) {
            setConfigurationPendingDeleteId(null);
          }
        }}
        onConfirm={() => {
          if (deleteProviderConfigPending) {
            return;
          }

          if (!configurationPendingDeleteId) {
            return;
          }

          void onDeleteProviderConfig(configurationPendingDeleteId).then((succeeded) => {
            if (succeeded) {
              setConfigurationPendingDeleteId(null);
            }
          });
        }}
      />
    </AdminCard>
  );
}

function safeText(value: string | null | undefined, maxLength = 120) {
  const trimmed = value?.trim();
  return trimmed ? sanitizeSensitiveText(trimmed, maxLength) : "-";
}

function normalizeProviderCodeInput(value: string) {
  return value.toLowerCase().slice(0, ECONOMY_PROVIDER_CODE_MAX_LENGTH);
}

function normalizeProviderRegionInput(value: string) {
  return value.toUpperCase().slice(0, ECONOMY_PROVIDER_REGION_MAX_LENGTH);
}

function normalizeProviderVersionInput(value: string) {
  return value.slice(0, ECONOMY_PROVIDER_VERSION_MAX_LENGTH);
}

function normalizeProviderLabelInput(value: string) {
  return value.slice(0, ECONOMY_PROVIDER_LABEL_MAX_LENGTH);
}

function normalizeProviderMessageInput(value: string) {
  return value.slice(0, ECONOMY_PROVIDER_MESSAGE_MAX_LENGTH);
}

function isPaymentRouteDraftInvalid(draft: ProviderConfigDraft) {
  const bonusPercent = Number(draft.bonusTokensPercent);

  return (
    !draft.region.trim() ||
    !draft.mode.trim() ||
    !draft.allowedFromAppVersion.trim() ||
    !draft.bonusTokensPercent.trim() ||
    !Number.isInteger(bonusPercent) ||
    bonusPercent < 0 ||
    bonusPercent > 100
  );
}
