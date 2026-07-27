"use client";

import Link from "next/link";
import { useDeferredValue, useMemo, useState } from "react";

import { RefreshIcon } from "@/components/admin/admin-icons";
import { AdminCard, AdminMetricStrip, AdminStatusBadge } from "@/components/admin/admin-primitives";
import {
  getTemplatesCategoryDiagnosticsText,
  type TemplatesCategoryDiagnosticsText,
} from "@/components/templates/templates-category-diagnostics.content";
import {
  buildTemplateCategoryEditorPath,
  filterTemplateCategoryDiagnosticItems,
  type TemplateCategoryDiagnosticFilter,
} from "@/components/templates/templates-category-diagnostics.helpers";
import styles from "@/components/templates/templates-category-diagnostics.module.css";
import { Button } from "@/components/ui/button";
import type {
  AdminTemplateCategoryDiagnostics,
  AdminTemplateCategoryDiagnosticItem,
} from "@/lib/api-client.types.template-category-diagnostics";
import type { Locale } from "@/lib/i18n";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

type TemplatesCategoryDiagnosticsProps = {
  diagnostics: AdminTemplateCategoryDiagnostics | null;
  hasError: boolean;
  hasRun: boolean;
  isFetching: boolean;
  isStale: boolean;
  locale: Locale;
  onRun: () => void;
};

type IssueCopy = {
  hint: string;
  label: string;
  tone: string;
};

export function TemplatesCategoryDiagnostics({
  diagnostics,
  hasError,
  hasRun,
  isFetching,
  isStale,
  locale,
  onRun,
}: TemplatesCategoryDiagnosticsProps) {
  const text = useMemo(() => getTemplatesCategoryDiagnosticsText(locale), [locale]);
  const [search, setSearch] = useState("");
  const [issueFilter, setIssueFilter] = useState<TemplateCategoryDiagnosticFilter>("all");
  const deferredSearch = useDeferredValue(search);
  const visibleItems = useMemo(
    () =>
      filterTemplateCategoryDiagnosticItems(diagnostics?.items ?? [], issueFilter, deferredSearch),
    [deferredSearch, diagnostics?.items, issueFilter]
  );

  return (
    <AdminCard
      className={styles.diagnosticsCard}
      title={text.title}
      titleId="template-category-diagnostics-title"
      description={text.description}
      action={
        <Button type="button" variant="secondary" disabled={isFetching} onClick={onRun}>
          <RefreshIcon className={styles.buttonIcon} />
          {isFetching ? text.running : hasRun ? text.retry : text.run}
        </Button>
      }
    >
      <div
        className={styles.diagnosticsBody}
        aria-labelledby="template-category-diagnostics-title"
        aria-busy={isFetching}
      >
        {!hasRun ? (
          <DiagnosticsState
            tone="neutral"
            title={text.notRunTitle}
            description={text.notRunDescription}
          />
        ) : null}

        {hasRun && isFetching && !diagnostics ? (
          <DiagnosticsState tone="info" title={text.running} description={text.description} />
        ) : null}

        {hasError ? (
          <DiagnosticsState
            tone="danger"
            title={text.errorTitle}
            description={text.errorDescription}
          />
        ) : null}

        {diagnostics ? (
          <>
            {isStale ? (
              <DiagnosticsState
                tone="warning"
                title={text.staleTitle}
                description={text.staleDescription}
              />
            ) : null}

            <AdminMetricStrip
              className={styles.metricStrip}
              items={[
                { label: text.activeTemplates, value: diagnostics.totalActiveTemplates },
                { label: text.issues, value: diagnostics.noncanonicalTemplates },
                {
                  label: text.affected,
                  value: `${formatPercent(diagnostics.noncanonicalPercent)}%`,
                },
                {
                  label: text.generatedAt,
                  value: formatDateTime(diagnostics.generatedAtUtc, locale),
                },
              ]}
            />

            {diagnostics.items.length === 0 ? (
              <DiagnosticsState
                tone="success"
                title={text.healthyTitle}
                description={text.healthyDescription}
              />
            ) : (
              <div className={styles.resultsRegion}>
                <div className={styles.resultsHeading}>
                  <div>
                    <h3>{text.issuesTitle}</h3>
                    <p>{text.issuesDescription}</p>
                  </div>
                  <span>{text.resultCount(visibleItems.length, diagnostics.items.length)}</span>
                </div>

                <div className={styles.filters}>
                  <label className={styles.field}>
                    <span>{text.searchLabel}</span>
                    <input
                      type="search"
                      value={search}
                      maxLength={120}
                      placeholder={text.searchPlaceholder}
                      onChange={(event) => setSearch(event.target.value.slice(0, 120))}
                    />
                  </label>
                  <label className={styles.field}>
                    <span>{text.issueFilterLabel}</span>
                    <select
                      value={issueFilter}
                      onChange={(event) =>
                        setIssueFilter(event.target.value as TemplateCategoryDiagnosticFilter)
                      }
                    >
                      <option value="all">{text.allIssues}</option>
                      <option value="empty_category">{text.emptyCategory}</option>
                      <option value="archived_category">{text.archivedCategory}</option>
                      <option value="missing_category">{text.missingCategory}</option>
                    </select>
                  </label>
                </div>

                {visibleItems.length ? (
                  <DiagnosticsResults items={visibleItems} locale={locale} text={text} />
                ) : (
                  <p className={styles.filteredEmpty} role="status">
                    {text.filteredEmpty}
                  </p>
                )}
              </div>
            )}
          </>
        ) : null}
      </div>
    </AdminCard>
  );
}

function DiagnosticsState({
  description,
  title,
  tone,
}: {
  description: string;
  title: string;
  tone: "danger" | "info" | "neutral" | "success" | "warning";
}) {
  return (
    <div
      className={`${styles.stateBand} ${styles[`stateBand_${tone}`]}`}
      role={tone === "danger" || tone === "warning" ? "alert" : "status"}
    >
      <span className={styles.stateIndicator} aria-hidden="true" />
      <div>
        <strong>{title}</strong>
        <p>{description}</p>
      </div>
    </div>
  );
}

function DiagnosticsResults({
  items,
  locale,
  text,
}: {
  items: AdminTemplateCategoryDiagnosticItem[];
  locale: Locale;
  text: TemplatesCategoryDiagnosticsText;
}) {
  return (
    <>
      <div className={styles.desktopTableWrap}>
        <table className={styles.desktopTable}>
          <thead>
            <tr>
              <th>{text.issueColumn}</th>
              <th>{text.templateColumn}</th>
              <th>{text.categoryColumn}</th>
              <th>{text.typeColumn}</th>
              <th>{text.updatedColumn}</th>
              <th>{text.actionColumn}</th>
            </tr>
          </thead>
          <tbody>
            {items.map((item) => (
              <DiagnosticsTableRow key={item.templateId} item={item} locale={locale} text={text} />
            ))}
          </tbody>
        </table>
      </div>

      <ul className={styles.mobileCards}>
        {items.map((item) => {
          const issueCopy = resolveIssueCopy(item.issueKind, text);
          const title = sanitizeSensitiveText(item.title, 120);
          const category = sanitizeSensitiveText(item.category, 96) || text.emptyValue;

          return (
            <li key={item.templateId} className={styles.mobileCard}>
              <div className={styles.mobileCardHeading}>
                <AdminStatusBadge color={issueCopy.tone}>{issueCopy.label}</AdminStatusBadge>
                <span>{formatDateTime(item.updatedAtUtc, locale)}</span>
              </div>
              <strong className={styles.templateTitle}>{title}</strong>
              <p className={styles.issueHint}>{issueCopy.hint}</p>
              <dl>
                <div>
                  <dt>{text.categoryColumn}</dt>
                  <dd>{category}</dd>
                </div>
                <div>
                  <dt>{text.typeColumn}</dt>
                  <dd>{sanitizeSensitiveText(item.templateType, 32)}</dd>
                </div>
              </dl>
              <Link
                className={styles.editorLink}
                href={buildTemplateCategoryEditorPath(locale, item)}
              >
                {text.openEditor}
              </Link>
            </li>
          );
        })}
      </ul>
    </>
  );
}

function DiagnosticsTableRow({
  item,
  locale,
  text,
}: {
  item: AdminTemplateCategoryDiagnosticItem;
  locale: Locale;
  text: TemplatesCategoryDiagnosticsText;
}) {
  const issueCopy = resolveIssueCopy(item.issueKind, text);
  const title = sanitizeSensitiveText(item.title, 120);
  const category = sanitizeSensitiveText(item.category, 96) || text.emptyValue;

  return (
    <tr>
      <td>
        <div className={styles.issueCell}>
          <AdminStatusBadge color={issueCopy.tone}>{issueCopy.label}</AdminStatusBadge>
          <span>{issueCopy.hint}</span>
        </div>
      </td>
      <td>
        <strong className={styles.templateTitle}>{title}</strong>
      </td>
      <td>{category}</td>
      <td>{sanitizeSensitiveText(item.templateType, 32)}</td>
      <td>{formatDateTime(item.updatedAtUtc, locale)}</td>
      <td>
        <Link className={styles.editorLink} href={buildTemplateCategoryEditorPath(locale, item)}>
          {text.openEditor}
        </Link>
      </td>
    </tr>
  );
}

function resolveIssueCopy(issueKind: string, text: TemplatesCategoryDiagnosticsText): IssueCopy {
  switch (issueKind) {
    case "empty_category":
      return { label: text.emptyCategory, hint: text.emptyCategoryHint, tone: "var(--info)" };
    case "archived_category":
      return {
        label: text.archivedCategory,
        hint: text.archivedCategoryHint,
        tone: "var(--warning)",
      };
    case "missing_category":
      return {
        label: text.missingCategory,
        hint: text.missingCategoryHint,
        tone: "var(--danger)",
      };
    default:
      return {
        label: text.unknownIssue,
        hint: text.unknownIssueHint,
        tone: "var(--text-muted)",
      };
  }
}

function formatDateTime(value: string, locale: Locale): string {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return "—";
  }

  return new Intl.DateTimeFormat(locale === "ru" ? "ru-RU" : "en-US", {
    dateStyle: "medium",
    timeStyle: "short",
  }).format(date);
}

function formatPercent(value: number): string {
  return Number.isFinite(value) ? Math.max(0, Math.min(100, value)).toFixed(2) : "0.00";
}
