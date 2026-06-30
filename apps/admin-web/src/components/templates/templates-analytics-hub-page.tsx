"use client";

import { keepPreviousData, useQuery } from "@tanstack/react-query";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";

import {
  CalendarIcon,
  ChartIcon,
  DashboardIcon,
  DownloadIcon,
  TableIcon,
  TrendUpIcon,
} from "@/components/admin/admin-icons";
import {
  AdminFilterBar,
  AdminKpiCard,
  AdminMetricStrip,
  AdminPage,
  AdminPageHero,
  AdminStateCard,
  AdminToolbar,
} from "@/components/admin/admin-primitives";
import { ensureAdminSession } from "@/components/admin/admin-session";
import {
  getTemplateAccessLabel,
  getTemplateStatusLabel,
  getTemplateTypeLabel,
} from "@/components/templates/template-admin-shared";
import {
  sanitizeTemplatesAnalyticsOverviewForExport,
  sanitizeTemplatesAnalyticsQueryForExport,
} from "@/components/templates/templates-analytics-hub-export";
import {
  getTemplatesAnalyticsHubPageText,
  getTemplatesAnalyticsHubPeriodOptions,
} from "@/components/templates/templates-analytics-hub-page.content";
import styles from "@/components/templates/templates-analytics-hub-page.module.css";
import {
  BreakdownPanel,
  EventDimensionPanel,
  FeedbackFeedPanel,
  formatAnalyticsDisplayText,
  formatDateTime,
  formatMoney,
  formatNumber,
  formatPercent,
  formatTokens,
  FunnelList,
  getKpiTone,
  SelectBox,
  TemplatesTable,
  TopTemplatesPanel,
  TrendChart,
  type TrendMetricKey,
  TypePanel,
} from "@/components/templates/templates-analytics-hub-page.sections";
import { Button } from "@/components/ui/button";
import {
  fetchAdminTemplatesAnalyticsOverview,
  normalizeAdminTemplatesAnalyticsQuery,
  useAuthSession,
  type AdminTemplatesAnalyticsOverview,
  type AdminTemplatesAnalyticsQuery,
  type TemplateStatus,
  type TemplateType,
} from "@/lib/api-client";
import { clientLogger } from "@/lib/client-logger";
import { getDictionary, type Locale as AppLocale } from "@/lib/i18n";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

type TemplatesAnalyticsHubPageProps = {
  locale: AppLocale;
};

type PeriodKey = "7" | "30" | "90" | "all";

export function TemplatesAnalyticsHubPage({ locale }: TemplatesAnalyticsHubPageProps) {
  const text = useMemo(() => getTemplatesAnalyticsHubPageText(locale), [locale]);
  const periodOptions = useMemo(() => getTemplatesAnalyticsHubPeriodOptions(locale), [locale]);
  const dictionary = useMemo(() => getDictionary(locale), [locale]);
  const router = useRouter();
  const session = useAuthSession();
  const sessionRoles = session?.user.roles ?? [];
  const canViewTemplateAnalytics =
    sessionRoles.includes("Admin") || sessionRoles.includes("Moderator");
  const [period, setPeriod] = useState<PeriodKey>("30");
  const [templateType, setTemplateType] = useState<TemplateType | "All">("All");
  const [category, setCategory] = useState("");
  const [status, setStatus] = useState<TemplateStatus | "All">("All");
  const [access, setAccess] = useState<"all" | "free" | "premium">("all");
  const [sort, setSort] = useState<NonNullable<AdminTemplatesAnalyticsQuery["sort"]>>("views");
  const [chartMetric, setChartMetric] = useState<TrendMetricKey>("totalViews");

  const query = useMemo<AdminTemplatesAnalyticsQuery>(
    () =>
      normalizeAdminTemplatesAnalyticsQuery({
        periodDays: period === "all" ? undefined : Number(period),
        templateType,
        category: category || undefined,
        status,
        access,
        sort,
        take: 50,
      }),
    [access, category, period, sort, status, templateType]
  );

  useEffect(() => {
    if (!canViewTemplateAnalytics) {
      ensureAdminSession(locale, router);
    }
  }, [canViewTemplateAnalytics, locale, router, session]);

  const overviewQuery = useQuery<AdminTemplatesAnalyticsOverview>({
    queryKey: [
      "admin",
      "templates",
      "analytics-overview",
      query.periodDays ?? null,
      query.templateType ?? null,
      query.category ?? null,
      query.status ?? null,
      query.access ?? null,
      query.sort ?? null,
      query.take ?? null,
    ],
    queryFn: ({ signal }) => fetchAdminTemplatesAnalyticsOverview(query, signal),
    enabled: canViewTemplateAnalytics,
    placeholderData: keepPreviousData,
  });

  useEffect(() => {
    if (!overviewQuery.error) {
      return;
    }

    clientLogger.error("templates.analytics_hub_load_failed", {
      query: sanitizeTemplatesAnalyticsQueryForExport(query),
      errorName: overviewQuery.error instanceof Error ? overviewQuery.error.name : "UnknownError",
      errorDigest:
        overviewQuery.error &&
        typeof overviewQuery.error === "object" &&
        "digest" in overviewQuery.error
          ? sanitizeSensitiveText(
              String((overviewQuery.error as { digest?: unknown }).digest ?? ""),
              80
            )
          : undefined,
    });
  }, [overviewQuery.error, query]);

  const isOverviewRefreshing = overviewQuery.isFetching && overviewQuery.isPlaceholderData;
  const overview = overviewQuery.isPlaceholderData ? null : (overviewQuery.data ?? null);
  const isLoading = (overviewQuery.isPending && !overview) || isOverviewRefreshing;
  const hasBlockingError = overviewQuery.isError && !overview;
  const hasPartialError = overviewQuery.isError && Boolean(overview);
  const isHubControlsLocked = overviewQuery.isFetching;

  if (!canViewTemplateAnalytics) {
    return (
      <AdminPage className={styles.page}>
        <AdminStateCard tone="info" title={text.loading} />
      </AdminPage>
    );
  }

  function handleExport() {
    if (!overview) {
      return;
    }

    const blob = new Blob(
      [
        JSON.stringify(
          {
            query: sanitizeTemplatesAnalyticsQueryForExport(query),
            overview: sanitizeTemplatesAnalyticsOverviewForExport(overview),
          },
          null,
          2
        ),
      ],
      {
        type: "application/json",
      }
    );
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = `templates-analytics-${new Date().toISOString().slice(0, 10)}.json`;
    document.body.append(link);
    link.click();
    link.remove();
    window.setTimeout(() => URL.revokeObjectURL(url), 1000);
  }

  function requestOverviewRetry() {
    if (!canViewTemplateAnalytics || overviewQuery.isFetching) {
      return;
    }

    void overviewQuery.refetch().catch(() => undefined);
  }

  if (isLoading) {
    return (
      <AdminPage className={styles.page}>
        <AdminStateCard tone="info" title={text.loading} />
      </AdminPage>
    );
  }

  if (hasBlockingError || !overview) {
    return (
      <AdminPage className={styles.page}>
        <AdminStateCard
          tone="danger"
          title={text.loadError}
          action={
            <Button
              type="button"
              variant="secondary"
              disabled={!canViewTemplateAnalytics || overviewQuery.isFetching}
              onClick={requestOverviewRetry}
            >
              {text.retryAction}
            </Button>
          }
        />
      </AdminPage>
    );
  }

  const summary = overview.summary;
  const kpis = [
    {
      label: text.views,
      value: formatNumber(summary.totalViews, locale),
      hint: text.viewsHint,
      tone: "green",
    },
    {
      label: text.starts,
      value: formatNumber(summary.totalGenerationStarts, locale),
      hint: text.startsHint,
      tone: "violet",
    },
    {
      label: text.completed,
      value: formatNumber(summary.completedGenerations, locale),
      hint: text.completedHint,
      tone: "green",
    },
    {
      label: text.conversion,
      value: formatPercent(summary.conversionPercent, locale),
      hint: text.conversionHint,
      tone: "blue",
    },
    {
      label: text.tokens,
      value: formatTokens(summary.totalTokenCost, locale),
      hint: text.tokensHint,
      tone: "amber",
    },
    {
      label: text.providerSpend,
      value: formatMoney(summary.totalProviderCostUsd, locale),
      hint: text.providerSpendHint,
      tone: "red",
    },
    {
      label: text.complaints,
      value: formatNumber(summary.totalComplaints, locale),
      hint: text.complaintsHint,
      tone: summary.totalComplaints > 0 ? "red" : "neutral",
    },
  ];
  const chartTabs: Array<{ key: TrendMetricKey; label: string }> = [
    { key: "totalViews", label: text.chartViews },
    { key: "totalGenerationStarts", label: text.chartStarts },
    { key: "completedGenerations", label: text.chartCompleted },
    { key: "totalProviderCostUsd", label: text.chartCost },
  ];

  return (
    <AdminPage className={styles.page}>
      <AdminPageHero
        eyebrow={text.eyebrow}
        title={text.title}
        description={text.description}
        actions={
          <div className={styles.heroActions}>
            <Link href={`/${locale}/templates/video`} className={styles.secondaryLink}>
              <TableIcon className={styles.controlIcon} />
              <span>{text.catalog}</span>
            </Link>
            <button
              type="button"
              className={styles.primaryButton}
              onClick={handleExport}
              disabled={isHubControlsLocked}
            >
              <DownloadIcon className={styles.controlIcon} />
              <span>{text.export}</span>
            </button>
          </div>
        }
        metaItems={[
          `${text.templates}: ${formatNumber(summary.totalTemplates, locale)}`,
          `${text.video}: ${formatNumber(summary.videoTemplates, locale)}`,
          `${text.image}: ${formatNumber(summary.imageTemplates, locale)}`,
          `${text.updated}: ${formatDateTime(overview.generatedAtUtc, locale)}`,
        ]}
      />

      <AdminMetricStrip
        items={[
          { label: text.active, value: formatNumber(summary.activeTemplates, locale) },
          { label: text.premium, value: formatNumber(summary.premiumTemplates, locale) },
        ]}
      />

      {hasPartialError ? (
        <AdminStateCard
          tone="warning"
          title={text.partialErrorTitle}
          description={text.partialErrorDescription}
          action={
            <Button
              type="button"
              variant="secondary"
              disabled={!canViewTemplateAnalytics || overviewQuery.isFetching}
              onClick={requestOverviewRetry}
            >
              {text.retryAction}
            </Button>
          }
        />
      ) : null}

      <AdminToolbar className={styles.toolbar}>
        <div className={styles.segmented} aria-label={text.periodLabel}>
          {periodOptions.map((option) => {
            const isActivePeriod = period === option.key;

            return (
              <button
                key={option.key}
                type="button"
                className={isActivePeriod ? styles.segmentedActive : styles.segmentedButton}
                disabled={isActivePeriod || isHubControlsLocked}
                onClick={() => setPeriod(option.key)}
              >
                <CalendarIcon className={styles.controlIcon} />
                <span>{option.label}</span>
              </button>
            );
          })}
        </div>

        <AdminFilterBar className={styles.filters}>
          <SelectBox
            label={text.typeFilter}
            value={templateType}
            disabled={isHubControlsLocked}
            onChange={(value) => setTemplateType(value as TemplateType | "All")}
            options={[
              { value: "All", label: text.allTemplates },
              { value: "Video", label: getTemplateTypeLabel("Video", dictionary) },
              { value: "Image", label: getTemplateTypeLabel("Image", dictionary) },
            ]}
          />
          <SelectBox
            label={text.categoryFilter}
            value={category}
            disabled={isHubControlsLocked}
            onChange={setCategory}
            options={[
              { value: "", label: text.allCategories },
              ...overview.availableCategories.map((value) => ({
                value,
                label: formatAnalyticsDisplayText(value, 120),
              })),
            ]}
          />
          <SelectBox
            label={text.statusFilter}
            value={status}
            disabled={isHubControlsLocked}
            onChange={(value) => setStatus(value as TemplateStatus | "All")}
            options={[
              { value: "All", label: text.allStatuses },
              { value: "Active", label: getTemplateStatusLabel("Active", locale) },
              { value: "Draft", label: getTemplateStatusLabel("Draft", locale) },
              { value: "Archived", label: getTemplateStatusLabel("Archived", locale) },
            ]}
          />
          <SelectBox
            label={text.accessFilter}
            value={access}
            disabled={isHubControlsLocked}
            onChange={(value) => setAccess(value as "all" | "free" | "premium")}
            options={[
              { value: "all", label: text.allAccess },
              { value: "free", label: getTemplateAccessLabel(false, dictionary) },
              { value: "premium", label: getTemplateAccessLabel(true, dictionary) },
            ]}
          />
          <SelectBox
            label={text.sortFilter}
            value={sort}
            disabled={isHubControlsLocked}
            onChange={(value) =>
              setSort(value as NonNullable<AdminTemplatesAnalyticsQuery["sort"]>)
            }
            options={[
              { value: "views", label: text.sortViews },
              { value: "starts", label: text.sortStarts },
              { value: "conversion", label: text.sortConversion },
              { value: "cost", label: text.sortCost },
              { value: "updated", label: text.sortUpdated },
            ]}
          />
        </AdminFilterBar>
      </AdminToolbar>

      <div className={styles.kpiGrid}>
        {kpis.map((item) => (
          <AdminKpiCard
            key={item.label}
            label={item.label}
            value={item.value}
            hint={item.hint}
            tone={getKpiTone(item.tone)}
          />
        ))}
      </div>

      <div className={styles.mainGrid}>
        <section className={`${styles.panel} ${styles.panelWide}`}>
          <div className={styles.panelHeaderRow}>
            <div>
              <h2 className={styles.panelTitle}>
                <TrendUpIcon className={styles.panelIcon} />
                {text.trendTitle}
              </h2>
              <p>{text.trendHint}</p>
            </div>
            <div className={styles.chartTabs} aria-label={text.trendTitle}>
              {chartTabs.map((tab) => {
                const isActiveChartMetric = chartMetric === tab.key;

                return (
                  <button
                    key={tab.key}
                    type="button"
                    className={isActiveChartMetric ? styles.chartTabActive : styles.chartTab}
                    disabled={isActiveChartMetric || isHubControlsLocked}
                    onClick={() => setChartMetric(tab.key)}
                  >
                    {tab.label}
                  </button>
                );
              })}
            </div>
          </div>
          <TrendChart
            points={overview.trendPoints}
            metric={chartMetric}
            locale={locale}
            text={text}
          />
        </section>

        <section className={styles.panel}>
          <div className={styles.panelHeader}>
            <h2 className={styles.panelTitle}>
              <DashboardIcon className={styles.panelIcon} />
              {text.funnelTitle}
            </h2>
            <p>{text.funnelHint}</p>
          </div>
          <FunnelList overview={overview} locale={locale} text={text} />
        </section>
      </div>

      <div className={styles.secondaryGrid}>
        <BreakdownPanel
          title={text.categoriesTitle}
          hint={text.categoriesHint}
          rows={overview.categories}
          locale={locale}
          templateCountLabel={text.templateCountLabel}
        />
        <TypePanel rows={overview.templateTypes} locale={locale} text={text} />
        <TopTemplatesPanel rows={overview.topTemplates} locale={locale} text={text} />
      </div>

      <section className={styles.panel}>
        <div className={styles.panelHeader}>
          <h2 className={styles.panelTitle}>
            <ChartIcon className={styles.panelIcon} />
            {text.feedbackTitle}
          </h2>
          <p>{text.feedbackHint}</p>
        </div>
        <FeedbackFeedPanel items={overview.feedbackItems} locale={locale} text={text} />
      </section>

      <div className={styles.dimensionGrid}>
        <EventDimensionPanel
          title={text.sourcesTitle}
          hint={text.sourcesHint}
          rows={overview.sources}
          locale={locale}
        />
        <EventDimensionPanel
          title={text.devicesTitle}
          hint={text.devicesHint}
          rows={overview.devices}
          locale={locale}
        />
        <EventDimensionPanel
          title={text.geographyTitle}
          hint={text.geographyHint}
          rows={overview.geography}
          locale={locale}
        />
      </div>

      <section className={styles.panel}>
        <div className={styles.panelHeaderRow}>
          <div>
            <h2 className={styles.panelTitle}>
              <TableIcon className={styles.panelIcon} />
              {text.tableTitle}
            </h2>
            <p>{text.tableHint}</p>
          </div>
          {overviewQuery.isFetching ? (
            <span className={styles.refreshPill}>{text.refreshing}</span>
          ) : null}
        </div>
        <TemplatesTable rows={overview.templates} locale={locale} text={text} />
      </section>
    </AdminPage>
  );
}
