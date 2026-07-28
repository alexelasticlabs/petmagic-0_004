"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useEffect, useMemo, useState } from "react";

import {
  AdminBadge,
  AdminCard,
  AdminKpiCard,
  AdminPageHero,
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
  type AdminGenerationControlSnapshot,
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

type RenderScaleReviewBaseline = {
  instances: number;
  plan: string;
};

function getErrorStatus(error: unknown): number | null {
  if (!error || typeof error !== "object" || !("status" in error)) return null;
  return typeof error.status === "number" ? error.status : null;
}

function healthColor(value: string): string {
  if (value === "healthy") return "var(--success)";
  if (value === "critical") return "var(--danger)";
  if (value === "degraded" || value === "low") return "var(--warning)";
  return "var(--text-secondary)";
}

function isTerminalOperation(operation: AdminRenderScaleOperation | null | undefined): boolean {
  return Boolean(operation && ["completed", "failed", "cancelled"].includes(operation.status));
}

function validateSettings(
  draft: GenerationCapacityMutableSettings,
  text: GenerationCapacityCopy
): string[] {
  const errors: string[] = [];
  const invalidInteger = integerFieldKeys.find(
    (key) =>
      !Number.isInteger(draft[key]) ||
      draft[key] < (key.includes("Reserved") || key.includes("Borrow") ? 0 : 1)
  );
  if (invalidInteger) errors.push(`${text.fields[invalidInteger].label}: invalid value.`);
  if (draft.workerLoopsPerInstance < 1 || draft.workerLoopsPerInstance > 2) {
    errors.push(`${text.fields.workerLoopsPerInstance.label}: 1–2.`);
  }
  if (draft.globalMaxConcurrent > draft.falConfiguredConcurrency - draft.falReservedConcurrency) {
    errors.push("Global max must not exceed fal.ai usable concurrency.");
  }
  if (draft.imageMaxConcurrent > draft.globalMaxConcurrent) {
    errors.push("Image max must not exceed Global max.");
  }
  if (draft.imageProtectedConcurrent > draft.imageMaxConcurrent) {
    errors.push("Image protected must not exceed Image max.");
  }
  if (draft.videoMaxConcurrent > draft.globalMaxConcurrent) {
    errors.push("Video max must not exceed Global max.");
  }
  if (draft.videoGuaranteedConcurrent > draft.videoMaxConcurrent) {
    errors.push("Video guaranteed must not exceed Video max.");
  }
  if (draft.videoGuaranteedConcurrent + draft.videoBorrowMaxConcurrent < draft.videoMaxConcurrent) {
    errors.push("Video guaranteed + Video borrow must cover Video max.");
  }
  if (
    draft.falBalanceCriticalThresholdUsd < 0 ||
    draft.falBalanceLowThresholdUsd < draft.falBalanceCriticalThresholdUsd
  ) {
    errors.push("Balance Critical must be non-negative and not exceed Balance Low.");
  }
  return errors;
}

export function GenerationCapacityPage({ locale }: { locale: Locale }) {
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
  const [settingsDraft, setSettingsDraft] = useState<GenerationCapacitySettingsDraft | null>(null);
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
  const validationErrors = useMemo(
    () => (draft ? validateSettings(draft, text) : []),
    [draft, text]
  );

  const saveMutation = useMutation({
    mutationFn: (command: UpdateAdminGenerationControlCommand) =>
      updateAdminGenerationControl(command),
    onSuccess: (next) => {
      queryClient.setQueryData(adminQueryKeys.generationControl, next);
      setSettingsDraft(null);
      setSettingsConflict(false);
      setSettingsReason("");
      setReviewOpen(false);
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
    onSuccess: (next) => queryClient.setQueryData(adminQueryKeys.generationControl, next),
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
  const activeAlerts = snapshot.alerts.filter((alert) => alert.isActive);
  const freshWorkers = snapshot.workers.filter((worker) => !worker.isStale);
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
  const expectedWorkerInstances = Math.ceil(
    snapshot.settings.globalMaxConcurrent / snapshot.settings.workerLoopsPerInstance
  );
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

  function updateDraft(key: keyof GenerationCapacityMutableSettings, rawValue: string) {
    const numericValue = Number(rawValue);
    if (!Number.isFinite(numericValue)) return;
    setSettingsDraft((current) =>
      updateGenerationCapacitySettingsDraft(current, currentServerSettings, key, numericValue)
    );
  }

  function submitSettings() {
    if (!settingsDraft || validationErrors.length > 0 || settingsReason.trim().length < 3) return;
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

  return (
    <>
      <section className={styles.page}>
        <AdminPageHero
          eyebrow={text.eyebrow}
          title={text.title}
          description={text.description}
          badge={<AdminBadge tone="danger">{text.adminOnly}</AdminBadge>}
          actions={
            <Button
              variant="secondary"
              disabled={query.isFetching}
              onClick={() => void query.refetch()}
            >
              {text.refresh}
            </Button>
          }
          metaItems={[
            `${text.live}: ${formatDateTime(snapshot.status.generatedAtUtc, locale)}`,
            `Revision ${snapshot.settings.version}`,
          ]}
        />

        <div className={styles.overviewGrid}>
          <AdminCard
            title={text.queue.title}
            description={text.queue.description}
            action={
              <AdminStatusBadge color={healthColor(snapshot.status.health)}>
                {text.health[snapshot.status.health] ?? snapshot.status.health}
              </AdminStatusBadge>
            }
          >
            {snapshot.status.isDraining ? (
              <AdminStateCard tone="warning" title={text.queue.draining} />
            ) : null}
            <div className={styles.kpiGrid}>
              <AdminKpiCard
                label={text.queue.activeGlobal}
                value={`${snapshot.status.activeGlobal}/${snapshot.settings.globalMaxConcurrent}`}
                tone="primary"
              />
              <AdminKpiCard
                label={text.queue.activeImage}
                value={`${snapshot.status.activeImage}/${snapshot.status.effectiveImageMaxConcurrent}`}
                tone="info"
              />
              <AdminKpiCard
                label={text.queue.activeVideo}
                value={`${snapshot.status.activeVideo}/${snapshot.settings.videoMaxConcurrent}`}
                tone="warning"
              />
              <AdminKpiCard
                label={text.queue.queuedImage}
                value={snapshot.status.queuedImage}
                tone="neutral"
              />
              <AdminKpiCard
                label={text.queue.queuedVideo}
                value={snapshot.status.queuedVideo}
                tone="neutral"
              />
              <AdminKpiCard
                label={text.queue.borrowedVideo}
                value={snapshot.status.borrowedVideo}
                tone="warning"
              />
            </div>
          </AdminCard>

          <AdminCard
            title={text.fal.title}
            description={text.fal.description}
            action={
              <AdminStatusBadge color={healthColor(snapshot.fal.balanceStatus)}>
                {text.health[snapshot.fal.balanceStatus] ?? snapshot.fal.balanceStatus}
              </AdminStatusBadge>
            }
          >
            {snapshot.fal.isStale ? <AdminStateCard tone="danger" title={text.fal.stale} /> : null}
            <dl className={styles.factGrid}>
              <div>
                <dt>{text.fal.balance}</dt>
                <dd>
                  {snapshot.fal.balanceUsd === null
                    ? "—"
                    : `$${snapshot.fal.balanceUsd.toFixed(2)}`}
                </dd>
              </div>
              <div>
                <dt>{text.fal.usable}</dt>
                <dd>
                  {snapshot.fal.usableConcurrency}/{snapshot.fal.configuredConcurrency}
                </dd>
              </div>
              <div>
                <dt>{text.fal.inflight}</dt>
                <dd>{snapshot.fal.inflightRequests}</dd>
              </div>
              <div>
                <dt>{text.fal.reserve}</dt>
                <dd>{snapshot.fal.reservedConcurrency}</dd>
              </div>
              <div className={styles.factWide}>
                <dt>{text.fal.checked}</dt>
                <dd>{formatDateTime(snapshot.fal.checkedAtUtc, locale)}</dd>
              </div>
            </dl>
            <p className={styles.helperText}>{text.fal.manualLimit}</p>
            {providerRefreshMutation.isError ? (
              <AdminStateCard
                tone="warning"
                title={getAdminErrorMessage(providerRefreshMutation.error, text.errorTitle)}
              />
            ) : null}
            <Button
              variant="secondary"
              disabled={providerRefreshMutation.isPending}
              onClick={() => providerRefreshMutation.mutate()}
            >
              {providerRefreshMutation.isPending ? text.fal.refreshing : text.fal.refresh}
            </Button>
          </AdminCard>
        </div>

        <AdminCard
          title={text.workers.title}
          description={text.workers.description}
          action={
            <AdminBadge
              tone={observedLoops === snapshot.settings.globalMaxConcurrent ? "success" : "warning"}
            >
              {text.workers.totalCapacity}: {observedLoops}
              {paidUnusedLoops > 0
                ? ` · ${text.workers.paidUnusedCapacity}: ${paidUnusedLoops}`
                : ""}
            </AdminBadge>
          }
        >
          <p className={styles.helperText}>
            {text.workers.expectedTopology}: {expectedWorkerInstances} ×{" "}
            {snapshot.settings.workerLoopsPerInstance} = {snapshot.settings.globalMaxConcurrent} ·{" "}
            {text.workers.observedTopology}: {observedWorkerInstances} instance(s) / {observedLoops}{" "}
            loops
          </p>
          {snapshot.workers.length === 0 ? (
            <AdminStateCard tone="warning" title={text.workers.empty} />
          ) : (
            <div className={adminTableStyles.tableWrap}>
              <table className={adminTableStyles.table}>
                <thead>
                  <tr>
                    <th>{text.workers.instance}</th>
                    <th>{text.workers.loops}</th>
                    <th>{text.workers.revision}</th>
                    <th>{text.workers.heartbeat}</th>
                    <th>Status</th>
                  </tr>
                </thead>
                <tbody>
                  {snapshot.workers.map((worker) => (
                    <tr key={worker.instanceId}>
                      <td className={adminTableStyles.mono}>{worker.instanceId}</td>
                      <td>{worker.configuredLoops}</td>
                      <td>{worker.appliedSettingsVersion}</td>
                      <td>
                        {formatDateTime(worker.lastSeenAtUtc, locale)} ·{" "}
                        {Math.round(worker.heartbeatAgeSeconds)}s
                      </td>
                      <td>
                        <AdminBadge
                          tone={
                            worker.isStale || !worker.isConfigCurrent || worker.isDraining
                              ? "warning"
                              : "success"
                          }
                        >
                          {worker.isStale
                            ? text.workers.stale
                            : worker.isDraining
                              ? text.workers.draining
                              : worker.isConfigCurrent
                                ? text.workers.current
                                : `Revision ${worker.appliedSettingsVersion}`}
                        </AdminBadge>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </AdminCard>

        <AdminCard
          title={text.settings.title}
          description={text.settings.description}
          action={<AdminBadge tone="info">Revision {snapshot.settings.version}</AdminBadge>}
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
          <div className={styles.settingsGrid}>
            {settingsFieldKeys.map((key) => (
              <label key={key} className={styles.field}>
                <span className={styles.label}>{text.fields[key].label}</span>
                <input
                  className={styles.input}
                  type="number"
                  min={key === "workerLoopsPerInstance" ? 1 : 0}
                  max={key === "workerLoopsPerInstance" ? 2 : undefined}
                  step={moneyFieldKeys.includes(key as (typeof moneyFieldKeys)[number]) ? 0.01 : 1}
                  value={draft[key]}
                  onChange={(event) => updateDraft(key, event.target.value)}
                />
                <small>{text.fields[key].hint}</small>
              </label>
            ))}
          </div>
          {validationErrors.length > 0 ? (
            <AdminStateCard tone="danger" title={text.settings.validationTitle}>
              <ul className={styles.errorList}>
                {validationErrors.map((error) => (
                  <li key={error}>{error}</li>
                ))}
              </ul>
            </AdminStateCard>
          ) : null}
          {saveMutation.isError && !settingsConflict ? (
            <AdminStateCard
              tone="danger"
              title={getAdminErrorMessage(saveMutation.error, text.errorTitle)}
            />
          ) : null}
          <div className={styles.cardActions}>
            <span className={styles.helperText}>
              {changedFields.length === 0
                ? text.settings.noChanges
                : `${changedFields.length} change(s)`}
            </span>
            <Button
              variant="primary"
              disabled={
                settingsConflict ||
                changedFields.length === 0 ||
                validationErrors.length > 0 ||
                saveMutation.isPending
              }
              onClick={() => setReviewOpen(true)}
            >
              {text.settings.saveReview}
            </Button>
          </div>
        </AdminCard>

        <AdminCard title={text.alerts.title} description={text.alerts.description}>
          {acknowledgeMutation.isError ? (
            <AdminStateCard
              tone="danger"
              title={getAdminErrorMessage(acknowledgeMutation.error, text.errorTitle)}
            />
          ) : null}
          {activeAlerts.length === 0 ? (
            <AdminStateCard tone="success" title={text.alerts.empty} />
          ) : (
            <div className={styles.alertList}>
              {activeAlerts.map((alert) => (
                <article
                  key={alert.id}
                  className={`${styles.alertCard} ${styles[`alert_${alert.severity}`]}`}
                >
                  <div className={styles.alertBody}>
                    <div className={styles.alertMeta}>
                      <AdminBadge
                        tone={
                          alert.severity === "critical"
                            ? "danger"
                            : alert.severity === "warning"
                              ? "warning"
                              : "info"
                        }
                      >
                        {alert.code}
                      </AdminBadge>
                      <span>{formatDateTime(alert.activatedAtUtc, locale)}</span>
                    </div>
                    <h3>{alert.title}</h3>
                    <p>{alert.message}</p>
                  </div>
                  {alert.isAcknowledged ? (
                    <AdminBadge tone="success">{text.alerts.acknowledged}</AdminBadge>
                  ) : (
                    <Button
                      size="sm"
                      disabled={
                        acknowledgeMutation.isPending && acknowledgeMutation.variables === alert.id
                      }
                      onClick={() => {
                        acknowledgeMutation.reset();
                        acknowledgeMutation.mutate(alert.id);
                      }}
                    >
                      {acknowledgeMutation.isPending && acknowledgeMutation.variables === alert.id
                        ? text.alerts.acknowledging
                        : text.alerts.acknowledge}
                    </Button>
                  )}
                </article>
              ))}
            </div>
          )}
        </AdminCard>

        <AdminCard title={text.render.title} description={text.render.description}>
          {!snapshot.render?.isConfigured ? (
            <AdminStateCard
              tone="warning"
              title={text.render.unavailable}
              description={snapshot.render?.configurationError ?? undefined}
            />
          ) : (
            <>
              {snapshot.render.autoscalingEnabled ? (
                <AdminStateCard tone="warning" title={text.render.autoscaling} />
              ) : null}
              {snapshot.render.configurationError ? (
                <AdminStateCard
                  tone="danger"
                  title={text.render.unavailable}
                  description={snapshot.render.configurationError}
                />
              ) : null}
              <dl className={styles.factGrid}>
                <div className={styles.factWide}>
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
                  <dt>{text.render.instances}</dt>
                  <dd>
                    {snapshot.render.activeInstances ?? "—"} /{" "}
                    {snapshot.render.desiredInstances ?? "—"}
                  </dd>
                </div>
                <div>
                  <dt>Mode</dt>
                  <dd>{text.render.managed}</dd>
                </div>
              </dl>
              {renderOperation ? (
                <div className={styles.operationCard}>
                  <div>
                    <span>{text.render.operation}</span>
                    <strong>
                      {text.render.operationStatuses[renderOperation.status] ??
                        renderOperation.status}
                    </strong>
                    <small>
                      {renderOperation.initialInstances ?? "—"} → {renderOperation.targetInstances}{" "}
                      · {renderOperation.loopsPerInstance} loops
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
              <div className={styles.cardActions}>
                <span className={styles.helperText}>
                  {snapshot.render.plan ?? "Render"} ×{" "}
                  {snapshot.render.desiredInstances ?? snapshot.render.activeInstances ?? 1}
                </span>
                <Button
                  variant="primary"
                  disabled={!renderCanScale}
                  onClick={() => {
                    const currentInstances =
                      snapshot.render?.desiredInstances ?? snapshot.render?.activeInstances ?? 1;
                    const currentPlan = snapshot.render?.plan?.trim() || "Render";
                    setScaleTarget(Math.max(1, Math.min(8, currentInstances)));
                    setScaleReviewBaseline({ instances: currentInstances, plan: currentPlan });
                    setScaleIdempotencyKey(`generation-scale:${createAdminCorrelationId()}`);
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
        </AdminCard>
      </section>

      <ConfirmationDialog
        open={reviewOpen}
        title={text.settings.reviewTitle}
        description={text.settings.reviewDescription}
        confirmLabel={saveMutation.isPending ? text.settings.saving : text.settings.confirm}
        cancelLabel={text.settings.cancel}
        isSubmitting={saveMutation.isPending}
        confirmDisabled={settingsReason.trim().length < 3 || validationErrors.length > 0}
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
