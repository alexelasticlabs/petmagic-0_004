"use client";

import { useInfiniteQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useRef, useState } from "react";

import { useAdminNotifications } from "@/components/admin/admin-notifications";
import { AdminBadge, AdminStateCard } from "@/components/admin/admin-primitives";
import { ConfirmationDialog } from "@/components/admin/confirmation-dialog";
import styles from "@/components/generation-capacity-panel.module.css";
import { createAdminCorrelationId } from "@/lib/admin-correlation-id";
import { getAdminErrorMessage } from "@/lib/admin-error-message";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
  fetchAdminTemplateProviderAttemptRecovery,
  GENERATION_CONTROL_REASON_MAX_LENGTH,
  resolveAdminTemplateProviderAttempt,
  type AdminTemplateProviderAttemptRecoveryItem,
} from "@/lib/api-client";
import { formatDateTime } from "@/lib/format-date-time";
import type { Locale } from "@/lib/i18n";

type GenerationProviderRecoveryPanelProps = {
  locale: Locale;
  enabled: boolean;
};

type RecoveryResolution = "correlated_accepted" | "confirmed_not_found";

type RecoveryDraft = {
  attempt: AdminTemplateProviderAttemptRecoveryItem;
  resolution: RecoveryResolution;
  reason: string;
  evidenceReference: string;
  providerRequestId: string;
  acknowledged: boolean;
  idempotencyKey: string;
};

const PAGE_SIZE = 25;
const REASON_MIN_LENGTH = 3;
const EVIDENCE_REFERENCE_MAX_LENGTH = 160;
const EVIDENCE_REFERENCE_PATTERN = /^[A-Za-z0-9._:/#@-]+$/;
const PROVIDER_REQUEST_ERROR_ID = "generation-provider-recovery-provider-request-error";
const EVIDENCE_REFERENCE_ERROR_ID = "generation-provider-recovery-evidence-reference-error";
const REASON_ERROR_ID = "generation-provider-recovery-reason-error";

const recoveryText = {
  ru: {
    title: "Ручная сверка provider submits",
    description:
      "Эти attempts исчерпали безопасное автоматическое восстановление. Не выбирайте исход без проверки fal.ai Dashboard или ответа support.",
    refresh: "Обновить список",
    loading: "Загружаем attempts, требующие ручной сверки…",
    unavailable: "Список provider recovery временно недоступен.",
    empty:
      "Сейчас нет attempts, доступных для ручного решения. Неоднозначные submits могут ещё проходить автоматическое восстановление.",
    loadedCount: (loaded: number, total: number) => `Показано ${loaded} из ${total}`,
    loadMore: "Показать ещё attempts",
    loadingMore: "Загружаем ещё…",
    resolve: "Разрешить attempt",
    generation: "Generation",
    attempt: "Attempt",
    stage: "Stage",
    version: "Version",
    created: "Создан",
    updated: "Обновлён",
    deadline: "Recovery deadline",
    errorCode: "Safe error code",
    evidenceNeeded: "Допустимый исход",
    dialogTitle: "Evidence-backed provider recovery",
    dialogDescription:
      "Операция меняет durable provider state и может продолжить платную генерацию либо отменить её с возвратом PawSpark.",
    resolution: "Подтверждённый исход",
    accepted: "fal.ai принял запрос",
    notFound: "fal.ai точно не принял запрос",
    providerRequestId: "fal.ai request ID",
    providerRequestRequired: "Для принятого запроса нужен request ID из fal.ai.",
    reason: "Причина решения",
    reasonPlaceholder: "Что было проверено и почему выбран этот исход",
    reasonRequired: "Укажите причину длиной от 3 до 500 символов.",
    evidenceReference: "Ссылка на доказательство",
    evidencePlaceholder: "fal-dashboard:request_123 или support:case_456",
    evidenceInvalid: "Используйте 3–160 символов: латиница, цифры и знаки . _ : / # @ -",
    warningAccepted:
      "Worker возобновит polling и обработку этого fal.ai request. Проверьте, что request ID относится именно к этой generation и stage.",
    warningNotFound:
      "Generation будет отменена. Если PawSpark уже списаны, backend запланирует идемпотентный refund.",
    acknowledge: "Я сверил generation, stage и данные fal.ai и понимаю последствия этого решения",
    confirm: "Применить решение",
    confirming: "Применяем…",
    cancel: "Отмена",
    resolvedAccepted: "Provider request привязан; worker продолжит reconciliation.",
    resolvedNotFoundRefundScheduled:
      "Отсутствие provider request подтверждено; cancellation/refund запланированы.",
    resolvedNotFoundNoRefund:
      "Отсутствие provider request подтверждено; generation отменена, новый refund не требовался.",
    resolveError: "Не удалось применить provider recovery.",
    conflict:
      "Attempt изменился на сервере. Загружена новая version; ещё раз проверьте доказательство.",
    conflictRefreshFailed:
      "Attempt конфликтует с сервером, но актуальную version получить не удалось. Повторная отправка заблокирована.",
    refreshConflict: "Загрузить новую version",
    refreshingConflict: "Обновляем version…",
    resolvedElsewhere: "Attempt уже разрешён другим процессом или администратором.",
    notificationSource: "Generation provider recovery",
  },
  en: {
    title: "Manual provider submit reconciliation",
    description:
      "These attempts exhausted safe automatic recovery. Do not choose an outcome without checking the fal.ai Dashboard or a support response.",
    refresh: "Refresh list",
    loading: "Loading attempts that require manual reconciliation…",
    unavailable: "Provider recovery is temporarily unavailable.",
    empty:
      "No attempts are currently eligible for a manual decision. Ambiguous submits might still be in automatic recovery.",
    loadedCount: (loaded: number, total: number) => `Showing ${loaded} of ${total}`,
    loadMore: "Load more attempts",
    loadingMore: "Loading more…",
    resolve: "Resolve attempt",
    generation: "Generation",
    attempt: "Attempt",
    stage: "Stage",
    version: "Version",
    created: "Created",
    updated: "Updated",
    deadline: "Recovery deadline",
    errorCode: "Safe error code",
    evidenceNeeded: "Allowed outcome",
    dialogTitle: "Evidence-backed provider recovery",
    dialogDescription:
      "This changes durable provider state and can either continue a paid generation or cancel it with a PawSpark refund.",
    resolution: "Confirmed outcome",
    accepted: "fal.ai accepted the request",
    notFound: "fal.ai definitely did not accept the request",
    providerRequestId: "fal.ai request ID",
    providerRequestRequired: "An accepted request requires its fal.ai request ID.",
    reason: "Decision reason",
    reasonPlaceholder: "What was checked and why this outcome is correct",
    reasonRequired: "Provide a reason between 3 and 500 characters.",
    evidenceReference: "Evidence reference",
    evidencePlaceholder: "fal-dashboard:request_123 or support:case_456",
    evidenceInvalid: "Use 3–160 characters: Latin letters, numbers, and . _ : / # @ -",
    warningAccepted:
      "The worker will resume polling this fal.ai request. Verify that the request ID belongs to this generation and stage.",
    warningNotFound:
      "The generation will be cancelled. If PawSpark was charged, the backend will schedule an idempotent refund.",
    acknowledge:
      "I verified the generation, stage, and fal.ai evidence and understand this decision",
    confirm: "Apply decision",
    confirming: "Applying…",
    cancel: "Cancel",
    resolvedAccepted: "The provider request was correlated; worker reconciliation will continue.",
    resolvedNotFoundRefundScheduled:
      "Provider request absence was confirmed; cancellation and refund recovery were scheduled.",
    resolvedNotFoundNoRefund:
      "Provider request absence was confirmed; the generation was cancelled and no new refund was required.",
    resolveError: "Failed to apply provider recovery.",
    conflict:
      "The attempt changed on the server. Its latest version was loaded; review the evidence again.",
    conflictRefreshFailed:
      "The attempt conflicts with the server, but its current version could not be loaded. Retry is blocked.",
    refreshConflict: "Load latest version",
    refreshingConflict: "Loading version…",
    resolvedElsewhere: "Another process or administrator already resolved this attempt.",
    notificationSource: "Generation provider recovery",
  },
} as const;

function createRecoveryIdempotencyKey(): string {
  return `provider-attempt-resolution:${createAdminCorrelationId()}`;
}

function getErrorStatus(error: unknown): number | undefined {
  if (!error || typeof error !== "object" || !("status" in error)) {
    return undefined;
  }

  return typeof error.status === "number" ? error.status : undefined;
}

function createDraft(attempt: AdminTemplateProviderAttemptRecoveryItem): RecoveryDraft {
  return {
    attempt,
    resolution: "correlated_accepted",
    reason: "",
    evidenceReference: "",
    providerRequestId: attempt.providerRequestId ?? "",
    acknowledged: false,
    idempotencyKey: createRecoveryIdempotencyKey(),
  };
}

export function GenerationProviderRecoveryPanel({
  locale,
  enabled,
}: GenerationProviderRecoveryPanelProps) {
  const text = recoveryText[locale];
  const queryClient = useQueryClient();
  const { addNotification } = useAdminNotifications();
  const [draft, setDraft] = useState<RecoveryDraft | null>(null);
  const [dialogError, setDialogError] = useState<string | null>(null);
  const [conflictBlocked, setConflictBlocked] = useState(false);
  const [isConflictRefreshing, setIsConflictRefreshing] = useState(false);
  const firstFieldRef = useRef<HTMLSelectElement>(null);
  const conflictRefreshSequenceRef = useRef(0);
  const recoveryQuery = useInfiniteQuery({
    queryKey: adminQueryKeys.templateGenerationProviderRecoveryRoot,
    queryFn: ({ pageParam, signal }) =>
      fetchAdminTemplateProviderAttemptRecovery(pageParam, PAGE_SIZE, signal),
    initialPageParam: 0,
    getNextPageParam: (lastPage) =>
      lastPage.hasMore && lastPage.items.length > 0
        ? lastPage.skip + lastPage.items.length
        : undefined,
    enabled,
    staleTime: 5_000,
    refetchInterval: 15_000,
    refetchIntervalInBackground: false,
  });
  const recoveryItems = recoveryQuery.data?.pages.flatMap((page) => page.items) ?? [];
  const recoveryTotalCount = recoveryQuery.data?.pages.at(-1)?.totalCount ?? 0;

  const reasonLength = draft?.reason.trim().length ?? 0;
  const reasonValid =
    reasonLength >= REASON_MIN_LENGTH && reasonLength <= GENERATION_CONTROL_REASON_MAX_LENGTH;
  const evidenceReference = draft?.evidenceReference.trim() ?? "";
  const evidenceValid =
    evidenceReference.length >= 3 &&
    evidenceReference.length <= EVIDENCE_REFERENCE_MAX_LENGTH &&
    EVIDENCE_REFERENCE_PATTERN.test(evidenceReference);
  const providerRequestValid = Boolean(
    draft &&
    (draft.resolution === "confirmed_not_found" || draft.providerRequestId.trim().length > 0)
  );
  const canResolve = Boolean(
    draft &&
    reasonValid &&
    evidenceValid &&
    providerRequestValid &&
    draft.acknowledged &&
    !conflictBlocked
  );

  const resolutionMutation = useMutation({
    mutationFn: resolveAdminTemplateProviderAttempt,
    onMutate: () => setDialogError(null),
    onSuccess: (result) => {
      const resolution = draft?.resolution ?? result.resolution;
      conflictRefreshSequenceRef.current += 1;
      setDraft(null);
      setDialogError(null);
      setConflictBlocked(false);
      setIsConflictRefreshing(false);
      addNotification({
        title: text.title,
        message:
          resolution === "correlated_accepted"
            ? text.resolvedAccepted
            : result.refundScheduled
              ? text.resolvedNotFoundRefundScheduled
              : text.resolvedNotFoundNoRefund,
        category: "system",
        source: text.notificationSource,
        tone: resolution === "correlated_accepted" ? "success" : "warning",
        href: `/${locale}/generations`,
        dedupeKey: `provider-attempt-resolved:${result.providerAttemptId}:${result.attemptVersion}`,
      });
      void Promise.all([
        queryClient.invalidateQueries({
          queryKey: adminQueryKeys.templateGenerationProviderRecoveryRoot,
        }),
        queryClient.invalidateQueries({
          queryKey: adminQueryKeys.templateGenerationControl,
          exact: true,
        }),
        queryClient.invalidateQueries({
          queryKey: ["admin", "templates", "generations"],
        }),
      ]);
    },
    onError: async (error) => {
      if (getErrorStatus(error) !== 409 || !draft) {
        setDialogError(getAdminErrorMessage(error, text.resolveError));
        return;
      }

      await refreshRecoveryConflict();
    },
  });

  function updateDraft(patch: Partial<Omit<RecoveryDraft, "attempt">>) {
    if (!conflictBlocked) {
      setDialogError(null);
    }
    setDraft((current) =>
      current
        ? {
            ...current,
            ...patch,
            acknowledged: "acknowledged" in patch ? Boolean(patch.acknowledged) : false,
            idempotencyKey: createRecoveryIdempotencyKey(),
          }
        : current
    );
  }

  async function refreshRecoveryConflict() {
    if (!draft) {
      setConflictBlocked(true);
      setDialogError(text.conflictRefreshFailed);
      return;
    }

    const targetAttemptId = draft.attempt.attemptId;
    const refreshSequence = conflictRefreshSequenceRef.current + 1;
    conflictRefreshSequenceRef.current = refreshSequence;
    setIsConflictRefreshing(true);
    try {
      const previousVersion = draft.attempt.attemptVersion;
      const refreshed = await recoveryQuery.refetch({ cancelRefetch: false });
      if (conflictRefreshSequenceRef.current !== refreshSequence) {
        return;
      }
      if (refreshed.isError || !refreshed.data) {
        setConflictBlocked(true);
        setDialogError(text.conflictRefreshFailed);
        return;
      }

      const currentAttempt = refreshed.data.pages
        .flatMap((page) => page.items)
        .find((candidate) => candidate.attemptId === targetAttemptId);
      if (!currentAttempt) {
        setDraft(null);
        setDialogError(null);
        setConflictBlocked(false);
        addNotification({
          title: text.title,
          message: text.resolvedElsewhere,
          category: "system",
          source: text.notificationSource,
          tone: "info",
          href: `/${locale}/generations`,
          dedupeKey: `provider-attempt-resolved-elsewhere:${targetAttemptId}`,
        });
        return;
      }

      if (currentAttempt.attemptVersion <= previousVersion) {
        setConflictBlocked(true);
        setDialogError(text.conflictRefreshFailed);
        return;
      }

      setDraft((current) =>
        current
          ? {
              ...current,
              attempt: currentAttempt,
              acknowledged: false,
              idempotencyKey: createRecoveryIdempotencyKey(),
            }
          : current
      );
      setConflictBlocked(false);
      setDialogError(text.conflict);
    } catch {
      if (conflictRefreshSequenceRef.current === refreshSequence) {
        setConflictBlocked(true);
        setDialogError(text.conflictRefreshFailed);
      }
    } finally {
      if (conflictRefreshSequenceRef.current === refreshSequence) {
        setIsConflictRefreshing(false);
      }
    }
  }

  function resolveAttempt() {
    if (!draft || !canResolve) {
      return;
    }

    resolutionMutation.mutate({
      attemptId: draft.attempt.attemptId,
      expectedAttemptVersion: draft.attempt.attemptVersion,
      resolution: draft.resolution,
      reason: draft.reason.trim(),
      evidenceReference,
      providerRequestId:
        draft.resolution === "correlated_accepted" ? draft.providerRequestId.trim() : null,
      providerStatusUrl: null,
      providerResponseUrl: null,
      providerCancelUrl: null,
      idempotencyKey: draft.idempotencyKey,
    });
  }

  const isRecoveryBusy = resolutionMutation.isPending || isConflictRefreshing;

  if (!enabled) {
    return null;
  }

  return (
    <section className={styles.recovery} aria-label={text.title}>
      <header className={styles.recoveryHeader}>
        <div>
          <h3>{text.title}</h3>
          <p>{text.description}</p>
        </div>
        <button
          className={styles.button}
          type="button"
          disabled={recoveryQuery.isFetching}
          onClick={() => void recoveryQuery.refetch().catch(() => undefined)}
        >
          {text.refresh}
        </button>
      </header>

      {recoveryQuery.isPending ? (
        <AdminStateCard title={text.loading} tone="info" />
      ) : recoveryQuery.isError || !recoveryQuery.data ? (
        <AdminStateCard
          title={text.unavailable}
          description={getAdminErrorMessage(recoveryQuery.error, text.unavailable)}
          tone="warning"
        />
      ) : recoveryItems.length === 0 ? (
        <AdminStateCard title={text.empty} tone="info" />
      ) : (
        <>
          <div className={styles.recoveryGrid}>
            {recoveryItems.map((attempt) => (
              <article className={styles.recoveryCard} key={attempt.attemptId}>
                <div className={styles.recoveryCardHeader}>
                  <AdminBadge tone="danger">{attempt.state}</AdminBadge>
                  <span>
                    {text.stage}: {attempt.stage} #{attempt.ordinal}
                  </span>
                </div>
                <dl className={styles.recoveryDefinitionGrid}>
                  <div>
                    <dt>{text.generation}</dt>
                    <dd>{attempt.generationId}</dd>
                  </div>
                  <div>
                    <dt>{text.attempt}</dt>
                    <dd>{attempt.attemptId}</dd>
                  </div>
                  <div>
                    <dt>{text.version}</dt>
                    <dd>{attempt.attemptVersion}</dd>
                  </div>
                  <div>
                    <dt>{text.created}</dt>
                    <dd>{formatDateTime(attempt.createdAtUtc, locale)}</dd>
                  </div>
                  <div>
                    <dt>{text.updated}</dt>
                    <dd>{formatDateTime(attempt.updatedAtUtc, locale)}</dd>
                  </div>
                  <div>
                    <dt>{text.deadline}</dt>
                    <dd>{formatDateTime(attempt.reconciliationDeadlineAtUtc, locale)}</dd>
                  </div>
                  <div>
                    <dt>{text.errorCode}</dt>
                    <dd>{attempt.errorCode ?? "—"}</dd>
                  </div>
                  <div>
                    <dt>{text.evidenceNeeded}</dt>
                    <dd>{attempt.evidenceNeeded}</dd>
                  </div>
                </dl>
                <button
                  className={styles.primaryButton}
                  type="button"
                  aria-label={`${text.resolve}: ${text.generation} ${attempt.generationId}, ${text.stage} ${attempt.stage} #${attempt.ordinal}`}
                  onClick={() => {
                    conflictRefreshSequenceRef.current += 1;
                    setDialogError(null);
                    setConflictBlocked(false);
                    setIsConflictRefreshing(false);
                    setDraft(createDraft(attempt));
                  }}
                >
                  {text.resolve}
                </button>
              </article>
            ))}
          </div>
          <div className={styles.recoveryPagination} aria-live="polite">
            <span>{text.loadedCount(recoveryItems.length, recoveryTotalCount)}</span>
            {recoveryQuery.hasNextPage ? (
              <button
                className={styles.button}
                type="button"
                disabled={recoveryQuery.isFetchingNextPage}
                onClick={() => void recoveryQuery.fetchNextPage().catch(() => undefined)}
              >
                {recoveryQuery.isFetchingNextPage ? text.loadingMore : text.loadMore}
              </button>
            ) : null}
          </div>
        </>
      )}

      <ConfirmationDialog
        open={draft !== null}
        title={text.dialogTitle}
        description={text.dialogDescription}
        confirmLabel={resolutionMutation.isPending ? text.confirming : text.confirm}
        cancelLabel={text.cancel}
        confirmDisabled={!canResolve}
        initialFocusRef={firstFieldRef}
        isSubmitting={isRecoveryBusy}
        size="large"
        stickyActions
        tone="danger"
        onCancel={() => {
          if (!isRecoveryBusy) {
            conflictRefreshSequenceRef.current += 1;
            setDraft(null);
            setDialogError(null);
            setConflictBlocked(false);
            setIsConflictRefreshing(false);
          }
        }}
        onConfirm={resolveAttempt}
      >
        {draft ? (
          <div className={styles.editor}>
            {dialogError ? (
              <AdminStateCard
                title={dialogError}
                tone="warning"
                action={
                  conflictBlocked ? (
                    <button
                      className={styles.button}
                      type="button"
                      disabled={isConflictRefreshing}
                      onClick={() => void refreshRecoveryConflict()}
                    >
                      {isConflictRefreshing ? text.refreshingConflict : text.refreshConflict}
                    </button>
                  ) : undefined
                }
              />
            ) : null}
            <AdminStateCard
              title={`${text.generation}: ${draft.attempt.generationId}`}
              description={`${text.stage}: ${draft.attempt.stage} #${draft.attempt.ordinal} · ${text.version}: ${draft.attempt.attemptVersion}`}
              tone="warning"
            />
            <label className={styles.field}>
              <span>{text.resolution}</span>
              <select
                ref={firstFieldRef}
                value={draft.resolution}
                disabled={isRecoveryBusy}
                onChange={(event) =>
                  updateDraft({ resolution: event.target.value as RecoveryResolution })
                }
              >
                <option value="correlated_accepted">{text.accepted}</option>
                <option value="confirmed_not_found">{text.notFound}</option>
              </select>
            </label>

            <AdminStateCard
              title={
                draft.resolution === "correlated_accepted"
                  ? text.warningAccepted
                  : text.warningNotFound
              }
              tone="warning"
            />

            {draft.resolution === "correlated_accepted" ? (
              <label className={styles.field}>
                <span>{text.providerRequestId}</span>
                <input
                  value={draft.providerRequestId}
                  aria-invalid={!providerRequestValid}
                  aria-describedby={!providerRequestValid ? PROVIDER_REQUEST_ERROR_ID : undefined}
                  disabled={isRecoveryBusy}
                  onChange={(event) => updateDraft({ providerRequestId: event.target.value })}
                />
                {!providerRequestValid ? (
                  <small id={PROVIDER_REQUEST_ERROR_ID} role="alert">
                    {text.providerRequestRequired}
                  </small>
                ) : null}
              </label>
            ) : null}

            <label className={styles.field}>
              <span>{text.evidenceReference}</span>
              <input
                value={draft.evidenceReference}
                maxLength={EVIDENCE_REFERENCE_MAX_LENGTH}
                aria-invalid={!evidenceValid}
                aria-describedby={!evidenceValid ? EVIDENCE_REFERENCE_ERROR_ID : undefined}
                placeholder={text.evidencePlaceholder}
                disabled={isRecoveryBusy}
                onChange={(event) => updateDraft({ evidenceReference: event.target.value })}
              />
              {!evidenceValid ? (
                <small id={EVIDENCE_REFERENCE_ERROR_ID} role="alert">
                  {text.evidenceInvalid}
                </small>
              ) : null}
            </label>

            <label className={styles.field}>
              <span>{text.reason}</span>
              <textarea
                value={draft.reason}
                minLength={REASON_MIN_LENGTH}
                maxLength={GENERATION_CONTROL_REASON_MAX_LENGTH}
                aria-invalid={!reasonValid}
                aria-describedby={!reasonValid ? REASON_ERROR_ID : undefined}
                placeholder={text.reasonPlaceholder}
                disabled={isRecoveryBusy}
                onChange={(event) => updateDraft({ reason: event.target.value })}
              />
              {!reasonValid ? (
                <small id={REASON_ERROR_ID} role="alert">
                  {text.reasonRequired}
                </small>
              ) : null}
            </label>

            <label className={styles.riskField}>
              <input
                type="checkbox"
                checked={draft.acknowledged}
                disabled={isRecoveryBusy}
                onChange={(event) => updateDraft({ acknowledged: event.target.checked })}
              />
              <span>{text.acknowledge}</span>
            </label>
          </div>
        ) : null}
      </ConfirmationDialog>
    </section>
  );
}
