"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useEffect, useRef, useState } from "react";

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
  isGenerationCapacitySnapshotTooOld,
  isGenerationCapacityDecrease,
  parseGenerationCapacityAlertTransitions,
  retainRecentGenerationCapacityAlertTransitions,
  selectNewestGenerationCapacitySnapshot,
} from "@/components/generation-capacity-policy";
import { GenerationProviderRecoveryPanel } from "@/components/generation-provider-recovery-panel";
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
  falLimitConfirmed: boolean;
};

type ProviderRefreshVariables = {
  source: "automatic" | "manual";
};

const POLICY_LIMIT_MAX = 1_000;
const POLICY_REASON_MIN_LENGTH = 3;
const SNAPSHOT_FRESHNESS_TICK_MS = 10_000;
const CAPACITY_REFRESH_INTERVAL_MS = 15_000;
const PROVIDER_BALANCE_REFRESH_INTERVAL_MS = 5 * 60_000;
const POLICY_LIMITS_ERROR_ID = "generation-capacity-policy-limits-error";
const POLICY_REASON_ERROR_ID = "generation-capacity-policy-reason-error";
const POLICY_CONFIRMATION_ERROR_ID = "generation-capacity-policy-confirmation-error";

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
    falLimitConfirmed: false,
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
  const [policyConflictBlocked, setPolicyConflictBlocked] = useState(false);
  const [isPolicyConflictRefreshing, setIsPolicyConflictRefreshing] = useState(false);
  const [refreshError, setRefreshError] = useState<string | null>(null);
  const [isOverviewManuallyOpen, setIsOverviewManuallyOpen] = useState(false);
  const [freshnessNowMs, setFreshnessNowMs] = useState(() => Date.now());
  const firstEditorFieldRef = useRef<HTMLInputElement>(null);
  const policyConflictRefreshSequenceRef = useRef(0);
  const observedAlertTransitionsRef = useRef(new Set<string>());
  const observedAlertTransitionsStorageKeyRef = useRef<string | null>(null);
  const alertTransitionsStorageKey = getGenerationCapacityAlertTransitionsStorageKey(
    session?.user.userId
  );

  const capacityQuery = useQuery({
    queryKey: adminQueryKeys.templateGenerationControl,
    queryFn: async ({ signal }) => {
      const incoming = await fetchAdminTemplateGenerationControl(signal);
      const current = queryClient.getQueryData<AdminTemplateGenerationControl>(
        adminQueryKeys.templateGenerationControl
      );
      return selectNewestGenerationCapacitySnapshot(current, incoming);
    },
    enabled,
    staleTime: CAPACITY_REFRESH_INTERVAL_MS,
    refetchInterval: CAPACITY_REFRESH_INTERVAL_MS,
    refetchIntervalInBackground: true,
    refetchOnWindowFocus: "always",
  });

  const control = capacityQuery.data;
  const snapshotTooOld = Boolean(
    control && isGenerationCapacitySnapshotTooOld(control.generatedAtUtc, freshnessNowMs)
  );
  const confirmedLimit = draft ? parseWholeNumber(draft.confirmedFalConcurrencyLimit, 1) : null;
  const reservedHeadroom = draft ? parseWholeNumber(draft.reservedHeadroom, 0) : null;
  const hardCeiling = draft ? parseWholeNumber(draft.applicationHardCeiling, 1) : null;
  const previewProfile =
    control && confirmedLimit !== null && reservedHeadroom !== null && hardCeiling !== null
      ? calculateBalancedGenerationProfile(
          confirmedLimit,
          reservedHeadroom,
          hardCeiling,
          control.policy
        )
      : null;
  const reasonLength = draft?.reason.trim().length ?? 0;
  const isReasonValid =
    reasonLength >= POLICY_REASON_MIN_LENGTH &&
    reasonLength <= GENERATION_CONTROL_REASON_MAX_LENGTH;
  const confirmedLimitInvalid = draft !== null && confirmedLimit === null;
  const reservedHeadroomInvalid =
    draft !== null &&
    (reservedHeadroom === null || (confirmedLimit !== null && reservedHeadroom >= confirmedLimit));
  const hardCeilingInvalid = draft !== null && hardCeiling === null;
  const falLimitChanged = Boolean(
    control && confirmedLimit !== null && confirmedLimit !== control.confirmedFalConcurrencyLimit
  );
  const falLimitConfirmationMissing = Boolean(draft && falLimitChanged && !draft.falLimitConfirmed);
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
    isReasonValid &&
    !snapshotTooOld &&
    !policyConflictBlocked &&
    !falLimitConfirmationMissing &&
    (!requiresRiskAcknowledgement || draft.riskAcknowledged)
  );
  const requiresOperationalAttention = Boolean(
    snapshotTooOld ||
    capacityQuery.isRefetchError ||
    refreshError ||
    control?.alerts.length ||
    control?.lanes.submissionUnknownCount
  );
  const isOverviewOpen = requiresOperationalAttention || isOverviewManuallyOpen;

  useEffect(() => {
    if (!enabled) {
      return;
    }

    const interval = window.setInterval(
      () => setFreshnessNowMs(Date.now()),
      SNAPSHOT_FRESHNESS_TICK_MS
    );
    return () => window.clearInterval(interval);
  }, [enabled]);

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
    onMutate: async () => {
      setEditorError(null);
      await queryClient.cancelQueries({
        queryKey: adminQueryKeys.templateGenerationControl,
        exact: true,
      });
    },
    onSuccess: (updated) => {
      policyConflictRefreshSequenceRef.current += 1;
      const accepted = queryClient.setQueryData<AdminTemplateGenerationControl>(
        adminQueryKeys.templateGenerationControl,
        (current) => selectNewestGenerationCapacitySnapshot(current, updated)
      );
      setIsEditorOpen(false);
      setDraft(null);
      setEditorError(null);
      setPolicyConflictBlocked(false);
      addNotification({
        title: text.title,
        message: text.saved,
        category: "system",
        source: text.notificationSource,
        tone: "success",
        href: `/${locale}/generations`,
        dedupeKey: `generation-policy-saved:${accepted?.revision ?? updated.revision}`,
      });
      void queryClient.invalidateQueries({
        queryKey: adminQueryKeys.templateGenerationControl,
        exact: true,
      });
    },
    onError: async (error) => {
      if (getErrorStatus(error) === 409) {
        await refreshPolicyConflict();
        return;
      }

      setEditorError(getAdminErrorMessage(error, text.saveError));
    },
  });

  const refreshMutation = useMutation<
    Awaited<ReturnType<typeof refreshAdminTemplateGenerationProvider>>,
    unknown,
    ProviderRefreshVariables
  >({
    mutationFn: refreshAdminTemplateGenerationProvider,
    onMutate: async () => {
      setRefreshError(null);
      await queryClient.cancelQueries({
        queryKey: adminQueryKeys.templateGenerationControl,
        exact: true,
      });
    },
    onSuccess: (result, { source }) => {
      const updated = result.control;
      const accepted = queryClient.setQueryData<AdminTemplateGenerationControl>(
        adminQueryKeys.templateGenerationControl,
        (current) => selectNewestGenerationCapacitySnapshot(current, updated)
      );
      const message =
        result.outcome === "refreshed"
          ? text.refreshed
          : result.outcome === "coalesced"
            ? text.refreshCoalesced
            : text.refreshFailed;
      setRefreshError(result.outcome === "failed" ? message : null);
      if (source === "manual") {
        addNotification({
          title: text.title,
          message,
          category: "system",
          source: text.notificationSource,
          tone:
            result.outcome === "failed"
              ? "error"
              : result.outcome === "coalesced"
                ? "info"
                : "success",
          href: `/${locale}/generations`,
          dedupeKey: `generation-provider-refresh:${result.outcome}:${result.checkedAtUtc ?? accepted?.balance.checkedAtUtc ?? updated.revision}`,
        });
      }
      void queryClient.invalidateQueries({
        queryKey: adminQueryKeys.templateGenerationControl,
        exact: true,
      });
    },
    onError: (error) => setRefreshError(getAdminErrorMessage(error, text.refreshError)),
  });

  const isProviderRefreshPendingRef = useRef(false);
  const requestProviderRefreshRef = useRef(refreshMutation.mutate);
  useEffect(() => {
    isProviderRefreshPendingRef.current = refreshMutation.isPending;
  }, [refreshMutation.isPending]);
  useEffect(() => {
    requestProviderRefreshRef.current = refreshMutation.mutate;
  }, [refreshMutation.mutate]);

  useEffect(() => {
    if (!enabled) {
      return;
    }

    const interval = window.setInterval(() => {
      if (document.visibilityState === "visible" && !isProviderRefreshPendingRef.current) {
        requestProviderRefreshRef.current({ source: "automatic" });
      }
    }, PROVIDER_BALANCE_REFRESH_INTERVAL_MS);

    return () => window.clearInterval(interval);
  }, [enabled]);

  const isPolicyEditorBusy = policyMutation.isPending || isPolicyConflictRefreshing;

  function openEditor() {
    if (!control || snapshotTooOld) return;
    policyConflictRefreshSequenceRef.current += 1;
    setEditorError(null);
    setPolicyConflictBlocked(false);
    setIsPolicyConflictRefreshing(false);
    setDraft(createPolicyDraft(control));
    setIsEditorOpen(true);
  }

  function closeEditor() {
    if (isPolicyEditorBusy) return;
    policyConflictRefreshSequenceRef.current += 1;
    setIsEditorOpen(false);
    setDraft(null);
    setEditorError(null);
    setPolicyConflictBlocked(false);
    setIsPolicyConflictRefreshing(false);
  }

  function updateDraft(patch: Partial<PolicyDraft>) {
    if (!policyConflictBlocked) {
      setEditorError(null);
    }
    setDraft((current) =>
      current
        ? {
            ...current,
            ...patch,
            idempotencyKey: createPolicyIdempotencyKey(),
            riskAcknowledged: "riskAcknowledged" in patch ? Boolean(patch.riskAcknowledged) : false,
            falLimitConfirmed:
              "confirmedFalConcurrencyLimit" in patch
                ? false
                : "falLimitConfirmed" in patch
                  ? Boolean(patch.falLimitConfirmed)
                  : current.falLimitConfirmed,
          }
        : current
    );
  }

  async function refreshPolicyConflict() {
    const conflictedRevision = draft?.expectedRevision;
    if (conflictedRevision === undefined) {
      setPolicyConflictBlocked(true);
      setEditorError(text.staleConflictRefreshFailed);
      return;
    }

    const refreshSequence = policyConflictRefreshSequenceRef.current + 1;
    policyConflictRefreshSequenceRef.current = refreshSequence;
    setIsPolicyConflictRefreshing(true);
    try {
      const refreshed = await capacityQuery.refetch({ cancelRefetch: false });
      if (policyConflictRefreshSequenceRef.current !== refreshSequence) {
        return;
      }
      if (refreshed.isError || !refreshed.data || refreshed.data.revision <= conflictedRevision) {
        setPolicyConflictBlocked(true);
        setEditorError(text.staleConflictRefreshFailed);
        return;
      }

      setDraft((current) =>
        current
          ? {
              ...current,
              expectedRevision: refreshed.data.revision,
              idempotencyKey: createPolicyIdempotencyKey(),
              riskAcknowledged: false,
              falLimitConfirmed: false,
            }
          : current
      );
      setPolicyConflictBlocked(false);
      setEditorError(text.staleConflict);
    } catch {
      if (policyConflictRefreshSequenceRef.current === refreshSequence) {
        setPolicyConflictBlocked(true);
        setEditorError(text.staleConflictRefreshFailed);
      }
    } finally {
      if (policyConflictRefreshSequenceRef.current === refreshSequence) {
        setIsPolicyConflictRefreshing(false);
      }
    }
  }

  function savePolicy() {
    if (snapshotTooOld) {
      setEditorError(text.snapshotTooOldDescription);
      return;
    }

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
      reason: draft.reason.trim(),
      admissionEnabled: draft.admissionEnabled,
      confirmedFalConcurrencyLimit: confirmedLimit,
      reservedHeadroom,
      applicationHardCeiling: hardCeiling,
      confirmFalConcurrencyLimit: draft.falLimitConfirmed,
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
  const schedulerMode =
    control.worker.schedulerV2Enabled === null
      ? text.balanceUnknown
      : control.worker.schedulerV2Enabled
        ? text.schedulerV2On
        : text.schedulerV2Off;
  const isSynchronizing = capacityQuery.isFetching || refreshMutation.isPending;

  return (
    <>
      <div data-admin-surface="generation-capacity">
        <AdminCard
          title={text.title}
          description={text.description}
          action={
            <div className={styles.actions}>
              <button
                className={styles.button}
                type="button"
                disabled={refreshMutation.isPending}
                onClick={() => refreshMutation.mutate({ source: "manual" })}
              >
                {refreshMutation.isPending ? text.refreshingProvider : text.refreshProvider}
              </button>
              <button
                className={styles.primaryButton}
                type="button"
                disabled={snapshotTooOld}
                onClick={openEditor}
              >
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
            <span className={styles.liveStatus} aria-live="polite">
              <span
                aria-hidden="true"
                className={`${styles.liveStatusDot} ${
                  isSynchronizing ? styles.liveStatusDotSyncing : ""
                }`}
              />
              {isSynchronizing
                ? text.syncing
                : text.updatedAt(formatOptionalDate(control.generatedAtUtc, locale))}
            </span>
            <span className={styles.refreshPolicyNote}>{text.autoRefresh}</span>
            <span className={styles.refreshPolicyNote}>{text.providerBalanceRefresh}</span>
          </div>

          {capacityQuery.isRefetchError || snapshotTooOld ? (
            <AdminStateCard
              title={snapshotTooOld ? text.snapshotTooOldTitle : text.snapshotRefreshFailedTitle}
              description={
                snapshotTooOld
                  ? text.snapshotTooOldDescription
                  : getAdminErrorMessage(capacityQuery.error, text.snapshotRefreshFailedDescription)
              }
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
          ) : null}
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

          <GenerationProviderRecoveryPanel
            locale={locale}
            enabled={control.lanes.submissionUnknownCount > 0}
          />

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

          <details
            className={styles.overview}
            open={isOverviewOpen}
            onToggle={(event) => setIsOverviewManuallyOpen(event.currentTarget.open)}
          >
            <summary>
              <span>{text.overview}</span>
              <span className={styles.overviewSummary}>
                {control.effectiveGlobalLimit} {text.effectiveCapacity} · {control.queue.totalDepth}{" "}
                {text.queued}
              </span>
            </summary>

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

            <div className={styles.detailGrid}>
              <details className={styles.details}>
                <summary>
                  <span className={styles.detailSummaryCopy}>
                    <strong>{text.profile}</strong>
                    <small>
                      {control.effectiveGlobalLimit} {text.effectiveCapacity} · {text.providerLimit}
                      : {control.confirmedFalConcurrencyLimit}
                    </small>
                  </span>
                </summary>
                <dl className={styles.definitionGrid}>
                  <div>
                    <dt>{text.policyRevision}</dt>
                    <dd>{control.revision}</dd>
                  </div>
                  <div>
                    <dt>{text.confirmedAt}</dt>
                    <dd>{formatOptionalDate(control.confirmedAtUtc, locale)}</dd>
                  </div>
                  {profileRows(control.effectiveProfile, text).map(([label, value]) => (
                    <div key={label}>
                      <dt>{label}</dt>
                      <dd>{value}</dd>
                    </div>
                  ))}
                </dl>
              </details>

              <details className={styles.details}>
                <summary>
                  <span className={styles.detailSummaryCopy}>
                    <strong>{text.worker}</strong>
                    <small>
                      {control.worker.instanceCount} · {schedulerMode}
                    </small>
                  </span>
                </summary>
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
                    <dd>{schedulerMode}</dd>
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
                <summary>
                  <span className={styles.detailSummaryCopy}>
                    <strong>{text.stages}</strong>
                    <small>
                      {control.queue.totalDepth > 0
                        ? `${control.queue.totalDepth} ${text.queued}`
                        : text.noQueue}
                    </small>
                  </span>
                </summary>
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
          </details>
        </AdminCard>
      </div>

      <ConfirmationDialog
        open={isEditorOpen && draft !== null}
        title={text.editTitle}
        description={text.editDescription}
        confirmLabel={policyMutation.isPending ? text.saving : text.save}
        cancelLabel={text.cancel}
        confirmDisabled={!canSavePolicy}
        initialFocusRef={firstEditorFieldRef}
        isSubmitting={isPolicyEditorBusy}
        size="large"
        stickyActions
        tone="primary"
        onCancel={closeEditor}
        onConfirm={savePolicy}
      >
        {draft ? (
          <div className={styles.editor}>
            {editorError ? (
              <AdminStateCard
                title={editorError}
                tone="warning"
                action={
                  policyConflictBlocked ? (
                    <button
                      className={styles.button}
                      type="button"
                      disabled={isPolicyConflictRefreshing}
                      onClick={() => void refreshPolicyConflict()}
                    >
                      {isPolicyConflictRefreshing ? text.refreshingConflict : text.refreshConflict}
                    </button>
                  ) : undefined
                }
              />
            ) : null}
            {snapshotTooOld ? (
              <AdminStateCard
                title={text.snapshotTooOldTitle}
                description={text.snapshotTooOldDescription}
                tone="warning"
              />
            ) : null}
            <label className={styles.toggleField}>
              <input
                type="checkbox"
                checked={draft.admissionEnabled}
                disabled={isPolicyEditorBusy}
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
                  aria-invalid={confirmedLimitInvalid}
                  aria-describedby={confirmedLimitInvalid ? POLICY_LIMITS_ERROR_ID : undefined}
                  disabled={isPolicyEditorBusy}
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
                  aria-invalid={reservedHeadroomInvalid}
                  aria-describedby={reservedHeadroomInvalid ? POLICY_LIMITS_ERROR_ID : undefined}
                  disabled={isPolicyEditorBusy}
                  onChange={(event) => updateDraft({ reservedHeadroom: event.target.value })}
                />
              </label>
              <label className={styles.field}>
                <span>{text.ceilingLabel}</span>
                <input
                  inputMode="numeric"
                  value={draft.applicationHardCeiling}
                  aria-invalid={hardCeilingInvalid}
                  aria-describedby={hardCeilingInvalid ? POLICY_LIMITS_ERROR_ID : undefined}
                  disabled={isPolicyEditorBusy}
                  onChange={(event) => updateDraft({ applicationHardCeiling: event.target.value })}
                />
              </label>
            </div>
            <label className={styles.toggleField}>
              <input
                type="checkbox"
                checked={draft.falLimitConfirmed}
                disabled={isPolicyEditorBusy}
                aria-describedby={
                  falLimitConfirmationMissing ? POLICY_CONFIRMATION_ERROR_ID : undefined
                }
                onChange={(event) => updateDraft({ falLimitConfirmed: event.target.checked })}
              />
              <span>{text.confirmFalLimitLabel}</span>
            </label>
            {falLimitConfirmationMissing ? (
              <p id={POLICY_CONFIRMATION_ERROR_ID} className={styles.validation} role="alert">
                {text.confirmFalLimitRequired}
              </p>
            ) : null}
            {!isPolicyShapeValid ? (
              <p id={POLICY_LIMITS_ERROR_ID} className={styles.validation} role="alert">
                {text.invalidPolicy}
              </p>
            ) : null}

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
                    disabled={isPolicyEditorBusy}
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
                minLength={POLICY_REASON_MIN_LENGTH}
                maxLength={GENERATION_CONTROL_REASON_MAX_LENGTH}
                aria-invalid={!isReasonValid}
                aria-describedby={!isReasonValid ? POLICY_REASON_ERROR_ID : undefined}
                disabled={isPolicyEditorBusy}
                placeholder={text.reasonPlaceholder}
                onChange={(event) => updateDraft({ reason: event.target.value })}
              />
              {!isReasonValid ? (
                <small id={POLICY_REASON_ERROR_ID} role="alert">
                  {text.reasonRequired}
                </small>
              ) : null}
            </label>
          </div>
        ) : null}
      </ConfirmationDialog>
    </>
  );
}
