"use client";

import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";

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
import styles from "@/components/generations-page.module.css";
import { TemplateSecureMedia } from "@/components/templates/template-secure-media";
import { getAdminErrorMessage } from "@/lib/admin-error-message";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
  fetchAdminFeedback,
  fetchAdminTemplateGenerationMetrics,
  fetchAdminTemplateGenerations,
  GENERATION_PROVIDER_FILTER_MAX_LENGTH,
  GENERATION_SEARCH_FILTER_MAX_LENGTH,
  GENERATION_USER_FILTER_MAX_LENGTH,
  grantAdminGenerationCleanDownload,
  normalizeAdminTemplateGenerationsQuery,
  useAuthSession,
  type AdminGenerationStatus,
  type AdminFeedbackListItem,
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
    eyebrow: isRu ? "Операции" : "Operations",
    title: isRu ? "Генерации" : "Generations",
    description: isRu
      ? "Операционный список заданий генерации, статусов, провайдеров, попыток и кодов ошибок."
      : "Operational list of generation jobs, statuses, providers, attempts, and failure codes.",
    adminOnly: isRu ? "Только Admin" : "Admin only",
    total: isRu ? "Всего заданий" : "Total jobs",
    pending: isRu ? "Ожидает" : "Pending",
    running: isRu ? "В работе" : "Running",
    completed: isRu ? "Завершена" : "Completed",
    failed: isRu ? "Ошибка" : "Failed",
    cancelled: isRu ? "Отменена" : "Cancelled",
    retrying: isRu ? "Повторяется" : "Retrying",
    allJobsScope: isRu ? "Все задания" : "All jobs",
    filtersTitle: isRu ? "Фильтры" : "Filters",
    filtersDescription: isRu
      ? "Сузьте список по job id, статусу, провайдеру или user id."
      : "Narrow the list by job id, status, provider, or user id.",
    searchLabel: isRu ? "Job id" : "Job id",
    searchPlaceholder: isRu ? "Поиск по generation id" : "Search by generation id",
    statusLabel: isRu ? "Статус" : "Status",
    providerLabel: isRu ? "Провайдер" : "Provider",
    providerPlaceholder: isRu ? "fal, openai..." : "fal, openai...",
    userLabel: isRu ? "User id" : "User id",
    userPlaceholder: isRu ? "Фильтр по user id" : "Filter by user id",
    tableTitle: isRu ? "История генераций" : "Generation history",
    details: isRu ? "Детали" : "Details",
    showDetails: isRu ? "Показать" : "Show",
    hideDetails: isRu ? "Скрыть" : "Hide",
    before: isRu ? "До" : "Before",
    after: isRu ? "После" : "After",
    compareReady: isRu ? "Доступно" : "Available",
    compareUnavailable: isRu ? "Недоступно" : "Unavailable",
    compareState: isRu ? "Сравнение" : "Compare",
    sourceType: isRu ? "Источник" : "Source type",
    inputAsset: isRu ? "Входной asset" : "Input asset",
    resultAsset: isRu ? "Результат asset" : "Result asset",
    pet: isRu ? "Питомец" : "Pet",
    petPhoto: isRu ? "Фото питомца" : "Pet photo",
    previewMissing: isRu ? "Превью недоступно" : "Preview unavailable",
    debugTitle: isRu ? "Отладка" : "Debug",
    emptyTitle: isRu ? "Генераций не найдено" : "No generations found",
    emptyDescription: isRu
      ? "Измените фильтры или дождитесь новых заданий генерации."
      : "Adjust filters or wait for new generation jobs.",
    loadingTitle: isRu ? "Загрузка генераций" : "Loading generations",
    errorTitle: isRu ? "Не удалось загрузить генерации" : "Failed to load generations",
    metricsErrorTitle: isRu
      ? "Сводка генераций временно недоступна"
      : "Generation summary temporarily unavailable",
    metricsErrorDescription: isRu
      ? "История генераций загружается отдельно; повторите запрос, чтобы обновить верхние счётчики."
      : "Generation history loads separately; retry to refresh the top counters.",
    retry: isRu ? "Повторить" : "Retry",
    job: isRu ? "Задание" : "Job",
    user: isRu ? "Пользователь" : "User",
    template: isRu ? "Шаблон" : "Template",
    status: isRu ? "Статус" : "Status",
    provider: isRu ? "Провайдер" : "Provider",
    cost: isRu ? "Стоимость" : "Cost",
    attempts: isRu ? "Попытки" : "Attempts",
    failure: isRu ? "Ошибка" : "Failure",
    watermark: isRu ? "Watermark" : "Watermark",
    watermarkClean: isRu ? "Без watermark" : "Clean",
    watermarkApplied: isRu ? "С watermark" : "Watermarked",
    watermarkNotRequired: isRu ? "Не требуется" : "Not required",
    watermarkRemoved: isRu ? "Снят" : "Removed",
    watermarkPending: isRu ? "Подготовка" : "Preparing",
    watermarkUnlockedBy: isRu ? "кем" : "by",
    grantClean: isRu ? "Выдать clean" : "Grant clean",
    grantingClean: isRu ? "Выдаём..." : "Granting...",
    grantCleanError: isRu
      ? "Не удалось выдать clean download."
      : "Failed to grant clean download.",
    created: isRu ? "Создана" : "Created",
    completedAt: isRu ? "Завершена" : "Completed",
    noFailure: isRu ? "Нет" : "None",
    allStatuses: isRu ? "Все" : "All",
    previous: isRu ? "Назад" : "Previous",
    next: isRu ? "Вперед" : "Next",
    previousPageLabel: isRu ? "Предыдущая страница генераций" : "Previous generations page",
    nextPageLabel: isRu ? "Следующая страница генераций" : "Next generations page",
    page: isRu ? "Страница" : "Page",
    of: isRu ? "из" : "of",
    templateImage: isRu ? "Изображение" : "Image",
    templateVideo: isRu ? "Видео" : "Video",
    feedbackTab: isRu ? "Отзывы" : "Feedback",
    feedbackEmpty: isRu ? "Feedback по генерации пока нет" : "No feedback for this generation yet",
    feedbackError: isRu
      ? "Не удалось загрузить feedback по этой генерации"
      : "Failed to load feedback for this generation",
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
    return "var(--success)";
  }

  if (status === "Failed") {
    return "var(--danger)";
  }

  if (status === "Cancelled") {
    return "var(--neutral)";
  }

  if (status === "Retrying") {
    return "var(--magenta)";
  }

  if (status === "Running") {
    return "var(--info)";
  }

  return "var(--warning)";
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

function formatMetricCount(value: number | null | undefined): string {
  return typeof value === "number" && Number.isFinite(value) ? String(Math.max(0, value)) : "-";
}

function formatFeedbackRating(value?: number | null) {
  if (value === 1) return "Good";
  if (value === 0) return "Okay";
  if (value === -1) return "Bad";
  return "-";
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

function formatWatermarkMethod(value?: string | null) {
  const normalized = value?.trim();
  return normalized ? sanitizeSensitiveText(normalized, 32) : null;
}

function formatInputSourceType(
  value: AdminTemplateGenerationListItem["inputSourceType"],
  locale: Locale
) {
  const normalized = value.trim().toLowerCase();
  const isRu = locale === "ru";
  if (normalized === "generation_result") {
    return isRu ? "Результат генерации" : "Generation result";
  }
  if (normalized === "pet_photo") {
    return isRu ? "Фото питомца" : "Pet photo";
  }
  return isRu ? "Загрузка пользователя" : "User upload";
}

function GenerationRow({
  item,
  locale,
  text,
  onGrantClean,
  grantingGenerationId,
  grantCleanPending,
  isExpanded,
  onToggleDetails,
}: {
  item: AdminTemplateGenerationListItem;
  locale: Locale;
  text: ReturnType<typeof getCopy>;
  onGrantClean: (generationId: string) => void;
  grantingGenerationId: string | null;
  grantCleanPending: boolean;
  isExpanded: boolean;
  onToggleDetails: (generationId: string) => void;
}) {
  const failureText = formatSafeText(item.failureCode, text.noFailure);
  const providerText = formatSafeText(item.provider);
  const modelText = formatSafeText(item.model, "");
  const templateTitle = formatSafeText(item.templateTitle);
  const generationIdText = formatShortId(item.generationId);
  const userIdText = formatShortId(item.userId);
  const templateIdText = formatShortId(item.templateId);
  const detailsPanelId = `generation-details-${item.generationId.replace(/[^a-zA-Z0-9_-]/g, "-")}`;
  const toggleDetailsLabel = `${isExpanded ? text.hideDetails : text.showDetails}: ${generationIdText}`;
  const grantCleanLabel = `${text.grantClean}: ${generationIdText}`;
  const parentTitle = item.parentTemplateTitle
    ? sanitizeSensitiveText(item.parentTemplateTitle, 48)
    : item.similarToGenerationId
      ? `Similar to ${formatShortId(item.similarToGenerationId)}`
      : item.inputSourceType === "generation_result"
        ? "Generation result"
        : item.inputSourceType === "pet_photo"
          ? "Pet photo"
          : "User upload";
  const lineagePrefix =
    item.generationMode === "similar" ? `${parentTitle} -> similar` : parentTitle;
  const lineageText = `${lineagePrefix} -> ${templateTitle}${
    item.childCount > 0 ? ` -> ${item.childCount} child${item.childCount === 1 ? "" : "ren"}` : ""
  }`;
  const debugText =
    item.generationMode === "similar"
      ? [
          item.variationStrength
            ? `variation ${sanitizeSensitiveText(item.variationStrength, 16)}`
            : null,
          typeof item.generationSeed === "number" ? `seed ${item.generationSeed}` : null,
        ]
          .filter(Boolean)
          .join(" / ")
      : "";
  const watermarkMethod = formatWatermarkMethod(item.watermarkUnlockMethod);
  const watermarkUnlockedByText = item.watermarkUnlockedByUserId
    ? formatShortId(item.watermarkUnlockedByUserId)
    : null;
  const watermarkState = !item.isWatermarkRequired
    ? text.watermarkNotRequired
    : item.isWatermarkRemoved
      ? text.watermarkRemoved
      : item.watermarkedMediaPath
        ? text.watermarkApplied
        : text.watermarkPending;
  const compareState = item.canCompareBeforeAfter ? text.compareReady : text.compareUnavailable;
  const feedbackQuery = useQuery({
    queryKey: adminQueryKeys.feedback({ generationId: item.generationId, take: 5 }),
    queryFn: ({ signal }) =>
      fetchAdminFeedback({ generationId: item.generationId, take: 5 }, signal),
    enabled: isExpanded,
  });
  const feedbackItems = feedbackQuery.data?.items ?? [];

  function requestFeedbackRetry() {
    if (feedbackQuery.isFetching) {
      return;
    }

    void feedbackQuery.refetch().catch(() => undefined);
  }

  return (
    <>
      <tr>
        <td className={adminTableStyles.mono}>
          <span className={styles.jobId} title={generationIdText} aria-label={generationIdText}>
            {generationIdText}
          </span>
          <div>
            <button
              type="button"
              className={styles.inlineAction}
              onClick={() => onToggleDetails(item.generationId)}
              aria-expanded={isExpanded}
              aria-controls={detailsPanelId}
              aria-label={toggleDetailsLabel}
              title={toggleDetailsLabel}
            >
              {isExpanded ? text.hideDetails : text.showDetails}
            </button>
          </div>
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
            <span className={styles.lineage}>{lineageText}</span>
            {debugText ? <span className={styles.lineage}>{debugText}</span> : null}
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
        <td>
          <span className={styles.watermarkMeta}>
            <strong>{watermarkState}</strong>
            {watermarkMethod ? (
              <span>
                {watermarkMethod}
                {typeof item.watermarkCreditsSpent === "number"
                  ? ` / ${item.watermarkCreditsSpent} credits`
                  : ""}
              </span>
            ) : null}
            {watermarkUnlockedByText ? (
              <span>
                {text.watermarkUnlockedBy} {watermarkUnlockedByText}
              </span>
            ) : null}
            {item.watermarkUnlockedAtUtc ? (
              <span>{formatDateTime(item.watermarkUnlockedAtUtc, locale)}</span>
            ) : null}
            {item.isWatermarkRequired && !item.isWatermarkRemoved ? (
              <button
                type="button"
                className={styles.inlineAction}
                disabled={grantCleanPending}
                onClick={() => onGrantClean(item.generationId)}
                aria-label={grantCleanLabel}
                title={grantCleanLabel}
              >
                {grantingGenerationId === item.generationId ? text.grantingClean : text.grantClean}
              </button>
            ) : null}
          </span>
        </td>
        <td>{formatDateTime(item.createdAtUtc, locale)}</td>
        <td>{item.completedAtUtc ? formatDateTime(item.completedAtUtc, locale) : "-"}</td>
      </tr>
      {isExpanded ? (
        <tr>
          <td colSpan={12} className={styles.detailsCell}>
            <div className={styles.detailsPanel} id={detailsPanelId}>
              <div className={styles.previewGrid}>
                <section className={styles.previewCard}>
                  <header>
                    <strong>{text.before}</strong>
                  </header>
                  {item.inputPreviewUrl ? (
                    <TemplateSecureMedia
                      className={styles.previewImage}
                      url={item.inputPreviewUrl}
                      kind="image"
                      alt={text.before}
                      width={512}
                      height={512}
                      logContext={{
                        surface: "generations-before-preview",
                        templateId: item.templateId,
                      }}
                    />
                  ) : (
                    <div className={styles.previewFallback}>{text.previewMissing}</div>
                  )}
                </section>
                <section className={styles.previewCard}>
                  <header>
                    <strong>{text.after}</strong>
                  </header>
                  {item.resultPreviewUrl ? (
                    <TemplateSecureMedia
                      className={styles.previewImage}
                      url={item.resultPreviewUrl}
                      kind="image"
                      alt={text.after}
                      width={512}
                      height={512}
                      logContext={{
                        surface: "generations-after-preview",
                        templateId: item.templateId,
                      }}
                    />
                  ) : (
                    <div className={styles.previewFallback}>{text.previewMissing}</div>
                  )}
                </section>
              </div>
              <div className={styles.detailsGrid}>
                <div>
                  <span>{text.sourceType}</span>
                  <strong>{formatInputSourceType(item.inputSourceType, locale)}</strong>
                </div>
                <div>
                  <span>{text.compareState}</span>
                  <strong>{compareState}</strong>
                </div>
                <div>
                  <span>{text.pet}</span>
                  <strong>{item.petId ? formatShortId(item.petId) : "-"}</strong>
                </div>
                <div>
                  <span>{text.petPhoto}</span>
                  <strong>{item.petPhotoId ? formatShortId(item.petPhotoId) : "-"}</strong>
                </div>
                <div>
                  <span>{text.inputAsset}</span>
                  <strong>
                    {item.inputMediaAssetId ? formatShortId(item.inputMediaAssetId) : "-"}
                  </strong>
                </div>
                <div>
                  <span>{text.resultAsset}</span>
                  <strong>
                    {item.resultMediaAssetId ? formatShortId(item.resultMediaAssetId) : "-"}
                  </strong>
                </div>
                <div>
                  <span>{text.debugTitle}</span>
                  <strong>{watermarkState}</strong>
                </div>
              </div>
              <section className={styles.feedbackPanel}>
                <header>
                  <strong>{text.feedbackTab}</strong>
                  <span>{feedbackQuery.data?.totalCount ?? 0}</span>
                </header>
                {feedbackQuery.isLoading ? (
                  <p>{text.loadingTitle}</p>
                ) : feedbackQuery.isError ? (
                  <AdminStateCard
                    tone="warning"
                    title={text.feedbackError}
                    description={getAdminErrorMessage(feedbackQuery.error, text.feedbackError)}
                    action={
                      <button
                        type="button"
                        className={styles.button}
                        disabled={feedbackQuery.isFetching}
                        onClick={requestFeedbackRetry}
                      >
                        {text.retry}
                      </button>
                    }
                  />
                ) : feedbackItems.length === 0 ? (
                  <p>{text.feedbackEmpty}</p>
                ) : (
                  <div className={styles.feedbackList}>
                    {feedbackItems.map((feedback: AdminFeedbackListItem) => (
                      <div key={feedback.id} className={styles.feedbackItem}>
                        <strong>
                          {feedback.type} / {feedback.category} /{" "}
                          {formatFeedbackRating(feedback.rating)}
                        </strong>
                        <span>
                          {feedback.status} / {feedback.priority} /{" "}
                          {formatDateTime(feedback.createdAtUtc, locale)}
                        </span>
                        {feedback.message ? (
                          <p>{sanitizeSensitiveText(feedback.message, 220)}</p>
                        ) : null}
                      </div>
                    ))}
                  </div>
                )}
              </section>
            </div>
          </td>
        </tr>
      ) : null}
    </>
  );
}

export function GenerationsPage({ locale }: GenerationsPageProps) {
  const text = getCopy(locale);
  const router = useRouter();
  const queryClient = useQueryClient();
  const session = useAuthSession();
  const canViewGenerations = session?.user.roles.includes("Admin") ?? false;
  const [pageIndex, setPageIndex] = useState(0);
  const [status, setStatus] = useState<StatusFilter>("All");
  const [provider, setProvider] = useState("");
  const [user, setUser] = useState("");
  const [search, setSearch] = useState("");
  const [expandedGeneration, setExpandedGeneration] = useState<{
    queryKey: string;
    generationId: string;
  } | null>(null);
  const [grantCleanError, setGrantCleanError] = useState<string | null>(null);

  const debouncedProvider = useDebouncedValue(provider, 350);
  const debouncedUser = useDebouncedValue(user, 350);
  const debouncedSearch = useDebouncedValue(search, 350);

  useEffect(() => {
    ensureAdminSession(locale, router, { requiredRole: "Admin" });
  }, [locale, router, session]);

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
  const queryKey = JSON.stringify(query);
  const expandedGenerationId =
    expandedGeneration?.queryKey === queryKey ? expandedGeneration.generationId : null;

  const generationsQuery = useQuery({
    queryKey: adminQueryKeys.templateGenerations(query),
    queryFn: ({ signal }) => fetchAdminTemplateGenerations(query, signal),
    enabled: canViewGenerations,
    placeholderData: keepPreviousData,
  });
  const generationMetricsQuery = useQuery({
    queryKey: adminQueryKeys.templateGenerationMetrics,
    queryFn: ({ signal }) => fetchAdminTemplateGenerationMetrics(signal),
    enabled: canViewGenerations,
    placeholderData: keepPreviousData,
    staleTime: 30_000,
  });

  const visiblePage = generationsQuery.isPlaceholderData ? undefined : generationsQuery.data;
  const visibleItems = useMemo(() => visiblePage?.items ?? [], [visiblePage]);
  const visibleTotalCount = visiblePage?.totalCount ?? 0;
  const visiblePageCount = Math.max(1, Math.ceil(visibleTotalCount / PAGE_SIZE));
  const visibleGenerationIds = useMemo(
    () => new Set(visibleItems.map((item) => item.generationId)),
    [visibleItems]
  );
  const isGenerationsRefreshing = generationsQuery.isFetching && generationsQuery.isPlaceholderData;
  const areGenerationFiltersLocked = generationsQuery.isFetching;
  const generationMetrics = generationMetricsQuery.data ?? null;
  const grantCleanMutation = useMutation({
    mutationFn: grantAdminGenerationCleanDownload,
    onMutate: () => {
      setGrantCleanError(null);
    },
    onSuccess: async () => {
      await Promise.allSettled([
        queryClient.invalidateQueries({ queryKey: adminQueryKeys.templateGenerations(query) }),
      ]);
    },
    onError: (error) => {
      setGrantCleanError(getAdminErrorMessage(error, text.grantCleanError));
    },
  });
  const grantingGenerationId = grantCleanMutation.variables ?? null;
  const isGrantCleanLocked = grantCleanMutation.isPending || generationsQuery.isFetching;

  useEffect(() => {
    if (!expandedGenerationId || visibleGenerationIds.has(expandedGenerationId)) {
      return;
    }

    queueMicrotask(() => setExpandedGeneration(null));
  }, [expandedGenerationId, visibleGenerationIds]);

  function resetGenerationListContext(nextPageIndex = 0) {
    setExpandedGeneration(null);
    setPageIndex(nextPageIndex);
  }

  function requestGenerationMetricsRetry() {
    if (!canViewGenerations || generationMetricsQuery.isFetching) {
      return;
    }

    void generationMetricsQuery.refetch().catch(() => undefined);
  }

  function requestGenerationsRetry() {
    if (!canViewGenerations || generationsQuery.isFetching) {
      return;
    }

    void generationsQuery.refetch().catch(() => undefined);
  }

  function requestGrantClean(generationId: string) {
    if (!canViewGenerations || isGrantCleanLocked) {
      return;
    }

    grantCleanMutation.mutate(generationId);
  }

  if (!canViewGenerations) {
    return (
      <section className={styles.page}>
        <AdminPageHero
          eyebrow={text.eyebrow}
          title={text.title}
          description={text.description}
          badge={<AdminBadge tone="danger">{text.adminOnly}</AdminBadge>}
        />
        <AdminStateCard tone="info" title={text.loadingTitle} />
      </section>
    );
  }

  return (
    <section className={styles.page}>
      <AdminPageHero
        eyebrow={text.eyebrow}
        title={text.title}
        description={text.description}
        badge={<AdminBadge tone="danger">{text.adminOnly}</AdminBadge>}
      />

      <div className={styles.kpiGrid}>
        <AdminKpiCard
          label={text.total}
          value={formatMetricCount(generationMetrics?.totalJobs)}
          tone="primary"
        />
        <AdminKpiCard
          label={text.pending}
          value={formatMetricCount(generationMetrics?.pendingJobs)}
          hint={text.allJobsScope}
          tone="warning"
        />
        <AdminKpiCard
          label={text.running}
          value={formatMetricCount(generationMetrics?.runningJobs)}
          hint={text.allJobsScope}
          tone="info"
        />
        <AdminKpiCard
          label={text.failed}
          value={formatMetricCount(generationMetrics?.failedJobs)}
          hint={text.allJobsScope}
          tone="danger"
        />
        <AdminKpiCard
          label={text.retrying}
          value={formatMetricCount(generationMetrics?.retryingJobs)}
          hint={text.allJobsScope}
          tone="warning"
        />
        <AdminKpiCard
          label={text.cancelled}
          value={formatMetricCount(generationMetrics?.cancelledJobs)}
          hint={text.allJobsScope}
          tone="neutral"
        />
      </div>

      {generationMetricsQuery.isError ? (
        <AdminStateCard
          className={styles.metricsWarning}
          tone="warning"
          title={text.metricsErrorTitle}
          description={getAdminErrorMessage(
            generationMetricsQuery.error,
            text.metricsErrorDescription
          )}
          action={
            <button
              type="button"
              className={styles.button}
              disabled={!canViewGenerations || generationMetricsQuery.isFetching}
              onClick={requestGenerationMetricsRetry}
            >
              {text.retry}
            </button>
          }
        />
      ) : null}

      <AdminCard title={text.filtersTitle} description={text.filtersDescription}>
        <div className={styles.filters}>
          <label className={styles.field}>
            <span className={styles.label}>{text.searchLabel}</span>
            <input
              className={styles.input}
              value={search}
              disabled={areGenerationFiltersLocked}
              onChange={(event) => {
                setSearch(event.target.value.slice(0, GENERATION_SEARCH_FILTER_MAX_LENGTH));
                resetGenerationListContext();
              }}
              maxLength={GENERATION_SEARCH_FILTER_MAX_LENGTH}
              placeholder={text.searchPlaceholder}
            />
          </label>
          <label className={styles.field}>
            <span className={styles.label}>{text.statusLabel}</span>
            <select
              className={styles.select}
              value={status}
              disabled={areGenerationFiltersLocked}
              onChange={(event) => {
                setStatus(event.target.value as StatusFilter);
                resetGenerationListContext();
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
              disabled={areGenerationFiltersLocked}
              onChange={(event) => {
                setProvider(event.target.value.slice(0, GENERATION_PROVIDER_FILTER_MAX_LENGTH));
                resetGenerationListContext();
              }}
              maxLength={GENERATION_PROVIDER_FILTER_MAX_LENGTH}
              placeholder={text.providerPlaceholder}
            />
          </label>
          <label className={styles.field}>
            <span className={styles.label}>{text.userLabel}</span>
            <input
              className={styles.input}
              value={user}
              disabled={areGenerationFiltersLocked}
              onChange={(event) => {
                setUser(event.target.value.slice(0, GENERATION_USER_FILTER_MAX_LENGTH));
                resetGenerationListContext();
              }}
              maxLength={GENERATION_USER_FILTER_MAX_LENGTH}
              placeholder={text.userPlaceholder}
            />
          </label>
        </div>
      </AdminCard>

      {generationsQuery.isLoading || isGenerationsRefreshing ? (
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
              disabled={!canViewGenerations || generationsQuery.isFetching}
              onClick={requestGenerationsRetry}
            >
              {text.retry}
            </button>
          }
        />
      ) : visibleItems.length === 0 ? (
        <AdminStateCard title={text.emptyTitle} description={text.emptyDescription} />
      ) : (
        <AdminCard
          title={
            <span className={styles.tableHeader}>
              <span className={styles.tableTitle}>{text.tableTitle}</span>
              <span className={styles.tableMeta}>
                {visibleTotalCount} total / {formatDateTime(visiblePage?.generatedAtUtc, locale)}
              </span>
            </span>
          }
        >
          {grantCleanError ? (
            <AdminStateCard tone="warning" title={grantCleanError} />
          ) : null}
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
                  <th>{text.watermark}</th>
                  <th>{text.created}</th>
                  <th>{text.completedAt}</th>
                </tr>
              </thead>
              <tbody>
                {visibleItems.map((item) => (
                  <GenerationRow
                    key={item.generationId}
                    item={item}
                    locale={locale}
                    text={text}
                    grantingGenerationId={grantingGenerationId}
                    grantCleanPending={isGrantCleanLocked}
                    onGrantClean={requestGrantClean}
                    isExpanded={expandedGenerationId === item.generationId}
                    onToggleDetails={(generationId) =>
                      setExpandedGeneration((current) =>
                        current?.queryKey === queryKey && current.generationId === generationId
                          ? null
                          : { queryKey, generationId }
                      )
                    }
                  />
                ))}
              </tbody>
            </table>
          </div>
          <div className={styles.pager}>
            <span className={styles.pageInfo}>
              {text.page} {pageIndex + 1} {text.of} {visiblePageCount}
            </span>
            <button
              type="button"
              className={`${styles.button} ${styles.pagerButton}`}
              disabled={pageIndex === 0 || generationsQuery.isFetching}
              aria-label={text.previousPageLabel}
              title={text.previousPageLabel}
              onClick={() => resetGenerationListContext(Math.max(0, pageIndex - 1))}
            >
              <CaretDownIcon className={`${styles.pageIcon} ${styles.pageIconPrevious}`} />
            </button>
            <button
              type="button"
              className={`${styles.button} ${styles.pagerButton}`}
              disabled={!visiblePage?.hasMore || generationsQuery.isFetching}
              aria-label={text.nextPageLabel}
              title={text.nextPageLabel}
              onClick={() => resetGenerationListContext(pageIndex + 1)}
            >
              <CaretDownIcon className={`${styles.pageIcon} ${styles.pageIconNext}`} />
            </button>
          </div>
        </AdminCard>
      )}
    </section>
  );
}
