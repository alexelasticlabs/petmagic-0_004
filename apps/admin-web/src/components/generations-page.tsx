"use client";

import { keepPreviousData, useQuery } from "@tanstack/react-query";
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
import styles from "@/components/generations-page.module.css";
import { getAdminErrorMessage } from "@/lib/admin-error-message";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
  fetchAdminTemplateGenerations,
  normalizeAdminTemplateGenerationsQuery,
  type AdminGenerationStatus,
  type AdminTemplateGenerationListItem,
} from "@/lib/api-client";
import { formatDateTime } from "@/lib/format-date-time";
import { type Locale } from "@/lib/i18n";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

type GenerationsPageProps = {
  locale: Locale;
};

type StatusFilter = AdminGenerationStatus | "All";

const PAGE_SIZE = 25;

const statusOptions: StatusFilter[] = [
  "All",
  "Pending",
  "Running",
  "Completed",
  "Failed",
  "Cancelled",
  "Retrying",
];

function getCopy(locale: Locale) {
  const isRu = locale === "ru";
  return {
    eyebrow: isRu ? "Operations" : "Operations",
    title: isRu ? "Генерации" : "Generations",
    description: isRu
      ? "Серверный список generation jobs без signed URLs, provider payloads и API keys."
      : "Server-backed generation jobs without signed URLs, provider payloads, or API keys.",
    total: isRu ? "Всего jobs" : "Total jobs",
    pending: isRu ? "Ожидает" : "Pending",
    running: isRu ? "В работе" : "Running",
    completed: isRu ? "Завершена" : "Completed",
    failed: isRu ? "Ошибка" : "Failed",
    cancelled: isRu ? "Отменена" : "Cancelled",
    retrying: isRu ? "Повторяется" : "Retrying",
    currentPageScope: isRu ? "Текущая страница" : "Current page",
    filtersTitle: isRu ? "Фильтры" : "Filters",
    filtersDescription: isRu
      ? "Поиск и фильтры выполняются на backend; устаревшие запросы отменяются."
      : "Search and filters run on the backend; stale requests are aborted.",
    searchLabel: isRu ? "Job id" : "Job id",
    searchPlaceholder: isRu ? "Поиск по generation id" : "Search by generation id",
    statusLabel: isRu ? "Статус" : "Status",
    providerLabel: isRu ? "Провайдер" : "Provider",
    providerPlaceholder: isRu ? "fal, openai..." : "fal, openai...",
    userLabel: isRu ? "User id" : "User id",
    userPlaceholder: isRu ? "Фильтр по user id" : "Filter by user id",
    tableTitle: isRu ? "История генераций" : "Generation history",
    emptyTitle: isRu ? "Генераций не найдено" : "No generations found",
    emptyDescription: isRu
      ? "Измените фильтры или дождитесь новых generation jobs."
      : "Adjust filters or wait for new generation jobs.",
    loadingTitle: isRu ? "Загрузка генераций" : "Loading generations",
    errorTitle: isRu ? "Не удалось загрузить генерации" : "Failed to load generations",
    retry: isRu ? "Повторить" : "Retry",
    job: isRu ? "Job" : "Job",
    user: isRu ? "Пользователь" : "User",
    template: isRu ? "Шаблон" : "Template",
    status: isRu ? "Статус" : "Status",
    provider: isRu ? "Провайдер" : "Provider",
    cost: isRu ? "Стоимость" : "Cost",
    attempts: isRu ? "Попытки" : "Attempts",
    failure: isRu ? "Ошибка" : "Failure",
    created: isRu ? "Создана" : "Created",
    completedAt: isRu ? "Завершена" : "Completed",
    noFailure: isRu ? "Нет" : "None",
    allStatuses: isRu ? "Все" : "All",
    previous: isRu ? "Назад" : "Previous",
    next: isRu ? "Вперед" : "Next",
    page: isRu ? "Страница" : "Page",
    of: isRu ? "из" : "of",
    unsupportedActions: isRu
      ? "Retry/cancel не показаны: backend пока не предоставляет эти операции."
      : "Retry/cancel are hidden because the backend does not expose those operations yet.",
    templateImage: isRu ? "Изображение" : "Image",
    templateVideo: isRu ? "Видео" : "Video",
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

function getStatusTone(status: AdminGenerationStatus) {
  if (status === "Completed") {
    return "#22c55e";
  }

  if (status === "Failed") {
    return "#ef4444";
  }

  if (status === "Cancelled") {
    return "#64748b";
  }

  if (status === "Retrying") {
    return "#a855f7";
  }

  if (status === "Running") {
    return "#3b82f6";
  }

  return "#f59e0b";
}

function formatShortId(value: string) {
  const safeValue = sanitizeSensitiveText(value, 32);
  return safeValue.length > 12 ? `${safeValue.slice(0, 8)}...${safeValue.slice(-4)}` : safeValue;
}

function formatSafeText(value: string | null | undefined, fallback = "-") {
  const trimmed = value?.trim();
  return trimmed ? sanitizeSensitiveText(trimmed, 160) : fallback;
}

function formatMoney(value?: number | null) {
  if (typeof value !== "number") {
    return "-";
  }

  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
    maximumFractionDigits: 4,
  }).format(value);
}

function formatStatus(status: StatusFilter, text: ReturnType<typeof getCopy>) {
  if (status === "All") return text.allStatuses;
  if (status === "Pending") return text.pending;
  if (status === "Running") return text.running;
  if (status === "Completed") return text.completed;
  if (status === "Failed") return text.failed;
  if (status === "Cancelled") return text.cancelled;
  return text.retrying;
}

function formatTemplateType(
  templateType: AdminTemplateGenerationListItem["templateType"],
  text: ReturnType<typeof getCopy>
) {
  return templateType === "Image" ? text.templateImage : text.templateVideo;
}

function GenerationRow({
  item,
  locale,
  text,
}: {
  item: AdminTemplateGenerationListItem;
  locale: Locale;
  text: ReturnType<typeof getCopy>;
}) {
  const failureText = formatSafeText(item.failureCode, text.noFailure);
  const providerText = formatSafeText(item.provider);
  const modelText = formatSafeText(item.model, "");
  const templateTitle = formatSafeText(item.templateTitle);
  const generationIdText = formatShortId(item.generationId);
  const userIdText = formatShortId(item.userId);
  const templateIdText = formatShortId(item.templateId);

  return (
    <tr>
      <td className={adminTableStyles.mono}>
        <span className={styles.jobId} title={generationIdText} aria-label={generationIdText}>
          {generationIdText}
        </span>
      </td>
      <td className={adminTableStyles.mono}>
        <span className={styles.jobId} title={userIdText} aria-label={userIdText}>
          {userIdText}
        </span>
      </td>
      <td>
        <span className={styles.templateTitle}>
          <strong>{templateTitle}</strong>
          <span>
            {formatTemplateType(item.templateType, text)} / {templateIdText}
          </span>
        </span>
      </td>
      <td>
        <AdminStatusBadge color={getStatusTone(item.status)}>
          {formatStatus(item.status, text)}
        </AdminStatusBadge>
      </td>
      <td>
        {providerText !== "-" ? <AdminBadge tone="info">{providerText}</AdminBadge> : "-"}
        {modelText ? <div className={adminTableStyles.mono}>{modelText}</div> : null}
      </td>
      <td className={adminTableStyles.numeric}>{item.tokenCost}</td>
      <td className={adminTableStyles.numeric}>{item.attemptCount}</td>
      <td className={adminTableStyles.numeric}>{formatMoney(item.providerCostUsd)}</td>
      <td>
        <span className={styles.failure}>{failureText}</span>
      </td>
      <td>{formatDateTime(item.createdAtUtc, locale)}</td>
      <td>{item.completedAtUtc ? formatDateTime(item.completedAtUtc, locale) : "-"}</td>
    </tr>
  );
}

export function GenerationsPage({ locale }: GenerationsPageProps) {
  const text = getCopy(locale);
  const [pageIndex, setPageIndex] = useState(0);
  const [status, setStatus] = useState<StatusFilter>("All");
  const [provider, setProvider] = useState("");
  const [user, setUser] = useState("");
  const [search, setSearch] = useState("");

  const debouncedProvider = useDebouncedValue(provider, 350);
  const debouncedUser = useDebouncedValue(user, 350);
  const debouncedSearch = useDebouncedValue(search, 350);

  const query = useMemo(
    () =>
      normalizeAdminTemplateGenerationsQuery({
        status,
        provider: debouncedProvider,
        user: debouncedUser,
        search: debouncedSearch,
        skip: pageIndex * PAGE_SIZE,
        take: PAGE_SIZE,
      }),
    [debouncedProvider, debouncedSearch, debouncedUser, pageIndex, status]
  );

  const generationsQuery = useQuery({
    queryKey: adminQueryKeys.templateGenerations(query),
    queryFn: ({ signal }) => fetchAdminTemplateGenerations(query, signal),
    placeholderData: keepPreviousData,
  });

  const page = generationsQuery.data;
  const items = page?.items ?? [];
  const totalCount = page?.totalCount ?? 0;
  const pageCount = Math.max(1, Math.ceil(totalCount / PAGE_SIZE));
  const pendingCount = items.filter((item) => item.status === "Pending").length;
  const runningCount = items.filter((item) => item.status === "Running").length;
  const failedCount = items.filter((item) => item.status === "Failed").length;
  const cancelledCount = items.filter((item) => item.status === "Cancelled").length;
  const retryingCount = items.filter((item) => item.status === "Retrying").length;

  return (
    <section className={styles.page}>
      <AdminPageHero
        eyebrow={text.eyebrow}
        title={text.title}
        description={text.description}
        badge={<AdminBadge tone="danger">Admin only</AdminBadge>}
        metaItems={[text.unsupportedActions]}
      />

      <div className={styles.kpiGrid}>
        <AdminKpiCard label={text.total} value={String(totalCount)} tone="primary" />
        <AdminKpiCard
          label={text.pending}
          value={String(pendingCount)}
          hint={text.currentPageScope}
          tone="warning"
        />
        <AdminKpiCard
          label={text.running}
          value={String(runningCount)}
          hint={text.currentPageScope}
          tone="info"
        />
        <AdminKpiCard
          label={text.failed}
          value={String(failedCount)}
          hint={text.currentPageScope}
          tone="danger"
        />
        <AdminKpiCard
          label={text.retrying}
          value={String(retryingCount)}
          hint={text.currentPageScope}
          tone="warning"
        />
        <AdminKpiCard
          label={text.cancelled}
          value={String(cancelledCount)}
          hint={text.currentPageScope}
          tone="neutral"
        />
      </div>

      <AdminCard title={text.filtersTitle} description={text.filtersDescription}>
        <div className={styles.filters}>
          <label className={styles.field}>
            <span className={styles.label}>{text.searchLabel}</span>
            <input
              className={styles.input}
              value={search}
              onChange={(event) => {
                setSearch(event.target.value);
                setPageIndex(0);
              }}
              maxLength={80}
              placeholder={text.searchPlaceholder}
            />
          </label>
          <label className={styles.field}>
            <span className={styles.label}>{text.statusLabel}</span>
            <select
              className={styles.select}
              value={status}
              onChange={(event) => {
                setStatus(event.target.value as StatusFilter);
                setPageIndex(0);
              }}
            >
              {statusOptions.map((option) => (
                <option key={option} value={option}>
                  {formatStatus(option, text)}
                </option>
              ))}
            </select>
          </label>
          <label className={styles.field}>
            <span className={styles.label}>{text.providerLabel}</span>
            <input
              className={styles.input}
              value={provider}
              onChange={(event) => {
                setProvider(event.target.value);
                setPageIndex(0);
              }}
              maxLength={40}
              placeholder={text.providerPlaceholder}
            />
          </label>
          <label className={styles.field}>
            <span className={styles.label}>{text.userLabel}</span>
            <input
              className={styles.input}
              value={user}
              onChange={(event) => {
                setUser(event.target.value);
                setPageIndex(0);
              }}
              maxLength={80}
              placeholder={text.userPlaceholder}
            />
          </label>
        </div>
      </AdminCard>

      {generationsQuery.isLoading ? (
        <AdminStateCard title={text.loadingTitle} />
      ) : generationsQuery.isError ? (
        <AdminStateCard
          title={text.errorTitle}
          description={getAdminErrorMessage(generationsQuery.error, text.errorTitle)}
          tone="danger"
          action={
            <button
              type="button"
              className={styles.button}
              disabled={generationsQuery.isFetching}
              onClick={() => void generationsQuery.refetch().catch(() => undefined)}
            >
              {text.retry}
            </button>
          }
        />
      ) : items.length === 0 ? (
        <AdminStateCard title={text.emptyTitle} description={text.emptyDescription} />
      ) : (
        <AdminCard
          title={
            <span className={styles.tableHeader}>
              <span className={styles.tableTitle}>{text.tableTitle}</span>
              <span className={styles.tableMeta}>
                {totalCount} total / {formatDateTime(page?.generatedAtUtc, locale)}
              </span>
            </span>
          }
        >
          <div
            className={adminTableStyles.tableWrap}
            aria-busy={generationsQuery.isFetching ? "true" : undefined}
          >
            <table className={adminTableStyles.table}>
              <thead>
                <tr>
                  <th>{text.job}</th>
                  <th>{text.user}</th>
                  <th>{text.template}</th>
                  <th>{text.status}</th>
                  <th>{text.provider}</th>
                  <th>{text.cost}</th>
                  <th>{text.attempts}</th>
                  <th>USD</th>
                  <th>{text.failure}</th>
                  <th>{text.created}</th>
                  <th>{text.completedAt}</th>
                </tr>
              </thead>
              <tbody>
                {items.map((item) => (
                  <GenerationRow key={item.generationId} item={item} locale={locale} text={text} />
                ))}
              </tbody>
            </table>
          </div>
          <div className={styles.pager}>
            <span className={styles.pageInfo}>
              {text.page} {pageIndex + 1} {text.of} {pageCount}
            </span>
            <button
              type="button"
              className={styles.button}
              disabled={pageIndex === 0 || generationsQuery.isFetching}
              onClick={() => setPageIndex((value) => Math.max(0, value - 1))}
            >
              {text.previous}
            </button>
            <button
              type="button"
              className={styles.button}
              disabled={!page?.hasMore || generationsQuery.isFetching}
              onClick={() => setPageIndex((value) => value + 1)}
            >
              {text.next}
            </button>
          </div>
        </AdminCard>
      )}
    </section>
  );
}
