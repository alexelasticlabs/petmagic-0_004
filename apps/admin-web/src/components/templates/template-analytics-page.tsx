"use client";

import {
    CalendarIcon,
    ChartIcon,
    DownloadIcon,
    GlobeIcon,
    RefreshIcon,
    TableIcon,
    TrendUpIcon
} from "@/components/admin/admin-icons";
import { AdminMetricStrip, AdminPage, AdminStateCard, AdminToolbar } from "@/components/admin/admin-primitives";
import { ensureAdminSession } from "@/components/admin/admin-session";
import {
    TemplateAnalyticsFailureBreakdownSection,
    TemplateAnalyticsFeedbackSection,
    TemplateAnalyticsRecentRunsSection,
} from "@/components/templates/template-analytics-detail-sections";
import {
    TemplateAnalyticsInsightGridSection,
    TemplateAnalyticsOverviewSection,
    TemplateAnalyticsSnapshotSection,
    TemplateAnalyticsVisualSection,
} from "@/components/templates/template-analytics-overview-sections";
import styles from "@/components/templates/template-analytics-page.module.css";
import {
    buildPeriodAnalytics,
    calculateChange,
    formatDateTime,
    formatDuration,
    formatNumber,
    formatPercent,
    formatTokens,
    totalsFromStatistics,
    type PeriodKey,
    type TrendMetricKey,
} from "@/components/templates/template-analytics-utils";
import { useAdminTemplateAnalyticsOverview } from "@/components/templates/use-admin-template-analytics-overview";
import { useAdminTemplateFeedback } from "@/components/templates/use-admin-template-feedback";
import {
    fetchAdminTemplateRecentGenerations,
    useAuthSession,
    type AdminTemplateEventAnalytics,
    type AdminTemplateRecentGeneration,
} from "@/lib/api-client";
import { type Locale } from "@/lib/i18n";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useMemo, useState, type ComponentType } from "react";

type TemplateAnalyticsPageProps = {
  locale: Locale;
  templateId: string;
};

type MetricAccent = "blue" | "green" | "red" | "cyan" | "neutral";
type RecentRunsMode = "latest" | "all" | "failed";
type FeedbackFilterKey = "all" | "complaint" | "feedback";

const RECENT_RUNS_PREVIEW_LIMIT = 8;

const EMPTY_EVENT_ANALYTICS: AdminTemplateEventAnalytics = {
  totalViews: 0,
  totalVideoViews: 0,
  totalComplaints: 0,
  sources: [],
  devices: [],
  geography: [],
};

export function TemplateAnalyticsPage({ locale, templateId }: TemplateAnalyticsPageProps) {
  return <TemplateAnalyticsPageContent key={templateId} locale={locale} templateId={templateId} />;
}

function TemplateAnalyticsPageContent({ locale, templateId }: TemplateAnalyticsPageProps) {
  const isRu = locale === "ru";
  const text = useMemo(() => getAnalyticsCopy(locale), [locale]);
  const router = useRouter();
  const session = useAuthSession();
  const {
    eventAnalytics,
    failureBreakdown,
    hasError,
    hasSecondaryError,
    isLoading,
    isSecondaryLoading,
    recentRunsPreview,
    statistics,
    template,
    trendPoints,
  } = useAdminTemplateAnalyticsOverview({
    enabled: Boolean(session),
    previewTake: RECENT_RUNS_PREVIEW_LIMIT,
    templateId,
  });
  const [allRecentRuns, setAllRecentRuns] = useState<AdminTemplateRecentGeneration[] | null>(null);
  const [recentRunsMode, setRecentRunsMode] = useState<RecentRunsMode>("latest");
  const [isRecentRunsLoading, setIsRecentRunsLoading] = useState(false);
  const [recentRunsError, setRecentRunsError] = useState<string | null>(null);
  const [feedbackFilter, setFeedbackFilter] = useState<FeedbackFilterKey>("all");
  const [feedbackSearchInput, setFeedbackSearchInput] = useState("");
  const [feedbackSearch, setFeedbackSearch] = useState("");
  const [period, setPeriod] = useState<PeriodKey>("30d");
  const [chartMetric, setChartMetric] = useState<TrendMetricKey>("totalRuns");
  const [isComparisonEnabled, setIsComparisonEnabled] = useState(true);
  const {
    hasError: hasFeedbackError,
    isLoading: isFeedbackLoading,
    items: feedbackItems,
  } = useAdminTemplateFeedback({
    enabled: Boolean(session),
    filter: feedbackFilter,
    search: feedbackSearch,
    templateId,
  });
  const error = hasError ? text.loadError : null;
  const feedbackError = hasFeedbackError ? text.feedbackLoadError : null;
  const secondaryStateMessage = isSecondaryLoading ? text.loading : text.loadError;

  const periodAnalytics = useMemo(() => buildPeriodAnalytics(trendPoints, period), [trendPoints, period]);
  const feedbackOptions: Array<{ key: FeedbackFilterKey; label: string }> = [
    { key: "all", label: text.feedbackFilterAll },
    { key: "complaint", label: text.feedbackFilterComplaint },
    { key: "feedback", label: text.feedbackFilterFeedback },
  ];
  const visibleRecentRuns = useMemo(() => {
    const allRuns = allRecentRuns ?? recentRunsPreview;
    if (recentRunsMode === "all") {
      return allRuns;
    }

    if (recentRunsMode === "failed") {
      return allRuns.filter((run) => run.status === "Failed" || Boolean(run.failureCode) || Boolean(run.failureMessage));
    }

    return recentRunsPreview;
  }, [allRecentRuns, recentRunsMode, recentRunsPreview]);

  useEffect(() => {
    const handle = window.setTimeout(() => {
      setFeedbackSearch(feedbackSearchInput.trim());
    }, 250);

    return () => {
      window.clearTimeout(handle);
    };
  }, [feedbackSearchInput]);

  useEffect(() => {
    if (!session) {
      ensureAdminSession(locale, router);
    }
  }, [locale, router, session]);

  if (isLoading) {
    return (
      <AdminPage className={styles.page}>
        <AdminStateCard tone="info" title={text.loading} />
      </AdminPage>
    );
  }

  if (error || !template || !statistics) {
    return (
      <AdminPage className={styles.page}>
        <AdminStateCard tone="danger" title={error ?? text.loadError} />
      </AdminPage>
    );
  }

  const templateSlug = template.templateType === "Video" ? "video" : "image";
  const catalogPath = `/${locale}/templates/${templateSlug}`;
  const editorPath = `/${locale}/templates/${templateSlug}/editor?templateId=${templateId}`;
  const breadcrumbsRoot = template.templateType === "Video"
    ? (isRu ? "Видео шаблоны" : "Video templates")
    : (isRu ? "Шаблоны изображений" : "Image templates");
  const activeRuns = statistics.queuedRuns + statistics.processingRuns;
  const canShowAllRecentRuns = statistics.totalRuns > RECENT_RUNS_PREVIEW_LIMIT;
  const canShowFailedRecentRuns = statistics.failedRuns > 0;
  const shouldShowRecentRunModes = canShowAllRecentRuns || canShowFailedRecentRuns;
  const isSecondaryReady = !isSecondaryLoading && !hasSecondaryError;
  const events = eventAnalytics ?? EMPTY_EVENT_ANALYTICS;
  const selectedTotals = isSecondaryReady
    ? (period === "all" ? totalsFromStatistics(statistics) : periodAnalytics.current)
    : (period === "all" ? totalsFromStatistics(statistics) : null);
  const previousTotals = isSecondaryReady && isComparisonEnabled && period !== "all" ? periodAnalytics.previous : null;
  const chartPoints = isSecondaryReady ? (period === "all" ? trendPoints : periodAnalytics.currentPoints) : [];

  async function handleRecentRunsModeChange(mode: RecentRunsMode) {
    setRecentRunsError(null);

    if (mode === "latest") {
      setRecentRunsMode("latest");
      return;
    }

    setRecentRunsMode(mode);
    if (allRecentRuns || isRecentRunsLoading || !canShowAllRecentRuns) {
      return;
    }

    try {
      setIsRecentRunsLoading(true);
      const response = await fetchAdminTemplateRecentGenerations(templateId);
      setAllRecentRuns(response);
    } catch {
      setRecentRunsMode("latest");
      setRecentRunsError(text.recentRunsExpandError);
    } finally {
      setIsRecentRunsLoading(false);
    }
  }
  const kpiCards = [
    {
      label: text.views,
      value: isSecondaryReady ? formatNumber(events.totalViews, locale) : "...",
      hint: isSecondaryReady ? text.viewsHint : secondaryStateMessage,
      accent: "blue" as MetricAccent,
    },
    {
      label: text.generationStarts,
      value: selectedTotals ? formatNumber(selectedTotals.totalRuns, locale) : "...",
      hint: selectedTotals ? text.generationStartsHint : secondaryStateMessage,
      accent: "blue" as MetricAccent,
      delta: selectedTotals ? calculateChange(selectedTotals.totalRuns, previousTotals?.totalRuns) : null,
    },
    {
      label: text.successfulGenerations,
      value: selectedTotals ? formatNumber(selectedTotals.completedRuns, locale) : "...",
      hint: selectedTotals ? text.successfulGenerationsHint : secondaryStateMessage,
      accent: "green" as MetricAccent,
      delta: selectedTotals ? calculateChange(selectedTotals.completedRuns, previousTotals?.completedRuns) : null,
    },
    {
      label: text.generationConversion,
      value: selectedTotals ? formatPercent(selectedTotals.successRatePercent, isRu) : "...",
      hint: selectedTotals ? text.generationConversionHint : secondaryStateMessage,
      accent: "green" as MetricAccent,
      delta: selectedTotals ? calculateChange(selectedTotals.successRatePercent, previousTotals?.successRatePercent) : null,
    },
    {
      label: text.tokenSpend,
      value: selectedTotals ? formatTokens(selectedTotals.totalTokenCost, isRu) : "...",
      hint: selectedTotals ? text.tokenSpendHint : secondaryStateMessage,
      accent: "cyan" as MetricAccent,
      delta: selectedTotals ? calculateChange(selectedTotals.totalTokenCost, previousTotals?.totalTokenCost) : null,
    },
    {
      label: text.complaints,
      value: isSecondaryReady ? formatNumber(events.totalComplaints, locale) : "...",
      hint: isSecondaryReady ? text.complaintsHint : secondaryStateMessage,
      accent: isSecondaryReady && events.totalComplaints > 0 ? "red" as MetricAccent : "neutral" as MetricAccent,
    },
  ];
  const periodOptions: Array<{ key: PeriodKey; label: string }> = [
    { key: "7d", label: text.range7 },
    { key: "30d", label: text.range30 },
    { key: "90d", label: text.range90 },
    { key: "all", label: text.rangeAll },
  ];
  const chartTabs: Array<{ key: TrendMetricKey; label: string }> = [
    { key: "totalRuns", label: text.chartRuns },
    { key: "completedRuns", label: text.chartCompleted },
    { key: "failedRuns", label: text.chartFailed },
    { key: "totalTokenCost", label: text.chartTokens },
    { key: "averageGenerationSeconds", label: text.chartDuration },
  ];

  function handleExportAnalytics() {
    if (!template || !statistics) {
      return;
    }

    const payload = {
      exportedAtUtc: new Date().toISOString(),
      period,
      template,
      statistics,
      selectedTotals,
      trendPoints: chartPoints,
      recentRuns: visibleRecentRuns,
      failureBreakdown,
      eventAnalytics: events,
    };
    const blob = new Blob([JSON.stringify(payload, null, 2)], { type: "application/json" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = `template-${template.templateId}-analytics.json`;
    link.click();
    URL.revokeObjectURL(url);
  }

  return (
    <AdminPage className={styles.page}>
      <div className={styles.pageHeaderRow}>
        <div className={styles.breadcrumbs}>
          <Link href={catalogPath}>{breadcrumbsRoot}</Link>
          <span aria-hidden="true">/</span>
          <Link href={editorPath}>{template.title}</Link>
          <span aria-hidden="true">/</span>
          <span>{text.pageTitle}</span>
        </div>

        <div className={styles.heroActions}>
          <Link href={catalogPath} className={styles.secondaryLink}><TableIcon className={styles.controlIcon} /><span>{text.backToCatalog}</span></Link>
          <Link href={editorPath} className={styles.primaryLink}><ChartIcon className={styles.controlIcon} /><span>{text.openEditor}</span></Link>
        </div>
      </div>

      <AdminMetricStrip
        className={styles.metricStrip}
        items={[
          { label: text.lastRun, value: formatDateTime(statistics.lastRunAtUtc, locale) },
          { label: text.lastCompleted, value: formatDateTime(statistics.lastCompletedAtUtc, locale) },
          { label: text.averageGenerationTime, value: formatDuration(statistics.averageGenerationSeconds, isRu) },
          { label: text.activeQueue, value: String(activeRuns) },
        ]}
      />

      <AdminToolbar className={styles.analyticsToolbar}>
        <div className={styles.segmentedControl} aria-label={text.rangeLabel}>
          {periodOptions.map((option) => (
            <button
              key={option.key}
              type="button"
              className={option.key === period ? styles.segmentedButtonActive : styles.segmentedButton}
              onClick={() => setPeriod(option.key)}
            >
              <CalendarIcon className={styles.controlIcon} />
              <span>{option.label}</span>
            </button>
          ))}
        </div>

        <div className={styles.toolbarActions}>
          <button
            type="button"
            className={isComparisonEnabled ? styles.toolbarButtonActive : styles.toolbarButton}
            aria-pressed={isComparisonEnabled}
            onClick={() => setIsComparisonEnabled((value) => !value)}
          >
            <RefreshIcon className={styles.controlIcon} />
            <span>{text.comparePeriod}</span>
          </button>
          <button type="button" className={styles.exportButton} onClick={handleExportAnalytics} disabled={isSecondaryLoading}>
            <DownloadIcon className={styles.controlIcon} />
            <span>{text.exportAnalytics}</span>
          </button>
        </div>
        </AdminToolbar>

      <TemplateAnalyticsOverviewSection
        isRu={isRu}
        kpiCards={kpiCards}
        locale={locale}
        template={template}
        text={text}
      />

      <TemplateAnalyticsVisualSection
        chartMetric={chartMetric}
        chartPoints={chartPoints}
        chartTabs={chartTabs}
        isRu={isRu}
        locale={locale}
        onChartMetricChange={setChartMetric}
        statistics={statistics}
        text={text}
      />

      {isSecondaryReady ? (
        <TemplateAnalyticsInsightGridSection
          events={events}
          isRu={isRu}
          locale={locale}
          statistics={statistics}
          text={text}
        />
      ) : (
        <div className={styles.insightGrid}>
          <TemplateAnalyticsSectionPlaceholder icon={GlobeIcon} message={secondaryStateMessage} title={text.sourcesTitle} hint={text.sourcesHint} />
          <TemplateAnalyticsSectionPlaceholder icon={TrendUpIcon} message={secondaryStateMessage} title={text.retentionTitle} hint={text.retentionHint} />
          <TemplateAnalyticsSectionPlaceholder icon={GlobeIcon} message={secondaryStateMessage} title={text.geographyTitle} hint={text.geographyHint} />
          <TemplateAnalyticsSectionPlaceholder icon={GlobeIcon} message={secondaryStateMessage} title={text.devicesTitle} hint={text.devicesHint} />
        </div>
      )}

      <div className={styles.detailsGrid}>
        {isSecondaryReady ? (
          <TemplateAnalyticsRecentRunsSection
            canShowFailedRecentRuns={canShowFailedRecentRuns}
            canShowRecentRunModes={shouldShowRecentRunModes}
            error={recentRunsError}
            isLoading={isRecentRunsLoading}
            items={visibleRecentRuns}
            locale={locale}
            mode={recentRunsMode}
            onModeChange={(mode) => void handleRecentRunsModeChange(mode)}
            text={text}
          />
        ) : (
          <TemplateAnalyticsSectionPlaceholder
            wide
            icon={TableIcon}
            message={secondaryStateMessage}
            title={text.recentRunsTitle}
            hint={text.recentRunsHint}
          />
        )}

        {isSecondaryReady ? (
          <TemplateAnalyticsFailureBreakdownSection
            items={failureBreakdown}
            locale={locale}
            text={text}
          />
        ) : (
          <TemplateAnalyticsSectionPlaceholder
            icon={ChartIcon}
            message={secondaryStateMessage}
            title={text.failureBreakdownTitle}
            hint={text.failureBreakdownHint}
          />
        )}
      </div>

      <TemplateAnalyticsFeedbackSection
        error={feedbackError}
        feedbackFilter={feedbackFilter}
        feedbackOptions={feedbackOptions}
        feedbackSearch={feedbackSearchInput}
        isLoading={isFeedbackLoading}
        items={feedbackItems}
        locale={locale}
        onFeedbackFilterChange={setFeedbackFilter}
        onFeedbackSearchChange={setFeedbackSearchInput}
        text={text}
      />

      <TemplateAnalyticsSnapshotSection
        activeRuns={activeRuns}
        isRu={isRu}
        locale={locale}
        statistics={statistics}
        template={template}
        text={text}
      />
    </AdminPage>
  );
}

function TemplateAnalyticsSectionPlaceholder({
  hint,
  icon: Icon,
  message,
  title,
  wide = false,
}: {
  hint: string;
  icon: ComponentType<{ className?: string }>;
  message: string;
  title: string;
  wide?: boolean;
}) {
  return (
    <section className={wide ? `${styles.sectionCard} ${styles.sectionCardWide}` : styles.sectionCard}>
      <div className={styles.sectionHeader}>
        <h2 className={styles.sectionTitleWithIcon}><Icon className={styles.sectionTitleIcon} /><span>{title}</span></h2>
        <p>{hint}</p>
      </div>
      <p className={styles.emptyState}>{message}</p>
    </section>
  );
}

function getAnalyticsCopy(locale: Locale) {
  const isRu = locale === "ru";

  return {
    breadcrumbsRoot: isRu ? "Видео шаблоны" : "Video templates",
    eyebrow: isRu ? "Аналитика шаблона" : "Template analytics",
    pageTitle: isRu ? "Аналитика" : "Analytics",
    pageDescription: isRu
      ? "Первая версия аналитики строится на реальных generation metrics шаблона: запуски, успешность, токены, история и breakdown по сбоям."
      : "The first analytics version is built on real template generation metrics: runs, success rate, tokens, history, and failure breakdown.",
    backToCatalog: isRu ? "К каталогу" : "Back to catalog",
    openEditor: isRu ? "Открыть редактор" : "Open editor",
    loading: isRu ? "Загрузка аналитики шаблона..." : "Loading template analytics...",
    loadError: isRu ? "Не удалось загрузить аналитику шаблона." : "Failed to load template analytics.",
    rangeLabel: isRu ? "Период аналитики" : "Analytics period",
    range7: isRu ? "7 дней" : "7 days",
    range30: isRu ? "30 дней" : "30 days",
    range90: isRu ? "90 дней" : "90 days",
    rangeAll: isRu ? "Всё время" : "All time",
    comparePeriod: isRu ? "Сравнить период" : "Compare period",
    exportAnalytics: isRu ? "Экспорт JSON" : "Export JSON",
    compareNoBase: isRu ? "нет базы сравнения" : "no comparison base",
    statusLabel: isRu ? "Статус" : "Status",
    templateOverviewTitle: isRu ? "Карточка шаблона" : "Template card",
    templateIdLabel: "ID",
    categoryLabel: isRu ? "Категория" : "Category",
    priceLabel: isRu ? "Доступ" : "Access",
    tokenCostLabel: isRu ? "Цена запуска" : "Run price",
    estimatedTemplateCostLabel: isRu ? "Себестоимость, $" : "Provider cost, $",
    createdLabel: isRu ? "Создан" : "Created",
    updatedLabel: isRu ? "Обновлён" : "Updated",
    totalRuns: isRu ? "Всего запусков" : "Total runs",
    successRate: isRu ? "Успешность" : "Success rate",
    completedRuns: isRu ? "Успешные" : "Completed",
    failedRuns: isRu ? "Ошибки" : "Failed",
    totalTokenCost: isRu ? "Всего токенов" : "Total token cost",
    averageTokenCost: isRu ? "Средний cost" : "Average token cost",
    views: isRu ? "Просмотры" : "Views",
    viewsHint: isRu ? "События view из публичного template endpoint." : "View events from the public template endpoint.",
    generationStarts: isRu ? "Запуски генерации" : "Generation starts",
    generationStartsHint: isRu ? "Созданные задания генерации за выбранный период." : "Generation jobs created in the selected period.",
    successfulGenerations: isRu ? "Успешные генерации" : "Successful generations",
    successfulGenerationsHint: isRu ? "Задания, завершённые готовым видео." : "Jobs completed with an output video.",
    generationConversion: isRu ? "Конверсия в результат" : "Result conversion",
    generationConversionHint: isRu ? "Доля успешных jobs среди запусков." : "Completed jobs as a share of started jobs.",
    tokenSpend: isRu ? "Потрачено токенов" : "Token spend",
    tokenSpendHint: isRu ? "Суммарная стоимость запусков в токенах." : "Total token cost of runs.",
    complaints: isRu ? "Жалобы" : "Complaints",
    complaintsHint: isRu ? "События complaint из публичного analytics endpoint." : "Complaint events from the public analytics endpoint.",
    feedbackTitle: isRu ? "Жалобы и фидбек" : "Complaints and feedback",
    feedbackHint: isRu ? "Последние обращения пользователей по шаблону: complaint и feedback события с текстом и метаданными." : "Latest user complaints and feedback for this template with message text and event metadata.",
    feedbackFilterLabel: isRu ? "Фильтр фидбека" : "Feedback filter",
    feedbackFilterAll: isRu ? "Все" : "All",
    feedbackFilterComplaint: isRu ? "Жалобы" : "Complaints",
    feedbackFilterFeedback: isRu ? "Фидбек" : "Feedback",
    feedbackSearchLabel: isRu ? "Поиск по тексту фидбека" : "Search feedback text",
    feedbackSearchPlaceholder: isRu ? "Поиск по тексту сообщения" : "Search message text",
    feedbackLoading: isRu ? "Загрузка обращений..." : "Loading feedback...",
    feedbackEmpty: isRu ? "Пока нет пользовательских жалоб или фидбека по этому шаблону." : "There is no user complaint or feedback for this template yet.",
    feedbackFilteredEmpty: isRu ? "По текущему фильтру и поиску ничего не найдено." : "No items matched the current filter and search.",
    feedbackLoadError: isRu ? "Не удалось загрузить жалобы и фидбек." : "Failed to load complaints and feedback.",
    feedbackMessageMissing: isRu ? "Без текста сообщения." : "No message text provided.",
    feedbackTypeComplaint: isRu ? "Жалоба" : "Complaint",
    feedbackTypeFeedback: isRu ? "Фидбек" : "Feedback",
    feedbackSourceLabel: isRu ? "Источник" : "Source",
    feedbackDeviceLabel: isRu ? "Устройство" : "Device",
    feedbackCountryLabel: isRu ? "Страна" : "Country",
    activeQueue: isRu ? "Активная очередь" : "Active queue",
    averageGenerationTime: isRu ? "Среднее время" : "Average generation time",
    lastRun: isRu ? "Последний запуск" : "Last run",
    lastCompleted: isRu ? "Последний успех" : "Last completed",
    overviewHint: isRu ? "Текущий read model по шаблону" : "Current template read model",
    snapshotTitle: isRu ? "Сводка по шаблону" : "Template snapshot",
    snapshotHint: isRu ? "Этот блок собирается из существующей admin statistics модели и служит опорной сводкой для dashboard выше." : "This block is built from the existing admin statistics model and acts as the anchor summary for the dashboard above.",
    trendTitle: isRu ? "Динамика запусков" : "Run trend",
    trendHint: isRu ? "Группировка generation jobs по дням создания шаблонных запусков." : "Generation jobs grouped by creation day.",
    trendEmpty: isRu ? "Для этого шаблона ещё нет исторических точек тренда." : "There are no trend points for this template yet.",
    chartRuns: isRu ? "Запуски" : "Runs",
    chartCompleted: isRu ? "Успешные" : "Completed",
    chartFailed: isRu ? "Ошибки" : "Failed",
    chartTokens: isRu ? "Токены" : "Tokens",
    chartDuration: isRu ? "Время" : "Duration",
    statusBreakdownTitle: isRu ? "Состояние пайплайна" : "Pipeline health",
    statusBreakdownHint: isRu ? "Распределение текущих и завершённых состояний генерации." : "Distribution of current and completed generation pipeline states.",
    runsInQueue: isRu ? "В очереди" : "Queued",
    processingNow: isRu ? "В обработке" : "Processing",
    sourcesTitle: isRu ? "Источники просмотров" : "View sources",
    sourcesHint: isRu ? "Реальные source breakdown из template view events." : "Real source breakdown from template view events.",
    instrumentationPending: isRu ? "Нужна запись событий в публичном приложении/API, чтобы показывать эти метрики без догадок." : "Public app/API instrumentation is required to show this without guessing.",
    sourceHome: isRu ? "Главная" : "Home",
    sourceCategories: isRu ? "Категории" : "Categories",
    sourceSearch: isRu ? "Поиск" : "Search",
    sourceProfile: isRu ? "Профиль" : "Profile",
    retentionTitle: isRu ? "Воронка генерации" : "Generation funnel",
    retentionHint: isRu ? "Реальная operational воронка по generation jobs." : "Real operational funnel from generation jobs.",
    funnelStarted: isRu ? "Начали генерацию" : "Started generation",
    funnelCompleted: isRu ? "Дождались результата" : "Completed result",
    funnelFailed: isRu ? "Получили ошибку" : "Failed",
    funnelActive: isRu ? "Ещё в работе" : "Still active",
    geographyTitle: isRu ? "География пользователей" : "User geography",
    geographyHint: isRu ? "Реальная география из событий public traffic, если страна была записана." : "Real geography from public traffic events when country was captured.",
    countryUnknown: isRu ? "Страна не определена" : "Country unknown",
    countryHeader: isRu ? "Страна" : "Country",
    viewsHeader: isRu ? "Просмотры" : "Views",
    startsHeader: isRu ? "Запуски" : "Starts",
    devicesTitle: isRu ? "Устройства" : "Devices",
    devicesHint: isRu ? "Реальное распределение устройств из записанных analytics events." : "Real device distribution from recorded analytics events.",
    deviceIos: "iOS",
    deviceAndroid: "Android",
    deviceWeb: "Web",
    recentRunsTitle: isRu ? "Последние генерации" : "Recent generations",
    recentRunsHint: isRu ? "Последние задания по этому шаблону с минимальным operational срезом." : "Latest jobs for this template with a compact operational snapshot.",
    recentRunsAllHint: isRu ? "Все доступные генерации по этому шаблону за весь период, который хранится в системе." : "All available generations for this template across the full retained history.",
    recentRunsLatest: isRu ? "Последние" : "Latest",
    recentRunsAll: isRu ? "Все генерации" : "All generations",
    recentRunsFailed: isRu ? "Ошибочные" : "Failed only",
    recentRunsLoading: isRu ? "Загрузка..." : "Loading...",
    recentRunsExpandError: isRu ? "Не удалось загрузить полный список генераций." : "Failed to load the full generation history.",
    recentRunsEmpty: isRu ? "У шаблона пока нет недавних генераций." : "This template has no recent generations yet.",
    failedRunsHint: isRu ? "Все завершившиеся с ошибкой генерации по шаблону с кодом и текстом причины." : "All failed generations for this template with failure code and reason text.",
    failedRunsEmpty: isRu ? "По этому шаблону пока нет ошибочных генераций." : "There are no failed generations for this template yet.",
    generationIdHeader: isRu ? "ID генерации" : "Generation ID",
    userHeader: isRu ? "Пользователь" : "User",
    recentCreated: isRu ? "Создан" : "Created",
    recentStatus: isRu ? "Статус" : "Status",
    recentTokens: isRu ? "Токены" : "Tokens",
    recentDuration: isRu ? "Время" : "Duration",
    recentModels: isRu ? "Модели" : "Models",
    failureCodeHeader: isRu ? "Код ошибки" : "Failure code",
    failureReasonHeader: isRu ? "Причина" : "Reason",
    recentOutput: isRu ? "Выход" : "Output",
    openOutput: isRu ? "Открыть" : "Open",
    noOutput: isRu ? "Нет" : "None",
    failureBreakdownTitle: isRu ? "Breakdown ошибок" : "Failure breakdown",
    failureBreakdownHint: isRu ? "Сводка по failure codes из завершившихся с ошибкой generation jobs." : "Summary of failure codes from failed generation jobs.",
    failuresEmpty: isRu ? "Пока нет зарегистрированных ошибок по этому шаблону." : "There are no recorded failures for this template yet.",
    lastFailure: isRu ? "Последняя" : "Last",
    unknownFailure: isRu ? "Неизвестная ошибка" : "Unknown failure",
    totalProviderCost: isRu ? "Всего реальных затрат" : "Total real spend",
    recentProviderCost: isRu ? "Затраты в последних jobs" : "Cost in recent jobs",
    preprocessingModel: isRu ? "Image model" : "Image model",
    motionModel: isRu ? "Motion model" : "Motion model",
    noData: isRu ? "У шаблона пока нет запусков. После первых генераций здесь появятся полноценные метрики." : "This template has no runs yet. Full metrics will appear here after the first generations.",
  };
}

