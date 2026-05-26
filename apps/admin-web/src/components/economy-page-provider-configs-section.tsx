import { type Dispatch, type ReactNode, type SetStateAction } from "react";

import { AdminCard, AdminStateCard, adminTableStyles } from "@/components/admin/admin-primitives";
import { type EconomyPageText } from "@/components/economy-page.content";
import {
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
  onDeleteProviderConfig: (configurationId: string) => void;
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
                    provider: event.target.value.toLowerCase(),
                  }))
                }
                className={styles.input}
                placeholder="stripe"
              />
            </label>
            <label className={styles.field}>
              <span>{text.platformColumn}</span>
              <input
                value={createProviderDraft.platform}
                onChange={(event) =>
                  setCreateProviderDraft((current) => ({
                    ...current,
                    platform: event.target.value.toLowerCase(),
                  }))
                }
                className={styles.input}
                placeholder="web"
              />
            </label>
            <label className={styles.field}>
              <span>{text.regionColumn}</span>
              <input
                value={createProviderDraft.region}
                onChange={(event) =>
                  setCreateProviderDraft((current) => ({
                    ...current,
                    region: event.target.value.toUpperCase(),
                  }))
                }
                className={styles.input}
                placeholder="US"
              />
            </label>
            <label className={styles.field}>
              <span>{text.modeColumn}</span>
              <input
                value={createProviderDraft.mode}
                onChange={(event) =>
                  setCreateProviderDraft((current) => ({
                    ...current,
                    mode: event.target.value.toLowerCase(),
                  }))
                }
                className={styles.input}
                placeholder="test"
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
                    allowedFromAppVersion: event.target.value,
                  }))
                }
                className={styles.input}
              />
            </label>
            <label className={styles.field}>
              <span>{text.bonusPercentLabel}</span>
              <input
                type="number"
                min="0"
                max="100"
                value={createProviderDraft.bonusTokensPercent}
                onChange={(event) =>
                  setCreateProviderDraft((current) => ({
                    ...current,
                    bonusTokensPercent: event.target.value,
                  }))
                }
                className={styles.input}
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

          <Button onClick={onCreateProviderConfig} disabled={createProviderConfigPending}>
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
                    provider: event.target.value.toLowerCase(),
                  }))
                }
                className={styles.input}
                placeholder="stripe"
              />
            </label>
            <label className={styles.field}>
              <span>{text.platformColumn}</span>
              <input
                value={matchDraft.platform}
                onChange={(event) =>
                  setMatchDraft((current) => ({
                    ...current,
                    platform: event.target.value.toLowerCase(),
                  }))
                }
                className={styles.input}
                placeholder="ios"
              />
            </label>
            <label className={styles.field}>
              <span>{text.regionColumn}</span>
              <input
                value={matchDraft.country}
                onChange={(event) =>
                  setMatchDraft((current) => ({
                    ...current,
                    country: event.target.value.toUpperCase(),
                  }))
                }
                className={styles.input}
                placeholder="DE"
              />
            </label>
            <label className={styles.field}>
              <span>{text.minVersionLabel}</span>
              <input
                value={matchDraft.appVersion}
                onChange={(event) =>
                  setMatchDraft((current) => ({ ...current, appVersion: event.target.value }))
                }
                className={styles.input}
                placeholder="1.0.0"
              />
            </label>
          </div>

          <Button onClick={onTestProviderConfig} disabled={testProviderConfigPending}>
            {testProviderConfigPending ? text.savingAction : text.providerConfigTestAction}
          </Button>

          {matchResult ? (
            <AdminStateCard
              tone={matchResult.allowedForCheckout ? "success" : "warning"}
              title={`${matchResult.decisionCode}: ${matchResult.decisionMessage}`}
              description={
                matchResult.matchedConfiguration
                  ? `${text.providerConfigMatchLabel}: ${matchResult.matchedConfiguration.provider}/${matchResult.matchedConfiguration.platform}/${matchResult.matchedConfiguration.region} (${matchResult.matchedConfiguration.mode})`
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

                return (
                  <tr key={config.configurationId}>
                    <td>{humanizeProvider(config.provider, locale)}</td>
                    <td>{config.platform}</td>
                    <td>
                      <input
                        value={draft.region}
                        onChange={(event) =>
                          updateProviderConfigDraft(
                            setProviderConfigDrafts,
                            config.configurationId,
                            {
                              region: event.target.value.toUpperCase(),
                            }
                          )
                        }
                        className={styles.input}
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
                                  allowedFromAppVersion: event.target.value,
                                }
                              )
                            }
                            className={styles.input}
                          />
                        </label>
                        <label className={styles.field}>
                          <span>{text.bonusPercentLabel}</span>
                          <input
                            type="number"
                            min="0"
                            max="100"
                            value={draft.bonusTokensPercent}
                            onChange={(event) =>
                              updateProviderConfigDraft(
                                setProviderConfigDrafts,
                                config.configurationId,
                                {
                                  bonusTokensPercent: event.target.value,
                                }
                              )
                            }
                            className={styles.input}
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
                                  mode: event.target.value,
                                }
                              )
                            }
                            className={styles.input}
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
                                  displayLabel: event.target.value,
                                }
                              )
                            }
                            className={styles.input}
                            placeholder={humanizeProvider(config.provider, locale)}
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
                                  displaySubtitle: event.target.value,
                                }
                              )
                            }
                            className={styles.input}
                            placeholder={text.noDescription}
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
                                  warningTitle: event.target.value,
                                }
                              )
                            }
                            className={styles.input}
                            placeholder={text.noDescription}
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
                                  warningMessage: event.target.value,
                                }
                              )
                            }
                            className={styles.input}
                            placeholder={text.noDescription}
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
                                  notes: event.target.value,
                                }
                              )
                            }
                            className={styles.input}
                            placeholder={text.noDescription}
                          />
                        </label>
                      </div>
                    </td>
                    <td>
                      <div className={styles.tableActions}>
                        <Button
                          onClick={() => onSaveProviderConfig(config.configurationId)}
                          disabled={isSavingConfig}
                        >
                          {isSavingConfig ? text.savingAction : text.saveAction}
                        </Button>

                        <input
                          value={cloneRegionDrafts[config.configurationId] ?? ""}
                          onChange={(event) =>
                            setCloneRegionDrafts((current) => ({
                              ...current,
                              [config.configurationId]: event.target.value.toUpperCase(),
                            }))
                          }
                          className={styles.input}
                          placeholder={text.cloneRegionPlaceholder}
                        />

                        <Button
                          onClick={() =>
                            onCloneProviderConfig({
                              configurationId: config.configurationId,
                              region: (cloneRegionDrafts[config.configurationId] ?? "").trim(),
                            })
                          }
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
                            if (!window.confirm(text.providerConfigDeleteConfirm)) {
                              return;
                            }

                            onDeleteProviderConfig(config.configurationId);
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
    </AdminCard>
  );
}
