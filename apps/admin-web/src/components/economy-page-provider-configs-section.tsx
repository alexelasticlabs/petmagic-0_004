import {
  type Dispatch,
  type ReactNode,
  type SetStateAction,
  useEffect,
  useMemo,
  useState,
} from "react";

import { AdminCard, AdminStateCard } from "@/components/admin/admin-primitives";
import { ConfirmationDialog } from "@/components/admin/confirmation-dialog";
import { EconomySelectField } from "@/components/economy-page-select-field";
import { type EconomyPageText } from "@/components/economy-page.content";
import {
  ECONOMY_PROVIDER_BONUS_PERCENT_MAX_LENGTH,
  ECONOMY_PROVIDER_LABEL_MAX_LENGTH,
  ECONOMY_PROVIDER_MESSAGE_MAX_LENGTH,
  ECONOMY_PROVIDER_NOTES_MAX_LENGTH,
  ECONOMY_PROVIDER_REGION_MAX_LENGTH,
  ECONOMY_PROVIDER_SUBTITLE_MAX_LENGTH,
  ECONOMY_PROVIDER_VERSION_MAX_LENGTH,
  ECONOMY_PROVIDER_WARNING_TITLE_MAX_LENGTH,
  isProviderConfigCreateDraftInvalid,
  isProviderConfigDraftDirty,
  isProviderConfigDraftInvalid,
  isProviderConfigMatchDraftInvalid,
  normalizeEconomyPercentInput,
  paymentPlatformOptions,
  paymentProviderOptions,
  paymentRouteModeOptions,
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

const providerOptions = paymentProviderOptions.map((value) => ({
  value,
  label: value === "stripe" ? "Stripe" : value === "app_store" ? "Apple App Store" : "Google Play",
}));
const platformOptions = paymentPlatformOptions.map((value) => ({
  value,
  label: value.toUpperCase(),
}));

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
  const [configurationPendingClone, setConfigurationPendingClone] = useState<{
    configurationId: string;
    region: string;
  } | null>(null);
  const [editingConfigurationId, setEditingConfigurationId] = useState<string | null>(null);
  const configurationPendingDelete = configurationPendingDeleteId
    ? providerConfigs.find((config) => config.configurationId === configurationPendingDeleteId)
    : null;
  const configurationPendingCloneSource = configurationPendingClone
    ? providerConfigs.find(
        (config) => config.configurationId === configurationPendingClone.configurationId
      )
    : null;
  const providerConfigIds = useMemo(
    () => new Set(providerConfigs.map((config) => config.configurationId)),
    [providerConfigs]
  );
  const editingConfiguration = editingConfigurationId
    ? providerConfigs.find((config) => config.configurationId === editingConfigurationId)
    : null;

  useEffect(() => {
    let isActive = true;
    if (
      !configurationPendingDeleteId ||
      providerConfigIds.has(configurationPendingDeleteId) ||
      deleteProviderConfigPending
    ) {
      return;
    }

    queueMicrotask(() => {
      if (isActive) {
        setConfigurationPendingDeleteId(null);
      }
    });

    return () => {
      isActive = false;
    };
  }, [configurationPendingDeleteId, deleteProviderConfigPending, providerConfigIds]);

  useEffect(() => {
    let isActive = true;
    if (
      !configurationPendingClone ||
      providerConfigIds.has(configurationPendingClone.configurationId) ||
      cloneProviderConfigPending
    ) {
      return;
    }

    queueMicrotask(() => {
      if (isActive) {
        setConfigurationPendingClone(null);
      }
    });

    return () => {
      isActive = false;
    };
  }, [cloneProviderConfigPending, configurationPendingClone, providerConfigIds]);

  useEffect(() => {
    let isActive = true;
    if (!editingConfigurationId || providerConfigIds.has(editingConfigurationId)) {
      return;
    }

    queueMicrotask(() => {
      if (isActive) {
        setEditingConfigurationId(null);
      }
    });

    return () => {
      isActive = false;
    };
  }, [editingConfigurationId, providerConfigIds]);

  const isCreateProviderRegionValid = isValidPaymentRouteRegion(createProviderDraft.region);
  const isProviderConfigMatchCountryValid = isValidPaymentRouteCountry(matchDraft.country);
  const isCreateProviderConfigInvalid =
    !isCreateProviderRegionValid || isProviderConfigCreateDraftInvalid(createProviderDraft);
  const isProviderConfigMatchInvalid =
    !isProviderConfigMatchCountryValid || isProviderConfigMatchDraftInvalid(matchDraft);
  const modeOptions = paymentRouteModeOptions.map((value) => ({
    value,
    label: value === "test" ? text.providerModeTestLabel : text.providerModeLiveLabel,
  }));
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
        <details className={`${styles.redeemForm} ${styles.utilityDisclosure}`}>
          <summary className={styles.utilityDisclosureSummary}>
            <strong>{text.providerConfigCreateTitle}</strong>
            <span>{text.providerConfigCreateAction}</span>
          </summary>
          <div className={styles.formRow}>
            <EconomySelectField
              label={text.providerColumn}
              value={createProviderDraft.provider}
              options={providerOptions}
              disabled={createProviderConfigPending}
              onChange={(provider) =>
                setCreateProviderDraft((current) => ({ ...current, provider }))
              }
            />
            <EconomySelectField
              label={text.platformColumn}
              value={createProviderDraft.platform}
              options={platformOptions}
              disabled={createProviderConfigPending}
              onChange={(platform) =>
                setCreateProviderDraft((current) => ({ ...current, platform }))
              }
            />
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
                placeholder={text.providerRegionPlaceholder}
                maxLength={ECONOMY_PROVIDER_REGION_MAX_LENGTH}
                pattern="[A-Za-z]{2}|[*]"
                aria-invalid={!isCreateProviderRegionValid || undefined}
                disabled={createProviderConfigPending}
              />
            </label>
            <EconomySelectField
              label={text.modeColumn}
              value={createProviderDraft.mode}
              options={modeOptions}
              disabled={createProviderConfigPending}
              onChange={(mode) => setCreateProviderDraft((current) => ({ ...current, mode }))}
            />
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
                placeholder={text.providerAppVersionPlaceholder}
                maxLength={ECONOMY_PROVIDER_VERSION_MAX_LENGTH}
                disabled={createProviderConfigPending}
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
                placeholder={text.providerBonusPlaceholder}
                maxLength={ECONOMY_PROVIDER_BONUS_PERCENT_MAX_LENGTH}
                disabled={createProviderConfigPending}
              />
            </label>
          </div>

          <div className={styles.flagList}>
            <label className={styles.checkboxField}>
              <input
                type="checkbox"
                checked={createProviderDraft.isEnabled}
                disabled={createProviderConfigPending}
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
                disabled={createProviderConfigPending}
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
                disabled={createProviderConfigPending}
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
                disabled={createProviderConfigPending}
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
        </details>

        <details className={`${styles.redeemForm} ${styles.utilityDisclosure}`}>
          <summary className={styles.utilityDisclosureSummary}>
            <strong>{text.providerConfigTestTitle}</strong>
            <span>{text.providerConfigTestAction}</span>
          </summary>
          <div className={styles.formRow}>
            <EconomySelectField
              label={text.providerColumn}
              value={matchDraft.provider}
              options={providerOptions}
              disabled={testProviderConfigPending}
              onChange={(provider) => setMatchDraft((current) => ({ ...current, provider }))}
            />
            <EconomySelectField
              label={text.platformColumn}
              value={matchDraft.platform}
              options={platformOptions}
              disabled={testProviderConfigPending}
              onChange={(platform) => setMatchDraft((current) => ({ ...current, platform }))}
            />
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
                placeholder={text.providerRegionPlaceholder}
                maxLength={ECONOMY_PROVIDER_REGION_MAX_LENGTH}
                pattern="[A-Za-z]{2}"
                aria-invalid={!isProviderConfigMatchCountryValid || undefined}
                disabled={testProviderConfigPending}
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
                placeholder={text.providerAppVersionPlaceholder}
                maxLength={ECONOMY_PROVIDER_VERSION_MAX_LENGTH}
                disabled={testProviderConfigPending}
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
                  ? `${text.providerConfigMatchLabel}: ${humanizeProvider(matchResult.matchedConfiguration.provider, locale)}/${safeText(matchResult.matchedConfiguration.platform, 48)}/${safeText(matchResult.matchedConfiguration.region, 48)} (${humanizeRouteMode(matchResult.matchedConfiguration.mode, text)})`
                  : text.providerConfigNoMatchLabel
              }
            />
          ) : null}
        </details>
      </div>

      <TableOrEmpty hasItems={providerConfigs.length > 0} emptyTitle={text.noProviderConfigs}>
        <ul className={styles.providerConfigSummaryList} aria-label={text.providerConfigsTitle}>
          {providerConfigs.map((config) => {
            const draft =
              providerConfigDrafts[config.configurationId] ?? toProviderConfigDraft(config);
            const isProviderConfigDraftDirtyState = isProviderConfigDraftDirty(config, draft);
            const isProviderConfigBusy =
              (saveProviderConfigPending && saveProviderConfigId === config.configurationId) ||
              (cloneProviderConfigPending && cloneProviderConfigId === config.configurationId) ||
              (deleteProviderConfigPending && deleteProviderConfigId === config.configurationId);
            const isProviderConfigEditorOpen = editingConfigurationId === config.configurationId;
            const editorId = `economy-provider-config-editor-${config.configurationId}`;

            return (
              <li
                key={config.configurationId}
                className={styles.providerConfigSummaryItem}
                data-selected={isProviderConfigEditorOpen || undefined}
              >
                <div className={styles.providerConfigSummaryIdentity}>
                  <strong>{humanizeProvider(config.provider, locale)}</strong>
                  <span>
                    {safeText(config.platform.toUpperCase(), 48)} · {safeText(draft.region, 48)}
                  </span>
                </div>

                <div className={styles.providerConfigSummaryValue}>
                  <strong>{humanizeRouteMode(draft.mode, text)}</strong>
                  <span>
                    {text.minVersionLabel}: {safeText(draft.allowedFromAppVersion, 48)}
                  </span>
                </div>

                <div className={`${styles.flagList} ${styles.providerConfigSummaryFlags}`}>
                  <span>{draft.isEnabled ? text.activeState : text.inactiveState}</span>
                  {draft.externalCheckoutAllowed ? <span>{text.externalCheckoutFlag}</span> : null}
                  {draft.isRecommended ? <span>{text.recommendedFlag}</span> : null}
                  {draft.isSelectedByDefault ? <span>{text.defaultFlag}</span> : null}
                  {draft.requiresExternalWarning ? <span>{text.externalWarningFlag}</span> : null}
                  {draft.requiresStoreDisclosure ? <span>{text.storeDisclosureFlag}</span> : null}
                  {isProviderConfigDraftDirtyState ? (
                    <span className={styles.providerConfigSummaryDirty}>
                      {text.unsavedChangesLabel}
                    </span>
                  ) : null}
                </div>

                <Button
                  aria-controls={editorId}
                  aria-expanded={isProviderConfigEditorOpen}
                  aria-label={`${text.editAction}: ${humanizeProvider(config.provider, locale)} / ${safeText(config.platform, 48)} / ${safeText(draft.region, 48)}`}
                  disabled={isProviderConfigBusy}
                  onClick={() =>
                    setEditingConfigurationId((currentConfigurationId) =>
                      currentConfigurationId === config.configurationId
                        ? null
                        : config.configurationId
                    )
                  }
                >
                  {text.editAction}
                </Button>
              </li>
            );
          })}
        </ul>

        {editingConfiguration ? (
          <ProviderConfigEditor
            editorId={`economy-provider-config-editor-${editingConfiguration.configurationId}`}
            locale={locale}
            text={text}
            config={editingConfiguration}
            draft={
              providerConfigDrafts[editingConfiguration.configurationId] ??
              toProviderConfigDraft(editingConfiguration)
            }
            setProviderConfigDrafts={setProviderConfigDrafts}
            cloneRegion={cloneRegionDrafts[editingConfiguration.configurationId] ?? ""}
            setCloneRegionDrafts={setCloneRegionDrafts}
            modeOptions={modeOptions}
            saveProviderConfigPending={saveProviderConfigPending}
            saveProviderConfigId={saveProviderConfigId}
            cloneProviderConfigPending={cloneProviderConfigPending}
            cloneProviderConfigId={cloneProviderConfigId}
            deleteProviderConfigPending={deleteProviderConfigPending}
            deleteProviderConfigId={deleteProviderConfigId}
            onSaveProviderConfig={onSaveProviderConfig}
            onRequestClone={(region) =>
              setConfigurationPendingClone({
                configurationId: editingConfiguration.configurationId,
                region,
              })
            }
            onRequestDelete={() =>
              setConfigurationPendingDeleteId(editingConfiguration.configurationId)
            }
            onClose={() => setEditingConfigurationId(null)}
            humanizeProvider={humanizeProvider}
          />
        ) : null}
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
        cancelLabel={text.confirmationCancel}
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
      <ConfirmationDialog
        open={configurationPendingClone !== null}
        title={text.providerConfigCloneConfirmTitle}
        description={
          configurationPendingClone && configurationPendingCloneSource
            ? `${humanizeProvider(configurationPendingCloneSource.provider, locale)} / ${safeText(configurationPendingCloneSource.platform, 48)} / ${configurationPendingClone.region} · ${humanizeRouteMode(configurationPendingCloneSource.mode, text)} · ${configurationPendingCloneSource.isEnabled ? text.activeState : text.inactiveState}${configurationPendingCloneSource.isSelectedByDefault ? ` · ${text.defaultFlag}` : ""}. ${text.providerConfigCloneConfirmDescription}`
            : text.providerConfigCloneConfirmDescription
        }
        confirmLabel={text.cloneAction}
        cancelLabel={text.confirmationCancel}
        isSubmitting={false}
        onCancel={() => setConfigurationPendingClone(null)}
        onConfirm={() => {
          if (
            !configurationPendingClone ||
            !configurationPendingCloneSource ||
            cloneProviderConfigPending ||
            !isValidPaymentRouteRegion(configurationPendingClone.region)
          ) {
            return;
          }

          const payload = configurationPendingClone;
          setConfigurationPendingClone(null);
          onCloneProviderConfig(payload);
        }}
      />
    </AdminCard>
  );
}

type ProviderConfigEditorProps = {
  editorId: string;
  locale: Locale;
  text: EconomyPageText;
  config: AdminPaymentProviderConfiguration;
  draft: ProviderConfigDraft;
  setProviderConfigDrafts: Dispatch<SetStateAction<Record<string, ProviderConfigDraft>>>;
  cloneRegion: string;
  setCloneRegionDrafts: Dispatch<SetStateAction<Record<string, string>>>;
  modeOptions: Array<{ value: string; label: string }>;
  saveProviderConfigPending: boolean;
  saveProviderConfigId?: string;
  cloneProviderConfigPending: boolean;
  cloneProviderConfigId?: string;
  deleteProviderConfigPending: boolean;
  deleteProviderConfigId?: string;
  onSaveProviderConfig: (configurationId: string) => void;
  onRequestClone: (region: string) => void;
  onRequestDelete: () => void;
  onClose: () => void;
  humanizeProvider: (value: string, locale: Locale) => string;
};

function ProviderConfigEditor({
  editorId,
  locale,
  text,
  config,
  draft,
  setProviderConfigDrafts,
  cloneRegion,
  setCloneRegionDrafts,
  modeOptions,
  saveProviderConfigPending,
  saveProviderConfigId,
  cloneProviderConfigPending,
  cloneProviderConfigId,
  deleteProviderConfigPending,
  deleteProviderConfigId,
  onSaveProviderConfig,
  onRequestClone,
  onRequestDelete,
  onClose,
  humanizeProvider,
}: ProviderConfigEditorProps) {
  const isSavingConfig =
    saveProviderConfigPending && saveProviderConfigId === config.configurationId;
  const isProviderConfigRegionValid = isValidPaymentRouteRegion(draft.region);
  const isProviderConfigInvalid =
    !isProviderConfigRegionValid || isProviderConfigDraftInvalid(draft);
  const isProviderConfigDraftLocked =
    isSavingConfig ||
    (cloneProviderConfigPending && cloneProviderConfigId === config.configurationId) ||
    (deleteProviderConfigPending && deleteProviderConfigId === config.configurationId);
  const isSaveProviderConfigDisabled =
    saveProviderConfigPending ||
    isProviderConfigInvalid ||
    !isProviderConfigDraftDirty(config, draft);
  const isCloneRegionValid = isValidPaymentRouteRegion(cloneRegion);
  const isCloneProviderConfigDisabled =
    isProviderConfigDraftLocked || cloneProviderConfigPending || !isCloneRegionValid;

  function updateDraft(patch: Partial<ProviderConfigDraft>) {
    updateProviderConfigDraft(setProviderConfigDrafts, config.configurationId, patch);
  }

  return (
    <section
      className={styles.providerConfigEditor}
      id={editorId}
      aria-labelledby={`${editorId}-title`}
    >
      <div className={styles.providerConfigEditorHeader}>
        <div className={styles.packMeta}>
          <h3 id={`${editorId}-title`}>
            {`${text.editAction}: ${humanizeProvider(config.provider, locale)}`}
          </h3>
          <span>
            {safeText(config.platform.toUpperCase(), 48)} · {safeText(draft.region, 48)}
          </span>
        </div>
        <button
          type="button"
          className={styles.pagerButton}
          disabled={isProviderConfigDraftLocked}
          onClick={onClose}
        >
          {text.collapseEditorAction}
        </button>
      </div>

      <form
        className={styles.providerConfigEditorForm}
        onSubmit={(event) => {
          event.preventDefault();
          if (!isSaveProviderConfigDisabled) {
            onSaveProviderConfig(config.configurationId);
          }
        }}
      >
        <div className={styles.providerConfigEditorRouteFields}>
          <label className={styles.field}>
            <span>{text.regionColumn}</span>
            <input
              value={draft.region}
              onChange={(event) =>
                updateDraft({ region: normalizeProviderRegionInput(event.target.value) })
              }
              className={styles.input}
              maxLength={ECONOMY_PROVIDER_REGION_MAX_LENGTH}
              pattern="[A-Za-z]{2}|[*]"
              aria-invalid={!isProviderConfigRegionValid || undefined}
              disabled={isProviderConfigDraftLocked}
            />
          </label>
          <EconomySelectField
            label={text.modeColumn}
            value={draft.mode}
            options={modeOptions}
            onChange={(mode) => updateDraft({ mode })}
            disabled={isProviderConfigDraftLocked}
          />
          <label className={styles.field}>
            <span>{text.minVersionLabel}</span>
            <input
              value={draft.allowedFromAppVersion}
              onChange={(event) =>
                updateDraft({
                  allowedFromAppVersion: normalizeProviderVersionInput(event.target.value),
                })
              }
              className={styles.input}
              maxLength={ECONOMY_PROVIDER_VERSION_MAX_LENGTH}
              disabled={isProviderConfigDraftLocked}
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
                updateDraft({
                  bonusTokensPercent: normalizeEconomyPercentInput(event.target.value),
                })
              }
              className={styles.input}
              maxLength={ECONOMY_PROVIDER_BONUS_PERCENT_MAX_LENGTH}
              disabled={isProviderConfigDraftLocked}
            />
          </label>
        </div>

        <div className={styles.providerConfigEditorFlags}>
          <label className={styles.checkboxField}>
            <input
              type="checkbox"
              checked={draft.isEnabled}
              disabled={isProviderConfigDraftLocked}
              onChange={(event) => updateDraft({ isEnabled: event.target.checked })}
            />
            <span>{draft.isEnabled ? text.activeState : text.inactiveState}</span>
          </label>
          <label className={styles.checkboxField}>
            <input
              type="checkbox"
              checked={draft.externalCheckoutAllowed}
              disabled={isProviderConfigDraftLocked}
              onChange={(event) => updateDraft({ externalCheckoutAllowed: event.target.checked })}
            />
            <span>{text.externalCheckoutFlag}</span>
          </label>
          <label className={styles.checkboxField}>
            <input
              type="checkbox"
              checked={draft.isRecommended}
              disabled={isProviderConfigDraftLocked}
              onChange={(event) => updateDraft({ isRecommended: event.target.checked })}
            />
            <span>{text.recommendedFlag}</span>
          </label>
          <label className={styles.checkboxField}>
            <input
              type="checkbox"
              checked={draft.isSelectedByDefault}
              disabled={isProviderConfigDraftLocked}
              onChange={(event) => updateDraft({ isSelectedByDefault: event.target.checked })}
            />
            <span>{text.defaultFlag}</span>
          </label>
          <label className={styles.checkboxField}>
            <input
              type="checkbox"
              checked={draft.requiresExternalWarning}
              disabled={isProviderConfigDraftLocked}
              onChange={(event) => updateDraft({ requiresExternalWarning: event.target.checked })}
            />
            <span>{text.externalWarningFlag}</span>
          </label>
          <label className={styles.checkboxField}>
            <input
              type="checkbox"
              checked={draft.requiresStoreDisclosure}
              disabled={isProviderConfigDraftLocked}
              onChange={(event) => updateDraft({ requiresStoreDisclosure: event.target.checked })}
            />
            <span>{text.storeDisclosureFlag}</span>
          </label>
        </div>

        <div className={styles.providerConfigEditorDisplayFields}>
          <label className={styles.field}>
            <span>{text.displayLabelLabel}</span>
            <input
              value={draft.displayLabel}
              onChange={(event) =>
                updateDraft({
                  displayLabel: normalizeProviderTextInput(
                    event.target.value,
                    ECONOMY_PROVIDER_LABEL_MAX_LENGTH
                  ),
                })
              }
              className={styles.input}
              placeholder={humanizeProvider(config.provider, locale)}
              maxLength={ECONOMY_PROVIDER_LABEL_MAX_LENGTH}
              disabled={isProviderConfigDraftLocked}
            />
          </label>
          <label className={styles.field}>
            <span>{text.displaySubtitleLabel}</span>
            <input
              value={draft.displaySubtitle}
              onChange={(event) =>
                updateDraft({
                  displaySubtitle: normalizeProviderTextInput(
                    event.target.value,
                    ECONOMY_PROVIDER_SUBTITLE_MAX_LENGTH
                  ),
                })
              }
              className={styles.input}
              placeholder={text.noDescription}
              maxLength={ECONOMY_PROVIDER_SUBTITLE_MAX_LENGTH}
              disabled={isProviderConfigDraftLocked}
            />
          </label>
          <label className={styles.field}>
            <span>{text.warningTitleLabel}</span>
            <input
              value={draft.warningTitle}
              onChange={(event) =>
                updateDraft({
                  warningTitle: normalizeProviderTextInput(
                    event.target.value,
                    ECONOMY_PROVIDER_WARNING_TITLE_MAX_LENGTH
                  ),
                })
              }
              className={styles.input}
              placeholder={text.noDescription}
              maxLength={ECONOMY_PROVIDER_WARNING_TITLE_MAX_LENGTH}
              disabled={isProviderConfigDraftLocked}
            />
          </label>
          <label className={styles.field}>
            <span>{text.warningMessageLabel}</span>
            <input
              value={draft.warningMessage}
              onChange={(event) =>
                updateDraft({
                  warningMessage: normalizeProviderTextInput(
                    event.target.value,
                    ECONOMY_PROVIDER_MESSAGE_MAX_LENGTH
                  ),
                })
              }
              className={styles.input}
              placeholder={text.noDescription}
              maxLength={ECONOMY_PROVIDER_MESSAGE_MAX_LENGTH}
              disabled={isProviderConfigDraftLocked}
            />
          </label>
          <label className={styles.field}>
            <span>{text.notesLabel}</span>
            <input
              value={draft.notes}
              onChange={(event) =>
                updateDraft({
                  notes: normalizeProviderTextInput(
                    event.target.value,
                    ECONOMY_PROVIDER_NOTES_MAX_LENGTH
                  ),
                })
              }
              className={styles.input}
              placeholder={text.noDescription}
              maxLength={ECONOMY_PROVIDER_NOTES_MAX_LENGTH}
              disabled={isProviderConfigDraftLocked}
            />
          </label>
        </div>

        <div className={styles.providerConfigEditorClone}>
          <label className={styles.field}>
            <span>{text.cloneRegionPlaceholder}</span>
            <input
              value={cloneRegion}
              onChange={(event) =>
                setCloneRegionDrafts((current) => ({
                  ...current,
                  [config.configurationId]: normalizeProviderRegionInput(event.target.value),
                }))
              }
              className={styles.input}
              placeholder={text.providerRegionPlaceholder}
              maxLength={ECONOMY_PROVIDER_REGION_MAX_LENGTH}
              pattern="[A-Za-z]{2}|[*]"
              aria-invalid={!isCloneRegionValid || undefined}
              disabled={isProviderConfigDraftLocked}
            />
          </label>
          <Button
            type="button"
            onClick={() => {
              const nextCloneRegion = cloneRegion.trim();
              if (isCloneProviderConfigDisabled) {
                return;
              }

              onRequestClone(nextCloneRegion);
            }}
            disabled={isCloneProviderConfigDisabled}
            aria-label={`${text.cloneAction}: ${humanizeProvider(config.provider, locale)} / ${safeText(config.platform, 48)} / ${cloneRegion}`}
          >
            {cloneProviderConfigPending && cloneProviderConfigId === config.configurationId
              ? text.savingAction
              : text.cloneAction}
          </Button>
        </div>

        <div className={styles.providerConfigEditorActions}>
          <Button type="submit" disabled={isSaveProviderConfigDisabled}>
            {isSavingConfig ? text.savingAction : text.saveAction}
          </Button>
          <Button
            type="button"
            onClick={() => {
              if (deleteProviderConfigPending || isProviderConfigDraftLocked) {
                return;
              }

              onRequestDelete();
            }}
            disabled={deleteProviderConfigPending || isProviderConfigDraftLocked}
            variant="danger"
          >
            {deleteProviderConfigPending && deleteProviderConfigId === config.configurationId
              ? text.savingAction
              : text.deleteAction}
          </Button>
          <button
            type="button"
            className={styles.pagerButton}
            disabled={isProviderConfigDraftLocked}
            onClick={onClose}
          >
            {text.collapseEditorAction}
          </button>
        </div>

        {isProviderConfigInvalid && isProviderConfigDraftDirty(config, draft) ? (
          <p className={styles.validationMessage} aria-live="polite">
            {text.invalidProviderConfig}
          </p>
        ) : null}
      </form>
    </section>
  );
}

function safeText(value: string | null | undefined, maxLength = 120) {
  const trimmed = value?.trim();
  return trimmed ? sanitizeSensitiveText(trimmed, maxLength) : "-";
}

function normalizeProviderRegionInput(value: string) {
  return value.toUpperCase().slice(0, ECONOMY_PROVIDER_REGION_MAX_LENGTH);
}

function isValidPaymentRouteRegion(value: string) {
  const normalizedValue = value.trim().toUpperCase();
  return normalizedValue === "*" || /^[A-Z]{2}$/.test(normalizedValue);
}

function isValidPaymentRouteCountry(value: string) {
  return /^[A-Z]{2}$/.test(value.trim().toUpperCase());
}

function humanizeRouteMode(value: string, text: EconomyPageText) {
  return value.trim().toLowerCase() === "test"
    ? text.providerModeTestLabel
    : text.providerModeLiveLabel;
}

function normalizeProviderVersionInput(value: string) {
  return value.slice(0, ECONOMY_PROVIDER_VERSION_MAX_LENGTH);
}

function normalizeProviderTextInput(value: string, maxLength: number) {
  return value.slice(0, maxLength);
}
