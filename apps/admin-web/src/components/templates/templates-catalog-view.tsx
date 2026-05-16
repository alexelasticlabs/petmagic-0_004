"use client";

import { AdminCard, AdminStatusBadge, adminTableStyles } from "@/components/admin/admin-primitives";
import { TemplatePreviewCard } from "@/components/templates/template-phone-preview-card";
import styles from "@/components/templates/templates-catalog.module.css";
import { Button } from "@/components/ui/button";
import { Select, type SelectOption } from "@/components/ui/select";
import {
    changeTemplateStatus,
    deleteTemplate,
    fetchAdminTemplateStatistics,
    fetchAdminTemplates,
    getSession,
    type AdminTemplateListItem,
    type AdminTemplateStatistics,
    type TemplateStatus,
    type TemplateType,
} from "@/lib/api-client";
import { getDictionary, type Locale } from "@/lib/i18n";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";

type TemplatesCatalogViewProps = {
  locale: Locale;
  templateType: TemplateType;
  initialCategory?: string;
};

type ViewMode = "cards" | "list";
type ArchiveFilter = "active" | "archived";
type AccessFilter = "all" | "premium" | "free";
type SortMode = "newest" | "title" | "tokens";

const statusColors: Record<TemplateStatus, string> = {
  Draft: "#facc15",
  Active: "#22c55e",
  Archived: "#94a3b8",
};

export function TemplatesCatalogView({ locale, templateType, initialCategory }: TemplatesCatalogViewProps) {
  const text = getDictionary(locale);
  const copy = getCatalogCopy(locale, templateType);
  const router = useRouter();
  const [templates, setTemplates] = useState<AdminTemplateListItem[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [busyTemplateId, setBusyTemplateId] = useState<string | null>(null);
  const [viewMode, setViewMode] = useState<ViewMode>("cards");
  const [archiveFilter, setArchiveFilter] = useState<ArchiveFilter>("active");
  const [search, setSearch] = useState("");
  const [categoryFilter, setCategoryFilter] = useState(initialCategory?.trim() || "all");
  const [accessFilter, setAccessFilter] = useState<AccessFilter>("all");
  const [statusFilter, setStatusFilter] = useState<TemplateStatus | "all">("all");
  const [sortMode, setSortMode] = useState<SortMode>("newest");
  const [statisticsTemplateId, setStatisticsTemplateId] = useState<string | null>(null);
  const [statistics, setStatistics] = useState<AdminTemplateStatistics | null>(null);
  const [statisticsLoading, setStatisticsLoading] = useState(false);
  const [statisticsError, setStatisticsError] = useState<string | null>(null);

  async function loadTemplates(showLoading = true) {
    if (showLoading) {
      setIsLoading(true);
    }
    setError(null);

    try {
      const session = getSession();
      if (!session) {
        router.replace(`/${locale}`);
        return;
      }

      const response = await fetchAdminTemplates(templateType);
      setTemplates(response);
    } catch {
      setError(text.errorLoadingTemplates);
    } finally {
      if (showLoading) {
        setIsLoading(false);
      }
    }
  }

  useEffect(() => {
    let isCancelled = false;

    async function initialize() {
      setIsLoading(true);
      setError(null);

      try {
        const session = getSession();
        if (!session) {
          router.replace(`/${locale}`);
          return;
        }

        const response = await fetchAdminTemplates(templateType);
        if (!isCancelled) {
          setTemplates(response);
        }
      } catch {
        if (!isCancelled) {
          setError(text.errorLoadingTemplates);
        }
      } finally {
        if (!isCancelled) {
          setIsLoading(false);
        }
      }
    }

    void initialize();

    return () => {
      isCancelled = true;
    };
  }, [locale, router, templateType, text.errorLoadingTemplates]);

  async function handleStatusChange(templateId: string, status: TemplateStatus) {
    setBusyTemplateId(templateId);
    setError(null);

    try {
      await changeTemplateStatus(templateId, status);
      await loadTemplates(false);
    } catch {
      setError(text.errorSavingTemplate);
    } finally {
      setBusyTemplateId(null);
    }
  }

  async function handleDelete(templateId: string) {
    const confirmed = window.confirm(text.confirmDeleteTemplate);
    if (!confirmed) {
      return;
    }

    setBusyTemplateId(templateId);
    setError(null);

    try {
      await deleteTemplate(templateId);
      await loadTemplates(false);
    } catch {
      setError(text.errorDeletingTemplate);
    } finally {
      setBusyTemplateId(null);
    }
  }

  function handleOpenStatistics(templateId: string) {
    setStatisticsTemplateId(templateId);
  }

  const editorBasePath = `/${locale}/templates/${templateType === "Video" ? "video" : "image"}/editor`;
  const testBasePath = `/${locale}/templates/${templateType === "Video" ? "video" : "image"}/test`;
  const categoriesPath = `/${locale}/templates/categories`;
  const catalog = buildCatalogModel(templates);
  const selectedStatisticsTemplate = statisticsTemplateId
    ? templates.find((template) => template.templateId === statisticsTemplateId) ?? null
    : null;
  const visiblePool = archiveFilter === "archived" ? catalog.archivedTemplates : catalog.activeTemplates;
  const categoryStats = catalog.categoryStats.slice(0, 6);
  const tagStats = catalog.tagStats.slice(0, 6);
  const categoryOptions: SelectOption[] = [
    { value: "all", label: copy.allCategories, tone: "neutral" },
    ...catalog.categories.map((category) => ({ value: category, label: category, tone: "neutral" as const })),
  ];
  const accessOptions: SelectOption[] = [
    { value: "all", label: copy.allAccess, tone: "neutral" },
    { value: "premium", label: "Premium", badge: "Premium", tone: "premium" },
    { value: "free", label: "Free", badge: "Free", tone: "recommended" },
  ];
  const statusOptions: SelectOption[] = [
    { value: "all", label: copy.allStatuses, tone: "neutral" },
    { value: "Active", label: formatStatus("Active", locale), badge: "Live", tone: "premium" },
    { value: "Draft", label: formatStatus("Draft", locale), badge: "Draft", tone: "fast" },
    { value: "Archived", label: formatStatus("Archived", locale), badge: "Archive", tone: "neutral" },
  ];
  const sortOptions: SelectOption[] = [
    { value: "newest", label: copy.sortNewest, description: locale === "ru" ? "Сначала свежие шаблоны" : "Most recent templates first", tone: "recommended" },
    { value: "title", label: copy.sortTitle, description: locale === "ru" ? "Алфавитный порядок" : "Alphabetical order", tone: "neutral" },
    { value: "tokens", label: copy.sortTokens, description: locale === "ru" ? "По стоимости в токенах" : "By token cost", tone: "fast" },
  ];
  const normalizedSearch = search.trim().toLowerCase();
  const filteredTemplates = visiblePool
    .filter((template) => {
      const matchesSearch = !normalizedSearch
        || template.title.toLowerCase().includes(normalizedSearch)
        || template.shortDescription.toLowerCase().includes(normalizedSearch)
        || template.tags.some((tag) => tag.toLowerCase().includes(normalizedSearch));
      const matchesCategory = categoryFilter === "all" || template.category === categoryFilter;
      const matchesAccess = accessFilter === "all"
        || (accessFilter === "premium" && template.isPremium)
        || (accessFilter === "free" && !template.isPremium);
      const matchesStatus = statusFilter === "all" || template.status === statusFilter;

      return matchesSearch && matchesCategory && matchesAccess && matchesStatus;
    })
    .sort((firstTemplate, secondTemplate) => compareTemplates(firstTemplate, secondTemplate, sortMode));

  useEffect(() => {
    if (!statisticsTemplateId) {
      setStatistics(null);
      setStatisticsError(null);
      setStatisticsLoading(false);
      return;
    }

    const templateId = statisticsTemplateId;

    let isCancelled = false;

    async function loadStatistics() {
      setStatisticsLoading(true);
      setStatistics(null);
      setStatisticsError(null);

      try {
        const response = await fetchAdminTemplateStatistics(templateId);
        if (!isCancelled) {
          setStatistics(response);
        }
      } catch {
        if (!isCancelled) {
          setStatisticsError(copy.statisticsLoadError);
        }
      } finally {
        if (!isCancelled) {
          setStatisticsLoading(false);
        }
      }
    }

    void loadStatistics();

    return () => {
      isCancelled = true;
    };
  }, [copy.statisticsLoadError, statisticsTemplateId]);

  useEffect(() => {
    if (!isLoading && statisticsTemplateId && !templates.some((template) => template.templateId === statisticsTemplateId)) {
      setStatisticsTemplateId(null);
      setStatistics(null);
      setStatisticsError(null);
    }
  }, [isLoading, statisticsTemplateId, templates]);

  if (isLoading) {
    return (
      <section className={styles.loadingGrid} aria-busy="true" aria-live="polite">
        {Array.from({ length: 8 }).map((_, index) => (
          <div key={index} className={styles.skeletonCard} />
        ))}
      </section>
    );
  }

  return (
    <section className={styles.catalogPage}>
      <div className={styles.catalogActions}>
        <Link href={categoriesPath} className={styles.secondaryLink}>{copy.manageCategories}</Link>
        <Link href={editorBasePath} className={styles.primaryLink}>{copy.createTemplate}</Link>
      </div>

      <div className={styles.tabRow} role="tablist" aria-label={copy.archiveTabsLabel}>
        <button type="button" className={archiveFilter === "active" ? styles.tabActive : styles.tab} onClick={() => setArchiveFilter("active")}>
          {copy.allTemplates}
        </button>
        <button type="button" className={archiveFilter === "archived" ? styles.tabActive : styles.tab} onClick={() => setArchiveFilter("archived")}>
          {copy.archivedTemplates}
        </button>
      </div>

      {error ? <p className={styles.error}>{error}</p> : null}

      <div className={styles.catalogShell}>
        <div className={styles.catalogMain}>
          <div className={styles.filtersBar}>
            <label className={styles.searchField}>
              <span className={styles.visuallyHidden}>{copy.searchLabel}</span>
              <input value={search} onChange={(event) => setSearch(event.target.value)} placeholder={copy.searchPlaceholder} />
            </label>

            <label className={styles.selectField}>
              <span>{text.categoryLabel}</span>
              <Select value={categoryFilter} options={categoryOptions} ariaLabel={text.categoryLabel} onChange={setCategoryFilter} />
            </label>

            <label className={styles.selectField}>
              <span>{copy.accessLabel}</span>
              <Select value={accessFilter} options={accessOptions} ariaLabel={copy.accessLabel} onChange={(value) => setAccessFilter(value as AccessFilter)} />
            </label>

            <label className={styles.selectField}>
              <span>{text.statusLabel}</span>
              <Select value={statusFilter} options={statusOptions} ariaLabel={text.statusLabel} onChange={(value) => setStatusFilter(value as TemplateStatus | "all")} />
            </label>

            <label className={styles.selectField}>
              <span>{copy.sortLabel}</span>
              <Select value={sortMode} options={sortOptions} ariaLabel={copy.sortLabel} showSelectedDescription={false} onChange={(value) => setSortMode(value as SortMode)} />
            </label>

            <div className={styles.viewToggleShell}>
              <span className={styles.viewToggleCaption}>{copy.viewToggleLabel}</span>
              <div className={styles.viewToggle} role="group" aria-label={copy.viewToggleLabel}>
                <button
                  type="button"
                  className={viewMode === "cards" ? styles.viewButtonActive : styles.viewButton}
                  aria-pressed={viewMode === "cards"}
                  onClick={() => setViewMode("cards")}
                >
                  <span className={`${styles.viewButtonGlyph} ${styles.viewButtonGlyphCards}`} aria-hidden="true">
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
                  onClick={() => setViewMode("list")}
                >
                  <span className={`${styles.viewButtonGlyph} ${styles.viewButtonGlyphList}`} aria-hidden="true">
                    <span />
                    <span />
                    <span />
                  </span>
                  <span>{copy.listView}</span>
                </button>
              </div>
            </div>
          </div>
          {!filteredTemplates.length ? (
            <div className={styles.empty}>{text.noTemplates}</div>
          ) : viewMode === "cards" ? (
            <div className={styles.cardGrid}>
              {filteredTemplates.map((template) => (
                <TemplateCatalogCard
                  key={template.templateId}
                  locale={locale}
                  template={template}
                  editorBasePath={editorBasePath}
                  testBasePath={testBasePath}
                  busyTemplateId={busyTemplateId}
                  onStatusChange={handleStatusChange}
                  onDeleteTemplate={handleDelete}
                  onOpenStatistics={handleOpenStatistics}
                  isStatisticsSelected={statisticsTemplateId === template.templateId}
                />
              ))}
            </div>
          ) : (
            <AdminCard padding="md" className={styles.listCard}>
              <div className={adminTableStyles.tableWrap}>
                <table className={adminTableStyles.table}>
                  <thead>
                    <tr>
                      <th>{text.titleLabel}</th>
                      <th>{text.categoryLabel}</th>
                      <th>{copy.accessLabel}</th>
                      <th>{text.tokenCostLabel}</th>
                      <th>{text.statusLabel}</th>
                      <th>{templateType === "Video" ? text.characterOrientationLabel : copy.updatedLabel}</th>
                      <th>{text.actionsLabel}</th>
                    </tr>
                  </thead>
                  <tbody>
                    {filteredTemplates.map((template) => {
                      const isBusy = busyTemplateId === template.templateId;

                      return (
                        <tr key={template.templateId}>
                          <td data-label={text.titleLabel}>
                            <div className={styles.titleCell}>
                              <strong>{template.title}</strong>
                              <span>{template.shortDescription}</span>
                            </div>
                          </td>
                          <td data-label={text.categoryLabel}>{template.category}</td>
                          <td data-label={copy.accessLabel}>{template.isPremium ? "Premium" : "Free"}</td>
                          <td data-label={text.tokenCostLabel}>{template.tokenCost}</td>
                          <td data-label={text.statusLabel}>
                            <AdminStatusBadge color={statusColors[template.status]}>{formatStatus(template.status, locale)}</AdminStatusBadge>
                          </td>
                          <td data-label={templateType === "Video" ? text.characterOrientationLabel : copy.updatedLabel}>
                            {templateType === "Video" ? formatOrientation(template.characterOrientation, locale) : formatDate(template.updatedAtUtc, locale)}
                          </td>
                          <td data-label={text.actionsLabel} className={styles.tableActionsCell}>
                            <div className={styles.tableActions}>
                              <Link href={`${editorBasePath}?templateId=${template.templateId}`} className={styles.compactLink}>{text.editTemplate}</Link>
                              <Button size="sm" variant={statisticsTemplateId === template.templateId ? "secondary" : "ghost"} onClick={() => handleOpenStatistics(template.templateId)}>{copy.statisticsAction}</Button>
                              {template.templateType === "Video" ? (
                                <Link href={`${testBasePath}/${template.templateId}`} className={styles.compactLink}>{copy.testAction}</Link>
                              ) : null}
                              {template.status !== "Active" ? (
                                <Button size="sm" variant="ghost" disabled={isBusy} onClick={() => void handleStatusChange(template.templateId, "Active")}>{text.activate}</Button>
                              ) : null}
                              {template.status !== "Archived" ? (
                                <Button size="sm" variant="danger" disabled={isBusy} onClick={() => void handleStatusChange(template.templateId, "Archived")}>{text.archive}</Button>
                              ) : null}
                              <Button size="sm" variant="danger" disabled={isBusy} onClick={() => void handleDelete(template.templateId)}>{text.deleteTemplate}</Button>
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
        </div>

        <aside className={styles.sideRail} aria-label={copy.quickStats}>
          <div className={styles.railPanel}>
            <div className={styles.statsPanelHeader}>
              <p className={styles.statsPanelEyebrow}>{copy.statisticsPanelEyebrow}</p>
              <h2>{selectedStatisticsTemplate ? selectedStatisticsTemplate.title : copy.statisticsEmptyTitle}</h2>
              <p className={styles.statsPanelDescription}>
                {selectedStatisticsTemplate
                  ? `${selectedStatisticsTemplate.category} • ${formatStatus(selectedStatisticsTemplate.status, locale)}`
                  : copy.statisticsEmptyDescription}
              </p>
            </div>

            {statisticsLoading ? (
              <p className={styles.railHint}>{copy.statisticsLoading}</p>
            ) : statisticsError ? (
              <p className={styles.panelError}>{statisticsError}</p>
            ) : statistics ? (
              <>
                <StatLine label={copy.totalRunsLabel} value={statistics.totalRuns} />
                <StatLine label={copy.inProgressRunsLabel} value={statistics.queuedRuns + statistics.processingRuns} />
                <StatLine label={copy.completedRunsLabel} value={statistics.completedRuns} />
                <StatLine label={copy.failedRunsLabel} value={statistics.failedRuns} />
                <StatLine label={copy.successRateLabel} value={formatPercent(statistics.successRatePercent)} />
                <StatLine label={copy.totalTokensSpentLabel} value={statistics.totalTokenCost} />
                <StatLine label={copy.averageTokensLabel} value={statistics.averageTokenCost.toFixed(1)} />
                <StatLine label={copy.averageTimeLabel} value={formatSeconds(statistics.averageGenerationSeconds, locale)} />
                <StatLine label={copy.lastRunLabel} value={formatDateTime(statistics.lastRunAtUtc, locale)} />
                <StatLine label={copy.lastCompletedLabel} value={formatDateTime(statistics.lastCompletedAtUtc, locale)} />
              </>
            ) : (
              <p className={styles.railHint}>{copy.statisticsEmptyDescription}</p>
            )}
          </div>

          <div className={styles.railPanel}>
            <h2>{copy.quickStats}</h2>
            <StatLine label={copy.totalTemplates} value={catalog.stats.total} />
            <StatLine label={copy.activeTemplates} value={catalog.stats.active} />
            <StatLine label={copy.draftTemplates} value={catalog.stats.draft} />
            <StatLine label={copy.archivedTemplates} value={catalog.stats.archived} />
            <StatLine label="Premium" value={catalog.stats.premium} />
            <StatLine label="Free" value={catalog.stats.free} />
          </div>

          <div className={styles.railPanel}>
            <h2>{copy.categoriesTitle}</h2>
            {categoryStats.map((category) => (
              <StatLine key={category.label} label={category.label} value={category.count} />
            ))}
            <Link href={categoriesPath} className={styles.railLink}>{copy.manageCategories}</Link>
          </div>

          <div className={styles.railPanel}>
            <h2>{copy.popularTags}</h2>
            <div className={styles.tagCloud}>
              {tagStats.map((tag) => <span key={tag.label}>#{tag.label} <b>{tag.count}</b></span>)}
            </div>
          </div>
        </aside>
      </div>
    </section>
  );
}

type TemplateCatalogCardProps = {
  locale: Locale;
  template: AdminTemplateListItem;
  editorBasePath: string;
  testBasePath: string;
  busyTemplateId: string | null;
  onStatusChange: (templateId: string, status: TemplateStatus) => void;
  onDeleteTemplate: (templateId: string) => void;
  onOpenStatistics: (templateId: string) => void;
  isStatisticsSelected: boolean;
};

function TemplateCatalogCard({ locale, template, editorBasePath, testBasePath, busyTemplateId, onStatusChange, onDeleteTemplate, onOpenStatistics, isStatisticsSelected }: TemplateCatalogCardProps) {
  const text = getDictionary(locale);
  const copy = getCatalogCopy(locale, template.templateType);
  const isBusy = busyTemplateId === template.templateId;

  return (
    <article className={styles.templateCard}>
      <TemplatePreviewCard
        className={styles.previewCard}
        title={template.title}
        shortDescription={template.shortDescription}
        previewUrl={template.previewAsset?.url}
        previewContentType={template.previewAsset?.contentType}
        tokenCost={template.tokenCost}
        category={template.category}
        isPremium={template.isPremium}
        referenceDurationSeconds={template.referenceVideoDurationSeconds}
        promoBadge={template.effectivePromoBadge}
      />
      <div className={styles.cardBody}>
        <div className={styles.cardFooter}>
          <span className={styles.cardTimestamp}>{copy.updatedShort} {formatDate(template.updatedAtUtc, locale)}</span>
          <AdminStatusBadge color={statusColors[template.status]}>{formatStatus(template.status, locale)}</AdminStatusBadge>
        </div>
        <div className={styles.cardActions}>
          <Link href={`${editorBasePath}?templateId=${template.templateId}`} className={`${styles.compactLink} ${styles.cardActionLink}`}>{text.editTemplate}</Link>
          <Button size="sm" variant={isStatisticsSelected ? "secondary" : "ghost"} className={`${styles.cardActionButton} ${isStatisticsSelected ? styles.cardActionButtonSelected : ""}`} onClick={() => onOpenStatistics(template.templateId)}>{copy.statisticsAction}</Button>
          {template.templateType === "Video" ? (
            <Link href={`${testBasePath}/${template.templateId}`} className={`${styles.compactLink} ${styles.cardActionLink}`}>{copy.testAction}</Link>
          ) : null}
          {template.status !== "Active" ? (
            <Button size="sm" variant="ghost" className={styles.cardActionButton} disabled={isBusy} onClick={() => onStatusChange(template.templateId, "Active")}>{text.activate}</Button>
          ) : (
            <Button size="sm" variant="ghost" className={styles.cardActionButton} disabled={isBusy} onClick={() => onStatusChange(template.templateId, "Archived")}>{text.archive}</Button>
          )}
          <Button size="sm" variant="danger" className={`${styles.cardActionButton} ${styles.cardActionDanger}`} disabled={isBusy} onClick={() => onDeleteTemplate(template.templateId)}>{text.deleteTemplate}</Button>
        </div>
      </div>
    </article>
  );
}

function StatLine({ label, value }: { label: string; value: number | string }) {
  return (
    <div className={styles.statLine}>
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  );
}

function compareTemplates(firstTemplate: AdminTemplateListItem, secondTemplate: AdminTemplateListItem, sortMode: SortMode) {
  if (sortMode === "title") {
    return firstTemplate.title.localeCompare(secondTemplate.title);
  }

  if (sortMode === "tokens") {
    return secondTemplate.tokenCost - firstTemplate.tokenCost;
  }

  return new Date(secondTemplate.updatedAtUtc).getTime() - new Date(firstTemplate.updatedAtUtc).getTime();
}

function buildCatalogModel(templates: AdminTemplateListItem[]) {
  const activeTemplates: AdminTemplateListItem[] = [];
  const archivedTemplates: AdminTemplateListItem[] = [];
  const categories = new Set<string>();
  const categoryCounts = new Map<string, number>();
  const tagCounts = new Map<string, number>();
  const stats = {
    total: templates.length,
    active: 0,
    draft: 0,
    archived: 0,
    premium: 0,
    free: 0,
  };

  for (const template of templates) {
    if (template.status === "Archived") {
      archivedTemplates.push(template);
      stats.archived += 1;
    } else {
      activeTemplates.push(template);
    }

    if (template.status === "Active") {
      stats.active += 1;
    }

    if (template.status === "Draft") {
      stats.draft += 1;
    }

    if (template.isPremium) {
      stats.premium += 1;
    } else {
      stats.free += 1;
    }

    if (template.category) {
      categories.add(template.category);
      categoryCounts.set(template.category, (categoryCounts.get(template.category) ?? 0) + 1);
    }

    for (const tag of template.tags) {
      tagCounts.set(tag, (tagCounts.get(tag) ?? 0) + 1);
    }
  }

  return {
    activeTemplates,
    archivedTemplates,
    categories: Array.from(categories).sort((firstCategory, secondCategory) => firstCategory.localeCompare(secondCategory)),
    categoryStats: toSortedStats(categoryCounts),
    tagStats: toSortedStats(tagCounts),
    stats,
  };
}

function toSortedStats(counts: Map<string, number>) {
  return Array.from(counts, ([label, count]) => ({ label, count })).sort((firstItem, secondItem) => secondItem.count - firstItem.count);
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

function formatDateTime(value: string | null | undefined, locale: Locale) {
  if (!value) {
    return "-";
  }

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return "-";
  }

  return new Intl.DateTimeFormat(locale === "ru" ? "ru-RU" : "en-US", {
    day: "2-digit",
    month: "short",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  }).format(date);
}

function formatPercent(value: number) {
  return `${value.toFixed(value % 1 === 0 ? 0 : 1)}%`;
}

function formatSeconds(value: number | null | undefined, locale: Locale) {
  if (value == null) {
    return "-";
  }

  const rounded = Math.max(0, Math.round(value));
  const minutes = Math.floor(rounded / 60);
  const seconds = rounded % 60;

  if (minutes > 0) {
    return `${minutes}:${seconds.toString().padStart(2, "0")}`;
  }

  return locale === "ru" ? `${rounded} сек` : `${rounded} sec`;
}

function formatDuration(seconds?: number) {
  if (!seconds) {
    return "-";
  }

  const roundedSeconds = Math.max(0, Math.round(seconds));
  const minutes = Math.floor(roundedSeconds / 60).toString().padStart(2, "0");
  const remainder = (roundedSeconds % 60).toString().padStart(2, "0");
  return `${minutes}:${remainder}`;
}

function formatStatus(status: TemplateStatus, locale: Locale) {
  if (locale === "ru") {
    return status === "Active" ? "Активен" : status === "Draft" ? "Черновик" : "Архив";
  }

  return status;
}

function formatOrientation(value: string | undefined, locale: Locale) {
  if (!value) {
    return "-";
  }

  if (locale === "ru") {
    return value === "Image" ? "image" : "video";
  }

  return value;
}

function getCatalogCopy(locale: Locale, templateType: TemplateType) {
  const isRu = locale === "ru";
  const isVideo = templateType === "Video";

  return {
    title: isVideo ? (isRu ? "Видео шаблоны" : "Video Templates") : (isRu ? "Шаблоны изображений" : "Image Templates"),
    description: isVideo
      ? (isRu ? "Каталог motion-шаблонов, статусы, категории и параметры доступа." : "Motion template catalog, statuses, categories, and access settings.")
      : (isRu ? "Каталог image-шаблонов, статусы, категории и параметры доступа." : "Image template catalog, statuses, categories, and access settings."),
    createTemplate: isVideo ? (isRu ? "Создать видео шаблон" : "Create video template") : (isRu ? "Создать image шаблон" : "Create image template"),
    manageCategories: isRu ? "Управление категориями" : "Manage categories",
    archiveTabsLabel: isRu ? "Фильтр архива" : "Archive filter",
    allTemplates: isRu ? "Все шаблоны" : "All templates",
    archivedTemplates: isRu ? "Архив" : "Archive",
    searchLabel: isRu ? "Поиск шаблонов" : "Search templates",
    searchPlaceholder: isRu ? "Поиск по названию, описанию, тегам..." : "Search by title, description, tags...",
    allCategories: isRu ? "Все категории" : "All categories",
    accessLabel: isRu ? "Доступ" : "Access",
    allAccess: isRu ? "Все" : "All",
    allStatuses: isRu ? "Все статусы" : "All statuses",
    sortLabel: isRu ? "Сортировка" : "Sort",
    sortNewest: isRu ? "Новые сначала" : "Newest first",
    sortTitle: isRu ? "По названию" : "By title",
    sortTokens: isRu ? "По токенам" : "By tokens",
    viewToggleLabel: isRu ? "Переключение вида" : "View mode",
    cardsView: isRu ? "Карточки" : "Cards",
    listView: isRu ? "Список" : "List",
    quickStats: isRu ? "Быстрая статистика" : "Quick stats",
    totalTemplates: isRu ? "Всего шаблонов" : "Total templates",
    activeTemplates: isRu ? "Активных" : "Active",
    draftTemplates: isRu ? "Черновиков" : "Drafts",
    categoriesTitle: isRu ? "Категории" : "Categories",
    popularTags: isRu ? "Популярные теги" : "Popular tags",
    statisticsAction: isRu ? "Статистика" : "Statistics",
    testAction: isRu ? "Тест" : "Test",
    statisticsPanelEyebrow: isRu ? "Generation stats" : "Generation stats",
    statisticsEmptyTitle: isRu ? "Выберите шаблон" : "Select a template",
    statisticsEmptyDescription: isRu ? "Откройте статистику на карточке, чтобы увидеть запуски, успехи и среднее время генерации." : "Open statistics from a card to inspect runs, success rate, and average generation time.",
    statisticsLoadError: isRu ? "Не удалось загрузить статистику шаблона." : "Failed to load template statistics.",
    statisticsLoading: isRu ? "Загрузка статистики шаблона..." : "Loading template statistics...",
    totalRunsLabel: isRu ? "Всего запусков" : "Total runs",
    inProgressRunsLabel: isRu ? "В работе" : "In progress",
    completedRunsLabel: isRu ? "Успешно" : "Completed",
    failedRunsLabel: isRu ? "Ошибок" : "Failed",
    successRateLabel: isRu ? "Успешность" : "Success rate",
    totalTokensSpentLabel: isRu ? "Токенов суммарно" : "Total tokens",
    averageTokensLabel: isRu ? "Средняя стоимость" : "Average cost",
    averageTimeLabel: isRu ? "Среднее время" : "Average time",
    lastRunLabel: isRu ? "Последний запуск" : "Last run",
    lastCompletedLabel: isRu ? "Последний успех" : "Last completed",
    tokensShort: isRu ? "ток." : "tokens",
    updatedLabel: isRu ? "Обновлен" : "Updated",
    updatedShort: isRu ? "Обновлен" : "Updated",
    showing: (visible: number, total: number) => isRu ? `Показано ${visible} из ${total} шаблонов` : `Showing ${visible} of ${total} templates`,
  };
}
