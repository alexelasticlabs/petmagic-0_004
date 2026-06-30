"use client";

import Link from "next/link";

import {
  DetailRow,
  StatusPill,
  StepHeader,
} from "@/components/templates/template-test-page.components";
import type { TemplateTestPageText } from "@/components/templates/template-test-page.content";
import {
  formatDateTime,
  formatTemplateTestDisplayText,
} from "@/components/templates/template-test-page.helpers";
import styles from "@/components/templates/template-test-page.module.css";
import type { DetailItem, TimelineItem } from "@/components/templates/template-test-page.types";
import type { AdminTemplateTestRun } from "@/lib/api-client";
import type { Locale } from "@/lib/i18n";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";


export function TemplateTestPageHeader({
  canManageTemplates,
  catalogPath,
  editorPath,
  headerPills,
  isVideoTemplate,
  pageText,
  templateTitle,
}: {
  canManageTemplates: boolean;
  catalogPath: string;
  editorPath: string;
  headerPills: Array<{
    label: string;
    tone: "success" | "warning" | "danger" | "info" | "premium" | "muted";
  }>;
  isVideoTemplate: boolean;
  pageText: TemplateTestPageText;
  templateTitle: string;
}) {
  return (
    <div className={styles.pageHeader}>
      <div className={styles.breadcrumbs}>
        <Link href={catalogPath}>
          {isVideoTemplate ? pageText.videoTemplates : pageText.imageTemplates}
        </Link>
        <span aria-hidden="true">/</span>
        {canManageTemplates ? (
          <Link href={editorPath}>{templateTitle}</Link>
        ) : (
          <span>{templateTitle}</span>
        )}
        <span aria-hidden="true">/</span>
        <span>{pageText.templateTest}</span>
      </div>

      <div className={styles.headerGrid}>
        <div className={styles.headerMeta}>
          <div className={styles.pillRow}>
            {headerPills.map((pill) => (
              <StatusPill key={`${pill.tone}-${pill.label}`} tone={pill.tone}>
                {pill.label}
              </StatusPill>
            ))}
          </div>
        </div>
        <div className={styles.headerActions}>
          <Link href={catalogPath} className={styles.secondaryLink}>
            <span>{pageText.backToCatalog}</span>
          </Link>
          {canManageTemplates ? (
            <Link href={editorPath} className={styles.primaryLink}>
              <span>{pageText.openEditor}</span>
            </Link>
          ) : null}
        </div>
      </div>
    </div>
  );
}

export function TemplateTestTimelineSection({
  pageText,
  timeline,
}: {
  pageText: TemplateTestPageText;
  timeline: TimelineItem[];
}) {
  return (
    <section className={styles.card}>
      <StepHeader number="2" title={pageText.generationEvents} />
      <div className={styles.timeline}>
        {timeline.length ? (
          timeline.map((event) => (
            <div key={`${event.label}-${event.at}`} className={styles.timelineItem}>
              <span
                className={`${styles.timelineDot} ${event.done ? styles.timelineDotDone : ""}`}
                aria-hidden="true"
              >
                ✓
              </span>
              <div className={styles.timelineText}>
                <strong>{event.label}</strong>
                <span>{event.description}</span>
              </div>
              <time>{event.at}</time>
              <StatusPill tone={event.done ? "success" : "info"}>
                {event.done ? pageText.done : pageText.runningShort}
              </StatusPill>
            </div>
          ))
        ) : (
          <p className={styles.infoText}>{pageText.timelineEmpty}</p>
        )}
      </div>
    </section>
  );
}

export function TemplateTestRunSummarySection({
  pageText,
  runDetails,
}: {
  pageText: TemplateTestPageText;
  runDetails: DetailItem[];
}) {
  return (
    <section className={styles.card}>
      <StepHeader number="3" title={pageText.runSummary} />
      <div className={styles.detailGrid}>
        {runDetails.map((item) => (
          <DetailRow
            key={item.label}
            label={item.label}
            value={item.value}
            multiline={item.multiline}
          />
        ))}
      </div>
    </section>
  );
}

function historyTone(status: string) {
  return status === "Completed"
    ? "success"
    : status === "Failed"
      ? "danger"
      : status === "Queued"
        ? "info"
        : "muted";
}

export function TemplateTestHistorySection({
  activeRun,
  emptyText,
  history,
  locale,
  pageText,
  setRunError,
  setSelectedHistoryGenerationId,
}: {
  activeRun: AdminTemplateTestRun | null;
  emptyText: string;
  history: AdminTemplateTestRun[];
  locale: Locale;
  pageText: TemplateTestPageText;
  setRunError: (value: string | null) => void;
  setSelectedHistoryGenerationId: (value: string | null) => void;
}) {
  return (
    <section className={styles.card}>
      <StepHeader
        number="4"
        title={pageText.testHistory}
        badge={history.length ? String(history.length) : undefined}
      />
      {history.length ? (
        <div className={styles.historyList}>
          {history.map((item) => {
            const isCurrent = activeRun?.generationId === item.generationId;
            const sourceLabel = sanitizeSensitiveText(
              item.sourceImageAsset?.fileName ?? pageText.noPhotoSelected,
              120
            );

            return (
              <button
                key={item.generationId}
                type="button"
                className={`${styles.historyItem} ${isCurrent ? styles.historyItemCurrent : ""}`}
                onClick={() => {
                  setSelectedHistoryGenerationId(item.generationId);
                  setRunError(null);
                }}
              >
                <div className={styles.historyItemHeader}>
                  <div className={styles.historyItemTitleBlock}>
                    <strong>{formatDateTime(item.createdAtUtc, locale, true)}</strong>
                    <span>{sourceLabel}</span>
                  </div>
                  <StatusPill tone={historyTone(item.status)}>
                    {formatTemplateTestDisplayText(item.status, "-", 64)}
                  </StatusPill>
                </div>
                <div className={styles.historyItemMeta}>
                  <span>
                    {pageText.attempt}: {item.attemptCount}
                  </span>
                  <span>PawSpark: {item.tokenCost}</span>
                  <span>
                    {pageText.started}: {formatDateTime(item.startedAtUtc, locale, true)}
                  </span>
                  <span>
                    {pageText.completed}: {formatDateTime(item.completedAtUtc, locale, true)}
                  </span>
                </div>
              </button>
            );
          })}
        </div>
      ) : (
        <p className={styles.infoText}>{emptyText}</p>
      )}
    </section>
  );
}
