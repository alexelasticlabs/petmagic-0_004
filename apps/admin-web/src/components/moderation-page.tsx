"use client";

import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { useEffect, useMemo, useRef, useState } from "react";

import { AdminDetailsDrawer } from "@/components/admin/admin-details-drawer";
import { AdminEntityLink } from "@/components/admin/admin-entity-link";
import { CaretDownIcon } from "@/components/admin/admin-icons";
import {
  AdminBadge,
  AdminCard,
  AdminKpiCard,
  AdminPageHero,
  AdminStateCard,
  AdminStatusBadge,
  adminTableStyles,
} from "@/components/admin/admin-primitives";
import { ensureAdminSession } from "@/components/admin/admin-session";
import { useAdminUrlStateSyncGuard } from "@/components/admin/use-admin-url-state-sync-guard";
import {
  hasActiveModerationLease,
  ModerationLeaseControl,
} from "@/components/moderation-lease-control";
import {
  getModerationPageText,
  type ModerationPageText,
} from "@/components/moderation-page.content";
import styles from "@/components/moderation-page.module.css";
import {
  ModerationReviewDialog,
  type ModerationDecisionAction,
} from "@/components/moderation-review-dialog";
import { Button } from "@/components/ui/button";
import { Select, type SelectOption } from "@/components/ui/select";
import { Toast } from "@/components/ui/toast";
import { getAdminErrorMessage } from "@/lib/admin-error-message";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import { updateAdminUrlState } from "@/lib/admin-url-state";
import {
  decideAdminModerationItem,
  fetchAdminModerationQueue,
  MODERATION_DECISION_REASON_MAX_LENGTH,
  MODERATION_SEARCH_MAX_LENGTH,
  normalizeAdminModerationQueueQuery,
  useAuthSession,
  type AdminModerationQueueItem,
  type AdminModerationQueuePage,
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
  action: ModerationDecisionAction | null;
};

const PAGE_SIZE = 25;
const MODERATION_DECISION_CONFLICT_CODE = "templates.moderation_decision_conflict";
const moderationEventIdPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function readModerationStatus(value: string | null): StatusFilter {
  return value === "approved" || value === "rejected" || value === "all" ? value : "pending";
}

function readModerationPage(value: string | null): number {
  const parsed = Number.parseInt(value ?? "", 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed - 1 : 0;
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

function getModerationDecisionErrorCode(error: unknown) {
  if (!error || typeof error !== "object" || !("code" in error)) {
    return undefined;
  }

  const code = (error as { code?: unknown }).code;
  return typeof code === "string" ? sanitizeSensitiveText(code, 100) : undefined;
}

function getModerationDecisionErrorDetails(error: unknown) {
  return {
    errorName: error instanceof Error ? error.name : "UnknownError",
    errorCode: getModerationDecisionErrorCode(error),
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
    action: decision?.action ?? undefined,
  };
}

export function ModerationPage({ locale }: ModerationPageProps) {
  const text = getModerationPageText(locale);
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();
  const queryClient = useQueryClient();
  const session = useAuthSession();
  const sessionRoles = session?.user.roles ?? [];
  const sessionUserId = session?.user.userId ?? null;
  const canModerate = sessionRoles.includes("Admin") || sessionRoles.includes("Moderator");
  const [status, setStatus] = useState<StatusFilter>(() =>
    readModerationStatus(searchParams.get("status"))
  );
  const [search, setSearch] = useState(() =>
    (searchParams.get("search") ?? "").trim().slice(0, MODERATION_SEARCH_MAX_LENGTH)
  );
  const [page, setPage] = useState(() => readModerationPage(searchParams.get("page")));
  const [decision, setDecision] = useState<DecisionState | null>(null);
  const [reason, setReason] = useState("");
  const [reasonError, setReasonError] = useState<string | null>(null);
  const [toast, setToast] = useState<{ type: "success" | "error"; message: string } | null>(null);
  const [isDecisionInFlight, setIsDecisionInFlight] = useState(false);
  const decisionInFlightRef = useRef(false);
  const debouncedSearch = useDebouncedValue(search, 350);
  const trimmedReason = reason.trim().slice(0, MODERATION_DECISION_REASON_MAX_LENGTH);
  const isReasonValid = trimmedReason.length >= 3;
  const isUrlStateSyncSuspended = Boolean(decision) || isDecisionInFlight;
  const currentSearchParams = searchParams.toString();
  const { consumeUrlStateApplication, markUrlStateWritten } = useAdminUrlStateSyncGuard({
    currentSearch: currentSearchParams,
    suspended: isUrlStateSyncSuspended,
    applyUrlState: (nextSearchParams) => {
      setStatus(readModerationStatus(nextSearchParams.get("status")));
      setSearch(
        (nextSearchParams.get("search") ?? "").trim().slice(0, MODERATION_SEARCH_MAX_LENGTH)
      );
      setPage(readModerationPage(nextSearchParams.get("page")));
    },
  });
  const moderationUrlStatus = readModerationStatus(searchParams.get("status"));
  const moderationUrlSearch = (searchParams.get("search") ?? "")
    .trim()
    .slice(0, MODERATION_SEARCH_MAX_LENGTH);
  const moderationUrlPage = readModerationPage(searchParams.get("page"));
  const isModerationUrlStatePending =
    status !== moderationUrlStatus ||
    search.trim() !== moderationUrlSearch ||
    debouncedSearch !== moderationUrlSearch ||
    page !== moderationUrlPage;

  useEffect(() => {
    if (!toast) return;
    const timeoutId = window.setTimeout(() => setToast(null), 3_600);
    return () => window.clearTimeout(timeoutId);
  }, [toast]);

  useEffect(() => {
    ensureAdminSession(locale, router);
  }, [locale, router, session]);

  useEffect(() => {
    if (isUrlStateSyncSuspended || consumeUrlStateApplication(isModerationUrlStatePending)) {
      return;
    }

    const next = new URLSearchParams(searchParams.toString());
    if (status === "pending") next.delete("status");
    else next.set("status", status);
    if (debouncedSearch) next.set("search", debouncedSearch);
    else next.delete("search");
    if (page > 0) next.set("page", String(page + 1));
    else next.delete("page");

    const nextSearch = next.toString();
    if (nextSearch !== searchParams.toString()) {
      markUrlStateWritten(nextSearch);
      router.replace(nextSearch ? `${pathname}?${nextSearch}` : pathname, { scroll: false });
    }
  }, [
    consumeUrlStateApplication,
    debouncedSearch,
    isModerationUrlStatePending,
    isUrlStateSyncSuspended,
    markUrlStateWritten,
    page,
    pathname,
    router,
    searchParams,
    status,
  ]);

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

  const statusOptions = useMemo<readonly SelectOption[]>(
    () => [
      { value: "pending", label: text.statusPending },
      { value: "approved", label: text.statusApproved },
      { value: "rejected", label: text.statusRejected },
      { value: "all", label: text.statusAll },
    ],
    [text]
  );

  function clearDecisionDraft() {
    setDecision(null);
    setReason("");
    setReasonError(null);
  }

  function assertCanModerate(): boolean {
    if (canModerate) {
      return true;
    }

    clearDecisionDraft();
    setToast({ type: "error", message: text.moderationActionsForbidden });
    return false;
  }

  async function invalidateModerationData() {
    await Promise.allSettled([
      queryClient.invalidateQueries({ queryKey: ["admin", "moderation"] }),
      queryClient.invalidateQueries({ queryKey: ["admin", "dashboard"] }),
    ]);
  }

  const queueQuery = useQuery({
    queryKey: adminQueryKeys.moderationQueue(query),
    queryFn: ({ signal }) => fetchAdminModerationQueue(query, signal),
    enabled: canModerate,
    placeholderData: keepPreviousData,
    refetchInterval: (currentQuery) =>
      currentQuery.state.data?.items.some((item) => item.status === "pending") ? 15_000 : false,
  });

  const decisionMutation = useMutation({
    mutationFn: async () => {
      if (!assertCanModerate()) throw new Error(text.moderationActionsForbidden);
      if (!decision || !decision.action) throw new Error(text.decisionMissing);
      if (!isReasonValid) throw new Error(text.reasonRequired);
      return decideAdminModerationItem(decision.item.eventId, {
        action: decision.action,
        reason: trimmedReason,
        expectedVersion: decision.item.version ?? 0,
      });
    },
    onSuccess: async () => {
      setToast({ type: "success", message: text.saved });
      clearDecisionDraft();
      await invalidateModerationData();
    },
    onError: async (error) => {
      clientLogger.warn("moderation.decision_failed", {
        ...getModerationDecisionContext(decision),
        ...getModerationDecisionErrorDetails(error),
      });

      if (getModerationDecisionErrorCode(error) === MODERATION_DECISION_CONFLICT_CODE) {
        clearDecisionDraft();
        setToast({ type: "error", message: text.decisionConflict });
        await invalidateModerationData();
        return;
      }

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
  const selectedEventId = moderationEventIdPattern.test(searchParams.get("selected") ?? "")
    ? searchParams.get("selected")
    : null;
  const selectedItem = visibleItems.find((item) => item.eventId === selectedEventId) ?? null;
  const selectedLeaseOwnedByCurrentUser = Boolean(
    selectedItem &&
    sessionUserId &&
    hasActiveModerationLease(selectedItem) &&
    selectedItem.leaseOwnerUserId === sessionUserId
  );
  const isQueueRefreshing = queueQuery.isFetching && queueQuery.isPlaceholderData;
  const visibleEventIdSignature = visibleItems.map((item) => item.eventId).join("|");
  const summary = queueQuery.data?.summary ?? null;
  const summaryGeneratedAt = summary?.generatedAtUtc ?? queueQuery.data?.generatedAtUtc;

  useEffect(() => {
    let isActive = true;
    if (
      !decision ||
      decisionInFlightRef.current ||
      decisionMutation.isPending ||
      isQueueRefreshing ||
      visibleItems.some((item) => item.eventId === decision.item.eventId)
    ) {
      return;
    }

    queueMicrotask(() => {
      if (!isActive) {
        return;
      }

      clearDecisionDraft();
    });

    return () => {
      isActive = false;
    };
    // The signature intentionally represents the visible queue identity.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [decision, decisionMutation.isPending, isQueueRefreshing, visibleEventIdSignature]);

  function selectModerationItem(item: AdminModerationQueueItem | null) {
    if (isDecisionSubmitting) return;
    const next = updateAdminUrlState(
      searchParams,
      { selected: item?.eventId ?? null, tab: item ? "queue" : null },
      { resetPageOnQueryChange: false }
    );
    const nextSearch = next.toString();
    router.replace(nextSearch ? `${pathname}?${nextSearch}` : pathname, { scroll: false });
  }

  function applyModerationItemUpdate(updatedItem: AdminModerationQueueItem) {
    queryClient.setQueriesData<AdminModerationQueuePage>(
      { queryKey: ["admin", "moderation"] },
      (current) =>
        current
          ? {
              ...current,
              items: current.items.map((item) =>
                item.eventId === updatedItem.eventId ? updatedItem : item
              ),
            }
          : current
    );
    void invalidateModerationData();
  }

  function openReview(
    item: AdminModerationQueueItem,
    action: ModerationDecisionAction | null = null
  ) {
    if (decisionInFlightRef.current || decisionMutation.isPending || item.status !== "pending") {
      return;
    }

    if (!assertCanModerate()) {
      return;
    }

    if (
      !sessionUserId ||
      !hasActiveModerationLease(item) ||
      item.leaseOwnerUserId !== sessionUserId
    ) {
      setToast({ type: "error", message: text.claimBeforeDecision });
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

    if (!decision?.action) {
      setReasonError(text.decisionMissing);
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

    clearDecisionDraft();
  }

  function resetQueueContext(nextPage = 0) {
    if (isQueueContextLocked) {
      return;
    }

    resetDecisionDraft();
    setPage(nextPage);
    selectModerationItem(null);
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

      {canModerate && summary ? (
        <>
          <div className={styles.summaryGrid} aria-label={text.summaryScope}>
            <AdminKpiCard
              label={text.summaryPending}
              value={summary.pendingCount.toLocaleString(locale)}
              hint={`${summary.pendingComplaintsCount.toLocaleString(locale)} ${
                text.complaintsShort
              } · ${summary.pendingFeedbackCount.toLocaleString(locale)} ${text.feedbackShort}`}
              tone="warning"
            />
            <AdminKpiCard
              label={text.summaryApproved}
              value={summary.approvedCount.toLocaleString(locale)}
              hint={text.summaryScope}
              tone="success"
            />
            <AdminKpiCard
              label={text.summaryRejected}
              value={summary.rejectedCount.toLocaleString(locale)}
              hint={text.summaryScope}
              tone="danger"
            />
            <AdminKpiCard
              label={text.summaryOldest}
              value={
                summary.oldestPendingAtUtc
                  ? formatDateTime(summary.oldestPendingAtUtc, locale)
                  : text.noPending
              }
              hint={text.summaryScope}
              tone="info"
            />
          </div>
          <div className={styles.summaryMeta}>
            <span className={styles.summaryComposition}>
              {text.pendingComposition}: {summary.pendingComplaintsCount.toLocaleString(locale)}{" "}
              {text.complaintsShort} · {summary.pendingFeedbackCount.toLocaleString(locale)}{" "}
              {text.feedbackShort}
            </span>
            {summaryGeneratedAt ? (
              <span>
                {text.updatedAt}: {formatDateTime(summaryGeneratedAt, locale)}
              </span>
            ) : null}
          </div>
        </>
      ) : null}

      {canModerate ? (
        <AdminCard title={text.filtersTitle}>
          <div className={styles.filters}>
            <div className={styles.field}>
              <span className={styles.label}>{text.status}</span>
              <Select
                value={status}
                options={statusOptions}
                ariaLabel={text.status}
                showSelectedDescription={false}
                disabled={isQueueContextLocked}
                onChange={(value) => {
                  if (isQueueContextLocked) return;
                  setStatus(value as StatusFilter);
                  resetQueueContext();
                }}
              />
            </div>
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
          <AdminCard
            title={text.queueTitle}
            action={
              <span className={styles.queueHeaderMeta}>
                {text.queueShowing} {visibleItems.length} / {queueQuery.data?.totalCount ?? 0}
              </span>
            }
          >
            <div
              className={`${adminTableStyles.tableWrap} ${styles.tableRegion}`}
              role="region"
              aria-label={text.queueRegionLabel}
              aria-busy={queueQuery.isFetching ? "true" : undefined}
              tabIndex={0}
            >
              <table className={adminTableStyles.table}>
                <caption className={styles.visuallyHidden}>{text.queueRegionLabel}</caption>
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
                        {item.status === "pending" ? (
                          <button
                            type="button"
                            className={`${styles.button} ${styles.primaryButton}`}
                            aria-label={`${text.reviewItemLabel}: ${formatModerationText(
                              item.templateTitle,
                              item.eventId,
                              80
                            )}`}
                            disabled={!canModerate || isDecisionSubmitting}
                            onClick={() => selectModerationItem(item)}
                          >
                            {text.review}
                          </button>
                        ) : (
                          <span className={styles.meta}>—</span>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>

            <ul
              className={styles.mobileQueue}
              aria-label={text.mobileQueueLabel}
              aria-busy={queueQuery.isFetching ? "true" : undefined}
            >
              {visibleItems.map((item) => (
                <li key={item.eventId}>
                  <article className={styles.mobileCard}>
                    <div className={styles.mobileCardHeader}>
                      <div>
                        <h3 className={styles.mobileTitle}>
                          {formatModerationText(item.templateTitle, "-", 120)}
                        </h3>
                        <div className={styles.meta}>
                          {formatTemplateType(item.templateType, text)} / {shortId(item.templateId)}
                        </div>
                      </div>
                      <div className={styles.mobileBadges}>
                        <AdminBadge tone={item.eventType === "complaint" ? "danger" : "info"}>
                          {formatModerationEvent(item.eventType, text)}
                        </AdminBadge>
                        <AdminStatusBadge color={statusColor(item.status)}>
                          {formatModerationStatus(item.status, text)}
                        </AdminStatusBadge>
                      </div>
                    </div>

                    <p className={styles.mobileMessage}>
                      {formatModerationText(item.message, text.noMessage, 480)}
                    </p>

                    <dl className={styles.mobileFacts}>
                      <div>
                        <dt>{text.source}</dt>
                        <dd>{formatModerationText(item.source, "-", 64)}</dd>
                      </div>
                      <div>
                        <dt>{text.created}</dt>
                        <dd>{formatDateTime(item.createdAtUtc, locale)}</dd>
                      </div>
                      <div>
                        <dt>{text.device}</dt>
                        <dd>{formatModerationText(item.deviceClass, "-", 32)}</dd>
                      </div>
                      <div>
                        <dt>{text.userId}</dt>
                        <dd>{shortId(item.userId)}</dd>
                      </div>
                    </dl>

                    {item.moderationComment ? (
                      <div className={styles.previousDecision}>
                        <strong>{text.previousDecision}</strong>
                        <span>{formatModerationText(item.moderationComment, "-", 480)}</span>
                      </div>
                    ) : null}

                    {item.status === "pending" ? (
                      <div className={styles.mobileCardFooter}>
                        <span className={styles.meta}>
                          {text.generationId}: {shortId(item.generationId)}
                        </span>
                        <button
                          type="button"
                          className={`${styles.button} ${styles.primaryButton}`}
                          aria-label={`${text.reviewItemLabel}: ${formatModerationText(
                            item.templateTitle,
                            item.eventId,
                            80
                          )}`}
                          disabled={!canModerate || isDecisionSubmitting}
                          onClick={() => selectModerationItem(item)}
                        >
                          {text.review}
                        </button>
                      </div>
                    ) : null}
                  </article>
                </li>
              ))}
            </ul>

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
                disabled={
                  !queueQuery.data?.hasMore || isQueueContextLocked || queueQuery.isFetching
                }
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

      <AdminDetailsDrawer
        open={Boolean(selectedItem)}
        title={
          selectedItem
            ? formatModerationText(selectedItem.templateTitle, "-", 160)
            : text.reviewTitle
        }
        description={
          selectedItem
            ? `${formatModerationEvent(selectedItem.eventType, text)} · ${shortId(selectedItem.eventId)}`
            : undefined
        }
        closeLabel={text.closeInspector}
        onClose={() => selectModerationItem(null)}
        footer={
          selectedItem?.status === "pending" ? (
            <div className={styles.inspectorDecisionActions}>
              <Button
                variant="primary"
                size="sm"
                disabled={!selectedLeaseOwnedByCurrentUser || isDecisionSubmitting}
                onClick={() => {
                  openReview(selectedItem, "approve");
                  selectModerationItem(null);
                }}
              >
                {text.approve}
              </Button>
              <Button
                variant="danger"
                size="sm"
                disabled={!selectedLeaseOwnedByCurrentUser || isDecisionSubmitting}
                onClick={() => {
                  openReview(selectedItem, "reject");
                  selectModerationItem(null);
                }}
              >
                {text.reject}
              </Button>
            </div>
          ) : undefined
        }
      >
        {selectedItem ? (
          <div className={styles.inspectorWorkspace}>
            <div className={styles.inspectorBadges}>
              <AdminBadge tone={selectedItem.eventType === "complaint" ? "danger" : "info"}>
                {formatModerationEvent(selectedItem.eventType, text)}
              </AdminBadge>
              <AdminStatusBadge color={statusColor(selectedItem.status)}>
                {formatModerationStatus(selectedItem.status, text)}
              </AdminStatusBadge>
            </div>

            <section className={styles.inspectorSection}>
              <h3>{text.message}</h3>
              <p className={styles.workspaceMessage}>
                {formatModerationText(selectedItem.message, text.noMessage, 1_200)}
              </p>
            </section>

            <section className={styles.inspectorSection}>
              <h3>{text.contextTitle}</h3>
              <div className={styles.entityLinks}>
                <AdminEntityLink
                  href={`/${locale}/templates/${selectedItem.templateType.toLowerCase()}/analytics/${encodeURIComponent(selectedItem.templateId)}`}
                  label={text.template}
                  secondaryLabel={shortId(selectedItem.templateId)}
                />
                {selectedItem.userId ? (
                  <AdminEntityLink
                    href={`/${locale}/users/${encodeURIComponent(selectedItem.userId)}`}
                    label={text.userId}
                    secondaryLabel={shortId(selectedItem.userId)}
                  />
                ) : null}
                {selectedItem.generationId ? (
                  <AdminEntityLink
                    href={`/${locale}/generations?selected=${encodeURIComponent(selectedItem.generationId)}`}
                    label={text.generationId}
                    secondaryLabel={shortId(selectedItem.generationId)}
                  />
                ) : null}
              </div>
              <dl className={styles.workspaceFacts}>
                <div>
                  <dt>{text.source}</dt>
                  <dd>{formatModerationText(selectedItem.source, "-", 64)}</dd>
                </div>
                <div>
                  <dt>{text.device}</dt>
                  <dd>{formatModerationText(selectedItem.deviceClass, "-", 32)}</dd>
                </div>
                <div>
                  <dt>{text.country}</dt>
                  <dd>{formatModerationText(selectedItem.countryCode, "-", 8)}</dd>
                </div>
                <div>
                  <dt>{text.created}</dt>
                  <dd>{formatDateTime(selectedItem.createdAtUtc, locale)}</dd>
                </div>
              </dl>
            </section>

            <section className={styles.inspectorSection}>
              <ModerationLeaseControl
                item={selectedItem}
                currentUserId={sessionUserId}
                roles={sessionRoles}
                locale={locale}
                onUpdated={applyModerationItemUpdate}
                onConflict={(message) => {
                  setToast({ type: "error", message });
                  void invalidateModerationData();
                }}
              />
              {selectedItem.status === "pending" && !selectedLeaseOwnedByCurrentUser ? (
                <p className={styles.leaseDecisionHint}>{text.claimBeforeDecision}</p>
              ) : null}
            </section>

            {selectedItem.moderationComment ? (
              <div className={styles.previousDecision}>
                <strong>{text.previousDecision}</strong>
                <span>{formatModerationText(selectedItem.moderationComment, "-", 600)}</span>
              </div>
            ) : null}
          </div>
        ) : null}
      </AdminDetailsDrawer>

      <ModerationReviewDialog
        locale={locale}
        text={text}
        item={decision?.item ?? null}
        action={decision?.action ?? null}
        reason={reason}
        reasonError={reasonError}
        isSubmitting={isDecisionSubmitting}
        canModerate={canModerate}
        onActionChange={(action) => {
          if (!isDecisionSubmitting) {
            setDecision((current) => (current ? { ...current, action } : current));
            setReasonError(null);
          }
        }}
        onReasonChange={(value) => {
          setReason(value);
          if (reasonError) {
            setReasonError(null);
          }
        }}
        onCancel={resetDecisionDraft}
        onConfirm={submitDecision}
      />

      {toast ? <Toast type={toast.type} message={toast.message} /> : null}
    </section>
  );
}
