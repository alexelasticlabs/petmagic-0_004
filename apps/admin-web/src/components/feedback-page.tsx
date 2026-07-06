"use client";

import { keepPreviousData, useQuery } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";

import { CaretDownIcon } from "@/components/admin/admin-icons";
import {
  AdminBadge,
  AdminCard,
  AdminPageHero,
  AdminStateCard,
  adminTableStyles,
} from "@/components/admin/admin-primitives";
import { ensureAdminSession } from "@/components/admin/admin-session";
import styles from "@/components/feedback-page.module.css";
import {
  DetailsPanel,
  FeedbackRow,
  Field,
  Select,
  priorityOptions,
  statusOptions,
  typeOptions,
} from "@/components/feedback-page.sections";
import { getAdminErrorMessage } from "@/lib/admin-error-message";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
  ADMIN_FEEDBACK_FILTER_MAX_LENGTH,
  fetchAdminFeedback,
  fetchAdminFeedbackDetails,
  normalizeAdminFeedbackQuery,
  useAuthSession,
  type FeedbackPriority,
  type FeedbackStatus,
  type FeedbackType,
} from "@/lib/api-client";
import { type Locale } from "@/lib/i18n";

import { getFeedbackPageText } from "./feedback-page.content";

type FeedbackPageProps = {
  locale: Locale;
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

function dateInputToUtcStart(value: string): string | undefined {
  return value ? new Date(`${value}T00:00:00.000Z`).toISOString() : undefined;
}

function dateInputToUtcEnd(value: string): string | undefined {
  return value ? new Date(`${value}T23:59:59.999Z`).toISOString() : undefined;
}

export function FeedbackPage({ locale }: FeedbackPageProps) {
  const text = getFeedbackPageText(locale);
  const router = useRouter();
  const session = useAuthSession();
  const canView =
    session?.user.roles.some((role) => role === "Admin" || role === "Moderator") ?? false;
  const canViewUserProfile = session?.user.roles.includes("Admin") ?? false;
  const [status, setStatus] = useState<FeedbackStatus | "All">("All");
  const [priority, setPriority] = useState<FeedbackPriority | "All">("All");
  const [type, setType] = useState<FeedbackType | "All">("All");
  const [category, setCategory] = useState("");
  const [platform, setPlatform] = useState("");
  const [templateId, setTemplateId] = useState("");
  const [userId, setUserId] = useState("");
  const [fromUtc, setFromUtc] = useState("");
  const [toUtc, setToUtc] = useState("");
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [page, setPage] = useState(0);
  const debouncedCategory = useDebouncedValue(category, 350);
  const debouncedPlatform = useDebouncedValue(platform, 350);
  const debouncedTemplateId = useDebouncedValue(templateId, 350);
  const debouncedUserId = useDebouncedValue(userId, 350);

  useEffect(() => {
    ensureAdminSession(locale, router);
  }, [locale, router, session]);

  const query = useMemo(
    () =>
      normalizeAdminFeedbackQuery({
        status,
        priority,
        type,
        category: debouncedCategory,
        platform: debouncedPlatform,
        templateId: debouncedTemplateId,
        userId: debouncedUserId,
        fromUtc: dateInputToUtcStart(fromUtc),
        toUtc: dateInputToUtcEnd(toUtc),
        skip: page * PAGE_SIZE,
        take: PAGE_SIZE,
      }),
    [
      debouncedCategory,
      debouncedPlatform,
      debouncedTemplateId,
      debouncedUserId,
      fromUtc,
      page,
      priority,
      status,
      toUtc,
      type,
    ]
  );
  const feedbackQuery = useQuery({
    queryKey: adminQueryKeys.feedback(query),
    queryFn: ({ signal }) => fetchAdminFeedback(query, signal),
    enabled: canView,
    placeholderData: keepPreviousData,
  });
  const detailsQuery = useQuery({
    queryKey: selectedId
      ? adminQueryKeys.feedbackDetails(selectedId)
      : ["admin", "feedback", "none"],
    queryFn: ({ signal }) => fetchAdminFeedbackDetails(selectedId!, signal),
    enabled: canView && Boolean(selectedId),
  });
  const pageData = feedbackQuery.data;
  const visiblePageData = feedbackQuery.isPlaceholderData ? undefined : pageData;
  const visibleFeedbackItems = useMemo(() => visiblePageData?.items ?? [], [visiblePageData]);
  const isFeedbackRefreshing = feedbackQuery.isFetching && feedbackQuery.isPlaceholderData;
  const isFeedbackFetching = feedbackQuery.isFetching;
  const areFeedbackFiltersLocked = isFeedbackFetching;
  const isDetailsFetching = detailsQuery.isFetching;
  const visibleFeedbackIds = useMemo(
    () => new Set(visibleFeedbackItems.map((item) => item.id)),
    [visibleFeedbackItems]
  );

  useEffect(() => {
    let isActive = true;
    if (!visiblePageData || !selectedId || visibleFeedbackIds.has(selectedId)) {
      return;
    }

    queueMicrotask(() => {
      if (isActive) {
        setSelectedId(null);
      }
    });

    return () => {
      isActive = false;
    };
  }, [selectedId, visibleFeedbackIds, visiblePageData]);

  function resetFeedbackSelection(nextPage = 0) {
    setSelectedId(null);
    setPage(nextPage);
  }

  function requestFeedbackPageChange(nextPage: number) {
    if (isFeedbackFetching) {
      return;
    }

    if (nextPage < 0) {
      return;
    }

    if (nextPage > page && !visiblePageData?.hasMore) {
      return;
    }

    resetFeedbackSelection(nextPage);
  }

  function requestFeedbackRetry() {
    if (isFeedbackFetching) {
      return;
    }

    void feedbackQuery.refetch().catch(() => undefined);
  }

  function requestDetailsRetry() {
    if (isDetailsFetching) {
      return;
    }

    void detailsQuery.refetch().catch(() => undefined);
  }

  if (!canView) {
    return (
      <main className={styles.page}>
        <AdminPageHero
          eyebrow={text.eyebrow}
          title={text.title}
          description={text.description}
          badge={<AdminBadge tone="info">0</AdminBadge>}
        />
        <AdminStateCard title={text.loading} />
      </main>
    );
  }

  return (
    <main className={styles.page}>
      <AdminPageHero
        eyebrow={text.eyebrow}
        title={text.title}
        description={text.description}
        badge={<AdminBadge tone="info">{visiblePageData?.totalCount ?? 0}</AdminBadge>}
      />
      <AdminCard title={text.filters}>
        <div className={styles.filters}>
          <Select
            label={text.status}
            value={status}
            options={statusOptions}
            optionLabels={text.statusOptions}
            disabled={areFeedbackFiltersLocked}
            onChange={(value) => {
              setStatus(value as typeof status);
              resetFeedbackSelection();
            }}
          />
          <Select
            label={text.priority}
            value={priority}
            options={priorityOptions}
            optionLabels={text.priorityOptions}
            disabled={areFeedbackFiltersLocked}
            onChange={(value) => {
              setPriority(value as typeof priority);
              resetFeedbackSelection();
            }}
          />
          <Select
            label={text.type}
            value={type}
            options={typeOptions}
            optionLabels={text.typeOptions}
            disabled={areFeedbackFiltersLocked}
            onChange={(value) => {
              setType(value as typeof type);
              resetFeedbackSelection();
            }}
          />
          <Field
            label={text.category}
            value={category}
            maxLength={ADMIN_FEEDBACK_FILTER_MAX_LENGTH}
            disabled={areFeedbackFiltersLocked}
            onChange={(value) => {
              setCategory(value);
              resetFeedbackSelection();
            }}
          />
          <Field
            label={text.platform}
            value={platform}
            maxLength={ADMIN_FEEDBACK_FILTER_MAX_LENGTH}
            disabled={areFeedbackFiltersLocked}
            onChange={(value) => {
              setPlatform(value);
              resetFeedbackSelection();
            }}
          />
          <Field
            label={text.templateId}
            value={templateId}
            maxLength={ADMIN_FEEDBACK_FILTER_MAX_LENGTH}
            disabled={areFeedbackFiltersLocked}
            onChange={(value) => {
              setTemplateId(value);
              resetFeedbackSelection();
            }}
          />
          <Field
            label={text.userId}
            value={userId}
            maxLength={ADMIN_FEEDBACK_FILTER_MAX_LENGTH}
            disabled={areFeedbackFiltersLocked}
            onChange={(value) => {
              setUserId(value);
              resetFeedbackSelection();
            }}
          />
          <Field
            label={text.from}
            value={fromUtc}
            type="date"
            disabled={areFeedbackFiltersLocked}
            onChange={(value) => {
              setFromUtc(value);
              resetFeedbackSelection();
            }}
          />
          <Field
            label={text.to}
            value={toUtc}
            type="date"
            disabled={areFeedbackFiltersLocked}
            onChange={(value) => {
              setToUtc(value);
              resetFeedbackSelection();
            }}
          />
        </div>
      </AdminCard>
      <AdminCard
        title={
          <div className={styles.tableHeader}>
            <h2 className={styles.tableTitle}>{text.table}</h2>
            <span className={styles.meta}>
              {visiblePageData
                ? `${visibleFeedbackItems.length} / ${visiblePageData.totalCount}`
                : ""}
            </span>
          </div>
        }
      >
        {feedbackQuery.isLoading || isFeedbackRefreshing ? (
          <AdminStateCard title={text.loading} />
        ) : feedbackQuery.isError ? (
          <AdminStateCard
            title={text.error}
            description={getAdminErrorMessage(feedbackQuery.error, text.error)}
            action={
              <button
                className={styles.button}
                type="button"
                disabled={isFeedbackFetching}
                onClick={requestFeedbackRetry}
              >
                {text.retry}
              </button>
            }
          />
        ) : visibleFeedbackItems.length === 0 ? (
          <AdminStateCard title={text.empty} />
        ) : (
          <div className={adminTableStyles.tableWrap}>
            <table className={adminTableStyles.table}>
              <thead>
                <tr>
                  <th>{text.date}</th>
                  <th>{text.user}</th>
                  <th>{text.type}</th>
                  <th>{text.category}</th>
                  <th>{text.rating}</th>
                  <th>{text.template}</th>
                  <th>{text.platform}</th>
                  <th>{text.status}</th>
                  <th>{text.priority}</th>
                  <th>{text.preview}</th>
                  <th>{text.message}</th>
                  <th />
                </tr>
              </thead>
              <tbody>
                {visibleFeedbackItems.map((item) => (
                  <FeedbackRow
                    key={item.id}
                    item={item}
                    text={text}
                    locale={locale}
                    onOpen={setSelectedId}
                  />
                ))}
              </tbody>
            </table>
          </div>
        )}
        <div className={styles.actions}>
          <button
            className={`${styles.button} ${styles.pagerButton}`}
            type="button"
            disabled={page === 0 || isFeedbackFetching}
            aria-label={text.previousPageLabel}
            title={text.previousPageLabel}
            onClick={() => {
              requestFeedbackPageChange(page - 1);
            }}
          >
            <CaretDownIcon className={`${styles.pageIcon} ${styles.pageIconPrevious}`} />
          </button>
          <button
            className={`${styles.button} ${styles.pagerButton}`}
            type="button"
            disabled={!visiblePageData?.hasMore || isFeedbackFetching}
            aria-label={text.nextPageLabel}
            title={text.nextPageLabel}
            onClick={() => {
              requestFeedbackPageChange(page + 1);
            }}
          >
            <CaretDownIcon className={`${styles.pageIcon} ${styles.pageIconNext}`} />
          </button>
        </div>
      </AdminCard>
      {selectedId && detailsQuery.isLoading ? (
        <AdminStateCard title={text.detailsLoading} />
      ) : selectedId && detailsQuery.isError ? (
        <AdminStateCard
          title={text.detailsError}
          description={getAdminErrorMessage(detailsQuery.error, text.detailsError)}
          action={
            <button
              className={styles.button}
              type="button"
              disabled={isDetailsFetching}
              onClick={requestDetailsRetry}
            >
              {text.retry}
            </button>
          }
        />
      ) : detailsQuery.data ? (
        <DetailsPanel
          key={[
            detailsQuery.data.id,
            detailsQuery.data.status,
            detailsQuery.data.priority,
            detailsQuery.data.reviewedAtUtc ?? "",
            detailsQuery.data.adminNote ?? "",
          ].join(":")}
          details={detailsQuery.data}
          isDetailsFetching={isDetailsFetching}
          canViewUserProfile={canViewUserProfile}
          locale={locale}
        />
      ) : null}
    </main>
  );
}
