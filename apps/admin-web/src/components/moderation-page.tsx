"use client";

import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { useEffect, useMemo, useRef, useState } from "react";

import {
  AdminBadge,
  AdminCard,
  AdminPageHero,
  AdminStateCard,
  AdminStatusBadge,
  adminTableStyles,
} from "@/components/admin/admin-primitives";
import { ensureAdminSession } from "@/components/admin/admin-session";
import { ConfirmationDialog } from "@/components/admin/confirmation-dialog";
import styles from "@/components/moderation-page.module.css";
import { Toast } from "@/components/ui/toast";
import { getAdminErrorMessage } from "@/lib/admin-error-message";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
  decideAdminModerationItem,
  fetchAdminModerationQueue,
  MODERATION_DECISION_REASON_MAX_LENGTH,
  MODERATION_SEARCH_MAX_LENGTH,
  normalizeAdminModerationQueueQuery,
  useAuthSession,
  type AdminModerationQueueItem,
  type AdminModerationStatus,
} from "@/lib/api-client";
import { formatDateTime } from "@/lib/format-date-time";
import { type Locale } from "@/lib/i18n";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

type ModerationPageProps = {
  locale: Locale;
};

type StatusFilter = AdminModerationStatus | "all";

type DecisionState = {
  item: AdminModerationQueueItem;
  action: "approve" | "reject";
};

const PAGE_SIZE = 25;

function getCopy(locale: Locale) {
  const isRu = locale === "ru";
  return {
    eyebrow: isRu ? "Безопасность контента" : "Content safety",
    title: isRu ? "Модерация" : "Moderation",
    description: isRu
      ? "Очередь жалоб и обратной связи по шаблонам. Решения пишутся в audit log."
      : "Complaint and feedback queue for templates. Decisions are written to the audit log.",
    filtersTitle: isRu ? "Фильтры" : "Filters",
    status: isRu ? "Статус" : "Status",
    search: isRu ? "Поиск" : "Search",
    searchPlaceholder: isRu
      ? "template, message, user/generation id"
      : "template, message, user/generation id",
    queueTitle: isRu ? "Очередь" : "Queue",
    loading: isRu ? "Загрузка очереди" : "Loading queue",
    error: isRu ? "Не удалось загрузить очередь" : "Failed to load queue",
    empty: isRu ? "В очереди ничего нет" : "No moderation items",
    template: isRu ? "Шаблон" : "Template",
    event: isRu ? "Событие" : "Event",
    message: isRu ? "Сообщение" : "Message",
    source: isRu ? "Источник" : "Source",
    created: isRu ? "Создано" : "Created",
    actions: isRu ? "Действия" : "Actions",
    approve: isRu ? "Одобрить" : "Approve",
    reject: isRu ? "Отклонить" : "Reject",
    reason: isRu ? "Причина/комментарий" : "Reason/comment",
    reasonPlaceholder: isRu ? "Коротко укажите причину решения" : "Briefly explain the decision",
    cancel: isRu ? "Отмена" : "Cancel",
    confirmApprove: isRu ? "Одобрить элемент?" : "Approve item?",
    confirmReject: isRu ? "Отклонить элемент?" : "Reject item?",
    saved: isRu ? "Решение сохранено" : "Decision saved",
    failed: isRu ? "Не удалось сохранить решение" : "Failed to save decision",
    moderationActionsForbidden: isRu
      ? "Действия модерации доступны только Admin или Moderator."
      : "Moderation actions are available only to Admin or Moderator.",
    decisionMissing: isRu ? "Выберите элемент модерации." : "Select a moderation item.",
    reasonRequired: isRu
      ? "Укажите причину решения: минимум 3 символа."
      : "Enter a decision reason: at least 3 characters.",
    previous: isRu ? "Назад" : "Previous",
    next: isRu ? "Вперед" : "Next",
    pageLabel: isRu ? "Страница" : "Page",
    previousPageLabel: isRu ? "Предыдущая страница очереди" : "Previous queue page",
    nextPageLabel: isRu ? "Следующая страница очереди" : "Next queue page",
    retry: isRu ? "Повторить" : "Retry",
    statusPending: isRu ? "Ожидает" : "Pending",
    statusApproved: isRu ? "Одобрено" : "Approved",
    statusRejected: isRu ? "Отклонено" : "Rejected",
    statusAll: isRu ? "Все" : "All",
    eventComplaint: isRu ? "Жалоба" : "Complaint",
    eventFeedback: isRu ? "Отзыв" : "Feedback",
    templateImage: isRu ? "Изображение" : "Image",
    templateVideo: isRu ? "Видео" : "Video",
    userPrefix: isRu ? "пользователь" : "user",
  };
}

function useDebouncedValue(value: string, delayMs: number) {
  const [debounced, setDebounced] = useState(value);

  useEffect(() => {
    const timeoutId = window.setTimeout(() => setDebounced(value), delayMs);
    return () => window.clearTimeout(timeoutId);
  }, [delayMs, value]);

  return debounced;
}

function statusColor(status: string) {
  if (status === "approved") return "var(--success)";
  if (status === "rejected") return "var(--danger)";
  return "var(--warning)";
}

function shortId(value?: string | null) {
  const safeValue = sanitizeSensitiveText(value?.trim() || "-", 32);
  return safeValue === "-" ? safeValue : safeValue.slice(0, 8);
}

function formatModerationText(value: string | null | undefined, fallback = "-", maxLength = 240) {
  const trimmed = value?.trim();
  return sanitizeSensitiveText(trimmed || fallback, maxLength);
}

function formatModerationStatus(status: AdminModerationStatus, text: ReturnType<typeof getCopy>) {
  if (status === "approved") return text.statusApproved;
  if (status === "rejected") return text.statusRejected;
  return text.statusPending;
}

function formatModerationEvent(eventType: string, text: ReturnType<typeof getCopy>) {
  return eventType === "complaint" ? text.eventComplaint : text.eventFeedback;
}

function formatTemplateType(templateType: string, text: ReturnType<typeof getCopy>) {
  if (templateType === "Image") return text.templateImage;
  if (templateType === "Video") return text.templateVideo;
  return sanitizeSensitiveText(templateType, 48);
}

export function ModerationPage({ locale }: ModerationPageProps) {
  const text = getCopy(locale);
  const router = useRouter();
  const queryClient = useQueryClient();
  const session = useAuthSession();
  const sessionRoles = session?.user.roles ?? [];
  const canModerate = sessionRoles.includes("Admin") || sessionRoles.includes("Moderator");
  const [status, setStatus] = useState<StatusFilter>("pending");
  const [search, setSearch] = useState("");
  const [page, setPage] = useState(0);
  const [decision, setDecision] = useState<DecisionState | null>(null);
  const [reason, setReason] = useState("");
  const [reasonError, setReasonError] = useState<string | null>(null);
  const [toast, setToast] = useState<{ type: "success" | "error"; message: string } | null>(null);
  const [isDecisionInFlight, setIsDecisionInFlight] = useState(false);
  const decisionInFlightRef = useRef(false);
  const debouncedSearch = useDebouncedValue(search, 350);
  const trimmedReason = reason.trim().slice(0, MODERATION_DECISION_REASON_MAX_LENGTH);
  const isReasonValid = trimmedReason.length >= 3;

  useEffect(() => {
    if (!toast) return;
    const timeoutId = window.setTimeout(() => setToast(null), 2600);
    return () => window.clearTimeout(timeoutId);
  }, [toast]);

  useEffect(() => {
    ensureAdminSession(locale, router);
  }, [locale, router, session]);

  const query = useMemo(
    () =>
      normalizeAdminModerationQueueQuery({
        status,
        search: debouncedSearch,
        skip: page * PAGE_SIZE,
        take: PAGE_SIZE,
      }),
    [debouncedSearch, page, status]
  );

  const queueQuery = useQuery({
    queryKey: adminQueryKeys.moderationQueue(query),
    queryFn: ({ signal }) => fetchAdminModerationQueue(query, signal),
    enabled: canModerate,
    placeholderData: keepPreviousData,
  });

  const decisionMutation = useMutation({
    mutationFn: async () => {
      if (!assertCanModerate()) throw new Error(text.moderationActionsForbidden);
      if (!decision) throw new Error(text.decisionMissing);
      if (!isReasonValid) throw new Error(text.reasonRequired);
      return decideAdminModerationItem(decision.item.eventId, {
        action: decision.action,
        reason: trimmedReason,
      });
    },
    onSuccess: async () => {
      setToast({ type: "success", message: text.saved });
      setDecision(null);
      setReason("");
      setReasonError(null);
      await queryClient.invalidateQueries({ queryKey: ["admin", "moderation"] });
      await queryClient.invalidateQueries({ queryKey: adminQueryKeys.dashboard(locale) });
    },
    onError: (error) =>
      setToast({ type: "error", message: getAdminErrorMessage(error, text.failed) }),
    onSettled: () => {
      decisionInFlightRef.current = false;
      setIsDecisionInFlight(false);
    },
  });

  const isDecisionSubmitting = isDecisionInFlight || decisionMutation.isPending;
  const items = queueQuery.data?.items ?? [];

  function assertCanModerate(): boolean {
    if (canModerate) {
      return true;
    }

    setDecision(null);
    setReason("");
    setReasonError(null);
    setToast({ type: "error", message: text.moderationActionsForbidden });
    return false;
  }

  function openDecision(item: AdminModerationQueueItem, action: "approve" | "reject") {
    if (decisionInFlightRef.current || decisionMutation.isPending || item.status !== "pending") {
      return;
    }

    if (!assertCanModerate()) {
      return;
    }

    setDecision({ item, action });
    setReason("");
    setReasonError(null);
  }

  function submitDecision() {
    if (decisionInFlightRef.current || decisionMutation.isPending) {
      return;
    }

    if (!assertCanModerate()) {
      return;
    }

    if (!isReasonValid) {
      setReasonError(text.reasonRequired);
      return;
    }

    setReasonError(null);
    decisionInFlightRef.current = true;
    setIsDecisionInFlight(true);
    decisionMutation.mutate();
  }

  return (
    <section className={styles.page}>
      <AdminPageHero
        eyebrow={text.eyebrow}
        title={text.title}
        description={text.description}
        badge={<AdminBadge tone="info">Moderator</AdminBadge>}
      />

      <AdminCard title={text.filtersTitle}>
        <div className={styles.filters}>
          <label className={styles.field}>
            <span className={styles.label}>{text.status}</span>
            <select
              className={styles.select}
              value={status}
              onChange={(event) => {
                setStatus(event.target.value as StatusFilter);
                setPage(0);
              }}
            >
              <option value="pending">{text.statusPending}</option>
              <option value="approved">{text.statusApproved}</option>
              <option value="rejected">{text.statusRejected}</option>
              <option value="all">{text.statusAll}</option>
            </select>
          </label>
          <label className={styles.field}>
            <span className={styles.label}>{text.search}</span>
            <input
              className={styles.input}
              value={search}
              onChange={(event) => {
                setSearch(event.target.value.slice(0, MODERATION_SEARCH_MAX_LENGTH));
                setPage(0);
              }}
              maxLength={MODERATION_SEARCH_MAX_LENGTH}
              placeholder={text.searchPlaceholder}
            />
          </label>
        </div>
      </AdminCard>

      {!canModerate ? (
        <AdminStateCard title={text.loading} />
      ) : queueQuery.isLoading ? (
        <AdminStateCard title={text.loading} />
      ) : queueQuery.isError ? (
        <AdminStateCard
          title={text.error}
          description={getAdminErrorMessage(queueQuery.error, text.error)}
          tone="danger"
          action={
            <button
              type="button"
              className={styles.button}
              disabled={!canModerate || queueQuery.isFetching}
              onClick={() => {
                if (!canModerate) {
                  return;
                }

                void queueQuery.refetch().catch(() => undefined);
              }}
            >
              {text.retry}
            </button>
          }
        />
      ) : items.length === 0 ? (
        <AdminStateCard title={text.empty} />
      ) : (
        <AdminCard title={text.queueTitle}>
          <div
            className={adminTableStyles.tableWrap}
            aria-busy={queueQuery.isFetching ? "true" : undefined}
          >
            <table className={adminTableStyles.table}>
              <thead>
                <tr>
                  <th>{text.template}</th>
                  <th>{text.event}</th>
                  <th>{text.status}</th>
                  <th>{text.message}</th>
                  <th>{text.source}</th>
                  <th>{text.created}</th>
                  <th>{text.actions}</th>
                </tr>
              </thead>
              <tbody>
                {items.map((item) => (
                  <tr key={item.eventId}>
                    <td>
                      <strong>{formatModerationText(item.templateTitle, "-", 120)}</strong>
                      <div className={styles.meta}>
                        {formatTemplateType(item.templateType, text)} / {shortId(item.templateId)}
                      </div>
                    </td>
                    <td>
                      <AdminBadge tone={item.eventType === "complaint" ? "danger" : "info"}>
                        {formatModerationEvent(item.eventType, text)}
                      </AdminBadge>
                    </td>
                    <td>
                      <AdminStatusBadge color={statusColor(item.status)}>
                        {formatModerationStatus(item.status, text)}
                      </AdminStatusBadge>
                    </td>
                    <td>
                      <span className={styles.message}>{formatModerationText(item.message)}</span>
                      {item.moderationComment ? (
                        <div className={styles.meta}>
                          {formatModerationText(item.moderationComment)}
                        </div>
                      ) : null}
                    </td>
                    <td>
                      {formatModerationText(item.source, "-", 64)}
                      <div className={styles.meta}>
                        {formatModerationText(item.deviceClass, "-", 32)} /{" "}
                        {formatModerationText(item.countryCode, "-", 8)} / {text.userPrefix}{" "}
                        {shortId(item.userId)}
                      </div>
                    </td>
                    <td>{formatDateTime(item.createdAtUtc, locale)}</td>
                    <td>
                      <div className={styles.actions}>
                        <button
                          type="button"
                          className={styles.button}
                          disabled={
                            !canModerate || item.status !== "pending" || isDecisionSubmitting
                          }
                          onClick={() => openDecision(item, "approve")}
                        >
                          {text.approve}
                        </button>
                        <button
                          type="button"
                          className={`${styles.button} ${styles.danger}`}
                          disabled={
                            !canModerate || item.status !== "pending" || isDecisionSubmitting
                          }
                          onClick={() => openDecision(item, "reject")}
                        >
                          {text.reject}
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <div className={styles.pager}>
            <span className={styles.pageInfo}>
              {text.pageLabel} {page + 1}
            </span>
            <button
              type="button"
              className={styles.button}
              disabled={page === 0 || queueQuery.isFetching}
              aria-label={text.previousPageLabel}
              onClick={() => setPage((current) => Math.max(0, current - 1))}
            >
              {text.previous}
            </button>
            <button
              type="button"
              className={styles.button}
              disabled={!queueQuery.data?.hasMore || queueQuery.isFetching}
              aria-label={text.nextPageLabel}
              onClick={() => setPage((current) => current + 1)}
            >
              {text.next}
            </button>
          </div>
        </AdminCard>
      )}

      <ConfirmationDialog
        open={Boolean(decision)}
        title={decision?.action === "approve" ? text.confirmApprove : text.confirmReject}
        description={formatModerationText(
          decision?.item.message,
          decision?.item.templateTitle ?? ""
        )}
        confirmLabel={decision?.action === "approve" ? text.approve : text.reject}
        cancelLabel={text.cancel}
        tone={decision?.action === "reject" ? "danger" : "primary"}
        isSubmitting={isDecisionSubmitting}
        onCancel={() => {
          if (!decisionInFlightRef.current && !decisionMutation.isPending) {
            setDecision(null);
            setReason("");
            setReasonError(null);
          }
        }}
        confirmDisabled={!canModerate || !isReasonValid}
        onConfirm={submitDecision}
      >
        <label className={styles.field}>
          <span className={styles.label}>{text.reason}</span>
          <textarea
            className={styles.textarea}
            value={reason}
            onChange={(event) => {
              setReason(event.target.value.slice(0, MODERATION_DECISION_REASON_MAX_LENGTH));
              if (reasonError) {
                setReasonError(null);
              }
            }}
            maxLength={MODERATION_DECISION_REASON_MAX_LENGTH}
            placeholder={text.reasonPlaceholder}
            disabled={isDecisionSubmitting}
          />
        </label>
        {reasonError ? (
          <p className={styles.validationError} role="alert">
            {reasonError}
          </p>
        ) : null}
      </ConfirmationDialog>
      {toast ? <Toast type={toast.type} message={toast.message} /> : null}
    </section>
  );
}
