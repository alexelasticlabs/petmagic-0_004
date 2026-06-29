"use client";

import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { useEffect, useMemo, useRef, useState } from "react";

import { CaretDownIcon } from "@/components/admin/admin-icons";
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
import {
  getModerationPageText,
  type ModerationPageText,
} from "@/components/moderation-page.content";
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
import { clientLogger } from "@/lib/client-logger";
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

function formatModerationStatus(status: AdminModerationStatus, text: ModerationPageText) {
  if (status === "approved") return text.statusApproved;
  if (status === "rejected") return text.statusRejected;
  return text.statusPending;
}

function formatModerationEvent(eventType: string, text: ModerationPageText) {
  return eventType === "complaint" ? text.eventComplaint : text.eventFeedback;
}

function formatTemplateType(templateType: string, text: ModerationPageText) {
  if (templateType === "Image") return text.templateImage;
  if (templateType === "Video") return text.templateVideo;
  return sanitizeSensitiveText(templateType, 48);
}

function getModerationDecisionErrorDetails(error: unknown) {
  return {
    errorName: error instanceof Error ? error.name : "UnknownError",
    errorDigest:
      error && typeof error === "object" && "digest" in error
        ? sanitizeSensitiveText(String((error as { digest?: unknown }).digest ?? ""), 80)
        : undefined,
  };
}

function getModerationDecisionContext(decision: DecisionState | null) {
  return {
    eventId: decision?.item.eventId ? sanitizeSensitiveText(decision.item.eventId, 80) : undefined,
    templateId: decision?.item.templateId
      ? sanitizeSensitiveText(decision.item.templateId, 80)
      : undefined,
    action: decision?.action,
  };
}

export function ModerationPage({ locale }: ModerationPageProps) {
  const text = getModerationPageText(locale);
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
      await Promise.allSettled([
        queryClient.invalidateQueries({ queryKey: ["admin", "moderation"] }),
        queryClient.invalidateQueries({ queryKey: adminQueryKeys.dashboard(locale) }),
      ]);
    },
    onError: (error) => {
      clientLogger.warn("moderation.decision_failed", {
        ...getModerationDecisionContext(decision),
        ...getModerationDecisionErrorDetails(error),
      });
      setToast({ type: "error", message: getAdminErrorMessage(error, text.failed) });
    },
    onSettled: () => {
      decisionInFlightRef.current = false;
      setIsDecisionInFlight(false);
    },
  });

  const isDecisionSubmitting = isDecisionInFlight || decisionMutation.isPending;
  const isDecisionDraftOpen = Boolean(decision);
  const isQueueContextLocked = isDecisionDraftOpen || isDecisionSubmitting;
  const items = queueQuery.data?.items ?? [];
  const visibleItems = queueQuery.isPlaceholderData ? [] : items;
  const isQueueRefreshing = queueQuery.isFetching && queueQuery.isPlaceholderData;
  const visibleEventIdSignature = visibleItems.map((item) => item.eventId).join("|");

  useEffect(() => {
    if (
      !decision ||
      decisionInFlightRef.current ||
      decisionMutation.isPending ||
      isQueueRefreshing ||
      visibleEventIdSignature.split("|").includes(decision.item.eventId)
    ) {
      return;
    }

    queueMicrotask(() => {
      setDecision(null);
      setReason("");
      setReasonError(null);
    });
  }, [decision, decisionMutation.isPending, isQueueRefreshing, visibleEventIdSignature]);

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

  function resetDecisionDraft() {
    if (decisionInFlightRef.current || decisionMutation.isPending) {
      return;
    }

    setDecision(null);
    setReason("");
    setReasonError(null);
  }

  function resetQueueContext(nextPage = 0) {
    if (isQueueContextLocked) {
      return;
    }

    resetDecisionDraft();
    setPage(nextPage);
  }

  function requestQueueRetry() {
    if (!canModerate || isQueueContextLocked || queueQuery.isFetching) {
      return;
    }

    void queueQuery.refetch().catch(() => undefined);
  }

  return (
    <section className={styles.page}>
      <AdminPageHero
        eyebrow={text.eyebrow}
        title={text.title}
        description={text.description}
        badge={<AdminBadge tone="info">{text.workspaceBadge}</AdminBadge>}
      />

      {!canModerate ? <AdminStateCard title={text.loading} /> : null}

      {canModerate ? (
      <AdminCard title={text.filtersTitle}>
        <div className={styles.filters}>
          <label className={styles.field}>
            <span className={styles.label}>{text.status}</span>
            <select
              className={styles.select}
              value={status}
              disabled={isQueueContextLocked}
              onChange={(event) => {
                setStatus(event.target.value as StatusFilter);
                resetQueueContext();
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
              disabled={isQueueContextLocked}
              onChange={(event) => {
                setSearch(event.target.value.slice(0, MODERATION_SEARCH_MAX_LENGTH));
                resetQueueContext();
              }}
              maxLength={MODERATION_SEARCH_MAX_LENGTH}
              placeholder={text.searchPlaceholder}
            />
          </label>
        </div>
      </AdminCard>
      ) : null}

      {canModerate ? (
        queueQuery.isLoading || isQueueRefreshing ? (
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
                disabled={!canModerate || isQueueContextLocked || queueQuery.isFetching}
                onClick={requestQueueRetry}
              >
                {text.retry}
              </button>
            }
          />
        ) : visibleItems.length === 0 ? (
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
                {visibleItems.map((item) => (
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
                          aria-label={`${text.approveItemLabel}: ${formatModerationText(
                            item.templateTitle,
                            item.eventId,
                            80
                          )}`}
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
                          aria-label={`${text.rejectItemLabel}: ${formatModerationText(
                            item.templateTitle,
                            item.eventId,
                            80
                          )}`}
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
              className={`${styles.button} ${styles.pagerButton}`}
              disabled={page === 0 || isQueueContextLocked || queueQuery.isFetching}
              aria-label={text.previousPageLabel}
              title={text.previousPageLabel}
              onClick={() => resetQueueContext(Math.max(0, page - 1))}
            >
              <CaretDownIcon className={`${styles.pageIcon} ${styles.pageIconPrevious}`} />
            </button>
            <button
              type="button"
              className={`${styles.button} ${styles.pagerButton}`}
              disabled={!queueQuery.data?.hasMore || isQueueContextLocked || queueQuery.isFetching}
              aria-label={text.nextPageLabel}
              title={text.nextPageLabel}
              onClick={() => resetQueueContext(page + 1)}
            >
              <CaretDownIcon className={`${styles.pageIcon} ${styles.pageIconNext}`} />
            </button>
          </div>
          </AdminCard>
        )
      ) : null}

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
