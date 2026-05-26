"use client";

import Image from "next/image";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useDeferredValue, useEffect, useMemo, useState, type ReactElement } from "react";

import {
  CalendarIcon,
  CancelCircleIcon,
  ChartIcon,
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
import {
  getCharacterOrientationLabel,
  getTemplateAccessLabel,
  getTemplateStatusLabel,
  getTemplateTypeLabel,
} from "@/components/templates/template-admin-shared";
import { TemplatePreviewCard } from "@/components/templates/template-phone-preview-card";
import styles from "@/components/templates/templates-catalog.module.css";
import { useAdminTemplateCatalog } from "@/components/templates/use-admin-template-catalog";
import { Button } from "@/components/ui/button";
import { Select, type SelectOption } from "@/components/ui/select";
import {
  changeTemplateStatus,
  deleteTemplate,
  useAuthSession,
  type AdminTemplateListItem,
  type AdminTemplatesAnalyticsTemplateRow,
  type TemplateStatus,
  type TemplateType,
} from "@/lib/api-client";
import { getDictionary, type Locale } from "@/lib/i18n";

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

const METRIC_ICONS: Record<string, ReactElement> = {
  cardMetric_primary: (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      aria-hidden="true"
      style={{ width: "0.85rem", height: "0.85rem", opacity: 0.7, flexShrink: 0 }}
    >
      <circle cx="12" cy="12" r="9" stroke="currentColor" strokeWidth="1.7" />
      <path
        d="M12 7v1m0 8v1M9.5 9.5A2.5 2.5 0 0 1 12 8a2.5 2.5 0 0 1 0 5 2.5 2.5 0 0 0 0 5 2.5 2.5 0 0 0 2.5-1.5"
        stroke="currentColor"
        strokeWidth="1.6"
        strokeLinecap="round"
      />
    </svg>
  ),
  cardMetric_info: (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      aria-hidden="true"
      style={{ width: "0.85rem", height: "0.85rem", opacity: 0.7, flexShrink: 0 }}
    >
      <ellipse cx="12" cy="12" rx="10" ry="6" stroke="currentColor" strokeWidth="1.7" />
      <circle cx="12" cy="12" r="2.2" fill="currentColor" />
    </svg>
  ),
  cardMetric_success: (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      aria-hidden="true"
      style={{ width: "0.85rem", height: "0.85rem", opacity: 0.7, flexShrink: 0 }}
    >
      <path
        d="M12 2l2.4 7.4H22l-6.2 4.5 2.4 7.4L12 17l-6.2 4.3 2.4-7.4L2 9.4h7.6L12 2Z"
        stroke="currentColor"
        strokeWidth="1.6"
        strokeLinejoin="round"
      />
    </svg>
  ),
  cardMetric_danger: (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      aria-hidden="true"
      style={{ width: "0.85rem", height: "0.85rem", opacity: 0.7, flexShrink: 0 }}
    >
      <path
        d="M10.29 3.86 1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0Z"
        stroke="currentColor"
        strokeWidth="1.6"
        strokeLinejoin="round"
      />
      <line
        x1="12"
        y1="9"
        x2="12"
        y2="13"
        stroke="currentColor"
        strokeWidth="1.6"
        strokeLinecap="round"
      />
      <circle cx="12" cy="17" r="0.8" fill="currentColor" />
    </svg>
  ),
};

export function TemplatesCatalogView({
  locale,
  templateType,
  initialCategory,
}: TemplatesCatalogViewProps) {
  const isRu = locale === "ru";
  const text = getDictionary(locale);
  const copy = useMemo(() => getCatalogCopy(locale, templateType), [locale, templateType]);
  const router = useRouter();
  const session = useAuthSession();
  const { analyticsRows, hasError, isLoading, refresh, templates } = useAdminTemplateCatalog({
    enabled: Boolean(session),
    templateType,
  });
  const [actionError, setActionError] = useState<string | null>(null);
  const [busyTemplateId, setBusyTemplateId] = useState<string | null>(null);
  const [viewMode, setViewMode] = useState<ViewMode>("cards");
  const [archiveFilter, setArchiveFilter] = useState<ArchiveFilter>("active");
  const [search, setSearch] = useState("");
  const [categoryFilter, setCategoryFilter] = useState(initialCategory?.trim() || "all");
  const [accessFilter, setAccessFilter] = useState<AccessFilter>("all");
  const [statusFilter, setStatusFilter] = useState<TemplateStatus | "all">("all");
  const [sortMode, setSortMode] = useState<SortMode>("newest");
  const error = actionError ?? (hasError ? text.errorLoadingTemplates : null);

  useEffect(() => {
    if (!session) {
      ensureAdminSession(locale, router);
    }
  }, [locale, router, session]);

  async function handleStatusChange(templateId: string, status: TemplateStatus) {
    setBusyTemplateId(templateId);
    setActionError(null);

    try {
      await changeTemplateStatus(templateId, status);
      await refresh();
    } catch {
      setActionError(text.errorSavingTemplate);
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
    setActionError(null);

    try {
      await deleteTemplate(templateId);
      await refresh();
    } catch {
      setActionError(text.errorDeletingTemplate);
    } finally {
      setBusyTemplateId(null);
    }
  }

  const editorBasePath = `/${locale}/templates/${templateType === "Video" ? "video" : "image"}/editor`;
  const testBasePath = `/${locale}/templates/${templateType === "Video" ? "video" : "image"}/test`;
  const analyticsBasePath = `/${locale}/templates/${templateType === "Video" ? "video" : "image"}/analytics`;
  const categoriesPath = `/${locale}/templates/categories`;
  const catalog = useMemo(() => buildCatalogModel(templates), [templates]);
  const visiblePool =
    archiveFilter === "archived" ? catalog.archivedTemplates : catalog.activeTemplates;
  const deferredSearch = useDeferredValue(search);
  const categoryOptions: SelectOption[] = useMemo(
    () => [
      { value: "all", label: copy.allCategories, tone: "neutral" },
      ...catalog.categories.map((category) => ({
        value: category,
        label: category,
        tone: "neutral" as const,
      })),
    ],
    [catalog.categories, copy]
  );
  const accessOptions: SelectOption[] = [
    { value: "all", label: copy.allAccess, tone: "neutral" },
    { value: "premium", label: text.premiumLabel, tone: "premium" },
    { value: "free", label: text.freeLabel, tone: "recommended" },
  ];
  const statusOptions: SelectOption[] = useMemo(
    () => [
      { value: "all", label: copy.allStatuses, tone: "neutral" },
      { value: "Active", label: getTemplateStatusLabel("Active", locale), tone: "premium" },
      { value: "Draft", label: getTemplateStatusLabel("Draft", locale), tone: "fast" },
      { value: "Archived", label: getTemplateStatusLabel("Archived", locale), tone: "neutral" },
    ],
    [copy, locale]
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
        description: locale === "ru" ? "По стоимости в токенах" : "By token cost",
        tone: "fast",
      },
    ],
    [copy, locale]
  );
  const normalizedSearch = deferredSearch.trim().toLowerCase();
  const filteredTemplates = useMemo(
    () =>
      visiblePool
        .filter((template) => {
          const matchesSearch =
            !normalizedSearch ||
            template.title.toLowerCase().includes(normalizedSearch) ||
            template.shortDescription.toLowerCase().includes(normalizedSearch) ||
            template.tags.some((tag) => tag.toLowerCase().includes(normalizedSearch));
          const matchesCategory = categoryFilter === "all" || template.category === categoryFilter;
          const matchesAccess =
            accessFilter === "all" ||
            (accessFilter === "premium" && template.isPremium) ||
            (accessFilter === "free" && !template.isPremium);
          const matchesStatus = statusFilter === "all" || template.status === statusFilter;

          return matchesSearch && matchesCategory && matchesAccess && matchesStatus;
        })
        .sort((firstTemplate, secondTemplate) =>
          compareTemplates(firstTemplate, secondTemplate, sortMode)
        ),
    [accessFilter, categoryFilter, normalizedSearch, sortMode, statusFilter, visiblePool]
  );

  if (isLoading) {
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
        <Link href={categoriesPath} className={styles.secondaryLink}>
          {copy.manageCategories}
        </Link>
        <Link href={editorBasePath} className={styles.primaryLink}>
          {copy.createTemplate}
        </Link>
      </AdminToolbar>

      <div className={styles.tabRow} role="tablist" aria-label={copy.archiveTabsLabel}>
        <button
          type="button"
          className={archiveFilter === "active" ? styles.tabActive : styles.tab}
          onClick={() => setArchiveFilter("active")}
        >
          {copy.allTemplates}
        </button>
        <button
          type="button"
          className={archiveFilter === "archived" ? styles.tabActive : styles.tab}
          onClick={() => setArchiveFilter("archived")}
        >
          {copy.archivedTemplates}
        </button>
      </div>

      {error ? <AdminStateCard tone="danger" className={styles.error} title={error} /> : null}

      <div className={styles.catalogShell}>
        <div className={styles.catalogMain}>
          <AdminFilterBar className={styles.filtersBar}>
            <label className={styles.searchField}>
              <span className={styles.visuallyHidden}>{copy.searchLabel}</span>
              <input
                value={search}
                onChange={(event) => setSearch(event.target.value)}
                placeholder={copy.searchPlaceholder}
              />
            </label>

            <label className={styles.selectField}>
              <span>{text.categoryLabel}</span>
              <Select
                value={categoryFilter}
                options={categoryOptions}
                ariaLabel={text.categoryLabel}
                onChange={setCategoryFilter}
              />
            </label>

            <label className={styles.selectField}>
              <span>{copy.accessLabel}</span>
              <Select
                value={accessFilter}
                options={accessOptions}
                ariaLabel={copy.accessLabel}
                onChange={(value) => setAccessFilter(value as AccessFilter)}
              />
            </label>

            <label className={styles.selectField}>
              <span>{text.statusLabel}</span>
              <Select
                value={statusFilter}
                options={statusOptions}
                ariaLabel={text.statusLabel}
                onChange={(value) => setStatusFilter(value as TemplateStatus | "all")}
              />
            </label>

            <label className={styles.selectField}>
              <span>{copy.sortLabel}</span>
              <Select
                value={sortMode}
                options={sortOptions}
                ariaLabel={copy.sortLabel}
                showSelectedDescription={false}
                onChange={(value) => setSortMode(value as SortMode)}
              />
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
          {!filteredTemplates.length ? (
            <AdminStateCard tone="info" className={styles.empty} title={text.noTemplates} />
          ) : viewMode === "cards" ? (
            <div className={styles.cardGrid}>
              {filteredTemplates.map((template) => (
                <TemplateCatalogCard
                  key={template.templateId}
                  locale={locale}
                  template={template}
                  analytics={analyticsRows[template.templateId]}
                  editorBasePath={editorBasePath}
                  analyticsBasePath={analyticsBasePath}
                  testBasePath={testBasePath}
                  busyTemplateId={busyTemplateId}
                  onStatusChange={handleStatusChange}
                  onDeleteTemplate={handleDelete}
                />
              ))}
            </div>
          ) : (
            <AdminCard padding="md" className={styles.listCard}>
              <div className={adminTableStyles.tableWrap}>
                <table className={adminTableStyles.table}>
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
                    {filteredTemplates.map((template) => {
                      const isBusy = busyTemplateId === template.templateId;
                      const analytics = analyticsRows[template.templateId];

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
                                    <video
                                      className={styles.listTemplateMedia}
                                      src={template.previewAsset.url}
                                      muted
                                      playsInline
                                      autoPlay
                                      loop
                                      preload="metadata"
                                    />
                                  ) : (
                                    <Image
                                      className={styles.listTemplateMedia}
                                      src={template.previewAsset.url}
                                      alt=""
                                      width={56}
                                      height={56}
                                      unoptimized
                                    />
                                  )
                                ) : template.templateType === "Video" ? (
                                  <VideoIcon className={styles.listTemplateThumbIcon} />
                                ) : (
                                  <ImageIcon className={styles.listTemplateThumbIcon} />
                                )}
                              </div>
                              <div className={styles.titleCell} title={template.shortDescription}>
                                <strong>{template.title}</strong>
                                <span>{template.shortDescription}</span>
                                <small className={styles.templateMetaId}>
                                  ID: {template.templateId.slice(0, 12)}
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
                          <td data-label={text.categoryLabel}>{template.category}</td>
                          <td data-label={copy.accessLabel}>
                            <span
                              className={template.isPremium ? styles.premiumPill : styles.freePill}
                            >
                              {getTemplateAccessLabel(template.isPremium, text)}
                            </span>
                          </td>
                          <td data-label={text.statusLabel}>
                            <AdminStatusBadge color={statusColors[template.status]}>
                              {getTemplateStatusLabel(template.status, locale)}
                            </AdminStatusBadge>
                          </td>
                          <td
                            data-label={isRu ? "Просмотры" : "Views"}
                            className={styles.metricValueCell}
                          >
                            {formatAnalyticsInteger(analytics?.views)}
                          </td>
                          <td
                            data-label={isRu ? "Запуски" : "Starts"}
                            className={styles.metricValueCell}
                          >
                            {formatAnalyticsInteger(analytics?.generationStarts)}
                          </td>
                          <td
                            data-label={isRu ? "Конверсия" : "Conversion"}
                            className={styles.metricValueCell}
                          >
                            {formatPercentMetric(
                              analytics?.generationStarts ? analytics.conversionPercent : null
                            )}
                          </td>
                          <td
                            data-label={isRu ? "Успех" : "Success"}
                            className={styles.metricValueCell}
                          >
                            {formatPercentMetric(getSuccessRatePercent(analytics))}
                          </td>
                          <td
                            data-label={isRu ? "Средняя стоимость" : "Average cost"}
                            className={styles.numericCell}
                          >
                            {template.tokenCost}{" "}
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
                                href={`${editorBasePath}?templateId=${template.templateId}`}
                                className={styles.cardActionIconButton}
                                aria-label={text.editTemplate}
                                title={text.editTemplate}
                              >
                                <PencilIcon className={styles.actionIcon} />
                              </Link>
                              <Link
                                href={`${analyticsBasePath}/${template.templateId}`}
                                className={styles.cardActionIconButton}
                                aria-label={copy.analyticsAction}
                                title={copy.analyticsAction}
                              >
                                <ChartIcon className={styles.actionIcon} />
                              </Link>
                              <Link
                                href={`${testBasePath}/${template.templateId}`}
                                className={styles.cardActionIconButton}
                                aria-label={copy.testAction}
                                title={copy.testAction}
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
                                    void handleStatusChange(template.templateId, "Archived")
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
                                onClick={() => void handleDelete(template.templateId)}
                              >
                                <CancelCircleIcon className={styles.actionIcon} />
                              </Button>
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
      </div>
    </AdminPage>
  );
}

type TemplateCatalogCardProps = {
  locale: Locale;
  template: AdminTemplateListItem;
  analytics?: AdminTemplatesAnalyticsTemplateRow;
  editorBasePath: string;
  analyticsBasePath: string;
  testBasePath: string;
  busyTemplateId: string | null;
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
  onStatusChange,
  onDeleteTemplate,
}: TemplateCatalogCardProps) {
  const text = getDictionary(locale);
  const copy = getCatalogCopy(locale, template.templateType);
  const isBusy = busyTemplateId === template.templateId;

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
          <AdminStatusBadge color={statusColors[template.status]}>
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
            href={`${editorBasePath}?templateId=${template.templateId}`}
            className={styles.cardActionIconButton}
            aria-label={text.editTemplate}
            title={text.editTemplate}
          >
            <PencilIcon className={styles.actionIcon} />
          </Link>
          <Link
            href={`${analyticsBasePath}/${template.templateId}`}
            className={styles.cardActionIconButton}
            aria-label={copy.analyticsAction}
            title={copy.analyticsAction}
          >
            <ChartIcon className={styles.actionIcon} />
          </Link>
          <Link
            href={`${testBasePath}/${template.templateId}`}
            className={styles.cardActionIconButton}
            aria-label={copy.testAction}
            title={copy.testAction}
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
        </div>
      </div>
    </article>
  );
}

function compareTemplates(
  firstTemplate: AdminTemplateListItem,
  secondTemplate: AdminTemplateListItem,
  sortMode: SortMode
) {
  if (sortMode === "title") {
    return firstTemplate.title.localeCompare(secondTemplate.title);
  }

  if (sortMode === "tokens") {
    return secondTemplate.tokenCost - firstTemplate.tokenCost;
  }

  return (
    new Date(secondTemplate.updatedAtUtc).getTime() - new Date(firstTemplate.updatedAtUtc).getTime()
  );
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
    categories: Array.from(categories).sort((firstCategory, secondCategory) =>
      firstCategory.localeCompare(secondCategory)
    ),
    categoryStats: toSortedStats(categoryCounts),
    tagStats: toSortedStats(tagCounts),
    stats,
  };
}

function toSortedStats(counts: Map<string, number>) {
  return Array.from(counts, ([label, count]) => ({ label, count })).sort(
    (firstItem, secondItem) => secondItem.count - firstItem.count
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

function formatAnalyticsInteger(value?: number) {
  if (value === undefined || value === null) {
    return "-";
  }

  return new Intl.NumberFormat("ru-RU").format(value);
}

function formatPercentMetric(value?: number | null) {
  if (value === undefined || value === null || Number.isNaN(value)) {
    return "-";
  }

  return `${value.toFixed(1)}%`;
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
      : `${formatAnalyticsInteger(template.tokenCost)} ${isRu ? "ток." : "tok."}`;

  const metrics = [
    {
      label: isRu ? "Стоимость" : "Template cost",
      value: costValue,
      tone: "cardMetric_primary",
    },
    {
      label: isRu ? "Просмотры" : "Views",
      value: formatAnalyticsInteger(analytics?.views ?? 0),
      tone: "cardMetric_info",
    },
    {
      label: isRu ? "Генерации" : "Generations",
      value: formatAnalyticsInteger(analytics?.generationStarts ?? 0),
      tone: "cardMetric_success",
    },
    {
      label: isRu ? "Ошибки" : "Errors",
      value: formatAnalyticsInteger(analytics?.failedGenerations ?? 0),
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
    sortTokens: isRu ? "По токенам" : "By tokens",
    viewToggleLabel: isRu ? "Переключение вида" : "View mode",
    cardsView: isRu ? "Карточки" : "Cards",
    listView: isRu ? "Список" : "List",
    testAction: isRu ? "Тест" : "Test",
    tokensShort: isRu ? "ток." : "tokens",
    updatedLabel: isRu ? "Обновлен" : "Updated",
    updatedShort: isRu ? "Обновлен" : "Updated",
    showing: (visible: number, total: number) =>
      isRu
        ? `Показано ${visible} из ${total} шаблонов`
        : `Showing ${visible} of ${total} templates`,
  };
}
