"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import {
  type KeyboardEvent as ReactKeyboardEvent,
  type ReactNode,
  useEffect,
  useMemo,
  useState,
} from "react";

import {
  AdminBadge,
  AdminCard,
  AdminStateCard,
  AdminStatusBadge,
  adminTableStyles,
} from "@/components/admin/admin-primitives";
import { ConfirmationDialog } from "@/components/admin/confirmation-dialog";
import {
  getGenerationCapacityCopy,
  type GenerationCapacityCopy,
} from "@/components/generation-capacity-page.content";
import styles from "@/components/generation-capacity-page.module.css";
import { Button } from "@/components/ui/button";
import { createAdminCorrelationId } from "@/lib/admin-correlation-id";
import { getAdminErrorMessage } from "@/lib/admin-error-message";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
  acknowledgeAdminGenerationAlert,
  cancelAdminGenerationRenderScaleOperation,
  fetchAdminGenerationControl,
  fetchAdminGenerationRenderScaleOperation,
  refreshAdminFalProviderBalance,
  requestAdminGenerationRenderScale,
  updateAdminGenerationControl,
  type AdminGenerationControlAlert,
  type AdminGenerationControlSnapshot,
  type AdminGenerationWorkerState,
  type AdminRenderScaleOperation,
  type UpdateAdminGenerationControlCommand,
} from "@/lib/api-client";
import { formatDateTime } from "@/lib/format-date-time";
import {
  createGenerationCapacitySettingsCommand,
  generationCapacityMutableSettings,
  updateGenerationCapacitySettingsDraft,
  type GenerationCapacityMutableSettings,
  type GenerationCapacitySettingsDraft,
} from "@/lib/generation-capacity-settings-draft";
import {
  applyGenerationCapacityPreset,
  createGenerationCapacityViewModel,
} from "@/lib/generation-capacity-view-model";
import { type Locale } from "@/lib/i18n";

const integerFieldKeys = [
  "globalMaxConcurrent",
  "imageMaxConcurrent",
  "imageProtectedConcurrent",
  "videoGuaranteedConcurrent",
  "videoMaxConcurrent",
  "videoBorrowMaxConcurrent",
  "workerLoopsPerInstance",
  "falConfiguredConcurrency",
  "falReservedConcurrency",
] as const satisfies readonly (keyof GenerationCapacityMutableSettings)[];

const moneyFieldKeys = [
  "falBalanceLowThresholdUsd",
  "falBalanceCriticalThresholdUsd",
] as const satisfies readonly (keyof GenerationCapacityMutableSettings)[];

const settingsFieldKeys = [...integerFieldKeys, ...moneyFieldKeys] as const;

const settingsGroups = [
  {
    key: "total",
    fields: ["globalMaxConcurrent", "workerLoopsPerInstance"],
  },
  {
    key: "image",
    fields: ["imageMaxConcurrent", "imageProtectedConcurrent"],
  },
  {
    key: "video",
    fields: ["videoGuaranteedConcurrent", "videoMaxConcurrent", "videoBorrowMaxConcurrent"],
  },
  {
    key: "fal",
    fields: ["falConfiguredConcurrency", "falReservedConcurrency"],
  },
  {
    key: "balance",
    fields: ["falBalanceLowThresholdUsd", "falBalanceCriticalThresholdUsd"],
  },
] as const;

type SettingsFieldKey = (typeof settingsFieldKeys)[number];
type SettingsGroupKey = (typeof settingsGroups)[number]["key"];
type CapacitySection = "overview" | "limits" | "fal" | "workers" | "alerts";

const capacitySections = ["overview", "limits", "fal", "workers", "alerts"] as const;

type SettingsValidationIssue = {
  field: SettingsFieldKey;
  message: string;
};

type RenderScaleReviewBaseline = {
  instances: number;
  plan: string;
};

type ChecklistRowProps = {
  title: string;
  status: string;
  description: string;
  ready: boolean;
  action?: ReactNode;
};

type CapacityStageProps = {
  label: string;
  value: string;
  detail: string;
  isBottleneck?: boolean;
  bottleneckLabel: string;
};

type MetricStripProps = {
  items: readonly { label: ReactNode; value: ReactNode }[];
  className?: string;
};

type SettingsFieldProps = {
  fieldKey: SettingsFieldKey;
  value: number;
  copy: GenerationCapacityCopy;
  issues: SettingsValidationIssue[];
  onChange: (key: SettingsFieldKey, value: string) => void;
};

function getErrorStatus(error: unknown): number | null {
  if (!error || typeof error !== "object" || !("status" in error)) return null;
  return typeof error.status === "number" ? error.status : null;
}

function healthColor(value: string): string {
  if (value === "healthy") return "var(--success)";
  if (value === "critical") return "var(--danger)";
  if (value === "degraded" || value === "low") return "var(--warning)";
  return "var(--text-soft)";
}

function isCapacitySection(value: string | null | undefined): value is CapacitySection {
  return capacitySections.includes(value as CapacitySection);
}

function isTerminalOperation(operation: AdminRenderScaleOperation | null | undefined): boolean {
  return Boolean(operation && ["completed", "failed", "cancelled"].includes(operation.status));
}

function validateSettings(
  draft: GenerationCapacityMutableSettings,
  text: GenerationCapacityCopy
): SettingsValidationIssue[] {
  const issues: SettingsValidationIssue[] = [];
  const zeroAllowed = new Set<SettingsFieldKey>([
    "videoBorrowMaxConcurrent",
    "falReservedConcurrency",
  ]);

  for (const key of integerFieldKeys) {
    if (key === "falConfiguredConcurrency") continue;
    const minimum = zeroAllowed.has(key) ? 0 : 1;
    if (!Number.isInteger(draft[key]) || draft[key] < minimum) {
      issues.push({
        field: key,
        message: text.settings.validation.invalidInteger(text.fields[key].label),
      });
    }
  }

  if (!Number.isInteger(draft.falConfiguredConcurrency) || draft.falConfiguredConcurrency <= 0) {
    issues.push({
      field: "falConfiguredConcurrency",
      message: text.settings.validation.falLimitMissing,
    });
  }
  if (draft.workerLoopsPerInstance < 1 || draft.workerLoopsPerInstance > 2) {
    issues.push({ field: "workerLoopsPerInstance", message: text.settings.validation.workerLoops });
  }
  if (
    draft.falConfiguredConcurrency > 0 &&
    draft.globalMaxConcurrent > draft.falConfiguredConcurrency - draft.falReservedConcurrency
  ) {
    issues.push({
      field: "globalMaxConcurrent",
      message: text.settings.validation.globalExceedsFal,
    });
  }
  if (draft.imageMaxConcurrent > draft.globalMaxConcurrent) {
    issues.push({ field: "imageMaxConcurrent", message: text.settings.validation.imageMax });
  }
  if (
    draft.imageProtectedConcurrent < 1 ||
    draft.imageProtectedConcurrent > draft.imageMaxConcurrent
  ) {
    issues.push({
      field: "imageProtectedConcurrent",
      message: text.settings.validation.imageProtected,
    });
  }
  if (draft.videoMaxConcurrent > draft.globalMaxConcurrent) {
    issues.push({ field: "videoMaxConcurrent", message: text.settings.validation.videoMax });
  }
  if (draft.videoGuaranteedConcurrent > draft.videoMaxConcurrent) {
    issues.push({
      field: "videoGuaranteedConcurrent",
      message: text.settings.validation.videoGuaranteed,
    });
  }
  if (draft.videoGuaranteedConcurrent + draft.videoBorrowMaxConcurrent < draft.videoMaxConcurrent) {
    issues.push({
      field: "videoBorrowMaxConcurrent",
      message: text.settings.validation.videoBorrow,
    });
  }
  if (
    draft.falBalanceCriticalThresholdUsd < 0 ||
    draft.falBalanceLowThresholdUsd < draft.falBalanceCriticalThresholdUsd
  ) {
    issues.push({
      field: "falBalanceCriticalThresholdUsd",
      message: text.settings.validation.balanceThresholds,
    });
  }
  return issues;
}

function ChecklistRow({ title, status, description, ready, action }: ChecklistRowProps) {
  return (
    <li className={styles.checklistRow}>
      <span className={`${styles.checkMark} ${ready ? styles.checkReady : styles.checkAttention}`}>
        {ready ? "✓" : "!"}
      </span>
      <div className={styles.checklistCopy}>
        <div className={styles.checklistHeading}>
          <strong>{title}</strong>
          <span>{status}</span>
        </div>
        <p>{description}</p>
      </div>
      {action ? <div className={styles.checklistAction}>{action}</div> : null}
    </li>
  );
}

function CapacityStage({
  label,
  value,
  detail,
  isBottleneck = false,
  bottleneckLabel,
}: CapacityStageProps) {
  return (
    <div className={`${styles.capacityStage} ${isBottleneck ? styles.capacityBottleneck : ""}`}>
      <span>{label}</span>
      <strong>{value}</strong>
      <small>{isBottleneck ? bottleneckLabel : detail}</small>
    </div>
  );
}

function MetricStrip({ items, className }: MetricStripProps) {
  return (
    <dl className={`${styles.metricStrip} ${className ?? ""}`}>
      {items.map((item, index) => (
        <div key={index} className={styles.metricItem}>
          <dt>{item.label}</dt>
          <dd>{item.value}</dd>
        </div>
      ))}
    </dl>
  );
}

function SettingsField({ fieldKey, value, copy, issues, onChange }: SettingsFieldProps) {
  const fieldIssues = issues.filter((issue) => issue.field === fieldKey);
  const inputId = `generation-capacity-${fieldKey}`;
  const hintId = `${inputId}-hint`;
  const errorId = `${inputId}-error`;
  const isMoney = moneyFieldKeys.includes(fieldKey as (typeof moneyFieldKeys)[number]);

  return (
    <div className={styles.field}>
      <label className={styles.label} htmlFor={inputId}>
        {copy.fields[fieldKey].label}
      </label>
      <input
        id={inputId}
        className={styles.input}
        type="number"
        min={fieldKey === "workerLoopsPerInstance" ? 1 : 0}
        max={fieldKey === "workerLoopsPerInstance" ? 2 : undefined}
        step={isMoney ? 0.01 : 1}
        value={value}
        aria-describedby={`${hintId}${fieldIssues.length > 0 ? ` ${errorId}` : ""}`}
        aria-invalid={fieldIssues.length > 0}
        onChange={(event) => onChange(fieldKey, event.target.value)}
      />
      <small id={hintId}>{copy.fields[fieldKey].hint}</small>
      {fieldIssues.length > 0 ? (
        <span id={errorId} className={styles.fieldError}>
          {fieldIssues[0].message}
        </span>
      ) : null}
    </div>
  );
}

function formatHeartbeatAge(seconds: number, locale: Locale): string {
  const roundedSeconds = Math.max(0, Math.round(seconds));
  const formatter = new Intl.RelativeTimeFormat(locale, { numeric: "auto" });
  if (roundedSeconds < 60) return formatter.format(-roundedSeconds, "second");
  const minutes = Math.round(roundedSeconds / 60);
  if (minutes < 60) return formatter.format(-minutes, "minute");
  const hours = Math.round(minutes / 60);
  if (hours < 48) return formatter.format(-hours, "hour");
  return formatter.format(-Math.round(hours / 24), "day");
}

function shortWorkerId(instanceId: string): string {
  return instanceId.length > 18 ? `${instanceId.slice(0, 8)}…${instanceId.slice(-6)}` : instanceId;
}

function workerTone(worker: AdminGenerationWorkerState): "success" | "warning" {
  return worker.isStale || !worker.isConfigCurrent || worker.isDraining ? "warning" : "success";
}

function workerStatus(worker: AdminGenerationWorkerState, text: GenerationCapacityCopy): string {
  if (worker.isStale) return text.workers.stale;
  if (worker.isDraining) return text.workers.draining;
  if (worker.isConfigCurrent) return text.workers.current;
  return `${text.revision} ${worker.appliedSettingsVersion}`;
}

function alertPresentation(alert: AdminGenerationControlAlert, text: GenerationCapacityCopy) {
  return (
    text.alerts.catalog[alert.code] ?? {
      title: alert.title,
      message: alert.message,
      action: text.nav.overview,
      target: "limits" as const,
    }
  );
}

function alertTargetSection(target: "fal" | "limits" | "workers"): CapacitySection {
  if (target === "fal") return "fal";
  if (target === "workers") return "workers";
  return "limits";
}

export function GenerationCapacityPage({
  locale,
  initialSection,
}: {
  locale: Locale;
  initialSection?: string;
}) {
  const text = useMemo(() => getGenerationCapacityCopy(locale), [locale]);
  const queryClient = useQueryClient();
  const query = useQuery({
    queryKey: adminQueryKeys.generationControl,
    queryFn: ({ signal }) => fetchAdminGenerationControl(signal),
    staleTime: 5_000,
    refetchInterval: 15_000,
    refetchIntervalInBackground: false,
  });
  const snapshot = query.data;
  const [activeSection, setActiveSection] = useState<CapacitySection>(() =>
    isCapacitySection(initialSection) ? initialSection : "overview"
  );
  const [settingsEditing, setSettingsEditing] = useState(false);
  const [settingsDraft, setSettingsDraft] = useState<GenerationCapacitySettingsDraft | null>(null);
  const [presetAnnouncement, setPresetAnnouncement] = useState("");
  const [reviewOpen, setReviewOpen] = useState(false);
  const [settingsReason, setSettingsReason] = useState("");
  const [settingsConflict, setSettingsConflict] = useState(false);
  const [scaleOpen, setScaleOpen] = useState(false);
  const [scaleTarget, setScaleTarget] = useState(1);
  const [scaleReason, setScaleReason] = useState("");
  const [scaleCostConfirmed, setScaleCostConfirmed] = useState(false);
  const [scaleIdempotencyKey, setScaleIdempotencyKey] = useState("");
  const [scaleReviewBaseline, setScaleReviewBaseline] = useState<RenderScaleReviewBaseline | null>(
    null
  );
  const [scaleConflict, setScaleConflict] = useState(false);
  const [operationId, setOperationId] = useState<string | null>(null);

  const draft = useMemo(
    () =>
      settingsDraft?.values ??
      (snapshot ? generationCapacityMutableSettings(snapshot.settings) : null),
    [settingsDraft, snapshot]
  );
  const draftBaseValues = useMemo(
    () =>
      settingsDraft?.baseValues ??
      (snapshot ? generationCapacityMutableSettings(snapshot.settings) : null),
    [settingsDraft, snapshot]
  );
  const changedFields = useMemo(() => {
    if (!draft || !draftBaseValues) return [];
    return settingsFieldKeys.filter((key) => draft[key] !== draftBaseValues[key]);
  }, [draft, draftBaseValues]);
  const validationIssues = useMemo(
    () => (draft ? validateSettings(draft, text) : []),
    [draft, text]
  );

  const saveMutation = useMutation({
    mutationFn: (command: UpdateAdminGenerationControlCommand) =>
      updateAdminGenerationControl(command),
    onSuccess: (next) => {
      queryClient.setQueryData(adminQueryKeys.generationControl, next);
      setSettingsDraft(null);
      setPresetAnnouncement("");
      setSettingsConflict(false);
      setSettingsReason("");
      setReviewOpen(false);
      setSettingsEditing(false);
    },
    onError: (error) => {
      if (getErrorStatus(error) === 409) {
        setSettingsConflict(true);
        setReviewOpen(false);
        void queryClient.invalidateQueries({ queryKey: adminQueryKeys.generationControl });
      }
    },
  });

  const providerRefreshMutation = useMutation({
    mutationFn: refreshAdminFalProviderBalance,
    onMutate: async () => {
      await queryClient.cancelQueries({ queryKey: adminQueryKeys.generationControl });
    },
    onSuccess: (next) => queryClient.setQueryData(adminQueryKeys.generationControl, next),
    onSettled: () => {
      void queryClient.invalidateQueries({ queryKey: adminQueryKeys.generationControl });
    },
  });

  const acknowledgeMutation = useMutation({
    mutationFn: acknowledgeAdminGenerationAlert,
    onSuccess: (acknowledged) => {
      queryClient.setQueryData<AdminGenerationControlSnapshot>(
        adminQueryKeys.generationControl,
        (current) =>
          current
            ? {
                ...current,
                alerts: current.alerts.map((item) =>
                  item.id === acknowledged.id ? acknowledged : item
                ),
              }
            : current
      );
    },
  });

  const scaleMutation = useMutation({
    mutationFn: ({
      target,
      reason,
      idempotencyKey,
      expectedCurrentInstances,
    }: {
      target: number;
      reason: string;
      idempotencyKey: string;
      expectedCurrentInstances: number | null;
    }) =>
      requestAdminGenerationRenderScale(
        { targetInstances: target, expectedCurrentInstances, reason, confirmed: true },
        idempotencyKey
      ),
    onSuccess: (operation) => {
      setOperationId(operation.operationId);
      setScaleOpen(false);
      setScaleReason("");
      setScaleCostConfirmed(false);
      setScaleReviewBaseline(null);
      setScaleConflict(false);
      void queryClient.invalidateQueries({ queryKey: adminQueryKeys.generationControl });
    },
    onError: (error) => {
      if (getErrorStatus(error) === 409) {
        setScaleConflict(true);
        void queryClient.invalidateQueries({ queryKey: adminQueryKeys.generationControl });
      }
    },
  });

  const operationQuery = useQuery({
    queryKey: operationId
      ? adminQueryKeys.generationRenderOperation(operationId)
      : ["admin", "templates", "generation-control", "render", "operations", "disabled"],
    queryFn: ({ signal }) => fetchAdminGenerationRenderScaleOperation(operationId!, signal),
    enabled: Boolean(operationId),
    refetchInterval: (queryState) => (isTerminalOperation(queryState.state.data) ? false : 2_000),
  });

  useEffect(() => {
    if (isTerminalOperation(operationQuery.data)) {
      void queryClient.invalidateQueries({ queryKey: adminQueryKeys.generationControl });
    }
  }, [operationQuery.data, queryClient]);

  const cancelOperationMutation = useMutation({
    mutationFn: cancelAdminGenerationRenderScaleOperation,
    onSuccess: (operation) => {
      queryClient.setQueryData(
        adminQueryKeys.generationRenderOperation(operation.operationId),
        operation
      );
      void queryClient.invalidateQueries({ queryKey: adminQueryKeys.generationControl });
    },
  });

  if (query.isLoading) {
    return <AdminStateCard title={text.loadingTitle} />;
  }
  if (query.isError) {
    return (
      <AdminStateCard
        tone="danger"
        title={text.errorTitle}
        description={getAdminErrorMessage(query.error, text.errorTitle)}
        action={<Button onClick={() => void query.refetch()}>{text.retry}</Button>}
      />
    );
  }
  if (!snapshot || !draft || !draftBaseValues) {
    return <AdminStateCard tone="warning" title={text.noData} />;
  }

  const currentServerSettings = snapshot.settings;
  const severityRank = { critical: 0, warning: 1, info: 2 } as const;
  const activeAlerts = snapshot.alerts
    .filter((alert) => alert.isActive)
    .toSorted((left, right) => severityRank[left.severity] - severityRank[right.severity]);
  const freshWorkers = snapshot.workers.filter((worker) => !worker.isStale);
  const staleWorkers = snapshot.workers.filter((worker) => worker.isStale);
  const heartbeatObservedLoops = freshWorkers.reduce(
    (total, worker) => total + worker.configuredLoops,
    0
  );
  const authoritativeRenderInstances =
    snapshot.render?.isConfigured &&
    snapshot.render.configurationError === null &&
    snapshot.render.activeInstances !== null
      ? snapshot.render.activeInstances
      : null;
  const observedWorkerInstances =
    authoritativeRenderInstances === null
      ? freshWorkers.length
      : Math.min(freshWorkers.length, authoritativeRenderInstances);
  const observedLoops =
    authoritativeRenderInstances === null
      ? heartbeatObservedLoops
      : Math.min(
          heartbeatObservedLoops,
          authoritativeRenderInstances * snapshot.settings.workerLoopsPerInstance
        );
  const capacity = createGenerationCapacityViewModel(snapshot, observedLoops);
  const snapshotRenderOperation = snapshot.render?.operation ?? null;
  const queriedRenderOperation = operationQuery.data ?? null;
  const snapshotHasActiveRenderOperation = Boolean(
    snapshotRenderOperation && !isTerminalOperation(snapshotRenderOperation)
  );
  const queriedHasActiveRenderOperation = Boolean(
    queriedRenderOperation && !isTerminalOperation(queriedRenderOperation)
  );
  const renderOperation = snapshotHasActiveRenderOperation
    ? snapshotRenderOperation
    : (queriedRenderOperation ?? snapshotRenderOperation);
  const hasActiveRenderOperation =
    snapshotHasActiveRenderOperation || queriedHasActiveRenderOperation;
  const renderTopologyKnown = Boolean(
    snapshot.render &&
    snapshot.render.configurationError === null &&
    snapshot.render.desiredInstances !== null &&
    snapshot.render.activeInstances !== null &&
    snapshot.render.desiredInstances === snapshot.render.activeInstances
  );
  const renderCanScale = Boolean(
    snapshot.render?.isConfigured &&
    !snapshot.render.autoscalingEnabled &&
    renderTopologyKnown &&
    !snapshot.status.isDraining &&
    !hasActiveRenderOperation
  );
  const paidUnusedLoops = Math.max(0, observedLoops - snapshot.settings.globalMaxConcurrent);
  const readiness = text.readiness.states[capacity.state];
  const falEnabled = snapshot.fal.isEnabled ?? true;
  const providerReason =
    falEnabled && snapshot.fal.submissionBlockReason
      ? (text.readiness.providerReasons[snapshot.fal.submissionBlockReason] ??
        snapshot.fal.submissionBlockReason)
      : null;
  const balanceReady =
    !falEnabled ||
    (!snapshot.fal.isStale &&
      snapshot.fal.balanceUsd !== null &&
      snapshot.fal.balanceStatus === "healthy");
  const balanceNeedsTopUp = falEnabled && ["low", "critical"].includes(snapshot.fal.balanceStatus);
  const renderReady = Boolean(snapshot.render?.isConfigured && !snapshot.render.configurationError);
  const falLastAttemptSucceeded =
    snapshot.fal.lastAttemptSucceeded ??
    (snapshot.fal.checkedAtUtc !== null &&
      snapshot.fal.lastSuccessAtUtc === snapshot.fal.checkedAtUtc &&
      snapshot.fal.balanceUsd !== null);
  const falAttemptState =
    snapshot.fal.checkedAtUtc === null
      ? "waiting"
      : !falLastAttemptSucceeded
        ? "failed"
        : snapshot.fal.isStale
          ? "stale"
          : "success";
  const falAttemptLabel =
    falAttemptState === "waiting"
      ? text.fal.lastAttemptWaiting
      : falAttemptState === "failed"
        ? text.fal.lastAttemptFailed
        : falAttemptState === "stale"
          ? text.fal.lastAttemptStale
          : text.fal.lastAttemptSuccess;
  const falBalanceIsCurrent = falAttemptState === "success";
  const falLimitNeedsAttention = falEnabled && snapshot.fal.configuredConcurrency <= 0;
  const falBalanceNeedsAttention = falEnabled && !balanceReady;
  const workerNeedsAttention = !capacity.workerCapacitySufficient;
  const primarySetupIssue = falLimitNeedsAttention
    ? "fal-limit"
    : falBalanceNeedsAttention
      ? "fal-balance"
      : workerNeedsAttention
        ? "workers"
        : null;
  const secondarySetupIssueCount =
    Number(falLimitNeedsAttention && primarySetupIssue !== "fal-limit") +
    Number(falBalanceNeedsAttention && primarySetupIssue !== "fal-balance") +
    Number(workerNeedsAttention && primarySetupIssue !== "workers");
  const falDiagnostic = snapshot.fal.lastErrorCode
    ? (text.fal.diagnostics[snapshot.fal.lastErrorCode] ?? {
        title: text.fal.lastAttemptFailed,
        description: text.fal.stale,
      })
    : null;
  const sectionLabels: Record<CapacitySection, string> = {
    overview: text.nav.overview,
    limits: text.nav.limits,
    fal: text.nav.fal,
    workers: text.nav.workers,
    alerts: text.nav.alerts,
  };

  function updateDraft(key: SettingsFieldKey, rawValue: string) {
    const numericValue = Number(rawValue);
    if (!Number.isFinite(numericValue)) return;
    setPresetAnnouncement("");
    setSettingsDraft((current) =>
      updateGenerationCapacitySettingsDraft(current, currentServerSettings, key, numericValue)
    );
  }

  function applySafeStartPreset() {
    setSettingsDraft((current) => {
      const baseValues =
        current?.baseValues ?? generationCapacityMutableSettings(currentServerSettings);
      const values = current?.values ?? baseValues;
      return {
        baseVersion: current?.baseVersion ?? currentServerSettings.version,
        baseValues,
        values: applyGenerationCapacityPreset(values),
      };
    });
    setSettingsEditing(true);
    setPresetAnnouncement(text.readiness.presetApplied);
    selectSection("limits");
  }

  function submitSettings() {
    if (!settingsDraft || validationIssues.length > 0 || settingsReason.trim().length < 3) return;
    saveMutation.mutate(
      createGenerationCapacitySettingsCommand(settingsDraft, settingsReason.trim())
    );
  }

  function resetScaleReview() {
    setScaleOpen(false);
    setScaleReason("");
    setScaleCostConfirmed(false);
    setScaleReviewBaseline(null);
    setScaleConflict(false);
    setScaleIdempotencyKey("");
    scaleMutation.reset();
  }

  function reloadScaleReview() {
    resetScaleReview();
    void query.refetch();
  }

  function selectSection(section: CapacitySection) {
    setActiveSection(section);
    const url = new URL(window.location.href);
    if (section === "overview") url.searchParams.delete("section");
    else url.searchParams.set("section", section);
    window.history.replaceState(window.history.state, "", url);
    requestAnimationFrame(() => {
      const tab = document.getElementById(`generation-tab-${section}`);
      tab?.scrollIntoView({ block: "nearest", inline: "nearest" });
      tab?.focus({ preventScroll: true });
    });
  }

  function handleSectionKeyDown(
    event: ReactKeyboardEvent<HTMLButtonElement>,
    section: CapacitySection
  ) {
    const currentIndex = capacitySections.indexOf(section);
    let nextIndex = currentIndex;
    if (event.key === "ArrowRight") nextIndex = (currentIndex + 1) % capacitySections.length;
    else if (event.key === "ArrowLeft") {
      nextIndex = (currentIndex - 1 + capacitySections.length) % capacitySections.length;
    } else if (event.key === "Home") nextIndex = 0;
    else if (event.key === "End") nextIndex = capacitySections.length - 1;
    else return;

    event.preventDefault();
    const nextSection = capacitySections[nextIndex];
    selectSection(nextSection);
  }

  return (
    <>
      <section className={styles.page}>
        <div className={styles.controlBar}>
          <div className={styles.liveMeta}>
            <span>
              {text.updated} {formatDateTime(snapshot.status.generatedAtUtc, locale)}
            </span>
            <span>{text.autoRefresh}</span>
            <span>
              {text.revision} {snapshot.settings.version}
            </span>
          </div>
          <Button
            size="sm"
            variant="secondary"
            disabled={query.isFetching}
            onClick={() => void query.refetch()}
          >
            {query.isFetching ? text.refreshing : text.refresh}
          </Button>
        </div>

        <div className={styles.sectionNav} role="tablist" aria-label={text.nav.label}>
          {capacitySections.map((section) => (
            <button
              key={section}
              id={`generation-tab-${section}`}
              type="button"
              role="tab"
              aria-selected={activeSection === section}
              aria-controls={activeSection === section ? `generation-${section}` : undefined}
              tabIndex={activeSection === section ? 0 : -1}
              onClick={() => selectSection(section)}
              onKeyDown={(event) => handleSectionKeyDown(event, section)}
            >
              {sectionLabels[section]}
              {section === "alerts" && activeAlerts.length > 0 ? (
                <span className={styles.tabCount}>{activeAlerts.length}</span>
              ) : null}
            </button>
          ))}
        </div>

        {activeSection === "overview" ? (
          <section
            id="generation-overview"
            role="tabpanel"
            tabIndex={-1}
            aria-labelledby="generation-tab-overview"
            className={`${styles.commandPanel} ${styles[`command_${capacity.tone}`]}`}
          >
            <div className={styles.readinessGrid}>
              <div className={styles.readinessMain}>
                <div className={styles.readinessHeader}>
                  <span className={styles.statusSignal} aria-hidden="true" />
                  <div>
                    <span className={styles.sectionLabel}>{text.readiness.title}</span>
                    <h2 id="generation-readiness-title">{readiness.title}</h2>
                    <p>{readiness.description}</p>
                  </div>
                  <AdminStatusBadge color={healthColor(snapshot.status.health)}>
                    {text.health[snapshot.status.health] ?? snapshot.status.health}
                  </AdminStatusBadge>
                </div>

                {providerReason ? (
                  <div className={styles.blockerLine}>
                    <strong>{providerReason}</strong>
                    <span>{text.readiness.queueContinues}</span>
                  </div>
                ) : null}

                {primarySetupIssue ? (
                  <div className={styles.primaryActions}>
                    {primarySetupIssue === "fal-limit" ? (
                      <Button variant="primary" onClick={applySafeStartPreset}>
                        {text.readiness.configureSafeStart}
                      </Button>
                    ) : primarySetupIssue === "fal-balance" ? (
                      balanceNeedsTopUp ? (
                        <>
                          <a
                            className="ui-button ui-button--primary ui-button--md"
                            href="https://fal.ai/dashboard/usage-billing/credits"
                            target="_blank"
                            rel="noreferrer"
                          >
                            {text.fal.topUpBalance}
                          </a>
                          <Button variant="secondary" onClick={() => selectSection("fal")}>
                            {text.readiness.checkBalance}
                          </Button>
                        </>
                      ) : (
                        <Button variant="primary" onClick={() => selectSection("fal")}>
                          {text.readiness.checkBalance}
                        </Button>
                      )
                    ) : (
                      <Button variant="primary" onClick={() => selectSection("workers")}>
                        {text.checklist.openScaling}
                      </Button>
                    )}
                  </div>
                ) : null}
                <span className={styles.srOnly} aria-live="polite">
                  {presetAnnouncement}
                </span>

                <div
                  className={`${styles.capacityRail} ${!falEnabled ? styles.capacityRailCompact : ""}`}
                  aria-label={text.readiness.effectiveCapacity}
                >
                  <CapacityStage
                    label={text.capacity.petmagic}
                    value={String(snapshot.settings.globalMaxConcurrent)}
                    detail={text.capacity.usage(
                      snapshot.status.activeGlobal,
                      snapshot.settings.globalMaxConcurrent
                    )}
                    isBottleneck={capacity.bottleneck === "petmagic"}
                    bottleneckLabel={text.capacity.bottleneck}
                  />
                  <CapacityStage
                    label={text.capacity.workers}
                    value={String(observedLoops)}
                    detail={text.capacity.workerTopology(observedWorkerInstances, observedLoops)}
                    isBottleneck={capacity.bottleneck === "workers"}
                    bottleneckLabel={text.capacity.bottleneck}
                  />
                  {falEnabled ? (
                    <CapacityStage
                      label={text.capacity.fal}
                      value={String(snapshot.fal.usableConcurrency)}
                      detail={
                        snapshot.fal.configuredConcurrency > 0
                          ? text.capacity.falFormula(
                              snapshot.fal.configuredConcurrency,
                              snapshot.fal.reservedConcurrency
                            )
                          : text.capacity.noLimit
                      }
                      isBottleneck={capacity.bottleneck === "fal"}
                      bottleneckLabel={text.capacity.bottleneck}
                    />
                  ) : null}
                  <CapacityStage
                    label={text.capacity.effective}
                    value={String(capacity.effectiveCapacity)}
                    detail={text.readiness.effectiveCapacity}
                    bottleneckLabel={text.capacity.bottleneck}
                  />
                </div>

                <MetricStrip
                  className={styles.queueMetrics}
                  items={[
                    {
                      label: `${text.capacity.image} · ${text.capacity.active}`,
                      value: `${snapshot.status.activeImage}/${snapshot.status.effectiveImageMaxConcurrent}`,
                    },
                    {
                      label: `${text.capacity.video} · ${text.capacity.active}`,
                      value: `${snapshot.status.activeVideo}/${snapshot.settings.videoMaxConcurrent}`,
                    },
                    {
                      label: `${text.capacity.image} · ${text.capacity.queued}`,
                      value: snapshot.status.queuedImage,
                    },
                    {
                      label: `${text.capacity.video} · ${text.capacity.queued}`,
                      value: snapshot.status.queuedVideo,
                    },
                    {
                      label: text.capacity.borrowed,
                      value: snapshot.status.borrowedVideo,
                    },
                  ]}
                />
                {snapshot.status.isDraining ? (
                  <p className={styles.inlineWarning}>{text.queue.draining}</p>
                ) : null}
              </div>

              <aside className={styles.checklistPanel} aria-labelledby="generation-checklist-title">
                <div className={styles.checklistTitle}>
                  <h2 id="generation-checklist-title">{text.checklist.title}</h2>
                  <p>{text.checklist.description}</p>
                </div>
                <ul className={styles.checklist}>
                  {falLimitNeedsAttention && primarySetupIssue !== "fal-limit" ? (
                    <ChecklistRow
                      title={text.checklist.falLimit}
                      status={
                        snapshot.fal.configuredConcurrency > 0
                          ? `${text.checklist.falLimitReady}: ${snapshot.fal.configuredConcurrency}`
                          : text.checklist.falLimitMissing
                      }
                      description={text.checklist.falLimitConsequence}
                      ready={snapshot.fal.configuredConcurrency > 0}
                      action={
                        snapshot.fal.configuredConcurrency <= 0 ? (
                          <button
                            className={styles.textAction}
                            type="button"
                            onClick={() => selectSection("limits")}
                          >
                            {text.checklist.configure}
                          </button>
                        ) : undefined
                      }
                    />
                  ) : null}
                  {falBalanceNeedsAttention && primarySetupIssue !== "fal-balance" ? (
                    <ChecklistRow
                      title={text.checklist.balance}
                      status={
                        snapshot.fal.balanceStatus === "healthy"
                          ? text.checklist.balanceReady
                          : snapshot.fal.balanceStatus === "low"
                            ? text.checklist.balanceLow
                            : snapshot.fal.balanceStatus === "critical"
                              ? text.checklist.balanceCritical
                              : text.checklist.balanceUnknown
                      }
                      description={text.checklist.balanceConsequence}
                      ready={balanceReady}
                      action={
                        balanceNeedsTopUp ? (
                          <a
                            className={styles.textAction}
                            href="https://fal.ai/dashboard/usage-billing/credits"
                            target="_blank"
                            rel="noreferrer"
                          >
                            {text.fal.openDashboard}
                          </a>
                        ) : !balanceReady ? (
                          <button
                            className={styles.textAction}
                            type="button"
                            onClick={() => selectSection("fal")}
                          >
                            {text.readiness.checkBalance}
                          </button>
                        ) : undefined
                      }
                    />
                  ) : null}
                  {workerNeedsAttention && primarySetupIssue !== "workers" ? (
                    <ChecklistRow
                      title={text.checklist.workers}
                      status={text.capacity.usage(
                        observedLoops,
                        snapshot.settings.globalMaxConcurrent
                      )}
                      description={text.checklist.workersConsequence}
                      ready={capacity.workerCapacitySufficient}
                      action={
                        !capacity.workerCapacitySufficient ? (
                          <button
                            className={styles.textAction}
                            type="button"
                            onClick={() => selectSection("workers")}
                          >
                            {text.checklist.openScaling}
                          </button>
                        ) : undefined
                      }
                    />
                  ) : null}
                </ul>
                {primarySetupIssue && secondarySetupIssueCount === 0 ? (
                  <div className={styles.checklistFocus}>{text.checklist.primaryShown}</div>
                ) : !primarySetupIssue ? (
                  <div className={styles.checklistReady}>✓ {text.checklist.ready}</div>
                ) : null}
              </aside>
            </div>
          </section>
        ) : null}

        {activeSection === "limits" ? (
          <section
            id="generation-limits"
            className={styles.anchorSection}
            role="tabpanel"
            tabIndex={-1}
            aria-labelledby="generation-tab-limits"
          >
            <AdminCard
              title={text.settings.title}
              description={text.settings.description}
              action={
                <div className={styles.cardActions}>
                  <AdminBadge tone="info">
                    {text.revision} {snapshot.settings.version}
                  </AdminBadge>
                  {settingsEditing ? (
                    <Button
                      size="sm"
                      variant="secondary"
                      onClick={() => {
                        setSettingsDraft(null);
                        setPresetAnnouncement("");
                        setSettingsEditing(false);
                      }}
                    >
                      {text.settings.discardDraft}
                    </Button>
                  ) : null}
                </div>
              }
            >
              {settingsConflict ? (
                <AdminStateCard
                  tone="warning"
                  title={text.settings.conflictTitle}
                  description={text.settings.conflictMessage}
                  action={
                    <Button
                      onClick={() => {
                        setSettingsDraft(null);
                        setSettingsConflict(false);
                        setSettingsReason("");
                      }}
                    >
                      {text.settings.reload}
                    </Button>
                  }
                />
              ) : null}

              {!settingsEditing ? (
                <div className={styles.settingsSummary}>
                  <div className={styles.settingsSummaryHeading}>
                    <div>
                      <strong>{text.settings.summaryTitle}</strong>
                      <p>{text.settings.summaryDescription}</p>
                    </div>
                    <div className={styles.settingsSummaryActions}>
                      <Button variant="secondary" onClick={applySafeStartPreset}>
                        {text.settings.applyPreset}
                      </Button>
                      <Button variant="primary" onClick={() => setSettingsEditing(true)}>
                        {text.settings.edit}
                      </Button>
                    </div>
                  </div>
                  <dl className={styles.settingsSummaryGrid}>
                    <div>
                      <dt>{text.fields.globalMaxConcurrent.label}</dt>
                      <dd>{snapshot.settings.globalMaxConcurrent}</dd>
                    </div>
                    <div>
                      <dt>{text.fields.imageMaxConcurrent.label}</dt>
                      <dd>
                        {snapshot.settings.imageMaxConcurrent} /{" "}
                        {snapshot.settings.imageProtectedConcurrent}
                      </dd>
                    </div>
                    <div>
                      <dt>{text.fields.videoMaxConcurrent.label}</dt>
                      <dd>
                        {snapshot.settings.videoGuaranteedConcurrent} /{" "}
                        {snapshot.settings.videoMaxConcurrent}
                        {snapshot.settings.videoBorrowMaxConcurrent > 0
                          ? ` +${snapshot.settings.videoBorrowMaxConcurrent}`
                          : ""}
                      </dd>
                    </div>
                    <div>
                      <dt>{text.fields.workerLoopsPerInstance.label}</dt>
                      <dd>{snapshot.settings.workerLoopsPerInstance}</dd>
                    </div>
                    <div>
                      <dt>{text.fields.falConfiguredConcurrency.label}</dt>
                      <dd>
                        {snapshot.settings.falConfiguredConcurrency || "—"} −{" "}
                        {snapshot.settings.falReservedConcurrency}
                      </dd>
                    </div>
                    <div>
                      <dt>{text.settings.groups.balance.title}</dt>
                      <dd>
                        ${snapshot.settings.falBalanceLowThresholdUsd} / $
                        {snapshot.settings.falBalanceCriticalThresholdUsd}
                      </dd>
                    </div>
                  </dl>
                </div>
              ) : (
                <>
                  <div className={styles.presetBand}>
                    <div>
                      <strong>{text.settings.presetTitle}</strong>
                      <span>{text.settings.presetDescription}</span>
                      <code>{text.settings.presetValues}</code>
                      <small>{text.settings.presetDoesNotSave}</small>
                    </div>
                    <Button variant="secondary" onClick={applySafeStartPreset}>
                      {text.settings.applyPreset}
                    </Button>
                  </div>
                  {presetAnnouncement ? (
                    <p className={styles.presetAnnouncement} role="status">
                      {presetAnnouncement}
                    </p>
                  ) : null}

                  <div className={styles.settingsGroups}>
                    {settingsGroups.map((group) => {
                      const groupCopy = text.settings.groups[group.key as SettingsGroupKey];
                      return (
                        <fieldset key={group.key} className={styles.settingsGroup}>
                          <legend>{groupCopy.title}</legend>
                          <p>{groupCopy.description}</p>
                          <div className={styles.groupFields}>
                            {group.fields.map((key) => (
                              <SettingsField
                                key={key}
                                fieldKey={key}
                                value={draft[key]}
                                copy={text}
                                issues={validationIssues}
                                onChange={updateDraft}
                              />
                            ))}
                          </div>
                        </fieldset>
                      );
                    })}
                  </div>

                  {validationIssues.length > 0 ? (
                    <div className={styles.validationPanel} role="alert">
                      <strong>{text.settings.validationTitle}</strong>
                      <ul>
                        {Array.from(new Set(validationIssues.map((issue) => issue.message))).map(
                          (message) => (
                            <li key={message}>{message}</li>
                          )
                        )}
                      </ul>
                    </div>
                  ) : null}
                  {saveMutation.isError && !settingsConflict ? (
                    <AdminStateCard
                      tone="danger"
                      title={getAdminErrorMessage(saveMutation.error, text.errorTitle)}
                    />
                  ) : null}
                  <div className={styles.settingsActions}>
                    <div>
                      <strong>
                        {changedFields.length === 0
                          ? text.settings.noChanges
                          : text.settings.changes(changedFields.length)}
                      </strong>
                      <span>
                        {changedFields.length === 0 || validationIssues.length > 0
                          ? text.settings.whyDisabled
                          : text.settings.presetDoesNotSave}
                      </span>
                    </div>
                    <Button
                      variant="primary"
                      disabled={
                        settingsConflict ||
                        changedFields.length === 0 ||
                        validationIssues.length > 0 ||
                        saveMutation.isPending
                      }
                      onClick={() => setReviewOpen(true)}
                    >
                      {text.settings.saveReview}
                    </Button>
                  </div>
                </>
              )}
            </AdminCard>
          </section>
        ) : null}

        {activeSection === "fal" ? (
          <section
            id="generation-fal"
            className={styles.anchorSection}
            role="tabpanel"
            tabIndex={-1}
            aria-labelledby="generation-tab-fal"
          >
            <AdminCard
              title={text.fal.title}
              description={text.fal.description}
              action={
                <AdminStatusBadge
                  color={
                    !falEnabled
                      ? "var(--text-muted)"
                      : snapshot.fal.providerSubmissionsAllowed
                        ? "var(--success)"
                        : "var(--danger)"
                  }
                >
                  {!falEnabled
                    ? (snapshot.fal.configuredProvider ?? "Fake")
                    : snapshot.fal.providerSubmissionsAllowed
                      ? text.health.healthy
                      : text.health.critical}
                </AdminStatusBadge>
              }
            >
              {!falEnabled ? (
                <div className={styles.inlineWarning}>{text.fal.providerNotUsed}</div>
              ) : !snapshot.fal.providerSubmissionsAllowed ? (
                <div className={styles.inlineDanger}>
                  <strong>{providerReason ?? text.fal.stale}</strong>
                  <span>{text.readiness.queueContinues}</span>
                </div>
              ) : null}
              <div className={styles.providerWorkspace}>
                <div className={styles.providerStatusPanel}>
                  <div className={styles.providerAttempt} aria-live="polite">
                    <span
                      className={`${styles.attemptSignal} ${
                        falAttemptState === "success"
                          ? styles.attemptSuccess
                          : falAttemptState === "failed"
                            ? styles.attemptFailure
                            : falAttemptState === "stale"
                              ? styles.attemptStale
                              : styles.attemptNeutral
                      }`}
                      aria-hidden="true"
                    />
                    <div>
                      <strong>{falAttemptLabel}</strong>
                      <span>
                        {snapshot.fal.checkedAtUtc === null
                          ? "—"
                          : formatDateTime(snapshot.fal.checkedAtUtc, locale)}
                      </span>
                    </div>
                    {snapshot.fal.billingAdminKeyConfigured !== undefined &&
                    snapshot.fal.billingAdminKeyConfigured !== null ? (
                      <AdminBadge
                        tone={snapshot.fal.billingAdminKeyConfigured ? "success" : "warning"}
                      >
                        {snapshot.fal.billingAdminKeyConfigured
                          ? text.fal.billingKeyReady
                          : text.fal.billingKeyMissing}
                      </AdminBadge>
                    ) : null}
                  </div>

                  {falDiagnostic ? (
                    <div className={styles.providerDiagnostic} role="status">
                      <strong>{falDiagnostic.title}</strong>
                      <p>{falDiagnostic.description}</p>
                      <small>
                        {text.fal.diagnosticReason}: <code>{snapshot.fal.lastErrorCode}</code>
                        {typeof snapshot.fal.consecutiveFailures === "number" &&
                        snapshot.fal.consecutiveFailures > 1
                          ? ` · ×${snapshot.fal.consecutiveFailures}`
                          : ""}
                      </small>
                    </div>
                  ) : null}

                  <dl className={styles.providerFacts}>
                    <div>
                      <dt>
                        {falBalanceIsCurrent ? text.fal.balance : text.fal.lastConfirmedBalance}
                      </dt>
                      <dd>
                        {snapshot.fal.balanceUsd === null
                          ? "—"
                          : `$${snapshot.fal.balanceUsd.toFixed(2)}`}
                      </dd>
                    </div>
                    <div>
                      <dt>{text.fal.lastSuccess}</dt>
                      <dd>{formatDateTime(snapshot.fal.lastSuccessAtUtc, locale)}</dd>
                    </div>
                    <div>
                      <dt>{text.fal.usable}</dt>
                      <dd>{snapshot.fal.usableConcurrency}</dd>
                    </div>
                    <div>
                      <dt>{text.fal.configured}</dt>
                      <dd>{snapshot.fal.configuredConcurrency || "—"}</dd>
                    </div>
                    <div>
                      <dt>{text.fal.reserve}</dt>
                      <dd>{snapshot.fal.reservedConcurrency}</dd>
                    </div>
                    <div>
                      <dt>{text.fal.inflight}</dt>
                      <dd>{snapshot.fal.inflightRequests}</dd>
                    </div>
                  </dl>

                  <div className={styles.providerActions}>
                    <Button
                      variant="primary"
                      disabled={providerRefreshMutation.isPending || !falEnabled}
                      onClick={() => {
                        providerRefreshMutation.reset();
                        providerRefreshMutation.mutate();
                      }}
                    >
                      {providerRefreshMutation.isPending ? text.fal.refreshing : text.fal.refresh}
                    </Button>
                    <a
                      className={styles.externalAction}
                      href="https://fal.ai/dashboard/usage-billing/credits"
                      target="_blank"
                      rel="noreferrer"
                    >
                      {text.fal.openDashboard}
                    </a>
                  </div>
                </div>

                <aside className={styles.verificationPanel}>
                  <strong>{text.fal.verificationTitle}</strong>
                  <p>{text.fal.verificationDescription}</p>
                  <ol>
                    {text.fal.verificationChecks.map((check) => (
                      <li key={check}>{check}</li>
                    ))}
                  </ol>
                  <p className={styles.verificationBoundary}>{text.fal.verificationDoesNotCheck}</p>
                  <small>{text.fal.keyNotice}</small>
                  <small>{text.fal.manualLimit}</small>
                </aside>
              </div>
              {providerRefreshMutation.isError ? (
                <AdminStateCard
                  tone="warning"
                  title={getAdminErrorMessage(providerRefreshMutation.error, text.errorTitle)}
                />
              ) : null}
            </AdminCard>
          </section>
        ) : null}

        {activeSection === "workers" ? (
          <section
            id="generation-workers"
            className={styles.anchorSection}
            role="tabpanel"
            tabIndex={-1}
            aria-labelledby="generation-tab-workers"
          >
            <AdminCard title={text.workers.title} description={text.workers.description}>
              <div className={styles.workersRenderGrid}>
                <div className={styles.workerPanel}>
                  <MetricStrip
                    items={[
                      { label: text.workers.currentWorkers, value: freshWorkers.length },
                      { label: text.workers.observedCapacity, value: observedLoops },
                      {
                        label: text.workers.requiredCapacity,
                        value: snapshot.settings.globalMaxConcurrent,
                      },
                      {
                        label: text.workers.requiredInstances,
                        value: capacity.requiredWorkerInstances,
                      },
                      ...(paidUnusedLoops > 0
                        ? [{ label: text.workers.paidUnusedCapacity, value: paidUnusedLoops }]
                        : []),
                    ]}
                  />

                  {freshWorkers.length === 0 ? (
                    <div className={styles.inlineWarning}>{text.workers.empty}</div>
                  ) : (
                    <>
                      <div className={`${adminTableStyles.tableWrap} ${styles.workerTableWrap}`}>
                        <table className={adminTableStyles.table}>
                          <caption className={styles.srOnly}>{text.workers.currentWorkers}</caption>
                          <thead>
                            <tr>
                              <th scope="col">{text.workers.instance}</th>
                              <th scope="col">{text.workers.loops}</th>
                              <th scope="col">{text.workers.revision}</th>
                              <th scope="col">{text.workers.heartbeat}</th>
                              <th scope="col">{text.workers.status}</th>
                            </tr>
                          </thead>
                          <tbody>
                            {freshWorkers.map((worker) => (
                              <tr key={worker.instanceId}>
                                <td className={adminTableStyles.mono} title={worker.instanceId}>
                                  {shortWorkerId(worker.instanceId)}
                                </td>
                                <td>{worker.configuredLoops}</td>
                                <td>{worker.appliedSettingsVersion}</td>
                                <td>{formatHeartbeatAge(worker.heartbeatAgeSeconds, locale)}</td>
                                <td>
                                  <AdminBadge tone={workerTone(worker)}>
                                    {workerStatus(worker, text)}
                                  </AdminBadge>
                                </td>
                              </tr>
                            ))}
                          </tbody>
                        </table>
                      </div>
                      <ul className={styles.workerCards} aria-label={text.workers.currentWorkers}>
                        {freshWorkers.map((worker) => (
                          <li key={worker.instanceId}>
                            <div>
                              <code title={worker.instanceId}>
                                {shortWorkerId(worker.instanceId)}
                              </code>
                              <AdminBadge tone={workerTone(worker)}>
                                {workerStatus(worker, text)}
                              </AdminBadge>
                            </div>
                            <dl>
                              <div>
                                <dt>{text.workers.loops}</dt>
                                <dd>{worker.configuredLoops}</dd>
                              </div>
                              <div>
                                <dt>{text.workers.revision}</dt>
                                <dd>{worker.appliedSettingsVersion}</dd>
                              </div>
                              <div>
                                <dt>{text.workers.heartbeat}</dt>
                                <dd>{formatHeartbeatAge(worker.heartbeatAgeSeconds, locale)}</dd>
                              </div>
                            </dl>
                          </li>
                        ))}
                      </ul>
                    </>
                  )}

                  {staleWorkers.length > 0 ? (
                    <details className={styles.staleWorkers}>
                      <summary>{text.workers.staleHistory(staleWorkers.length)}</summary>
                      <p>{text.workers.staleHistoryHint}</p>
                      <ul>
                        {staleWorkers.map((worker) => (
                          <li key={worker.instanceId}>
                            <code title={worker.instanceId}>
                              {shortWorkerId(worker.instanceId)}
                            </code>
                            <span>{formatHeartbeatAge(worker.heartbeatAgeSeconds, locale)}</span>
                            <AdminBadge tone="neutral">{text.workers.stale}</AdminBadge>
                          </li>
                        ))}
                      </ul>
                    </details>
                  ) : null}
                </div>

                <div className={styles.renderPanel}>
                  <div className={styles.subsectionHeading}>
                    <div>
                      <h3>{text.render.title}</h3>
                      <p>{text.render.description}</p>
                    </div>
                    <AdminBadge tone={renderReady ? "success" : "warning"}>
                      {renderReady ? text.checklist.renderReady : text.checklist.renderMissing}
                    </AdminBadge>
                  </div>

                  {!snapshot.render?.isConfigured ? (
                    <details id="generation-render-setup" className={styles.setupDetails}>
                      <summary>{text.render.setupTitle}</summary>
                      <p>{text.render.setupDescription}</p>
                      <ol className={styles.setupSteps}>
                        {text.render.setupSteps.map((step) => (
                          <li key={step}>{step}</li>
                        ))}
                      </ol>
                      <ul className={styles.setupVariables}>
                        {text.render.setupVariables.map((variable) => (
                          <li key={variable}>
                            <code>{variable}</code>
                          </li>
                        ))}
                      </ul>
                      <small>{text.render.setupSecretNotice}</small>
                      <a
                        className={styles.externalAction}
                        href="https://dashboard.render.com/"
                        target="_blank"
                        rel="noreferrer"
                      >
                        {text.render.openDashboard}
                      </a>
                      {snapshot.render?.configurationError ? (
                        <small>{snapshot.render.configurationError}</small>
                      ) : null}
                    </details>
                  ) : (
                    <>
                      {snapshot.render.autoscalingEnabled ? (
                        <div className={styles.inlineWarning}>{text.render.autoscaling}</div>
                      ) : null}
                      {snapshot.render.configurationError ? (
                        <div id="generation-render-setup" className={styles.inlineDanger}>
                          <strong>{text.render.unavailable}</strong>
                          <span>{snapshot.render.configurationError}</span>
                        </div>
                      ) : null}
                      <dl className={styles.renderFacts}>
                        <div>
                          <dt>{text.render.service}</dt>
                          <dd>{snapshot.render.serviceName ?? "—"}</dd>
                        </div>
                        <div>
                          <dt>{text.render.plan}</dt>
                          <dd>{snapshot.render.plan ?? "—"}</dd>
                        </div>
                        <div>
                          <dt>{text.render.region}</dt>
                          <dd>{snapshot.render.region ?? "—"}</dd>
                        </div>
                        <div>
                          <dt>{text.render.topology}</dt>
                          <dd>
                            {snapshot.render.activeInstances ?? "—"} /{" "}
                            {snapshot.render.desiredInstances ?? "—"}
                          </dd>
                        </div>
                      </dl>
                      {renderOperation ? (
                        <div className={styles.operationRow}>
                          <div>
                            <span>{text.render.operation}</span>
                            <strong>
                              {text.render.operationStatuses[renderOperation.status] ??
                                renderOperation.status}
                            </strong>
                            <small>
                              {renderOperation.initialInstances ?? "—"} →{" "}
                              {renderOperation.targetInstances} · {renderOperation.loopsPerInstance}{" "}
                              loops
                            </small>
                          </div>
                          {renderOperation.canCancel && !isTerminalOperation(renderOperation) ? (
                            <Button
                              variant="danger"
                              size="sm"
                              disabled={cancelOperationMutation.isPending}
                              onClick={() => {
                                cancelOperationMutation.reset();
                                cancelOperationMutation.mutate(renderOperation.operationId);
                              }}
                            >
                              {text.render.cancelOperation}
                            </Button>
                          ) : null}
                        </div>
                      ) : null}
                      <div className={styles.renderActions}>
                        <div>
                          <strong>
                            {snapshot.render.plan ?? "Render"} ×{" "}
                            {snapshot.render.desiredInstances ??
                              snapshot.render.activeInstances ??
                              1}
                          </strong>
                          <span>{text.render.billingNotice}</span>
                        </div>
                        <Button
                          variant="primary"
                          disabled={!renderCanScale}
                          onClick={() => {
                            const currentInstances =
                              snapshot.render?.desiredInstances ??
                              snapshot.render?.activeInstances ??
                              1;
                            const currentPlan = snapshot.render?.plan?.trim() || "Render";
                            setScaleTarget(Math.max(1, Math.min(8, currentInstances)));
                            setScaleReviewBaseline({
                              instances: currentInstances,
                              plan: currentPlan,
                            });
                            setScaleIdempotencyKey(
                              `generation-scale:${createAdminCorrelationId()}`
                            );
                            setScaleCostConfirmed(false);
                            setScaleConflict(false);
                            scaleMutation.reset();
                            setScaleOpen(true);
                          }}
                        >
                          {text.render.review}
                        </Button>
                      </div>
                    </>
                  )}
                  {cancelOperationMutation.isError ? (
                    <AdminStateCard
                      tone="danger"
                      title={getAdminErrorMessage(cancelOperationMutation.error, text.errorTitle)}
                    />
                  ) : null}
                  {scaleMutation.isError ? (
                    <AdminStateCard
                      tone="danger"
                      title={getAdminErrorMessage(scaleMutation.error, text.errorTitle)}
                    />
                  ) : null}
                </div>
              </div>
            </AdminCard>
          </section>
        ) : null}

        {activeSection === "alerts" ? (
          <section
            id="generation-alerts"
            className={styles.anchorSection}
            role="tabpanel"
            tabIndex={-1}
            aria-labelledby="generation-tab-alerts"
          >
            <AdminCard title={text.alerts.title} description={text.alerts.description}>
              {acknowledgeMutation.isError ? (
                <AdminStateCard
                  tone="danger"
                  title={getAdminErrorMessage(acknowledgeMutation.error, text.errorTitle)}
                />
              ) : null}
              {activeAlerts.length === 0 ? (
                <div className={styles.emptyAlerts}>✓ {text.alerts.empty}</div>
              ) : (
                <div className={styles.alertList}>
                  {activeAlerts.map((alert) => {
                    const presentation = alertPresentation(alert, text);
                    return (
                      <article
                        key={alert.id}
                        className={`${styles.alertRow} ${styles[`alert_${alert.severity}`]}`}
                      >
                        <span className={styles.alertIndicator} aria-hidden="true" />
                        <div className={styles.alertBody}>
                          <div className={styles.alertHeading}>
                            <h3>{presentation.title}</h3>
                            <time dateTime={alert.activatedAtUtc}>
                              {formatDateTime(alert.activatedAtUtc, locale)}
                            </time>
                          </div>
                          <p>{presentation.message}</p>
                          <small>
                            {text.alerts.technicalCode}: <code>{alert.code}</code>
                          </small>
                        </div>
                        <div className={styles.alertActions}>
                          <button
                            className={styles.textAction}
                            type="button"
                            onClick={() => selectSection(alertTargetSection(presentation.target))}
                          >
                            {presentation.action}
                          </button>
                          {alert.isAcknowledged ? (
                            <AdminBadge tone="success">{text.alerts.acknowledged}</AdminBadge>
                          ) : (
                            <Button
                              size="sm"
                              variant="secondary"
                              aria-label={`${text.alerts.acknowledge}: ${presentation.title}`}
                              disabled={
                                acknowledgeMutation.isPending &&
                                acknowledgeMutation.variables === alert.id
                              }
                              onClick={() => {
                                acknowledgeMutation.reset();
                                acknowledgeMutation.mutate(alert.id);
                              }}
                            >
                              {acknowledgeMutation.isPending &&
                              acknowledgeMutation.variables === alert.id
                                ? text.alerts.acknowledging
                                : text.alerts.acknowledge}
                            </Button>
                          )}
                        </div>
                      </article>
                    );
                  })}
                </div>
              )}
              <p className={styles.acknowledgementHint}>{text.alerts.acknowledgementHint}</p>
            </AdminCard>
          </section>
        ) : null}
      </section>

      <ConfirmationDialog
        open={reviewOpen}
        title={text.settings.reviewTitle}
        description={text.settings.reviewDescription}
        confirmLabel={saveMutation.isPending ? text.settings.saving : text.settings.confirm}
        cancelLabel={text.settings.cancel}
        isSubmitting={saveMutation.isPending}
        confirmDisabled={settingsReason.trim().length < 3 || validationIssues.length > 0}
        size="large"
        onCancel={() => {
          if (!saveMutation.isPending) setReviewOpen(false);
        }}
        onConfirm={submitSettings}
      >
        {saveMutation.isError && !settingsConflict ? (
          <AdminStateCard
            tone="danger"
            title={getAdminErrorMessage(saveMutation.error, text.errorTitle)}
          />
        ) : null}
        <div className={styles.reviewChanges}>
          {changedFields.map((key) => (
            <div key={key}>
              <strong>{text.fields[key].label}</strong>
              <span>
                {text.settings.current}: {draftBaseValues[key]}
              </span>
              <span>
                {text.settings.proposed}: {draft[key]}
              </span>
            </div>
          ))}
        </div>
        <label className={styles.dialogField}>
          <span>{text.settings.reason}</span>
          <textarea
            value={settingsReason}
            maxLength={500}
            placeholder={text.settings.reasonPlaceholder}
            onChange={(event) => setSettingsReason(event.target.value.slice(0, 500))}
          />
          <small>{text.settings.reasonHint}</small>
        </label>
      </ConfirmationDialog>

      <ConfirmationDialog
        open={scaleOpen}
        title={text.render.reviewTitle}
        description={text.render.reviewDescription}
        confirmLabel={text.render.submit}
        cancelLabel={text.settings.cancel}
        tone="danger"
        size="large"
        isSubmitting={scaleMutation.isPending}
        confirmDisabled={
          scaleConflict ||
          !scaleReviewBaseline ||
          scaleReason.trim().length < 3 ||
          !scaleCostConfirmed ||
          scaleTarget < 1 ||
          scaleTarget > 8
        }
        onCancel={() => {
          if (!scaleMutation.isPending) resetScaleReview();
        }}
        onConfirm={() => {
          if (!scaleReviewBaseline || scaleConflict) return;
          scaleMutation.mutate({
            target: scaleTarget,
            reason: scaleReason.trim(),
            idempotencyKey: scaleIdempotencyKey,
            expectedCurrentInstances: scaleReviewBaseline.instances,
          });
        }}
      >
        {scaleConflict ? (
          <AdminStateCard
            tone="warning"
            title={text.render.conflictTitle}
            description={text.render.conflictMessage}
            action={<Button onClick={reloadScaleReview}>{text.render.reload}</Button>}
          />
        ) : null}
        {scaleMutation.isError && !scaleConflict ? (
          <AdminStateCard
            tone="danger"
            title={getAdminErrorMessage(scaleMutation.error, text.errorTitle)}
          />
        ) : null}
        <label className={styles.dialogField}>
          <span>{text.render.target}</span>
          <select
            value={scaleTarget}
            onChange={(event) => setScaleTarget(Number(event.target.value))}
          >
            {Array.from({ length: 8 }, (_, index) => index + 1).map((value) => (
              <option key={value} value={value}>
                {value} instance{value === 1 ? "" : "s"}
              </option>
            ))}
          </select>
        </label>
        <label className={styles.dialogField}>
          <span>{text.render.reason}</span>
          <textarea
            value={scaleReason}
            maxLength={500}
            placeholder={text.render.reasonPlaceholder}
            onChange={(event) => setScaleReason(event.target.value.slice(0, 500))}
          />
        </label>
        <AdminStateCard
          tone="warning"
          title={`${scaleReviewBaseline?.plan ?? "Render"} × ${scaleReviewBaseline?.instances ?? "—"} → ${scaleReviewBaseline?.plan ?? "Render"} × ${scaleTarget}`}
          description={text.render.costNotice}
        />
        <label className={styles.confirmCheck}>
          <input
            type="checkbox"
            checked={scaleCostConfirmed}
            onChange={(event) => setScaleCostConfirmed(event.target.checked)}
          />
          <span>{text.render.confirmUnderstanding}</span>
        </label>
      </ConfirmationDialog>
    </>
  );
}
