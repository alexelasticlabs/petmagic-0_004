"use client";

import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";

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
import styles from "@/components/feedback-page.module.css";
import { TemplateSecureMedia } from "@/components/templates/template-secure-media";
import { getAdminErrorMessage } from "@/lib/admin-error-message";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
  ADMIN_FEEDBACK_ADMIN_NOTE_MAX_LENGTH,
  ADMIN_FEEDBACK_FILTER_MAX_LENGTH,
  fetchAdminFeedback,
  fetchAdminFeedbackDetails,
  fetchAdminUser,
  fetchAdminUserAnalytics,
  normalizeAdminFeedbackQuery,
  refundAdminFeedbackCredits,
  updateAdminFeedback,
  useAuthSession,
  type AdminFeedbackDetails,
  type AdminFeedbackListItem,
  type FeedbackPriority,
  type FeedbackStatus,
  type FeedbackType,
} from "@/lib/api-client";
import { formatDateTime } from "@/lib/format-date-time";
import { type Locale } from "@/lib/i18n";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

import { getFeedbackPageText, type FeedbackPageText } from "./feedback-page.content";

type FeedbackPageProps = {
  locale: Locale;
};

const PAGE_SIZE = 25;
const statusOptions: Array<FeedbackStatus | "All"> = [
  "All",
  "New",
  "InReview",
  "Resolved",
  "Dismissed",
];
const priorityOptions: Array<FeedbackPriority | "All"> = [
  "All",
  "Low",
  "Medium",
  "High",
  "Critical",
];
const typeOptions: Array<FeedbackType | "All"> = [
  "All",
  "GenerationResult",
  "GenerationFailure",
  "BugReport",
  "FeatureRequest",
  "PaymentIssue",
  "General",
];

function useDebouncedValue(value: string, delayMs: number) {
  const [debounced, setDebounced] = useState(value);

  useEffect(() => {
    const timeoutId = window.setTimeout(() => setDebounced(value), delayMs);
    return () => window.clearTimeout(timeoutId);
  }, [delayMs, value]);

  return debounced;
}

function toneForPriority(priority: string) {
  if (priority === "Critical") return "var(--danger)";
  if (priority === "High") return "var(--warning)";
  if (priority === "Medium") return "var(--info)";
  return "var(--neutral)";
}

function toneForStatus(status: string) {
  if (status === "Resolved") return "var(--success)";
  if (status === "Dismissed") return "var(--neutral)";
  if (status === "InReview") return "var(--info)";
  return "var(--warning)";
}

function shortId(value?: string | null) {
  if (!value) return "-";
  const safe = sanitizeSensitiveText(value, 40);
  return safe.length > 14 ? `${safe.slice(0, 8)}...${safe.slice(-4)}` : safe;
}

function optionLabel<T extends string>(
  labels: Record<T | "All", string>,
  value?: T | null
) {
  if (!value) {
    return "-";
  }

  return labels[value] ?? value;
}

function ratingLabel(value: number | null | undefined, text: FeedbackPageText) {
  if (value === 1) return text.ratingLabels.positive;
  if (value === 0) return text.ratingLabels.neutral;
  if (value === -1) return text.ratingLabels.negative;
  return "-";
}

function dateInputToUtcStart(value: string): string | undefined {
  return value ? new Date(`${value}T00:00:00.000Z`).toISOString() : undefined;
}

function dateInputToUtcEnd(value: string): string | undefined {
  return value ? new Date(`${value}T23:59:59.999Z`).toISOString() : undefined;
}

function FeedbackRow({
  item,
  text,
  locale,
  onOpen,
}: {
  item: AdminFeedbackListItem;
  text: FeedbackPageText;
  locale: Locale;
  onOpen: (id: string) => void;
}) {
  return (
    <tr>
      <td>{formatDateTime(item.createdAtUtc, locale)}</td>
      <td className={styles.mono}>{shortId(item.userId)}</td>
      <td>{optionLabel(text.typeOptions, item.type)}</td>
      <td>{item.category}</td>
      <td>{ratingLabel(item.rating, text)}</td>
      <td>{item.templateTitle ?? shortId(item.templateId)}</td>
      <td>{item.platform ?? "-"}</td>
      <td>
        <AdminStatusBadge color={toneForStatus(item.status)}>
          {optionLabel(text.statusOptions, item.status)}
        </AdminStatusBadge>
      </td>
      <td>
        <AdminStatusBadge color={toneForPriority(item.priority)}>
          {optionLabel(text.priorityOptions, item.priority)}
        </AdminStatusBadge>
      </td>
      <td>
        {item.previewUrl ? (
          <TemplateSecureMedia
            className={styles.preview}
            url={item.previewUrl}
            kind="image"
            alt=""
            ariaHidden
            width={72}
            height={72}
            logContext={{ surface: "feedback-list-preview" }}
          />
        ) : (
          "-"
        )}
      </td>
      <td className={styles.message}>
        {item.message ? sanitizeSensitiveText(item.message, 180) : "-"}
      </td>
      <td>
        <button className={styles.button} type="button" onClick={() => onOpen(item.id)}>
          {text.show}
        </button>
      </td>
    </tr>
  );
}

function DetailsPanel({
  details,
  isDetailsFetching,
  locale,
}: {
  details: AdminFeedbackDetails;
  isDetailsFetching: boolean;
  locale: Locale;
}) {
  const text = getFeedbackPageText(locale);
  const queryClient = useQueryClient();
  const [status, setStatus] = useState((details.status as FeedbackStatus) || "New");
  const [priority, setPriority] = useState((details.priority as FeedbackPriority) || "Low");
  const [adminNote, setAdminNote] = useState(details.adminNote ?? "");
  const updateMutation = useMutation({
    mutationFn: () => updateAdminFeedback(details.id, { status, priority, adminNote }),
    onSuccess: async () => {
      await Promise.allSettled([
        queryClient.invalidateQueries({ queryKey: adminQueryKeys.feedbackDetails(details.id) }),
        queryClient.invalidateQueries({ queryKey: ["admin", "feedback"] }),
      ]);
    },
  });
  const refundMutation = useMutation({
    mutationFn: () =>
      refundAdminFeedbackCredits(details.id, {
        amount: details.generation?.creditsCharged,
        reason: `Feedback refund ${details.id}`,
      }),
    onSuccess: async () => {
      await Promise.allSettled([
        queryClient.invalidateQueries({ queryKey: adminQueryKeys.feedbackDetails(details.id) }),
        queryClient.invalidateQueries({ queryKey: ["admin", "feedback"] }),
      ]);
    },
  });
  const isFeedbackActionLocked =
    updateMutation.isPending || refundMutation.isPending || isDetailsFetching;
  const isFeedbackDraftDirty =
    status !== ((details.status as FeedbackStatus) || "New") ||
    priority !== ((details.priority as FeedbackPriority) || "Low") ||
    adminNote !== (details.adminNote ?? "");
  const isSaveFeedbackDisabled = !isFeedbackDraftDirty || isFeedbackActionLocked;
  const isRefundFeedbackDisabled = !details.canRefund || isFeedbackActionLocked;
  const requestSaveFeedback = () => {
    if (isSaveFeedbackDisabled) {
      return;
    }

    updateMutation.mutate();
  };
  const requestRefundFeedback = () => {
    if (isRefundFeedbackDisabled) {
      return;
    }

    refundMutation.mutate();
  };
  const userQuery = useQuery({
    queryKey: details.userId
      ? adminQueryKeys.userDetail(details.userId)
      : adminQueryKeys.userDetailDisabled,
    queryFn: ({ signal }) => fetchAdminUser(details.userId!, signal),
    enabled: Boolean(details.userId),
  });
  const userAnalyticsQuery = useQuery({
    queryKey: details.userId
      ? adminQueryKeys.userAnalytics(details.userId)
      : adminQueryKeys.userAnalyticsDisabled,
    queryFn: ({ signal }) => fetchAdminUserAnalytics(details.userId!, signal),
    enabled: Boolean(details.userId),
  });
  const userPlan =
    details.userPlan ??
    (userQuery.isLoading
      ? text.userContextLoading
      : userQuery.data
        ? userQuery.data.isPremium
          ? text.userPlanPremium
          : text.userPlanFree
        : "-");
  const userCredits =
    details.userCredits ??
    (userAnalyticsQuery.isLoading
      ? text.userContextLoading
      : (userAnalyticsQuery.data?.summary.walletBalance ?? "-"));
  const hasUserContextError = Boolean(details.userId) && (userQuery.isError || userAnalyticsQuery.isError);
  const isUserContextFetching = userQuery.isFetching || userAnalyticsQuery.isFetching;

  return (
    <AdminCard title={text.details}>
      <div className={styles.details} aria-busy={isDetailsFetching ? "true" : undefined}>
        <div className={styles.detailsMain}>
          <div className={styles.detailGrid}>
            <Detail label={text.type} value={optionLabel(text.typeOptions, details.type)} />
            <Detail label={text.category} value={details.category} />
            <Detail label={text.rating} value={ratingLabel(details.rating, text)} />
            <Detail label={text.user} value={userQuery.data?.email ?? shortId(details.userId)} />
            <Detail label={text.planCredits} value={`${userPlan} / ${userCredits}`} />
            <Detail label={text.source} value={details.sourceScreen} />
            <Detail label={text.platform} value={details.platform ?? "-"} />
            <Detail label={text.app} value={details.appVersion ?? "-"} />
            <Detail label={text.device} value={details.deviceModel ?? "-"} />
            <Detail
              label={text.provider}
              value={details.providerName ?? details.generation?.providerName ?? "-"}
            />
            <Detail
              label={text.errorCode}
              value={details.errorCode ?? details.generation?.errorCode ?? "-"}
            />
            <Detail label={text.message} value={details.message ?? "-"} />
            <Detail label={text.date} value={formatDateTime(details.createdAtUtc, locale)} />
          </div>
          {hasUserContextError ? (
            <AdminStateCard
              tone="warning"
              title={text.userContextErrorTitle}
              description={getAdminErrorMessage(
                userQuery.error ?? userAnalyticsQuery.error,
                text.userContextErrorDescription
              )}
              action={
                <button
                  className={styles.button}
                  type="button"
                  disabled={isUserContextFetching}
                  onClick={() => {
                    void Promise.allSettled([
                      userQuery.refetch(),
                      userAnalyticsQuery.refetch(),
                    ]);
                  }}
                >
                  {text.retry}
                </button>
              }
            />
          ) : null}
        </div>
        <div>
          {details.generation ? (
            <>
              <div className={styles.previewGrid}>
                {details.generation.inputPreviewUrl ? (
                  <TemplateSecureMedia
                    className={styles.largePreview}
                    url={details.generation.inputPreviewUrl}
                    kind="image"
                    alt={text.input}
                    width={512}
                    height={512}
                    logContext={{
                      surface: "feedback-generation-input-preview",
                      templateId: details.generation.templateId,
                    }}
                  />
                ) : null}
                {details.generation.resultPreviewUrl ? (
                  <TemplateSecureMedia
                    className={styles.largePreview}
                    url={details.generation.resultPreviewUrl}
                    kind="image"
                    alt={text.result}
                    width={512}
                    height={512}
                    logContext={{
                      surface: "feedback-generation-result-preview",
                      templateId: details.generation.templateId,
                    }}
                  />
                ) : null}
              </div>
              <div className={styles.detailItem}>
                <span>{text.generation}</span>
                <strong>
                  {shortId(details.generation.generationId)} / {details.generation.creditsCharged}{" "}
                  {text.credits}
                </strong>
              </div>
            </>
          ) : null}
          <div className={styles.field}>
            <label className={styles.label}>{text.status}</label>
            <select
              className={styles.select}
              value={status}
              disabled={isFeedbackActionLocked}
              onChange={(event) => setStatus(event.target.value as FeedbackStatus)}
            >
              {statusOptions
                .filter((x) => x !== "All")
                .map((option) => (
                  <option key={option} value={option}>
                    {text.statusOptions[option]}
                  </option>
                ))}
            </select>
          </div>
          <div className={styles.field}>
            <label className={styles.label}>{text.priority}</label>
            <select
              className={styles.select}
              value={priority}
              disabled={isFeedbackActionLocked}
              onChange={(event) => setPriority(event.target.value as FeedbackPriority)}
            >
              {priorityOptions
                .filter((x) => x !== "All")
                .map((option) => (
                  <option key={option} value={option}>
                    {text.priorityOptions[option]}
                  </option>
                ))}
            </select>
          </div>
          <div className={styles.field}>
            <label className={styles.label}>{text.note}</label>
            <textarea
              className={styles.textarea}
              value={adminNote}
              maxLength={ADMIN_FEEDBACK_ADMIN_NOTE_MAX_LENGTH}
              disabled={isFeedbackActionLocked}
              onChange={(event) =>
                setAdminNote(event.target.value.slice(0, ADMIN_FEEDBACK_ADMIN_NOTE_MAX_LENGTH))
              }
            />
          </div>
          {updateMutation.isError ? (
            <AdminStateCard
              tone="warning"
              title={getAdminErrorMessage(updateMutation.error, text.saveError)}
            />
          ) : null}
          {refundMutation.isError ? (
            <AdminStateCard
              tone="warning"
              title={getAdminErrorMessage(refundMutation.error, text.refundError)}
            />
          ) : null}
          <div className={styles.actions}>
            <button
              className={styles.button}
              type="button"
              disabled={isSaveFeedbackDisabled}
              onClick={requestSaveFeedback}
            >
              {text.save}
            </button>
            <button
              className={`${styles.button} ${details.canRefund ? styles.danger : ""}`}
              type="button"
              disabled={isRefundFeedbackDisabled}
              onClick={requestRefundFeedback}
            >
              {details.refund ? text.refunded : text.refund}
            </button>
          </div>
        </div>
      </div>
    </AdminCard>
  );
}

function Detail({ label, value }: { label: string; value: string }) {
  return (
    <div className={styles.detailItem}>
      <span>{label}</span>
      <strong>{sanitizeSensitiveText(value, 220)}</strong>
    </div>
  );
}

export function FeedbackPage({ locale }: FeedbackPageProps) {
  const text = getFeedbackPageText(locale);
  const router = useRouter();
  const session = useAuthSession();
  const canView =
    session?.user.roles.some((role) => role === "Admin" || role === "Moderator") ?? false;
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
  const visibleFeedbackItems = useMemo(
    () => visiblePageData?.items ?? [],
    [visiblePageData]
  );
  const isFeedbackRefreshing = feedbackQuery.isFetching && feedbackQuery.isPlaceholderData;
  const isFeedbackFetching = feedbackQuery.isFetching;
  const areFeedbackFiltersLocked = isFeedbackFetching;
  const isDetailsFetching = detailsQuery.isFetching;
  const visibleFeedbackIds = useMemo(
    () => new Set(visibleFeedbackItems.map((item) => item.id)),
    [visibleFeedbackItems]
  );

  useEffect(() => {
    if (!visiblePageData || !selectedId || visibleFeedbackIds.has(selectedId)) {
      return;
    }

    queueMicrotask(() => setSelectedId(null));
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
              {visiblePageData ? `${visibleFeedbackItems.length} / ${visiblePageData.totalCount}` : ""}
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
          locale={locale}
        />
      ) : null}
    </main>
  );
}

function Field({
  label,
  value,
  type = "text",
  maxLength,
  disabled = false,
  onChange,
}: {
  label: string;
  value: string;
  type?: string;
  maxLength?: number;
  disabled?: boolean;
  onChange: (value: string) => void;
}) {
  return (
    <label className={styles.field}>
      <span className={styles.label}>{label}</span>
      <input
        className={styles.input}
        type={type}
        value={value}
        maxLength={maxLength}
        disabled={disabled}
        onChange={(event) =>
          onChange(
            typeof maxLength === "number"
              ? event.target.value.slice(0, maxLength)
              : event.target.value
          )
        }
      />
    </label>
  );
}

function Select({
  label,
  value,
  options,
  optionLabels,
  disabled = false,
  onChange,
}: {
  label: string;
  value: string;
  options: readonly string[];
  optionLabels?: Record<string, string>;
  disabled?: boolean;
  onChange: (value: string) => void;
}) {
  return (
    <label className={styles.field}>
      <span className={styles.label}>{label}</span>
      <select
        className={styles.select}
        value={value}
        disabled={disabled}
        onChange={(event) => onChange(event.target.value)}
      >
        {options.map((option) => (
          <option key={option} value={option}>
            {optionLabels?.[option] ?? option}
          </option>
        ))}
      </select>
    </label>
  );
}
