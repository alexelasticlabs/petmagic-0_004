"use client";

import Link from "next/link";

import {
  CalendarIcon,
  CaretDownIcon,
  ChartIcon,
  ImageIcon,
  PlusIcon,
  TemplatesIcon,
  VideoIcon,
} from "@/components/admin/admin-icons";
import { AdminCard, AdminContextBar, AdminMetricStrip } from "@/components/admin/admin-primitives";
import type { TemplatesCatalogViewText } from "@/components/templates/templates-catalog-view.content";
import styles from "@/components/templates/templates-catalog.module.css";
import type { AdminTemplateCatalogSummary, TemplateType } from "@/lib/api-client";
import type { Locale } from "@/lib/i18n";

type TemplatesCatalogWorkspaceHeaderProps = {
  canManageTemplates: boolean;
  copy: TemplatesCatalogViewText;
  locale: Locale;
  summary: AdminTemplateCatalogSummary | null;
  templateType?: TemplateType;
};

type TemplatesCatalogRailProps = {
  copy: TemplatesCatalogViewText;
  locale: Locale;
  summary: AdminTemplateCatalogSummary | null;
  onShowDrafts: () => void;
  onShowMissingPreview: () => void;
  onShowQaOnly: () => void;
};

function formatMetric(value: number | undefined, locale: Locale) {
  return new Intl.NumberFormat(locale === "ru" ? "ru-RU" : "en-US").format(value ?? 0);
}

function getTemplateTypePath(locale: Locale, templateType?: TemplateType) {
  if (templateType === "Video") {
    return `/${locale}/templates/video`;
  }

  if (templateType === "Image") {
    return `/${locale}/templates/image`;
  }

  return `/${locale}/templates`;
}

export function TemplatesCatalogWorkspaceHeader({
  canManageTemplates,
  copy,
  locale,
  summary,
  templateType,
}: TemplatesCatalogWorkspaceHeaderProps) {
  const categoriesPath = `/${locale}/templates/categories`;
  const editorType = templateType === "Image" ? "image" : "video";
  const typeTabs = [
    { href: getTemplateTypePath(locale), label: copy.allTypes, type: undefined },
    { href: getTemplateTypePath(locale, "Video"), label: copy.videoTypes, type: "Video" },
    { href: getTemplateTypePath(locale, "Image"), label: copy.imageTypes, type: "Image" },
  ] satisfies ReadonlyArray<{ href: string; label: string; type?: TemplateType }>;

  return (
    <>
      <AdminContextBar
        className={styles.catalogHero}
        actions={
          <div className={styles.catalogActions}>
            {canManageTemplates ? (
              <Link href={categoriesPath} className={styles.secondaryLink}>
                <TemplatesIcon className={styles.linkIcon} />
                <span>{copy.categoriesAction}</span>
              </Link>
            ) : null}
            {canManageTemplates && templateType ? (
              <Link
                href={`/${locale}/templates/${editorType}/editor`}
                className={styles.primaryLink}
              >
                <PlusIcon className={styles.linkIcon} />
                <span>{copy.createTemplate}</span>
              </Link>
            ) : null}
            {canManageTemplates && !templateType ? (
              <details className={styles.createMenu}>
                <summary className={styles.primaryLink}>
                  <PlusIcon className={styles.linkIcon} />
                  <span>{copy.createTemplate}</span>
                  <CaretDownIcon className={styles.createMenuCaret} />
                </summary>
                <div className={styles.createMenuPanel} aria-label={copy.chooseTemplateType}>
                  <Link
                    href={`/${locale}/templates/video/editor`}
                    className={styles.createMenuItem}
                  >
                    <VideoIcon className={styles.createMenuIcon} />
                    <span>{copy.createVideoTemplate}</span>
                  </Link>
                  <Link
                    href={`/${locale}/templates/image/editor`}
                    className={styles.createMenuItem}
                  >
                    <ImageIcon className={styles.createMenuIcon} />
                    <span>{copy.createImageTemplate}</span>
                  </Link>
                </div>
              </details>
            ) : null}
          </div>
        }
      />

      <nav className={styles.typeTabs} aria-label={copy.typesLabel}>
        {typeTabs.map((item) => {
          const isCurrent = item.type === templateType;
          return (
            <Link
              key={item.label}
              href={item.href}
              className={isCurrent ? styles.typeTabActive : styles.typeTab}
              aria-current={isCurrent ? "page" : undefined}
            >
              {item.label}
            </Link>
          );
        })}
      </nav>

      <AdminMetricStrip
        className={styles.catalogMetricStrip}
        items={[
          {
            label: copy.totalMetric,
            value: formatMetric(summary?.totalTemplates, locale),
          },
          {
            label: copy.activeMetric,
            value: formatMetric(summary?.activeTemplates, locale),
          },
          {
            label: copy.draftsMetric,
            value: formatMetric(summary?.draftTemplates, locale),
          },
          {
            label: copy.missingPreviewMetric,
            value: formatMetric(summary?.missingPreviewTemplates, locale),
          },
          {
            label: copy.qaOnlyMetric,
            value: formatMetric(summary?.qaOnlyTemplates, locale),
          },
        ]}
      />
    </>
  );
}

export function TemplatesCatalogRail({
  copy,
  locale,
  summary,
  onShowDrafts,
  onShowMissingPreview,
  onShowQaOnly,
}: TemplatesCatalogRailProps) {
  const attentionItems = [
    {
      label: copy.draftsMetric,
      value: summary?.draftTemplates ?? 0,
      onClick: onShowDrafts,
    },
    {
      label: copy.missingPreviewMetric,
      value: summary?.missingPreviewTemplates ?? 0,
      onClick: onShowMissingPreview,
    },
    {
      label: copy.qaOnlyMetric,
      value: summary?.qaOnlyTemplates ?? 0,
      onClick: onShowQaOnly,
    },
  ];

  return (
    <aside className={styles.catalogRail} aria-label={copy.publicationControlTitle}>
      <AdminCard
        className={styles.railCard}
        title={copy.publicationControlTitle}
        description={copy.publicationControlDescription}
      >
        <div className={styles.railActions}>
          {attentionItems.map((item) => (
            <button
              key={item.label}
              type="button"
              className={styles.railAction}
              disabled={item.value === 0}
              onClick={item.onClick}
            >
              <span>{item.label}</span>
              <strong>{formatMetric(item.value, locale)}</strong>
              <CaretDownIcon className={styles.railActionIcon} />
            </button>
          ))}
        </div>
      </AdminCard>

      <AdminCard className={styles.railCard} title={copy.quickLinksTitle}>
        <nav className={styles.quickLinks} aria-label={copy.quickLinksTitle}>
          <Link href={`/${locale}/templates/analytics`} className={styles.quickLink}>
            <ChartIcon className={styles.quickLinkIcon} />
            <span>{copy.analyticsHubAction}</span>
            <CaretDownIcon className={styles.quickLinkCaret} />
          </Link>
          <Link href={`/${locale}/templates/daily-featured`} className={styles.quickLink}>
            <CalendarIcon className={styles.quickLinkIcon} />
            <span>{copy.dailyFeaturedAction}</span>
            <CaretDownIcon className={styles.quickLinkCaret} />
          </Link>
          <Link href={`/${locale}/templates/categories`} className={styles.quickLink}>
            <TemplatesIcon className={styles.quickLinkIcon} />
            <span>{copy.categoriesAction}</span>
            <CaretDownIcon className={styles.quickLinkCaret} />
          </Link>
        </nav>
      </AdminCard>
    </aside>
  );
}
