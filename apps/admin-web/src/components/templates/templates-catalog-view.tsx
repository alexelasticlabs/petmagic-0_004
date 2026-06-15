"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useCallback, useEffect, useMemo, useState, type ReactElement } from "react";

import {
  CalendarIcon,
  CancelCircleIcon,
  CaretDownIcon,
  ChartIcon,
  DollarIcon,
  ImageIcon,
  PencilIcon,
  PlayCircleIcon,
  RefreshIcon,
  VideoIcon,
} from "@/components/admin/admin-icons";
import {
  AdminCard,
  AdminFilterBar,
  AdminPage,
  AdminPageGrid,
  AdminStateCard,
  AdminStatusBadge,
  AdminToolbar,
  adminTableStyles,
} from "@/components/admin/admin-primitives";
import { ensureAdminSession } from "@/components/admin/admin-session";
import { ConfirmationDialog } from "@/components/admin/confirmation-dialog";
import {
  getCharacterOrientationLabel,
  getTemplateAccessLabel,
  getTemplateStatusLabel,
  getTemplateTypeLabel,
} from "@/components/templates/template-admin-shared";
import { TemplatePreviewCard } from "@/components/templates/template-phone-preview-card";
import { TemplateSecureMedia } from "@/components/templates/template-secure-media";
import styles from "@/components/templates/templates-catalog.module.css";
import { useAdminTemplateCatalog } from "@/components/templates/use-admin-template-catalog";
import { useAdminTemplateCategories } from "@/components/templates/use-admin-template-categories";
import { Button } from "@/components/ui/button";
import { Select, type SelectOption } from "@/components/ui/select";
import { getAdminErrorMessage } from "@/lib/admin-error-message";
import {
  changeTemplateStatus,
  deleteTemplate,
  useAuthSession,
  type AdminTemplateListItem,
  type AdminTemplatesAnalyticsTemplateRow,
  type TemplateStatus,
  type TemplateType,
} from "@/lib/api-client";
import { clientLogger } from "@/lib/client-logger";
import { getDictionary, type Locale } from "@/lib/i18n";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

type TemplatesCatalogViewProps = {
  locale: Locale;
  templateType: TemplateType;
  initialCategory?: string;
};

type ViewMode = "cards" | "list";
type ArchiveFilter = "active" | "archived";
type AccessFilter = "all" | "premium" | "free";
type SortMode = "newest" | "title" | "tokens";

const TEMPLATE_CATALOG_SEARCH_MAX_LENGTH = 120;
const TEMPLATE_CATALOG_PAGE_SIZE = 24;

function useDebouncedValue(value: string, delayMs: number) {
  const [debounced, setDebounced] = useState(value);

  useEffect(() => {
    const timeoutId = window.setTimeout(() => setDebounced(value), delayMs);
    return () => window.clearTimeout(timeoutId);
  }, [delayMs, value]);

  return debounced;
}

const statusColors: Record<TemplateStatus, string> = {
  Draft: "var(--warning)",
  Active: "var(--success)",
  Archived: "var(--text-muted)",
};

const METRIC_ICONS: Record<string, ReactElement> = {
  cardMetric_primary: <DollarIcon className={styles.cardMetricIcon} />,
  cardMetric_info: <ImageIcon className={styles.cardMetricIcon} />,
  cardMetric_success: <PlayCircleIcon className={styles.cardMetricIcon} />,
  cardMetric_danger: <CancelCircleIcon className={styles.cardMetricIcon} />,
};

function getCatalogActionErrorDetails(error: unknown) {
  return {
    errorName: error instanceof Error ? error.name : "UnknownError",
    errorDigest:
      error && typeof error === "object" && "digest" in error
        ? sanitizeSensitiveText(String((error as { digest?: unknown }).digest ?? ""), 80)
        : undefined,
  };
}

export function TemplatesCatalogView({
  locale,
  templateType,
  initialCategory,
}: TemplatesCatalogViewProps) {
  const isRu = locale === "ru";
  const text = useMemo(() => getDictionary(locale), [locale]);
  const copy = useMemo(() => getCatalogCopy(locale, templateType), [locale, templateType]);
  const router = useRouter();
  const session = useAuthSession();
  const sessionRoles = session?.user.roles ?? [];
  const canViewTemplates =
    sessionRoles.includes("Admin") || sessionRoles.includes("Moderator");
  const canManageTemplates = session?.user.roles.includes("Admin") ?? false;
  const [actionError, setActionError] = useState<string | null>(null);
  const [busyTemplateId, setBusyTemplateId] = useState<string | null>(null);
  const [viewMode, setViewMode] = useState<ViewMode>("cards");
  const [archiveFilter, setArchiveFilter] = useState<ArchiveFilter>("active");
  const [search, setSearch] = useState("");
  const [categoryFilter, setCategoryFilter] = useState(initialCategory?.trim() || "all");
  const [accessFilter, setAccessFilter] = useState<AccessFilter>("all");
  const [statusFilter, setStatusFilter] = useState<TemplateStatus | "all">("all");
  const [sortMode, setSortMode] = useState<SortMode>("newest");
  const [page, setPage] = useState(1);
  const debouncedSearch = useDebouncedValue(search, 300);
  const effectiveStatusFilter =
    archiveFilter === "active" && statusFilter === "Archived" ? "all" : statusFilter;
  const catalogQuery = useMemo(
    () => ({
      type: templateType,
      status:
        archiveFilter === "archived"
          ? ("Archived" as const)
          : effectiveStatusFilter === "all"
            ? ("not_archived" as const)
            : effectiveStatusFilter,
      search: debouncedSearch,
      category: categoryFilter === "all" ? undefined : categoryFilter,
      access: accessFilter === "all" ? undefined : accessFilter,
      sort: sortMode,
      skip: (page - 1) * TEMPLATE_CATALOG_PAGE_SIZE,
      take: TEMPLATE_CATALOG_PAGE_SIZE,
    }),
    [
      accessFilter,
      archiveFilter,
      categoryFilter,
      debouncedSearch,
      effectiveStatusFilter,
      page,
      sortMode,
      templateType,
    ]
  );
  const {
    getAnalyticsRow,
    hasError,
    hasMore,
    hasSecondaryError,
    isCatalogFetching,
    isFetching,
    isLoading,
    pageSkip,
    pageTake,
    refresh,
    templates,
    totalCount,
  } = useAdminTemplateCatalog({
    enabled: canViewTemplates,
    query: catalogQuery,
    templateType,
  });
  const categoriesQuery = useAdminTemplateCategories({
    enabled: canViewTemplates,
    includeArchived: true,
  });
  const [templatePendingArchiveId, setTemplatePendingArchiveId] = useState<string | null>(null);
  const [templatePendingDeleteId, setTemplatePendingDeleteId] = useState<string | null>(null);
  const isTemplateActionLocked = busyTemplateId !== null;
  const isCatalogRefreshing = isCatalogFetching && !isLoading;
  const isCatalogInteractionLocked = isTemplateActionLocked || isCatalogRefreshing;
  const error = actionError ?? (hasError ? text.errorLoadingTemplates : null);

  useEffect(() => {
    if (!canViewTemplates) {
      ensureAdminSession(locale, router);
    }
  }, [canViewTemplates, locale, router, session]);

  function assertCanManageTemplates(): boolean {
    if (canManageTemplates) {
      return true;
    }

    setActionError(copy.templateActionsAdminOnly);
    setTemplatePendingArchiveId(null);
    setTemplatePendingDeleteId(null);
    return false;
  }

  async function handleStatusChange(templateId: string, status: TemplateStatus): Promise<boolean> {
    if (!assertCanManageTemplates()) {
      return false;
    }

    if (isCatalogInteractionLocked) {
      return false;
    }

    setBusyTemplateId(templateId);
    setActionError(null);

    try {
      await changeTemplateStatus(templateId, status);
      await refresh();
      return true;
    } catch (error) {
      clientLogger.error("templates.catalog_status_change_failed", {
        templateId: sanitizeSensitiveText(templateId, 80),
        status,
        ...getCatalogActionErrorDetails(error),
      });
      setActionError(getAdminErrorMessage(error, text.errorSavingTemplate));
      return false;
    } finally {
      setBusyTemplateId(null);
    }
  }

  function requestStatusChange(templateId: string, status: TemplateStatus) {
    if (!assertCanManageTemplates()) {
      return;
    }

    if (isCatalogInteractionLocked) {
      return;
    }

    if (status === "Archived") {
      setTemplatePendingArchiveId(templateId);
      return;
    }

    void handleStatusChange(templateId, status);
  }

  function requestDeleteTemplate(templateId: string) {
    if (!assertCanManageTemplates()) {
      return;
    }

    if (isCatalogInteractionLocked) {
      return;
    }

    setTemplatePendingDeleteId(templateId);
  }

  async function handleDelete(templateId: string): Promise<boolean> {
    if (!assertCanManageTemplates()) {
      return false;
    }

    if (isCatalogInteractionLocked) {
      return false;
    }

    setBusyTemplateId(templateId);
    setActionError(null);

    try {
      await deleteTemplate(templateId);
      await refresh();
      return true;
    } catch (error) {
      clientLogger.error("templates.catalog_delete_failed", {
        templateId: sanitizeSensitiveText(templateId, 80),
        ...getCatalogActionErrorDetails(error),
      });
      setActionError(getAdminErrorMessage(error, text.errorDeletingTemplate));
      return false;
    } finally {
      setBusyTemplateId(null);
    }
  }

  const editorBasePath = `/${locale}/templates/${templateType === "Video" ? "video" : "image"}/editor`;
  const testBasePath = `/${locale}/templates/${templateType === "Video" ? "video" : "image"}/test`;
  const analyticsBasePath = `/${locale}/templates/${templateType === "Video" ? "video" : "image"}/analytics`;
  const categoriesPath = `/${locale}/templates/categories`;
  const categoryOptions: SelectOption[] = useMemo(
    () => [
      { value: "all", label: copy.allCategories, tone: "neutral" },
      ...categoriesQuery.categories.map((category) => ({
        value: category.name,
        label: sanitizeSensitiveText(category.name, 80),
        tone: "neutral" as const,
      })),
    ],
    [categoriesQuery.categories, copy]
  );
  const accessOptions: SelectOption[] = [
    { value: "all", label: copy.allAccess, tone: "neutral" },
    { value: "premium", label: text.premiumLabel, tone: "premium" },
    { value: "free", label: text.freeLabel, tone: "recommended" },
  ];
  const statusOptions: SelectOption[] = useMemo(
    () =>
      archiveFilter === "archived"
        ? [
            { value: "all", label: copy.allStatuses, tone: "neutral" },
            {
              value: "Archived",
              label: getTemplateStatusLabel("Archived", locale),
              tone: "neutral",
            },
          ]
        : [
            { value: "all", label: copy.allStatuses, tone: "neutral" },
            { value: "Active", label: getTemplateStatusLabel("Active", locale), tone: "premium" },
            { value: "Draft", label: getTemplateStatusLabel("Draft", locale), tone: "fast" },
          ],
    [archiveFilter, copy, locale]
  );
  const sortOptions: SelectOption[] = useMemo(
    () => [
      {
        value: "newest",
        label: copy.sortNewest,
        description: locale === "ru" ? "Сначала свежие шаблоны" : "Most recent templates first",
        tone: "recommended",
      },
      {
        value: "title",
        label: copy.sortTitle,
        description: locale === "ru" ? "Алфавитный порядок" : "Alphabetical order",
        tone: "neutral",
      },
      {
        value: "tokens",
        label: copy.sortTokens,
        description: locale === "ru" ? "По стоимости в PawSpark" : "By PawSpark cost",
        tone: "fast",
      },
    ],
    [copy, locale]
  );
  const currentPage = page;
  const totalPages = Math.max(1, Math.ceil(totalCount / Math.max(1, pageTake)));
  const shownStart = templates.length > 0 ? pageSkip + 1 : 0;
  const shownEnd = templates.length > 0 ? Math.min(totalCount, pageSkip + templates.length) : 0;
  const visibleTemplateIds = useMemo(
    () => new Set(templates.map((template) => template.templateId)),
    [templates]
  );
  const resetPendingTemplateAction = useCallback(() => {
    if (isTemplateActionLocked) {
      return;
    }

    setTemplatePendingArchiveId(null);
    setTemplatePendingDeleteId(null);
  }, [isTemplateActionLocked]);
  const resetCatalogContext = useCallback(
    (nextPage = 1) => {
      resetPendingTemplateAction();
      setPage(nextPage);
    },
    [resetPendingTemplateAction]
  );
  useEffect(() => {
    if (!isFetching && currentPage > totalPages) {
      queueMicrotask(() => resetCatalogContext(totalPages));
    }
  }, [currentPage, isFetching, resetCatalogContext, totalPages]);
  useEffect(() => {
    if (isCatalogInteractionLocked) {
      return;
    }

    const shouldResetArchive =
      templatePendingArchiveId !== null && !visibleTemplateIds.has(templatePendingArchiveId);
    const shouldResetDelete =
      templatePendingDeleteId !== null && !visibleTemplateIds.has(templatePendingDeleteId);

    if (!shouldResetArchive && !shouldResetDelete) {
      return;
    }

    queueMicrotask(() => {
      if (shouldResetArchive) {
        setTemplatePendingArchiveId(null);
      }

      if (shouldResetDelete) {
        setTemplatePendingDeleteId(null);
      }
    });
  }, [
    isCatalogInteractionLocked,
    templatePendingArchiveId,
    templatePendingDeleteId,
    visibleTemplateIds,
  ]);
  function requestCatalogRetry() {
    if (!canViewTemplates || isFetching) {
      return;
    }

    void refresh().catch(() => undefined);
  }

  const visiblePageNumbers = useMemo(() => {
    const end = totalCount > 0 ? Math.min(totalPages, Math.max(currentPage, 1)) : currentPage;
    const start = Math.max(1, end - 4);
    return Array.from({ length: end - start + 1 }, (_, index) => start + index);
  }, [currentPage, totalCount, totalPages]);

  if (!canViewTemplates || isLoading) {
    return (
      <AdminPage className={styles.catalogPage}>
        <AdminPageGrid
          columns="four"
          className={styles.loadingGrid}
          aria-busy="true"
          aria-live="polite"
        >
          {Array.from({ length: 8 }).map((_, index) => (
            <div key={index} className={styles.skeletonCard} />
          ))}
        </AdminPageGrid>
      </AdminPage>
    );
  }

  return (
    <AdminPage className={styles.catalogPage}>
      <AdminToolbar className={styles.catalogActions}>
        {canManageTemplates ? (
          <Link href={categoriesPath} className={styles.secondaryLink}>
            {copy.manageCategories}
          </Link>
        ) : null}
        {canManageTemplates ? (
          <Link href={editorBasePath} className={styles.primaryLink}>
            {copy.createTemplate}
          </Link>
        ) : null}
      </AdminToolbar>

      <div className={styles.tabRow} role="tablist" aria-label={copy.archiveTabsLabel}>
        <button
          type="button"
          className={archiveFilter === "active" ? styles.tabActive : styles.tab}
          disabled={archiveFilter === "active" || isCatalogInteractionLocked}
          onClick={() => {
            setArchiveFilter("active");
            setStatusFilter("all");
            resetCatalogContext();
          }}
        >
          {copy.allTemplates}
        </button>
        <button
          type="button"
          className={archiveFilter === "archived" ? styles.tabActive : styles.tab}
          disabled={archiveFilter === "archived" || isCatalogInteractionLocked}
          onClick={() => {
            setArchiveFilter("archived");
            setStatusFilter("all");
            resetCatalogContext();
          }}
        >
          {copy.archivedTemplates}
        </button>
      </div>

      {error ? (
        <AdminStateCard
          tone="danger"
          className={styles.error}
          title={error}
          action={
            <Button
              type="button"
              variant="secondary"
              disabled={!canViewTemplates || isFetching}
              onClick={requestCatalogRetry}
            >
              {isRu ? "Повторить" : "Retry"}
            </Button>
          }
        />
      ) : null}

      {hasSecondaryError ? (
        <AdminStateCard
          tone="warning"
          className={styles.error}
          title={copy.analyticsUnavailableTitle}
          description={copy.analyticsUnavailableDescription}
          action={
            <Button
              type="button"
              variant="secondary"
              disabled={!canViewTemplates || isFetching}
              onClick={requestCatalogRetry}
            >
              {isRu ? "Повторить" : "Retry"}
            </Button>
          }
        />
      ) : null}

      <div className={styles.catalogShell}>
        <div className={styles.catalogMain}>
          <AdminFilterBar className={styles.filtersBar}>
            <label className={styles.searchField}>
              <span className={styles.visuallyHidden}>{copy.searchLabel}</span>
              <input
                value={search}
                onChange={(event) => {
                  setSearch(event.target.value.slice(0, TEMPLATE_CATALOG_SEARCH_MAX_LENGTH));
                  resetCatalogContext();
                }}
                maxLength={TEMPLATE_CATALOG_SEARCH_MAX_LENGTH}
                placeholder={copy.searchPlaceholder}
                disabled={isCatalogInteractionLocked}
              />
            </label>

            <label className={styles.selectField}>
              <span>{text.categoryLabel}</span>
              <Select
                value={categoryFilter}
                options={categoryOptions}
                ariaLabel={text.categoryLabel}
                disabled={isCatalogInteractionLocked}
                onChange={(value) => {
                  setCategoryFilter(value);
                  resetCatalogContext();
                }}
              />
            </label>

            <label className={styles.selectField}>
              <span>{copy.accessLabel}</span>
              <Select
                value={accessFilter}
                options={accessOptions}
                ariaLabel={copy.accessLabel}
                disabled={isCatalogInteractionLocked}
                onChange={(value) => {
                  setAccessFilter(value as AccessFilter);
                  resetCatalogContext();
                }}
              />
            </label>

            <label className={styles.selectField}>
              <span>{text.statusLabel}</span>
              <Select
                value={statusFilter}
                options={statusOptions}
                ariaLabel={text.statusLabel}
                disabled={isCatalogInteractionLocked}
                onChange={(value) => {
                  setStatusFilter(value as TemplateStatus | "all");
                  resetCatalogContext();
                }}
              />
            </label>

            <label className={styles.selectField}>
              <span>{copy.sortLabel}</span>
              <Select
                value={sortMode}
                options={sortOptions}
                ariaLabel={copy.sortLabel}
                showSelectedDescription={false}
                disabled={isCatalogInteractionLocked}
                onChange={(value) => {
                  setSortMode(value as SortMode);
                  resetCatalogContext();
                }}
              />
            </label>

            <div className={styles.viewToggleShell}>
              <span className={styles.viewToggleCaption}>{copy.viewToggleLabel}</span>
              <div className={styles.viewToggle} role="group" aria-label={copy.viewToggleLabel}>
                <button
                  type="button"
                  className={viewMode === "cards" ? styles.viewButtonActive : styles.viewButton}
                  aria-pressed={viewMode === "cards"}
                  disabled={viewMode === "cards" || isCatalogInteractionLocked}
                  onClick={() => setViewMode("cards")}
                >
                  <span
                    className={`${styles.viewButtonGlyph} ${styles.viewButtonGlyphCards}`}
                    aria-hidden="true"
                  >
                    <span />
                    <span />
                    <span />
                    <span />
                  </span>
                  <span>{copy.cardsView}</span>
                </button>
                <button
                  type="button"
                  className={viewMode === "list" ? styles.viewButtonActive : styles.viewButton}
                  aria-pressed={viewMode === "list"}
                  disabled={viewMode === "list" || isCatalogInteractionLocked}
                  onClick={() => setViewMode("list")}
                >
                  <span
                    className={`${styles.viewButtonGlyph} ${styles.viewButtonGlyphList}`}
                    aria-hidden="true"
                  >
                    <span />
                    <span />
                    <span />
                  </span>
                  <span>{copy.listView}</span>
                </button>
              </div>
            </div>
          </AdminFilterBar>
          {isCatalogRefreshing ? (
            <AdminStateCard tone="info" className={styles.empty} title={text.loading} />
          ) : !templates.length ? (
            <AdminStateCard tone="info" className={styles.empty} title={text.noTemplates} />
          ) : viewMode === "cards" ? (
            <div className={styles.cardGrid} aria-busy={isFetching ? "true" : undefined}>
              {templates.map((template) => (
                <TemplateCatalogCard
                  key={template.templateId}
                  locale={locale}
                  template={template}
                  analytics={getAnalyticsRow(template.templateId)}
                  editorBasePath={editorBasePath}
                  analyticsBasePath={analyticsBasePath}
                  testBasePath={testBasePath}
                  busyTemplateId={
                    isCatalogInteractionLocked ? (busyTemplateId ?? "__refresh__") : null
                  }
                  canManageTemplates={canManageTemplates}
                  onStatusChange={requestStatusChange}
                  onDeleteTemplate={requestDeleteTemplate}
                />
              ))}
            </div>
          ) : (
            <AdminCard padding="md" className={styles.listCard}>
              <div className={adminTableStyles.tableWrap} aria-busy={isFetching ? "true" : undefined}>
                <table className={`${adminTableStyles.table} ${styles.listTable}`}>
                  <thead>
                    <tr>
                      <th>{isRu ? "Шаблон" : "Template"}</th>
                      <th>{isRu ? "Тип" : "Type"}</th>
                      <th>{text.categoryLabel}</th>
                      <th>{copy.accessLabel}</th>
                      <th>{text.statusLabel}</th>
                      <th>{isRu ? "Просмотры" : "Views"}</th>
                      <th>{isRu ? "Запуски" : "Starts"}</th>
                      <th>{isRu ? "Конверсия" : "Conversion"}</th>
                      <th>{isRu ? "Успех" : "Success"}</th>
                      <th>{isRu ? "Средняя стоимость" : "Average cost"}</th>
                      <th>{copy.updatedLabel}</th>
                      <th>{text.actionsLabel}</th>
                    </tr>
                  </thead>
                  <tbody>
                    {templates.map((template) => {
                      const isBusy = isCatalogInteractionLocked;
                      const analytics = getAnalyticsRow(template.templateId);
                      const safeTemplateTitle = sanitizeSensitiveText(template.title, 96);
                      const safeTemplateDescription = sanitizeSensitiveText(
                        template.shortDescription,
                        180
                      );
                      const safeTemplateCategory = sanitizeSensitiveText(template.category, 64);

                      return (
                        <tr key={template.templateId}>
                          <td data-label={isRu ? "Шаблон" : "Template"}>
                            <div className={styles.listTemplateCell}>
                              <div
                                className={`${styles.listTemplateThumb} ${template.templateType === "Video" ? styles.listTemplateThumbVideo : ""}`.trim()}
                                aria-hidden="true"
                              >
                                {template.previewAsset?.url ? (
                                  template.previewAsset.contentType?.startsWith("video/") ? (
                                    <TemplateSecureMedia
                                      className={styles.listTemplateMedia}
                                      url={template.previewAsset.url}
                                      kind="video"
                                      muted
                                      playsInline
                                      autoPlay
                                      loop
                                      preload="metadata"
                                      ariaHidden
                                      logContext={{
                                        templateId: template.templateId,
                                        contentType: template.previewAsset.contentType,
                                        surface: "catalog_list",
                                      }}
                                    />
                                  ) : (
                                    <TemplateSecureMedia
                                      className={styles.listTemplateMedia}
                                      url={template.previewAsset.url}
                                      kind="image"
                                      alt=""
                                      width={56}
                                      height={56}
                                      ariaHidden
                                      logContext={{
                                        templateId: template.templateId,
                                        contentType: template.previewAsset.contentType,
                                        surface: "catalog_list",
                                      }}
                                    />
                                  )
                                ) : template.templateType === "Video" ? (
                                  <VideoIcon className={styles.listTemplateThumbIcon} />
                                ) : (
                                  <ImageIcon className={styles.listTemplateThumbIcon} />
                                )}
                              </div>
                              <div className={styles.titleCell} title={safeTemplateDescription}>
                                <strong>{safeTemplateTitle}</strong>
                                <span>{safeTemplateDescription}</span>
                                <small className={styles.templateMetaId}>
                                  ID: {formatTemplateId(template.templateId, 12)}
                                </small>
                              </div>
                            </div>
                          </td>
                          <td data-label={isRu ? "Тип" : "Type"}>
                            <div className={styles.typeCell}>
                              <span className={styles.typeBadge}>
                                {template.templateType === "Video" ? (
                                  <VideoIcon className={styles.typeIcon} />
                                ) : (
                                  <ImageIcon className={styles.typeIcon} />
                                )}
                                {getTemplateTypeLabel(template.templateType, text)}
                              </span>
                              <span className={styles.typeMeta}>
                                {template.templateType === "Video"
                                  ? formatDuration(template.referenceVideoDurationSeconds)
                                  : getCharacterOrientationLabel(
                                      template.characterOrientation,
                                      text
                                    )}
                              </span>
                            </div>
                          </td>
                          <td data-label={text.categoryLabel}>{safeTemplateCategory}</td>
                          <td data-label={copy.accessLabel}>
                            <span
                              className={template.isPremium ? styles.premiumPill : styles.freePill}
                            >
                              {getTemplateAccessLabel(template.isPremium, text)}
                            </span>
                          </td>
                          <td data-label={text.statusLabel}>
                            <AdminStatusBadge
                              className={styles.listStatusBadge}
                              color={statusColors[template.status]}
                            >
                              {getTemplateStatusLabel(template.status, locale)}
                            </AdminStatusBadge>
                          </td>
                          <td
                            data-label={isRu ? "Просмотры" : "Views"}
                            className={styles.metricValueCell}
                          >
                            {formatAnalyticsInteger(analytics?.views, locale)}
                          </td>
                          <td
                            data-label={isRu ? "Запуски" : "Starts"}
                            className={styles.metricValueCell}
                          >
                            {formatAnalyticsInteger(analytics?.generationStarts, locale)}
                          </td>
                          <td
                            data-label={isRu ? "Конверсия" : "Conversion"}
                            className={styles.metricValueCell}
                          >
                            {formatPercentMetric(
                              analytics?.generationStarts ? analytics.conversionPercent : null,
                              locale
                            )}
                          </td>
                          <td
                            data-label={isRu ? "Успех" : "Success"}
                            className={styles.metricValueCell}
                          >
                            {formatPercentMetric(getSuccessRatePercent(analytics), locale)}
                          </td>
                          <td
                            data-label={isRu ? "Средняя стоимость" : "Average cost"}
                            className={styles.numericCell}
                          >
                            {formatAnalyticsInteger(template.tokenCost, locale)}{" "}
                            <span className={styles.numericSuffix}>{copy.tokensShort}</span>
                          </td>
                          <td data-label={copy.updatedLabel}>
                            <div className={styles.updatedCell}>
                              <CalendarIcon className={styles.updatedIcon} />
                              <span>{formatDate(template.updatedAtUtc, locale)}</span>
                            </div>
                          </td>
                          <td data-label={text.actionsLabel} className={styles.tableActionsCell}>
                            <div className={styles.tableActions}>
                              <Link
                                href={`${analyticsBasePath}/${encodeURIComponent(template.templateId)}`}
                                className={`${styles.cardActionIconButton}${
                                  isBusy ? ` ${styles.cardActionIconButtonDisabled}` : ""
                                }`}
                                aria-label={copy.analyticsAction}
                                aria-disabled={isBusy}
                                tabIndex={isBusy ? -1 : undefined}
                                title={copy.analyticsAction}
                                onClick={(event) => {
                                  if (isBusy) {
                                    event.preventDefault();
                                  }
                                }}
                              >
                                <ChartIcon className={styles.actionIcon} />
                              </Link>
                              {canManageTemplates ? (
                                <>
                                  <Link
                                    href={`${editorBasePath}?templateId=${encodeURIComponent(template.templateId)}`}
                                    className={`${styles.cardActionIconButton}${
                                      isBusy ? ` ${styles.cardActionIconButtonDisabled}` : ""
                                    }`}
                                    aria-label={text.editTemplate}
                                    aria-disabled={isBusy}
                                    tabIndex={isBusy ? -1 : undefined}
                                    title={text.editTemplate}
                                    onClick={(event) => {
                                      if (isBusy) {
                                        event.preventDefault();
                                      }
                                    }}
                                  >
                                    <PencilIcon className={styles.actionIcon} />
                                  </Link>
                                  <Link
                                    href={`${testBasePath}/${encodeURIComponent(template.templateId)}`}
                                    className={`${styles.cardActionIconButton}${
                                      isBusy ? ` ${styles.cardActionIconButtonDisabled}` : ""
                                    }`}
                                    aria-label={copy.testAction}
                                    aria-disabled={isBusy}
                                    tabIndex={isBusy ? -1 : undefined}
                                    title={copy.testAction}
                                    onClick={(event) => {
                                      if (isBusy) {
                                        event.preventDefault();
                                      }
                                    }}
                                  >
                                    <PlayCircleIcon className={styles.actionIcon} />
                                  </Link>
                                  {template.status !== "Active" ? (
                                    <Button
                                      size="sm"
                                      variant="ghost"
                                      className={styles.cardActionIconButton}
                                      disabled={isBusy}
                                      aria-label={text.activate}
                                      title={text.activate}
                                      onClick={() =>
                                        void handleStatusChange(template.templateId, "Active")
                                      }
                                    >
                                      <RefreshIcon className={styles.actionIcon} />
                                    </Button>
                                  ) : null}
                                  {template.status !== "Archived" ? (
                                    <Button
                                      size="sm"
                                      variant="danger"
                                      className={`${styles.cardActionIconButton} ${styles.cardActionDanger}`}
                                      disabled={isBusy}
                                      aria-label={text.archive}
                                      title={text.archive}
                                      onClick={() =>
                                        requestStatusChange(template.templateId, "Archived")
                                      }
                                    >
                                      <RefreshIcon className={styles.actionIcon} />
                                    </Button>
                                  ) : null}
                                  <Button
                                    size="sm"
                                    variant="danger"
                                    className={`${styles.cardActionIconButton} ${styles.cardActionDanger}`}
                                    disabled={isBusy}
                                    aria-label={text.deleteTemplate}
                                    title={text.deleteTemplate}
                                    onClick={() => requestDeleteTemplate(template.templateId)}
                                  >
                                    <CancelCircleIcon className={styles.actionIcon} />
                                  </Button>
                                </>
                              ) : null}
                            </div>
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            </AdminCard>
          )}
          {templates.length || currentPage > 1 ? (
            <div className={styles.paginationBar}>
              <span>
                {isRu
                  ? `Страница ${currentPage}: ${shownStart}-${shownEnd} из ${totalCount}`
                  : `Page ${currentPage}: showing ${shownStart}-${shownEnd} of ${totalCount}`}
              </span>
              <div className={styles.paginationActions}>
                <Button
                  type="button"
                  variant="secondary"
                  size="sm"
                  disabled={currentPage <= 1 || isFetching}
                  aria-label={copy.previousPageLabel}
                  title={copy.previousPageLabel}
                  onClick={() => resetCatalogContext(Math.max(1, currentPage - 1))}
                >
                  <CaretDownIcon className={`${styles.pageIcon} ${styles.pageIconPrevious}`} />
                </Button>
                {visiblePageNumbers.map((pageNumber) => (
                  <Button
                    key={pageNumber}
                    type="button"
                    variant={pageNumber === currentPage ? "primary" : "secondary"}
                    size="sm"
                    disabled={isFetching}
                    onClick={() => resetCatalogContext(pageNumber)}
                  >
                    {pageNumber}
                  </Button>
                ))}
                <Button
                  type="button"
                  variant="secondary"
                  size="sm"
                  disabled={currentPage >= totalPages || !hasMore || isFetching}
                  aria-label={copy.nextPageLabel}
                  title={copy.nextPageLabel}
                  onClick={() => resetCatalogContext(currentPage + 1)}
                >
                  <CaretDownIcon className={`${styles.pageIcon} ${styles.pageIconNext}`} />
                </Button>
              </div>
            </div>
          ) : null}
        </div>
      </div>
      <ConfirmationDialog
        open={templatePendingArchiveId !== null}
        title={text.archive}
        description={
          templatePendingArchiveId
            ? `${formatTemplateActionLabel(templates, templatePendingArchiveId)}: ${
                isRu
                  ? "шаблон будет скрыт из активного каталога."
                  : "the template will be hidden from the active catalog."
              }`
            : ""
        }
        confirmLabel={text.archive}
        cancelLabel={isRu ? "Отмена" : "Cancel"}
        tone="danger"
        isSubmitting={Boolean(templatePendingArchiveId && isTemplateActionLocked)}
        onCancel={() => {
          if (!isTemplateActionLocked) {
            setTemplatePendingArchiveId(null);
          }
        }}
        onConfirm={() => {
          if (!templatePendingArchiveId) {
            return;
          }

          void handleStatusChange(templatePendingArchiveId, "Archived").then((succeeded) => {
            if (succeeded) {
              setTemplatePendingArchiveId(null);
            }
          });
        }}
      />
      <ConfirmationDialog
        open={templatePendingDeleteId !== null}
        title={text.deleteTemplate}
        description={
          templatePendingDeleteId
            ? `${formatTemplateActionLabel(templates, templatePendingDeleteId)}: ${text.confirmDeleteTemplate}`
            : ""
        }
        confirmLabel={text.deleteTemplate}
        cancelLabel={isRu ? "Отмена" : "Cancel"}
        isSubmitting={Boolean(templatePendingDeleteId && isTemplateActionLocked)}
        onCancel={() => {
          if (!isTemplateActionLocked) {
            setTemplatePendingDeleteId(null);
          }
        }}
        onConfirm={() => {
          if (!templatePendingDeleteId) {
            return;
          }

          void handleDelete(templatePendingDeleteId).then((succeeded) => {
            if (succeeded) {
              setTemplatePendingDeleteId(null);
            }
          });
        }}
      />
    </AdminPage>
  );
}

function formatTemplateActionLabel(templates: AdminTemplateListItem[], templateId: string): string {
  const template = templates.find((item) => item.templateId === templateId);
  return sanitizeSensitiveText(template?.title ?? templateId, 96);
}

function formatTemplateId(templateId: string, maxLength: number): string {
  return sanitizeSensitiveText(templateId, Math.max(maxLength, 1)).slice(0, maxLength);
}

type TemplateCatalogCardProps = {
  locale: Locale;
  template: AdminTemplateListItem;
  analytics?: AdminTemplatesAnalyticsTemplateRow;
  editorBasePath: string;
  analyticsBasePath: string;
  testBasePath: string;
  busyTemplateId: string | null;
  canManageTemplates: boolean;
  onStatusChange: (templateId: string, status: TemplateStatus) => void;
  onDeleteTemplate: (templateId: string) => void;
};

function TemplateCatalogCard({
  locale,
  template,
  analytics,
  editorBasePath,
  analyticsBasePath,
  testBasePath,
  busyTemplateId,
  canManageTemplates,
  onStatusChange,
  onDeleteTemplate,
}: TemplateCatalogCardProps) {
  const text = getDictionary(locale);
  const copy = getCatalogCopy(locale, template.templateType);
  const isBusy = busyTemplateId !== null;

  return (
    <article className={styles.templateCard}>
      <TemplatePreviewCard
        className={styles.previewCard}
        title={template.title}
        shortDescription={template.shortDescription}
        tags={template.tags}
        previewUrl={template.previewAsset?.url}
        previewContentType={template.previewAsset?.contentType}
        templateKind={template.templateType === "Video" ? "video" : "image"}
        templateKindLabel={
          template.templateType === "Video"
            ? text.templateKindVideoBadge
            : text.templateKindImageBadge
        }
        tokenCost={template.tokenCost}
        category={template.category}
        isPremium={template.isPremium}
        accessLabel={getTemplateAccessLabel(template.isPremium, text)}
        referenceDurationSeconds={template.referenceVideoDurationSeconds}
        promoBadge={template.effectivePromoBadge}
        musicDescription={template.musicDescription}
      />
      <div className={styles.cardBody}>
        <div className={styles.cardFooter}>
          <span className={styles.cardTimestamp}>
            {copy.updatedShort} {formatDate(template.updatedAtUtc, locale)}
          </span>
          <AdminStatusBadge className={styles.cardStatusBadge} color={statusColors[template.status]}>
            {getTemplateStatusLabel(template.status, locale)}
          </AdminStatusBadge>
        </div>
        <div className={styles.cardMetrics}>
          {getTemplateCardMetrics(template, analytics, locale).map((metric) => (
            <div
              key={metric.label}
              className={`${styles.cardMetric} ${styles[metric.tone]}`}
              title={metric.label}
            >
              {METRIC_ICONS[metric.tone]}
              <strong>{metric.value}</strong>
            </div>
          ))}
        </div>
        <div className={styles.cardActions}>
          <Link
            href={`${analyticsBasePath}/${encodeURIComponent(template.templateId)}`}
            className={`${styles.cardActionIconButton}${
              isBusy ? ` ${styles.cardActionIconButtonDisabled}` : ""
            }`}
            aria-label={copy.analyticsAction}
            aria-disabled={isBusy}
            tabIndex={isBusy ? -1 : undefined}
            title={copy.analyticsAction}
            onClick={(event) => {
              if (isBusy) {
                event.preventDefault();
              }
            }}
          >
            <ChartIcon className={styles.actionIcon} />
          </Link>
          {canManageTemplates ? (
            <>
              <Link
                href={`${editorBasePath}?templateId=${encodeURIComponent(template.templateId)}`}
                className={`${styles.cardActionIconButton}${
                  isBusy ? ` ${styles.cardActionIconButtonDisabled}` : ""
                }`}
                aria-label={text.editTemplate}
                aria-disabled={isBusy}
                tabIndex={isBusy ? -1 : undefined}
                title={text.editTemplate}
                onClick={(event) => {
                  if (isBusy) {
                    event.preventDefault();
                  }
                }}
              >
                <PencilIcon className={styles.actionIcon} />
              </Link>
              <Link
                href={`${testBasePath}/${encodeURIComponent(template.templateId)}`}
                className={`${styles.cardActionIconButton}${
                  isBusy ? ` ${styles.cardActionIconButtonDisabled}` : ""
                }`}
                aria-label={copy.testAction}
                aria-disabled={isBusy}
                tabIndex={isBusy ? -1 : undefined}
                title={copy.testAction}
                onClick={(event) => {
                  if (isBusy) {
                    event.preventDefault();
                  }
                }}
              >
                <PlayCircleIcon className={styles.actionIcon} />
              </Link>
              {template.status !== "Active" ? (
                <Button
                  size="sm"
                  variant="ghost"
                  className={styles.cardActionIconButton}
                  disabled={isBusy}
                  aria-label={text.activate}
                  title={text.activate}
                  onClick={() => onStatusChange(template.templateId, "Active")}
                >
                  <RefreshIcon className={styles.actionIcon} />
                </Button>
              ) : (
                <Button
                  size="sm"
                  variant="ghost"
                  className={`${styles.cardActionIconButton} ${styles.cardActionDanger}`}
                  disabled={isBusy}
                  aria-label={text.archive}
                  title={text.archive}
                  onClick={() => onStatusChange(template.templateId, "Archived")}
                >
                  <RefreshIcon className={styles.actionIcon} />
                </Button>
              )}
              <Button
                size="sm"
                variant="danger"
                className={`${styles.cardActionIconButton} ${styles.cardActionDanger}`}
                disabled={isBusy}
                aria-label={text.deleteTemplate}
                title={text.deleteTemplate}
                onClick={() => onDeleteTemplate(template.templateId)}
              >
                <CancelCircleIcon className={styles.actionIcon} />
              </Button>
            </>
          ) : null}
        </div>
      </div>
    </article>
  );
}

function formatDate(value: string, locale: Locale) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return "-";
  }

  return new Intl.DateTimeFormat(locale === "ru" ? "ru-RU" : "en-US", {
    day: "2-digit",
    month: "short",
    year: "numeric",
  }).format(date);
}

function formatDuration(seconds?: number) {
  if (!seconds) {
    return "-";
  }

  const roundedSeconds = Math.max(0, Math.round(seconds));
  const minutes = Math.floor(roundedSeconds / 60)
    .toString()
    .padStart(2, "0");
  const remainder = (roundedSeconds % 60).toString().padStart(2, "0");
  return `${minutes}:${remainder}`;
}

function formatAnalyticsInteger(value: number | null | undefined, locale: Locale) {
  if (value === undefined || value === null) {
    return "-";
  }

  return new Intl.NumberFormat(locale === "ru" ? "ru-RU" : "en-US").format(value);
}

function formatPercentMetric(value: number | null | undefined, locale: Locale) {
  if (value === undefined || value === null || Number.isNaN(value)) {
    return "-";
  }

  return `${new Intl.NumberFormat(locale === "ru" ? "ru-RU" : "en-US", {
    minimumFractionDigits: 1,
    maximumFractionDigits: 1,
  }).format(value)}%`;
}

function getSuccessRatePercent(analytics?: AdminTemplatesAnalyticsTemplateRow) {
  if (!analytics) {
    return null;
  }

  const finishedCount = analytics.completedGenerations + analytics.failedGenerations;
  if (finishedCount <= 0) {
    return null;
  }

  return (analytics.completedGenerations / finishedCount) * 100;
}

function getTemplateCardMetrics(
  template: AdminTemplateListItem,
  analytics: AdminTemplatesAnalyticsTemplateRow | undefined,
  locale: Locale
) {
  const isRu = locale === "ru";
  const costValue =
    template.estimatedCostUsd !== undefined && template.estimatedCostUsd !== null
      ? `$${template.estimatedCostUsd.toFixed(3)}`
      : `${formatAnalyticsInteger(template.tokenCost, locale)} ${isRu ? "ток." : "tok."}`;

  const metrics = [
    {
      label: isRu ? "Стоимость" : "Template cost",
      value: costValue,
      tone: "cardMetric_primary",
    },
    {
      label: isRu ? "Просмотры" : "Views",
      value: formatAnalyticsInteger(analytics?.views, locale),
      tone: "cardMetric_info",
    },
    {
      label: isRu ? "Генерации" : "Generations",
      value: formatAnalyticsInteger(analytics?.generationStarts, locale),
      tone: "cardMetric_success",
    },
    {
      label: isRu ? "Ошибки" : "Errors",
      value: formatAnalyticsInteger(analytics?.failedGenerations, locale),
      tone: "cardMetric_danger",
    },
  ];

  return metrics;
}

function getCatalogCopy(locale: Locale, templateType: TemplateType) {
  const isRu = locale === "ru";
  const isVideo = templateType === "Video";

  return {
    title: isVideo
      ? isRu
        ? "Видео шаблоны"
        : "Video Templates"
      : isRu
        ? "Шаблоны изображений"
        : "Image Templates",
    description: isVideo
      ? isRu
        ? "Каталог motion-шаблонов, статусы, категории и параметры доступа."
        : "Motion template catalog, statuses, categories, and access settings."
      : isRu
        ? "Каталог шаблонов изображений, статусы, категории и параметры доступа."
        : "Image template catalog, statuses, categories, and access settings.",
    createTemplate: isVideo
      ? isRu
        ? "Создать видео шаблон"
        : "Create video template"
      : isRu
        ? "Создать шаблон изображения"
        : "Create image template",
    manageCategories: isRu ? "Управление категориями" : "Manage categories",
    analyticsAction: isRu ? "Аналитика" : "Analytics",
    templateActionsAdminOnly: isRu
      ? "Управление шаблонами доступно только Admin."
      : "Template management actions are available to Admin only.",
    analyticsUnavailableTitle: isRu
      ? "Метрики шаблонов временно недоступны"
      : "Template metrics are temporarily unavailable",
    analyticsUnavailableDescription: isRu
      ? "Каталог остается доступным, но просмотры, генерации и ошибки могут быть неполными."
      : "The catalog is still available, but views, generations, and error metrics may be incomplete.",
    archiveTabsLabel: isRu ? "Фильтр архива" : "Archive filter",
    allTemplates: isRu ? "Все шаблоны" : "All templates",
    archivedTemplates: isRu ? "Архив" : "Archive",
    searchLabel: isRu ? "Поиск шаблонов" : "Search templates",
    searchPlaceholder: isRu
      ? "Поиск по названию, описанию, тегам..."
      : "Search by title, description, tags...",
    allCategories: isRu ? "Все категории" : "All categories",
    accessLabel: isRu ? "Доступ" : "Access",
    allAccess: isRu ? "Все" : "All",
    allStatuses: isRu ? "Все статусы" : "All statuses",
    sortLabel: isRu ? "Сортировка" : "Sort",
    sortNewest: isRu ? "Новые сначала" : "Newest first",
    sortTitle: isRu ? "По названию" : "By title",
    sortTokens: isRu ? "По PawSpark" : "By PawSpark",
    viewToggleLabel: isRu ? "Переключение вида" : "View mode",
    cardsView: isRu ? "Карточки" : "Cards",
    listView: isRu ? "Список" : "List",
    testAction: isRu ? "Тест" : "Test",
    tokensShort: "PawSpark",
    updatedLabel: isRu ? "Обновлен" : "Updated",
    updatedShort: isRu ? "Обновлен" : "Updated",
    previousPageLabel: isRu ? "Предыдущая страница шаблонов" : "Previous templates page",
    nextPageLabel: isRu ? "Следующая страница шаблонов" : "Next templates page",
    showing: (visible: number, total: number) =>
      isRu
        ? `Показано ${visible} из ${total} шаблонов`
        : `Showing ${visible} of ${total} templates`,
  };
}
