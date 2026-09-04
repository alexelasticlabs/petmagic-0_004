"use client";

import { useRouter } from "next/navigation";
import { useCallback, useEffect, useMemo, useState } from "react";

import { CaretDownIcon, RefreshIcon } from "@/components/admin/admin-icons";
import {
  AdminFilterBar,
  AdminPage,
  AdminPageGrid,
  AdminStateCard,
} from "@/components/admin/admin-primitives";
import { ensureAdminSession } from "@/components/admin/admin-session";
import { getTemplateStatusLabel } from "@/components/templates/template-admin-shared";
import { TemplateCatalogCard } from "@/components/templates/templates-catalog-view.card";
import { getTemplatesCatalogViewText } from "@/components/templates/templates-catalog-view.content";
import { TemplatesCatalogDialogs } from "@/components/templates/templates-catalog-view.dialogs";
import { TemplatesCatalogListTable } from "@/components/templates/templates-catalog-view.list";
import {
  TemplatesCatalogRail,
  TemplatesCatalogWorkspaceHeader,
} from "@/components/templates/templates-catalog-workspace";
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
  type TemplateStatus,
  type TemplateType,
} from "@/lib/api-client";
import { clientLogger } from "@/lib/client-logger";
import { getDictionary, type Locale } from "@/lib/i18n";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

type TemplatesCatalogViewProps = {
  locale: Locale;
  templateType?: TemplateType;
  initialCategory?: string;
};

type ViewMode = "cards" | "list";
type ArchiveFilter = "active" | "archived";
type AccessFilter = "all" | "premium" | "free";
type VisibilityFilter = "all" | "public" | "qa_only";
type ReadinessFilter = "all" | "ready" | "missing_preview";
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
  const text = useMemo(() => getDictionary(locale), [locale]);
  const copy = useMemo(
    () => getTemplatesCatalogViewText(locale, templateType),
    [locale, templateType]
  );
  const router = useRouter();
  const session = useAuthSession();
  const sessionRoles = session?.user.roles ?? [];
  const canViewTemplates = sessionRoles.includes("Admin") || sessionRoles.includes("Moderator");
  const canManageTemplates = session?.user.roles.includes("Admin") ?? false;
  const [actionError, setActionError] = useState<string | null>(null);
  const [busyTemplateId, setBusyTemplateId] = useState<string | null>(null);
  const [viewMode, setViewMode] = useState<ViewMode>("cards");
  const [archiveFilter, setArchiveFilter] = useState<ArchiveFilter>("active");
  const [search, setSearch] = useState("");
  const [categoryFilter, setCategoryFilter] = useState(initialCategory?.trim() || "all");
  const [accessFilter, setAccessFilter] = useState<AccessFilter>("all");
  const [visibilityFilter, setVisibilityFilter] = useState<VisibilityFilter>("all");
  const [readinessFilter, setReadinessFilter] = useState<ReadinessFilter>("all");
  const [statusFilter, setStatusFilter] = useState<TemplateStatus | "all">("all");
  const [sortMode, setSortMode] = useState<SortMode>("newest");
  const [filtersExpanded, setFiltersExpanded] = useState(false);
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
      visibility: visibilityFilter === "all" ? undefined : visibilityFilter,
      readiness: readinessFilter === "all" ? undefined : readinessFilter,
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
      readinessFilter,
      sortMode,
      templateType,
      visibilityFilter,
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
    summary,
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
  const visibilityOptions: SelectOption[] = [
    { value: "all", label: copy.allVisibility, tone: "neutral" },
    { value: "public", label: copy.publicVisibility, tone: "recommended" },
    { value: "qa_only", label: copy.qaVisibility, tone: "fast" },
  ];
  const readinessOptions: SelectOption[] = [
    { value: "all", label: copy.allReadiness, tone: "neutral" },
    { value: "ready", label: copy.readyReadiness, tone: "recommended" },
    { value: "missing_preview", label: copy.missingPreviewReadiness, tone: "fast" },
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
        description: copy.sortNewestDescription,
        tone: "recommended",
      },
      {
        value: "title",
        label: copy.sortTitle,
        description: copy.sortTitleDescription,
        tone: "neutral",
      },
      {
        value: "tokens",
        label: copy.sortTokens,
        description: copy.sortTokensDescription,
        tone: "fast",
      },
    ],
    [copy]
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
  const activeFilterCount = useMemo(
    () =>
      [
        search.trim().length > 0,
        categoryFilter !== "all",
        accessFilter !== "all",
        visibilityFilter !== "all",
        readinessFilter !== "all",
        statusFilter !== "all",
        archiveFilter === "archived",
      ].filter(Boolean).length,
    [
      accessFilter,
      archiveFilter,
      categoryFilter,
      readinessFilter,
      search,
      statusFilter,
      visibilityFilter,
    ]
  );
  const hasCatalogFilters = activeFilterCount > 0;

  function resetCatalogFilters() {
    if (isCatalogInteractionLocked) {
      return;
    }

    setActionError(null);
    setSearch("");
    setCategoryFilter("all");
    setAccessFilter("all");
    setVisibilityFilter("all");
    setReadinessFilter("all");
    setStatusFilter("all");
    setArchiveFilter("active");
    setSortMode("newest");
    resetCatalogContext();
  }

  function toggleArchiveFilter() {
    if (isCatalogInteractionLocked) {
      return;
    }

    setArchiveFilter((current) => (current === "active" ? "archived" : "active"));
    setStatusFilter("all");
    resetCatalogContext();
  }

  function showDraftTemplates() {
    if (isCatalogInteractionLocked) {
      return;
    }

    setArchiveFilter("active");
    setStatusFilter("Draft");
    setReadinessFilter("all");
    setVisibilityFilter("all");
    resetCatalogContext();
  }

  function showTemplatesMissingPreview() {
    if (isCatalogInteractionLocked) {
      return;
    }

    setArchiveFilter("active");
    setStatusFilter("all");
    setReadinessFilter("missing_preview");
    setVisibilityFilter("all");
    resetCatalogContext();
  }

  function showQaOnlyTemplates() {
    if (isCatalogInteractionLocked) {
      return;
    }

    setArchiveFilter("active");
    setStatusFilter("all");
    setReadinessFilter("all");
    setVisibilityFilter("qa_only");
    resetCatalogContext();
  }
  useEffect(() => {
    let isActive = true;
    if (!isFetching && currentPage > totalPages) {
      queueMicrotask(() => {
        if (isActive) {
          resetCatalogContext(totalPages);
        }
      });
    }

    return () => {
      isActive = false;
    };
  }, [currentPage, isFetching, resetCatalogContext, totalPages]);
  useEffect(() => {
    let isActive = true;
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
      if (!isActive) {
        return;
      }

      if (shouldResetArchive) {
        setTemplatePendingArchiveId(null);
      }

      if (shouldResetDelete) {
        setTemplatePendingDeleteId(null);
      }
    });

    return () => {
      isActive = false;
    };
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

    setActionError(null);
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
        <TemplatesCatalogWorkspaceHeader
          canBrowseTemplates={false}
          canManageTemplates={false}
          copy={copy}
          locale={locale}
          templateType={templateType}
        />
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
      <TemplatesCatalogWorkspaceHeader
        archiveDisabled={isCatalogInteractionLocked}
        canBrowseTemplates={canViewTemplates}
        canManageTemplates={canManageTemplates}
        copy={copy}
        locale={locale}
        onToggleArchive={toggleArchiveFilter}
        showingArchived={archiveFilter === "archived"}
        templateType={templateType}
      />

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
              {copy.retry}
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
              {copy.retry}
            </Button>
          }
        />
      ) : null}

      <div className={styles.catalogShell}>
        <div className={styles.catalogMain}>
          <div className={styles.filtersDock} aria-label={copy.filtersLabel}>
            <div className={styles.filterLeadRow}>
              <label className={styles.searchField}>
                <span className={styles.visuallyHidden}>{copy.searchLabel}</span>
                <input
                  value={search}
                  onChange={(event) => {
                    setActionError(null);
                    setSearch(event.target.value.slice(0, TEMPLATE_CATALOG_SEARCH_MAX_LENGTH));
                    resetCatalogContext();
                  }}
                  maxLength={TEMPLATE_CATALOG_SEARCH_MAX_LENGTH}
                  placeholder={copy.searchPlaceholder}
                  disabled={isCatalogInteractionLocked}
                />
              </label>

              <div className={styles.filterUtilities}>
                <Button
                  type="button"
                  variant="secondary"
                  className={styles.mobileFiltersToggle}
                  aria-expanded={filtersExpanded}
                  aria-controls="template-catalog-advanced-filters"
                  disabled={isCatalogInteractionLocked}
                  onClick={() => setFiltersExpanded((current) => !current)}
                >
                  {filtersExpanded ? copy.hideFilters : copy.showFilters}
                  {activeFilterCount > 0 ? (
                    <span
                      className={styles.activeFilterCount}
                      aria-label={copy.activeFilters(activeFilterCount)}
                    >
                      {activeFilterCount}
                    </span>
                  ) : null}
                </Button>
                <Button
                  type="button"
                  variant="secondary"
                  className={styles.resetButton}
                  disabled={!hasCatalogFilters || isCatalogInteractionLocked}
                  onClick={resetCatalogFilters}
                  title={copy.resetFilters}
                >
                  <RefreshIcon className={styles.resetButtonIcon} aria-hidden="true" />
                  <span className={styles.resetButtonLabel}>{copy.resetFilters}</span>
                </Button>
                <div className={styles.viewToggle} role="group" aria-label={copy.viewToggleLabel}>
                  <button
                    type="button"
                    className={viewMode === "cards" ? styles.viewButtonActive : styles.viewButton}
                    aria-pressed={viewMode === "cards"}
                    disabled={isCatalogInteractionLocked}
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
                    disabled={isCatalogInteractionLocked}
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
            </div>

            <AdminFilterBar
              className={`${styles.filtersBar}${filtersExpanded ? ` ${styles.filtersBarExpanded}` : ""}`}
            >
              <div id="template-catalog-advanced-filters" className={styles.advancedFilters}>
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
                  <span>{copy.visibilityLabel}</span>
                  <Select
                    value={visibilityFilter}
                    options={visibilityOptions}
                    ariaLabel={copy.visibilityLabel}
                    disabled={isCatalogInteractionLocked}
                    onChange={(value) => {
                      setVisibilityFilter(value as VisibilityFilter);
                      resetCatalogContext();
                    }}
                  />
                </label>

                <label className={styles.selectField}>
                  <span>{copy.readinessLabel}</span>
                  <Select
                    value={readinessFilter}
                    options={readinessOptions}
                    ariaLabel={copy.readinessLabel}
                    disabled={isCatalogInteractionLocked}
                    onChange={(value) => {
                      setReadinessFilter(value as ReadinessFilter);
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
              </div>
            </AdminFilterBar>
          </div>
          {isCatalogRefreshing ? (
            <AdminStateCard tone="info" className={styles.empty} title={text.loading} />
          ) : hasError && !templates.length ? null : !templates.length ? (
            <AdminStateCard
              tone="info"
              className={styles.empty}
              title={hasCatalogFilters ? copy.filteredEmptyTitle : copy.catalogEmptyTitle}
              description={
                hasCatalogFilters ? copy.filteredEmptyDescription : copy.catalogEmptyDescription
              }
              action={
                hasCatalogFilters ? (
                  <Button type="button" variant="secondary" onClick={resetCatalogFilters}>
                    {copy.resetFilters}
                  </Button>
                ) : undefined
              }
            />
          ) : viewMode === "cards" ? (
            <div className={styles.cardGrid} aria-busy={isCatalogFetching ? "true" : undefined}>
              {templates.map((template) => (
                <TemplateCatalogCard
                  key={template.templateId}
                  locale={locale}
                  copy={copy}
                  template={template}
                  analytics={getAnalyticsRow(template.templateId)}
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
            <TemplatesCatalogListTable
              canManageTemplates={canManageTemplates}
              copy={copy}
              getAnalyticsRow={getAnalyticsRow}
              isCatalogInteractionLocked={isCatalogInteractionLocked}
              isFetching={isCatalogFetching}
              locale={locale}
              onDeleteTemplate={requestDeleteTemplate}
              onStatusChange={requestStatusChange}
              templates={templates}
              text={text}
            />
          )}
          {templates.length || currentPage > 1 ? (
            <div className={styles.paginationBar}>
              <span>{copy.pageSummary(currentPage, shownStart, shownEnd, totalCount)}</span>
              <div className={styles.paginationActions}>
                <Button
                  type="button"
                  variant="secondary"
                  size="sm"
                  disabled={currentPage <= 1 || isCatalogFetching}
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
                    disabled={isCatalogFetching}
                    aria-current={pageNumber === currentPage ? "page" : undefined}
                    onClick={() => resetCatalogContext(pageNumber)}
                  >
                    {pageNumber}
                  </Button>
                ))}
                <Button
                  type="button"
                  variant="secondary"
                  size="sm"
                  disabled={currentPage >= totalPages || !hasMore || isCatalogFetching}
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
        <TemplatesCatalogRail
          copy={copy}
          locale={locale}
          summary={summary}
          onShowDrafts={showDraftTemplates}
          onShowMissingPreview={showTemplatesMissingPreview}
          onShowQaOnly={showQaOnlyTemplates}
        />
      </div>
      <TemplatesCatalogDialogs
        copy={copy}
        isTemplateActionLocked={isTemplateActionLocked}
        onCancelArchive={() => setTemplatePendingArchiveId(null)}
        onCancelDelete={() => setTemplatePendingDeleteId(null)}
        onConfirmArchive={() => {
          if (!templatePendingArchiveId) {
            return;
          }

          void handleStatusChange(templatePendingArchiveId, "Archived").then((succeeded) => {
            if (succeeded) {
              setTemplatePendingArchiveId(null);
            }
          });
        }}
        onConfirmDelete={() => {
          if (!templatePendingDeleteId) {
            return;
          }

          void handleDelete(templatePendingDeleteId).then((succeeded) => {
            if (succeeded) {
              setTemplatePendingDeleteId(null);
            }
          });
        }}
        templatePendingArchiveId={templatePendingArchiveId}
        templatePendingDeleteId={templatePendingDeleteId}
        templates={templates}
        text={text}
      />
    </AdminPage>
  );
}
