"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useEffect, useMemo, useRef, useState } from "react";

import { useAdminNotifications } from "@/components/admin/admin-notifications";
import {
  AdminBadge,
  AdminCard,
  AdminKpiCard,
  AdminStateCard,
} from "@/components/admin/admin-primitives";
import { ConfirmationDialog } from "@/components/admin/confirmation-dialog";
import {
  getGenerationCapacityAlertText,
  getGenerationCapacityPanelText,
  type GenerationCapacityPanelText,
} from "@/components/generation-capacity-panel.content";
import styles from "@/components/generation-capacity-panel.module.css";
import {
  buildGenerationCapacityAlertTransitionKey,
  calculateBalancedGenerationProfile,
  getGenerationCapacityAlertTransitionsStorageKey,
  isGenerationCapacityDecrease,
  parseGenerationCapacityAlertTransitions,
  retainRecentGenerationCapacityAlertTransitions,
} from "@/components/generation-capacity-policy";
import { createAdminCorrelationId } from "@/lib/admin-correlation-id";
import { getAdminErrorMessage } from "@/lib/admin-error-message";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
  fetchAdminTemplateGenerationControl,
  GENERATION_CONTROL_REASON_MAX_LENGTH,
  refreshAdminTemplateGenerationProvider,
  updateAdminTemplateGenerationControlPolicy,
  type AdminTemplateGenerationBalanceState,
  type AdminTemplateGenerationCapacityProfile,
  type AdminTemplateGenerationControl,
} from "@/lib/api-client";
import { useAuthSession } from "@/lib/api-client.core";
import { formatDateTime } from "@/lib/format-date-time";
import type { Locale } from "@/lib/i18n";

type GenerationCapacityPanelProps = {
  locale: Locale;
  enabled: boolean;
};

type PolicyDraft = {
  expectedRevision: number;
  admissionEnabled: boolean;
  confirmedFalConcurrencyLimit: string;
  reservedHeadroom: string;
  applicationHardCeiling: string;
  reason: string;
  idempotencyKey: string;
  riskAcknowledged: boolean;
};

const POLICY_LIMIT_MAX = 1_000;

function createPolicyIdempotencyKey(): string {
  return `generation-policy:${createAdminCorrelationId()}`;
}

function createPolicyDraft(control: AdminTemplateGenerationControl): PolicyDraft {
  return {
    expectedRevision: control.revision,
    admissionEnabled: control.admissionEnabled,
    confirmedFalConcurrencyLimit: String(control.confirmedFalConcurrencyLimit),
    reservedHeadroom: String(control.reservedHeadroom),
    applicationHardCeiling: String(control.applicationHardCeiling),
    reason: "",
    idempotencyKey: createPolicyIdempotencyKey(),
    riskAcknowledged: false,
  };
}

function parseWholeNumber(value: string, minimum: number): number | null {
  if (!/^\d+$/.test(value.trim())) {
    return null;
  }

  const parsed = Number.parseInt(value, 10);
  return Number.isSafeInteger(parsed) && parsed >= minimum && parsed <= POLICY_LIMIT_MAX
    ? parsed
    : null;
}

function getErrorStatus(error: unknown): number | undefined {
  if (!error || typeof error !== "object" || !("status" in error)) {
    return undefined;
  }

  return typeof error.status === "number" ? error.status : undefined;
}

function balanceTone(state: AdminTemplateGenerationBalanceState) {
  if (state === "fresh") return "success" as const;
  if (state === "low" || state === "stale") return "warning" as const;
  return "danger" as const;
}

function alertTone(severity: "info" | "warning" | "critical") {
  return severity === "critical" ? ("danger" as const) : severity;
}

function formatUsd(value: number | null | undefined, locale: Locale): string {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    return "—";
  }

  return new Intl.NumberFormat(locale === "ru" ? "ru-RU" : "en-US", {
    style: "currency",
    currency: "USD",
    maximumFractionDigits: 2,
  }).format(value);
}

function formatOptionalDate(value: string | null | undefined, locale: Locale): string {
  return value ? formatDateTime(value, locale) : "—";
}

function profileRows(
  profile: AdminTemplateGenerationCapacityProfile,
  text: GenerationCapacityPanelText
) {
  return [
    [text.effectiveCapacity, profile.globalMaxConcurrentGenerations],
    [text.imageReserved, profile.imageReservedConcurrentGenerations],
    [text.imageProtected, profile.imageProtectedConcurrentGenerations],
    [text.imageMax, profile.imageMaxConcurrentGenerations],
    [text.videoReserved, profile.videoReservedConcurrentGenerations],
    [text.videoMax, profile.videoMaxConcurrentGenerations],
    [text.videoBorrow, profile.videoBorrowMaxConcurrentGenerations],
    [text.videoPreprocessing, profile.videoPreprocessingMaxConcurrentGenerations],
  ] as const;
}

export function GenerationCapacityPanel({ locale, enabled }: GenerationCapacityPanelProps) {
  const text = getGenerationCapacityPanelText(locale);
  const session = useAuthSession();
  const queryClient = useQueryClient();
  const { addNotification } = useAdminNotifications();
  const [isEditorOpen, setIsEditorOpen] = useState(false);
  const [draft, setDraft] = useState<PolicyDraft | null>(null);
  const [editorError, setEditorError] = useState<string | null>(null);
  const [refreshError, setRefreshError] = useState<string | null>(null);
  const firstEditorFieldRef = useRef<HTMLInputElement>(null);
  const observedAlertTransitionsRef = useRef(new Set<string>());
  const observedAlertTransitionsStorageKeyRef = useRef<string | null>(null);
  const alertTransitionsStorageKey = getGenerationCapacityAlertTransitionsStorageKey(
    session?.user.userId
  );

  const capacityQuery = useQuery({
    queryKey: adminQueryKeys.templateGenerationControl,
    queryFn: ({ signal }) => fetchAdminTemplateGenerationControl(signal),
    enabled,
    staleTime: 10_000,
    refetchInterval: 25_000,
    refetchIntervalInBackground: false,
  });

  const control = capacityQuery.data;
  const confirmedLimit = draft ? parseWholeNumber(draft.confirmedFalConcurrencyLimit, 1) : null;
  const reservedHeadroom = draft ? parseWholeNumber(draft.reservedHeadroom, 0) : null;
  const hardCeiling = draft ? parseWholeNumber(draft.applicationHardCeiling, 1) : null;
  const previewProfile = useMemo(
    () =>
      confirmedLimit !== null && reservedHeadroom !== null && hardCeiling !== null
        ? calculateBalancedGenerationProfile(confirmedLimit, reservedHeadroom, hardCeiling)
        : null,
    [confirmedLimit, hardCeiling, reservedHeadroom]
  );
  const isPolicyShapeValid =
    confirmedLimit !== null &&
    reservedHeadroom !== null &&
    hardCeiling !== null &&
    reservedHeadroom < confirmedLimit;
  const requiresRiskAcknowledgement = Boolean(
    draft &&
    control &&
    previewProfile &&
    (draft.admissionEnabled !== control.admissionEnabled ||
      isGenerationCapacityDecrease(control.effectiveGlobalLimit, previewProfile))
  );
  const canSavePolicy = Boolean(
    draft &&
    previewProfile &&
    isPolicyShapeValid &&
    draft.reason.trim() &&
    (!requiresRiskAcknowledgement || draft.riskAcknowledged)
  );

  useEffect(() => {
    if (!alertTransitionsStorageKey) {
      return;
    }

    if (observedAlertTransitionsStorageKeyRef.current !== alertTransitionsStorageKey) {
      observedAlertTransitionsStorageKeyRef.current = alertTransitionsStorageKey;
      let persistedTransitions: string[] = [];
      try {
        persistedTransitions = parseGenerationCapacityAlertTransitions(
          window.localStorage.getItem(alertTransitionsStorageKey)
        );
      } catch {
        // In-memory dedupe still applies when browser storage is unavailable.
      }
      observedAlertTransitionsRef.current = new Set(persistedTransitions);
    }

    let observedNewTransition = false;
    for (const alert of control?.alerts ?? []) {
      const transitionKey = buildGenerationCapacityAlertTransitionKey(alert);
      if (!transitionKey || observedAlertTransitionsRef.current.has(transitionKey)) {
        continue;
      }

      observedAlertTransitionsRef.current.add(transitionKey);
      observedNewTransition = true;
      const localizedAlert = getGenerationCapacityAlertText(locale, alert);
      addNotification({
        title: localizedAlert.title,
        message: localizedAlert.message,
        category: "system",
        source: text.notificationSource,
        tone:
          alert.severity === "critical"
            ? "error"
            : alert.severity === "warning"
              ? "warning"
              : "info",
        priority: alert.severity === "critical" ? "critical" : "normal",
        href: `/${locale}/generations`,
        dedupeKey: transitionKey,
      });
    }

    if (observedNewTransition) {
      const persistedTransitions = retainRecentGenerationCapacityAlertTransitions(
        observedAlertTransitionsRef.current
      );
      observedAlertTransitionsRef.current = new Set(persistedTransitions);
      try {
        window.localStorage.setItem(
          alertTransitionsStorageKey,
          JSON.stringify(persistedTransitions)
        );
      } catch {
        // In-memory dedupe still applies when browser storage is unavailable.
      }
    }
  }, [
    addNotification,
    alertTransitionsStorageKey,
    control?.alerts,
    locale,
    text.notificationSource,
  ]);

  const policyMutation = useMutation({
    mutationFn: updateAdminTemplateGenerationControlPolicy,
    onSuccess: (updated) => {
      queryClient.setQueryData(adminQueryKeys.templateGenerationControl, updated);
      setIsEditorOpen(false);
      setDraft(null);
      setEditorError(null);
      addNotification({
        title: text.title,
        message: text.saved,
        category: "system",
        source: text.notificationSource,
        tone: "success",
        href: `/${locale}/generations`,
        dedupeKey: `generation-policy-saved:${updated.revision}`,
      });
    },
    onError: async (error) => {
      if (getErrorStatus(error) === 409) {
        const refreshed = await capacityQuery.refetch();
        if (refreshed.data) {
          setDraft(createPolicyDraft(refreshed.data));
        }
        setEditorError(text.staleConflict);
        return;
      }

      setEditorError(getAdminErrorMessage(error, text.saveError));
    },
  });

  const refreshMutation = useMutation({
    mutationFn: refreshAdminTemplateGenerationProvider,
    onMutate: () => setRefreshError(null),
    onSuccess: (updated) => {
      queryClient.setQueryData(adminQueryKeys.templateGenerationControl, updated);
      addNotification({
        title: text.title,
        message: text.refreshed,
        category: "system",
        source: text.notificationSource,
        tone: "success",
        href: `/${locale}/generations`,
        dedupeKey: `generation-provider-refresh:${updated.balance.checkedAtUtc ?? updated.revision}`,
      });
    },
    onError: (error) => setRefreshError(getAdminErrorMessage(error, text.refreshError)),
  });

  function openEditor() {
    if (!control) return;
    setEditorError(null);
    setDraft(createPolicyDraft(control));
    setIsEditorOpen(true);
  }

  function closeEditor() {
    if (policyMutation.isPending) return;
    setIsEditorOpen(false);
    setDraft(null);
    setEditorError(null);
  }

  function updateDraft(patch: Partial<PolicyDraft>) {
    setEditorError(null);
    setDraft((current) =>
      current
        ? {
            ...current,
            ...patch,
            idempotencyKey: createPolicyIdempotencyKey(),
            riskAcknowledged: "riskAcknowledged" in patch ? Boolean(patch.riskAcknowledged) : false,
          }
        : current
    );
  }

  function savePolicy() {
    if (
      !draft ||
      !canSavePolicy ||
      confirmedLimit === null ||
      reservedHeadroom === null ||
      hardCeiling === null
    ) {
      return;
    }

    setEditorError(null);
    policyMutation.mutate({
      expectedRevision: draft.expectedRevision,
      reason: draft.reason,
      admissionEnabled: draft.admissionEnabled,
      confirmedFalConcurrencyLimit: confirmedLimit,
      reservedHeadroom,
      applicationHardCeiling: hardCeiling,
      idempotencyKey: draft.idempotencyKey,
    });
  }

  if (!enabled) {
    return null;
  }

  if (capacityQuery.isPending) {
    return <AdminStateCard title={text.title} description={text.description} tone="info" />;
  }

  if (!control) {
    return (
      <AdminStateCard
        title={text.unavailable}
        description={getAdminErrorMessage(capacityQuery.error, text.unavailable)}
        tone="warning"
        action={
          <button
            className={styles.button}
            type="button"
            disabled={capacityQuery.isFetching}
            onClick={() => void capacityQuery.refetch().catch(() => undefined)}
          >
            {text.retry}
          </button>
        }
      />
    );
  }

  const usagePercent =
    control.effectiveGlobalLimit > 0
      ? Math.min(
          100,
          Math.round((control.lanes.inFlightTotal / control.effectiveGlobalLimit) * 100)
        )
      : 0;

  return (
    <>
      <AdminCard
        title={text.title}
        description={text.description}
        action={
          <div className={styles.actions}>
            <button
              className={styles.button}
              type="button"
              disabled={refreshMutation.isPending}
              onClick={() => refreshMutation.mutate()}
            >
              {refreshMutation.isPending ? text.refreshingProvider : text.refreshProvider}
            </button>
            <button className={styles.primaryButton} type="button" onClick={openEditor}>
              {text.editPolicy}
            </button>
          </div>
        }
      >
        <div className={styles.statusRow}>
          <AdminBadge tone={control.admissionEnabled ? "success" : "danger"}>
            {control.admissionEnabled ? text.admissionOn : text.admissionOff}
          </AdminBadge>
          <AdminBadge tone={balanceTone(control.balance.state)}>
            {text.balanceStateLabels[control.balance.state]}
          </AdminBadge>
          <span>
            {text.policyRevision}: {control.revision}
          </span>
          <span>
            {text.confirmedAt}: {formatOptionalDate(control.confirmedAtUtc, locale)}
          </span>
        </div>

        <div className={styles.metricGrid}>
          <AdminKpiCard
            label={text.effectiveCapacity}
            value={String(control.effectiveGlobalLimit)}
            hint={`${text.providerLimit}: ${control.confirmedFalConcurrencyLimit} · reserve ${control.reservedHeadroom}`}
            tone={control.admissionEnabled ? "primary" : "danger"}
          />
          <AdminKpiCard
            label={text.balance}
            value={formatUsd(control.balance.currentBalanceUsd, locale)}
            hint={`${text.checkedAt}: ${formatOptionalDate(control.balance.checkedAtUtc, locale)}`}
            tone={balanceTone(control.balance.state)}
          />
          <AdminKpiCard
            label={text.inFlight}
            value={`${control.lanes.inFlightTotal} / ${control.effectiveGlobalLimit}`}
            hint={`${usagePercent}% · ${text.borrowedSlots}: ${control.lanes.borrowedSlotsInUse}`}
            tone={usagePercent >= 90 ? "warning" : "info"}
          />
          <AdminKpiCard
            label={text.queued}
            value={String(control.queue.totalDepth)}
            hint={`${text.imageQueue}: ${control.queue.imageDepth} · ${text.videoQueue}: ${control.queue.videoDepth}`}
            tone={control.queue.totalDepth > 0 ? "magenta" : "success"}
          />
        </div>

        <div className={styles.progressHeader}>
          <span>{text.capacityUsage}</span>
          <strong>{usagePercent}%</strong>
        </div>
        <div
          className={styles.progressTrack}
          role="progressbar"
          aria-label={text.capacityUsage}
          aria-valuemin={0}
          aria-valuemax={100}
          aria-valuenow={usagePercent}
        >
          <span style={{ width: `${usagePercent}%` }} />
        </div>

        {refreshError ? <AdminStateCard title={refreshError} tone="warning" /> : null}
        {control.alerts.length > 0 ? (
          <section className={styles.alerts} aria-label={text.alerts}>
            {control.alerts.map((alert) => (
              <AdminStateCard
                key={buildGenerationCapacityAlertTransitionKey(alert)}
                title={getGenerationCapacityAlertText(locale, alert).title}
                description={getGenerationCapacityAlertText(locale, alert).message}
                tone={alertTone(alert.severity)}
              />
            ))}
          </section>
        ) : null}

        <div className={styles.detailGrid}>
          <details className={styles.details} open>
            <summary>{text.profile}</summary>
            <dl className={styles.definitionGrid}>
              {profileRows(control.effectiveProfile, text).map(([label, value]) => (
                <div key={label}>
                  <dt>{label}</dt>
                  <dd>{value}</dd>
                </div>
              ))}
            </dl>
          </details>

          <details className={styles.details}>
            <summary>{text.worker}</summary>
            <dl className={styles.definitionGrid}>
              <div>
                <dt>{text.workerInstances}</dt>
                <dd>{control.worker.instanceCount}</dd>
              </div>
              <div>
                <dt>{text.workerRevision}</dt>
                <dd>{control.worker.appliedPolicyRevision ?? "—"}</dd>
              </div>
              <div>
                <dt>{text.schedulerMode}</dt>
                <dd>
                  {control.worker.schedulerV2Enabled === null
                    ? text.balanceUnknown
                    : control.worker.schedulerV2Enabled
                      ? text.schedulerV2On
                      : text.schedulerV2Off}
                </dd>
              </div>
              <div>
                <dt>{text.workerHeartbeat}</dt>
                <dd>{formatOptionalDate(control.worker.heartbeatAtUtc, locale)}</dd>
              </div>
              <div>
                <dt>{text.workerProgress}</dt>
                <dd>{formatOptionalDate(control.worker.lastProgressAtUtc, locale)}</dd>
              </div>
              <div>
                <dt>{text.imageInFlight}</dt>
                <dd>{control.lanes.imageInFlight}</dd>
              </div>
              <div>
                <dt>{text.videoInFlight}</dt>
                <dd>{control.lanes.videoInFlight}</dd>
              </div>
              <div>
                <dt>{text.preprocessingInFlight}</dt>
                <dd>{control.lanes.videoPreprocessingInFlight}</dd>
              </div>
              <div>
                <dt>{text.submissionUnknown}</dt>
                <dd>{control.lanes.submissionUnknownCount}</dd>
              </div>
              <div>
                <dt>{text.nativeSlots}</dt>
                <dd>{control.lanes.nativeSlotsInUse}</dd>
              </div>
              <div>
                <dt>{text.borrowedSlots}</dt>
                <dd>{control.lanes.borrowedSlotsInUse}</dd>
              </div>
              <div>
                <dt>{text.reservedSlots}</dt>
                <dd>{control.lanes.reservedSlotsAvailable}</dd>
              </div>
              <div>
                <dt>{text.dispatch}</dt>
                <dd>{control.worker.dispatchConcurrency ?? text.balanceUnknown}</dd>
              </div>
              <div>
                <dt>{text.reconciliation}</dt>
                <dd>{control.worker.reconciliationConcurrency ?? text.balanceUnknown}</dd>
              </div>
              <div>
                <dt>{text.mediaImport}</dt>
                <dd>{control.worker.mediaImportConcurrency ?? text.balanceUnknown}</dd>
              </div>
              <div>
                <dt>{text.maintenance}</dt>
                <dd>{control.worker.maintenanceConcurrency ?? text.balanceUnknown}</dd>
              </div>
            </dl>
          </details>

          <details className={styles.details}>
            <summary>{text.stages}</summary>
            <p className={styles.emptyDetail}>
              {control.queue.oldestQueuedAtUtc
                ? `${text.oldestQueued}: ${formatOptionalDate(control.queue.oldestQueuedAtUtc, locale)}`
                : text.noQueue}
            </p>
            {control.queue.stages.length > 0 ? (
              <dl className={styles.definitionGrid}>
                {control.queue.stages.map((stage) => (
                  <div key={stage.stage}>
                    <dt>{stage.stage}</dt>
                    <dd>{stage.count}</dd>
                  </div>
                ))}
              </dl>
            ) : (
              <p className={styles.emptyDetail}>{text.noStages}</p>
            )}
          </details>
        </div>
      </AdminCard>

      <ConfirmationDialog
        open={isEditorOpen && draft !== null}
        title={text.editTitle}
        description={text.editDescription}
        confirmLabel={policyMutation.isPending ? text.saving : text.save}
        cancelLabel={text.cancel}
        confirmDisabled={!canSavePolicy}
        initialFocusRef={firstEditorFieldRef}
        isSubmitting={policyMutation.isPending}
        size="large"
        stickyActions
        tone="primary"
        onCancel={closeEditor}
        onConfirm={savePolicy}
      >
        {draft ? (
          <div className={styles.editor}>
            {editorError ? <AdminStateCard title={editorError} tone="warning" /> : null}
            <label className={styles.toggleField}>
              <input
                type="checkbox"
                checked={draft.admissionEnabled}
                disabled={policyMutation.isPending}
                onChange={(event) => updateDraft({ admissionEnabled: event.target.checked })}
              />
              <span>{text.admissionLabel}</span>
            </label>

            <div className={styles.editorGrid}>
              <label className={styles.field}>
                <span>{text.confirmedLimitLabel}</span>
                <input
                  ref={firstEditorFieldRef}
                  inputMode="numeric"
                  value={draft.confirmedFalConcurrencyLimit}
                  disabled={policyMutation.isPending}
                  onChange={(event) =>
                    updateDraft({ confirmedFalConcurrencyLimit: event.target.value })
                  }
                />
              </label>
              <label className={styles.field}>
                <span>{text.reserveLabel}</span>
                <input
                  inputMode="numeric"
                  value={draft.reservedHeadroom}
                  disabled={policyMutation.isPending}
                  onChange={(event) => updateDraft({ reservedHeadroom: event.target.value })}
                />
              </label>
              <label className={styles.field}>
                <span>{text.ceilingLabel}</span>
                <input
                  inputMode="numeric"
                  value={draft.applicationHardCeiling}
                  disabled={policyMutation.isPending}
                  onChange={(event) => updateDraft({ applicationHardCeiling: event.target.value })}
                />
              </label>
            </div>
            {!isPolicyShapeValid ? <p className={styles.validation}>{text.invalidPolicy}</p> : null}

            <section className={styles.preview} aria-label={text.previewTitle}>
              <header>
                <strong>{text.previewTitle}</strong>
                <span>{text.previewDescription}</span>
              </header>
              {previewProfile ? (
                <dl className={styles.definitionGrid}>
                  {profileRows(previewProfile, text).map(([label, value]) => (
                    <div key={label}>
                      <dt>{label}</dt>
                      <dd>{value}</dd>
                    </div>
                  ))}
                </dl>
              ) : null}
            </section>

            {requiresRiskAcknowledgement ? (
              <AdminStateCard
                title={text.riskyTitle}
                description={text.riskyDescription}
                tone="warning"
              >
                <label className={styles.riskField}>
                  <input
                    type="checkbox"
                    checked={draft.riskAcknowledged}
                    disabled={policyMutation.isPending}
                    onChange={(event) => updateDraft({ riskAcknowledged: event.target.checked })}
                  />
                  <span>{text.riskyAcknowledge}</span>
                </label>
              </AdminStateCard>
            ) : null}

            <label className={styles.field}>
              <span>{text.reasonLabel}</span>
              <textarea
                value={draft.reason}
                maxLength={GENERATION_CONTROL_REASON_MAX_LENGTH}
                disabled={policyMutation.isPending}
                placeholder={text.reasonPlaceholder}
                onChange={(event) => updateDraft({ reason: event.target.value })}
              />
              {!draft.reason.trim() ? <small>{text.reasonRequired}</small> : null}
            </label>
          </div>
        ) : null}
      </ConfirmationDialog>
    </>
  );
}
