"use client";

import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";

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
import { getAdminErrorMessage } from "@/lib/admin-error-message";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
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

function copy(locale: Locale) {
  const isRu = locale === "ru";
  return {
    eyebrow: isRu ? "Качество" : "Quality",
    title: "Feedback",
    description: isRu
      ? "Отзывы по генерациям, ошибкам, оплате и предложениям с управлением статусами."
      : "Generation, failure, payment, and general feedback with status management.",
    filters: isRu ? "Фильтры" : "Filters",
    table: isRu ? "Заявки" : "Feedback items",
    details: isRu ? "Детали" : "Details",
    status: isRu ? "Статус" : "Status",
    priority: isRu ? "Приоритет" : "Priority",
    type: isRu ? "Тип" : "Type",
    category: isRu ? "Категория" : "Category",
    platform: isRu ? "Платформа" : "Platform",
    templateId: isRu ? "Template id" : "Template id",
    userId: isRu ? "User id" : "User id",
    from: isRu ? "From" : "From",
    to: isRu ? "To" : "To",
    user: isRu ? "Пользователь" : "User",
    date: isRu ? "Дата" : "Date",
    rating: isRu ? "Рейтинг" : "Rating",
    template: isRu ? "Шаблон" : "Template",
    message: isRu ? "Сообщение" : "Message",
    preview: isRu ? "Превью" : "Preview",
    show: isRu ? "Открыть" : "Open",
    empty: isRu ? "Feedback не найден" : "No feedback found",
    loading: isRu ? "Загрузка feedback" : "Loading feedback",
    error: isRu ? "Не удалось загрузить feedback" : "Failed to load feedback",
    detailsLoading: isRu ? "Загрузка деталей feedback" : "Loading feedback details",
    detailsError: isRu ? "Не удалось загрузить детали feedback" : "Failed to load feedback details",
    retry: isRu ? "Повторить" : "Retry",
    save: isRu ? "Сохранить" : "Save",
    saveError: isRu ? "Не удалось сохранить изменения feedback." : "Failed to save feedback changes.",
    refund: isRu ? "Refund credits" : "Refund credits",
    refunded: isRu ? "Refund issued" : "Refund issued",
    refundError: isRu ? "Не удалось вернуть кредиты." : "Failed to refund credits.",
    note: isRu ? "Admin note" : "Admin note",
    generation: isRu ? "Генерация" : "Generation",
    input: isRu ? "Input" : "Input",
    result: isRu ? "Result" : "Result",
    technical: isRu ? "Технический контекст" : "Technical context",
    all: isRu ? "Все" : "All",
    previous: isRu ? "Назад" : "Previous",
    next: isRu ? "Вперёд" : "Next",
    previousPageLabel: isRu ? "Предыдущая страница feedback" : "Previous feedback page",
    nextPageLabel: isRu ? "Следующая страница feedback" : "Next feedback page",
    userContextLoading: isRu ? "Загрузка..." : "Loading...",
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

function ratingLabel(value?: number | null) {
  if (value === 1) return "Good";
  if (value === 0) return "Okay";
  if (value === -1) return "Bad";
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
  text: ReturnType<typeof copy>;
  locale: Locale;
  onOpen: (id: string) => void;
}) {
  return (
    <tr>
      <td>{formatDateTime(item.createdAtUtc, locale)}</td>
      <td className={styles.mono}>{shortId(item.userId)}</td>
      <td>{item.type}</td>
      <td>{item.category}</td>
      <td>{ratingLabel(item.rating)}</td>
      <td>{item.templateTitle ?? shortId(item.templateId)}</td>
      <td>{item.platform ?? "-"}</td>
      <td>
        <AdminStatusBadge color={toneForStatus(item.status)}>{item.status}</AdminStatusBadge>
      </td>
      <td>
        <AdminStatusBadge color={toneForPriority(item.priority)}>{item.priority}</AdminStatusBadge>
      </td>
      <td>
        {item.previewUrl ? <img className={styles.preview} src={item.previewUrl} alt="" /> : "-"}
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

function DetailsPanel({ details, locale }: { details: AdminFeedbackDetails; locale: Locale }) {
  const text = copy(locale);
  const queryClient = useQueryClient();
  const [status, setStatus] = useState((details.status as FeedbackStatus) || "New");
  const [priority, setPriority] = useState((details.priority as FeedbackPriority) || "Low");
  const [adminNote, setAdminNote] = useState(details.adminNote ?? "");
  const updateMutation = useMutation({
    mutationFn: () => updateAdminFeedback(details.id, { status, priority, adminNote }),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: adminQueryKeys.feedbackDetails(details.id) });
      await queryClient.invalidateQueries({ queryKey: ["admin", "feedback"] });
    },
  });
  const refundMutation = useMutation({
    mutationFn: () =>
      refundAdminFeedbackCredits(details.id, {
        amount: details.generation?.creditsCharged,
        reason: `Feedback refund ${details.id}`,
      }),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: adminQueryKeys.feedbackDetails(details.id) });
      await queryClient.invalidateQueries({ queryKey: ["admin", "feedback"] });
    },
  });
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
          ? "premium"
          : "free"
        : "-");
  const userCredits =
    details.userCredits ??
    (userAnalyticsQuery.isLoading
      ? text.userContextLoading
      : (userAnalyticsQuery.data?.summary.walletBalance ?? "-"));

  return (
    <AdminCard title={text.details}>
      <div className={styles.details}>
        <div className={styles.detailGrid}>
          <Detail label={text.type} value={details.type} />
          <Detail label={text.category} value={details.category} />
          <Detail label={text.rating} value={ratingLabel(details.rating)} />
          <Detail label={text.user} value={userQuery.data?.email ?? shortId(details.userId)} />
          <Detail label="Plan / credits" value={`${userPlan} / ${userCredits}`} />
          <Detail label="Source" value={details.sourceScreen} />
          <Detail label={text.platform} value={details.platform ?? "-"} />
          <Detail label="App" value={details.appVersion ?? "-"} />
          <Detail label="Device" value={details.deviceModel ?? "-"} />
          <Detail
            label="Provider"
            value={details.providerName ?? details.generation?.providerName ?? "-"}
          />
          <Detail label="Error" value={details.errorCode ?? details.generation?.errorCode ?? "-"} />
          <Detail label={text.message} value={details.message ?? "-"} />
          <Detail label={text.date} value={formatDateTime(details.createdAtUtc, locale)} />
        </div>
        <div>
          {details.generation ? (
            <>
              <div className={styles.previewGrid}>
                {details.generation.inputPreviewUrl ? (
                  <img
                    className={styles.largePreview}
                    src={details.generation.inputPreviewUrl}
                    alt={text.input}
                  />
                ) : null}
                {details.generation.resultPreviewUrl ? (
                  <img
                    className={styles.largePreview}
                    src={details.generation.resultPreviewUrl}
                    alt={text.result}
                  />
                ) : null}
              </div>
              <div className={styles.detailItem}>
                <span>{text.generation}</span>
                <strong>
                  {shortId(details.generation.generationId)} / {details.generation.creditsCharged}{" "}
                  credits
                </strong>
              </div>
            </>
          ) : null}
          <div className={styles.field}>
            <label className={styles.label}>{text.status}</label>
            <select
              className={styles.select}
              value={status}
              onChange={(event) => setStatus(event.target.value as FeedbackStatus)}
            >
              {statusOptions
                .filter((x) => x !== "All")
                .map((option) => (
                  <option key={option}>{option}</option>
                ))}
            </select>
          </div>
          <div className={styles.field}>
            <label className={styles.label}>{text.priority}</label>
            <select
              className={styles.select}
              value={priority}
              onChange={(event) => setPriority(event.target.value as FeedbackPriority)}
            >
              {priorityOptions
                .filter((x) => x !== "All")
                .map((option) => (
                  <option key={option}>{option}</option>
                ))}
            </select>
          </div>
          <div className={styles.field}>
            <label className={styles.label}>{text.note}</label>
            <textarea
              className={styles.textarea}
              value={adminNote}
              onChange={(event) => setAdminNote(event.target.value)}
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
              disabled={updateMutation.isPending || refundMutation.isPending}
              onClick={() => updateMutation.mutate()}
            >
              {text.save}
            </button>
            <button
              className={`${styles.button} ${details.canRefund ? styles.danger : ""}`}
              type="button"
              disabled={!details.canRefund || updateMutation.isPending || refundMutation.isPending}
              onClick={() => refundMutation.mutate()}
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
  const text = copy(locale);
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
  const isFeedbackFetching = feedbackQuery.isFetching;
  const isDetailsFetching = detailsQuery.isFetching;

  return (
    <main className={styles.page}>
      <AdminPageHero
        eyebrow={text.eyebrow}
        title={text.title}
        description={text.description}
        badge={<AdminBadge tone="info">{pageData?.totalCount ?? 0}</AdminBadge>}
      />
      <AdminCard title={text.filters}>
        <div className={styles.filters}>
          <Select
            label={text.status}
            value={status}
            options={statusOptions}
            onChange={(value) => {
              setStatus(value as typeof status);
              setPage(0);
            }}
          />
          <Select
            label={text.priority}
            value={priority}
            options={priorityOptions}
            onChange={(value) => {
              setPriority(value as typeof priority);
              setPage(0);
            }}
          />
          <Select
            label={text.type}
            value={type}
            options={typeOptions}
            onChange={(value) => {
              setType(value as typeof type);
              setPage(0);
            }}
          />
          <Field
            label={text.category}
            value={category}
            onChange={(value) => {
              setCategory(value);
              setPage(0);
            }}
          />
          <Field
            label={text.platform}
            value={platform}
            onChange={(value) => {
              setPlatform(value);
              setPage(0);
            }}
          />
          <Field
            label={text.templateId}
            value={templateId}
            onChange={(value) => {
              setTemplateId(value);
              setPage(0);
            }}
          />
          <Field
            label={text.userId}
            value={userId}
            onChange={(value) => {
              setUserId(value);
              setPage(0);
            }}
          />
          <Field
            label={text.from}
            value={fromUtc}
            type="date"
            onChange={(value) => {
              setFromUtc(value);
              setPage(0);
            }}
          />
          <Field
            label={text.to}
            value={toUtc}
            type="date"
            onChange={(value) => {
              setToUtc(value);
              setPage(0);
            }}
          />
        </div>
      </AdminCard>
      <AdminCard
        title={
          <div className={styles.tableHeader}>
            <h2 className={styles.tableTitle}>{text.table}</h2>
            <span className={styles.meta}>
              {pageData ? `${pageData.items.length} / ${pageData.totalCount}` : ""}
            </span>
          </div>
        }
      >
        {feedbackQuery.isLoading ? (
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
                onClick={() => {
                  void feedbackQuery.refetch().catch(() => undefined);
                }}
              >
                {text.retry}
              </button>
            }
          />
        ) : !pageData?.items.length ? (
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
                {pageData.items.map((item) => (
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
            className={styles.button}
            type="button"
            disabled={page === 0 || isFeedbackFetching}
            aria-label={text.previousPageLabel}
            onClick={() => setPage((current) => Math.max(0, current - 1))}
          >
            {text.previous}
          </button>
          <button
            className={styles.button}
            type="button"
            disabled={!pageData?.hasMore || isFeedbackFetching}
            aria-label={text.nextPageLabel}
            onClick={() => setPage((current) => current + 1)}
          >
            {text.next}
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
              onClick={() => {
                void detailsQuery.refetch().catch(() => undefined);
              }}
            >
              {text.retry}
            </button>
          }
        />
      ) : detailsQuery.data ? (
        <DetailsPanel key={detailsQuery.data.id} details={detailsQuery.data} locale={locale} />
      ) : null}
    </main>
  );
}

function Field({
  label,
  value,
  type = "text",
  onChange,
}: {
  label: string;
  value: string;
  type?: string;
  onChange: (value: string) => void;
}) {
  return (
    <label className={styles.field}>
      <span className={styles.label}>{label}</span>
      <input
        className={styles.input}
        type={type}
        value={value}
        onChange={(event) => onChange(event.target.value)}
      />
    </label>
  );
}

function Select({
  label,
  value,
  options,
  onChange,
}: {
  label: string;
  value: string;
  options: readonly string[];
  onChange: (value: string) => void;
}) {
  return (
    <label className={styles.field}>
      <span className={styles.label}>{label}</span>
      <select
        className={styles.select}
        value={value}
        onChange={(event) => onChange(event.target.value)}
      >
        {options.map((option) => (
          <option key={option} value={option}>
            {option}
          </option>
        ))}
      </select>
    </label>
  );
}
