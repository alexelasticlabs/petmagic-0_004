"use client";

import {
  useRef,
  type ChangeEvent,
  type DragEvent,
  type KeyboardEvent,
  type ReactNode,
} from "react";

import {
  CalendarIcon,
  ChartIcon,
  ClockIcon,
  ImageIcon,
  PlayCircleIcon,
  RefreshIcon,
  TableIcon,
  VideoIcon,
} from "@/components/admin/admin-icons";
import { TemplateSecureMedia } from "@/components/templates/template-secure-media";
import { formatTemplateTestDisplayText } from "@/components/templates/template-test-page.helpers";
import { TemplateTestMediaActions } from "@/components/templates/template-test-page.media-actions";
import styles from "@/components/templates/template-test-page.module.css";
import type {
  DetailItem,
  MediaPreviewCardProps,
  SourceUploadCardProps,
} from "@/components/templates/template-test-page.types";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

export function WorkflowConnector() {
  return (
    <div className={styles.mediaConnector} aria-hidden="true">
      <span className={styles.mediaConnectorLine} />
      <span className={styles.mediaConnectorArrow}>→</span>
    </div>
  );
}

export function StepHeader({
  number,
  title,
  badge,
}: {
  number: string;
  title: string;
  badge?: string;
}) {
  const icon =
    number === "1" ? (
      <PlayCircleIcon className={styles.stepIcon} />
    ) : number === "2" ? (
      <RefreshIcon className={styles.stepIcon} />
    ) : (
      <TableIcon className={styles.stepIcon} />
    );

  return (
    <div className={styles.stepHeader}>
      <h2>
        <span>{number}.</span> {icon}
        {title}
      </h2>
      {badge ? <StatusPill tone="success">{badge}</StatusPill> : null}
    </div>
  );
}

export function StatusPill({
  children,
  tone,
}: {
  children: ReactNode;
  tone: "success" | "warning" | "danger" | "info" | "premium" | "muted";
}) {
  return <span className={`${styles.statusPill} ${styles[`statusPill_${tone}`]}`}>{children}</span>;
}

export function MetricTile({ label, value }: { label: string; value: string }) {
  return (
    <div className={styles.metricTile}>
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  );
}

export function DetailRow({ label, value, multiline = false }: DetailItem) {
  const icon = /attempt|попыт/i.test(label) ? (
    <RefreshIcon className={styles.detailIcon} />
  ) : /status|статус/i.test(label) ? (
    <ChartIcon className={styles.detailIcon} />
  ) : /created|создан|started|запущен|completed|заверш|update|обнов/i.test(label) ? (
    <CalendarIcon className={styles.detailIcon} />
  ) : /duration|время|inference|sec|длительность/i.test(label) ? (
    <ClockIcon className={styles.detailIcon} />
  ) : /media|video|motion|preprocess|fal/i.test(label) ? (
    <VideoIcon className={styles.detailIcon} />
  ) : (
    <ImageIcon className={styles.detailIcon} />
  );
  const safeValue = formatTemplateTestDisplayText(value, "-", multiline ? 320 : 180);

  return (
    <div className={multiline ? styles.detailRowMultiline : styles.detailRow}>
      <span className={styles.detailLabel}>
        <span className={styles.detailLabelIcon}>{icon}</span>
        <span>{label}</span>
      </span>
      <strong>{safeValue}</strong>
    </div>
  );
}

export function MediaPreviewCard({
  title,
  accent,
  imageUrl,
  videoUrl,
  placeholderEyebrow,
  placeholderTitle,
  placeholderText,
  openLabel,
  downloadLabel,
  downloadName,
  canManageTemplates,
}: MediaPreviewCardProps) {
  const previewUrl = videoUrl ?? imageUrl;

  return (
    <section className={`${styles.mediaPreviewCard} ${styles[`mediaPreviewCard_${accent}`]}`}>
      <div className={styles.mediaCardHeader}>
        <strong className={styles.mediaCardTitle}>
          {videoUrl ? (
            <VideoIcon className={styles.inlineIcon} />
          ) : (
            <ImageIcon className={styles.inlineIcon} />
          )}
          <span>{title}</span>
        </strong>
        <span>{placeholderEyebrow}</span>
      </div>

      {videoUrl ? (
        <TemplateSecureMedia
          url={videoUrl}
          kind="video"
          controls
          muted
          playsInline
          preload="metadata"
          className={styles.mediaAsset}
          ariaLabel={title}
          logContext={{ surface: "template_test_result" }}
        />
      ) : imageUrl ? (
        <TemplateSecureMedia
          url={imageUrl}
          kind="image"
          alt={title}
          width={720}
          height={420}
          className={`${styles.mediaAsset} ${styles.mediaAssetImage}`}
          logContext={{ surface: "template_test_result" }}
        />
      ) : (
        <div className={`${styles.mediaAsset} ${styles.mediaPlaceholder}`}>
          <div className={styles.mediaPlaceholderGlow} aria-hidden="true" />
          <div className={styles.mediaPlaceholderBody}>
            <span>{placeholderEyebrow}</span>
            <strong>{placeholderTitle}</strong>
            <p>{placeholderText}</p>
          </div>
        </div>
      )}

      <div className={styles.mediaFooter}>
        {previewUrl ? (
          <TemplateTestMediaActions
            canManageTemplates={canManageTemplates}
            downloadLabel={downloadLabel}
            downloadName={downloadName}
            openLabel={openLabel}
            previewUrl={previewUrl}
            videoUrl={videoUrl}
          />
        ) : null}
      </div>
    </section>
  );
}

export function SourceUploadCard({
  text,
  imageUrl,
  fileName,
  fileMeta,
  isDragActive,
  isDisabled,
  onDragActiveChange,
  onFileSelected,
  onReset,
}: SourceUploadCardProps) {
  const inputRef = useRef<HTMLInputElement | null>(null);
  const safeFileName = sanitizeSensitiveText(fileName, 120);
  const safeFileMeta = sanitizeSensitiveText(fileMeta, 120);

  function handleInputChange(event: ChangeEvent<HTMLInputElement>) {
    if (isDisabled) {
      event.target.value = "";
      return;
    }

    onFileSelected(event.target.files?.[0] ?? null);
    event.target.value = "";
  }

  function handleDragOver(event: DragEvent<HTMLLabelElement>) {
    event.preventDefault();
    if (isDisabled) {
      return;
    }

    onDragActiveChange(true);
  }

  function handleDragLeave(event: DragEvent<HTMLLabelElement>) {
    const relatedTarget = event.relatedTarget;
    if (!(relatedTarget instanceof Node) || !event.currentTarget.contains(relatedTarget)) {
      onDragActiveChange(false);
    }
  }

  function handleDrop(event: DragEvent<HTMLLabelElement>) {
    event.preventDefault();
    onDragActiveChange(false);
    if (isDisabled) {
      return;
    }

    onFileSelected(event.dataTransfer.files?.[0] ?? null);
  }

  function handleKeyDown(event: KeyboardEvent<HTMLLabelElement>) {
    if (isDisabled) {
      return;
    }

    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault();
      inputRef.current?.click();
    }
  }

  return (
    <section className={`${styles.mediaPreviewCard} ${styles.mediaPreviewCard_source}`}>
      <div className={styles.mediaCardHeader}>
        <strong className={styles.mediaCardTitle}>
          <ImageIcon className={styles.inlineIcon} />
          <span>{text.sourceTitle}</span>
        </strong>
        <span>{text.sourceInputLabel}</span>
      </div>

      <label
        className={`${styles.uploadDropzone} ${isDragActive ? styles.uploadDropzoneActive : ""}`}
        onDragOver={handleDragOver}
        onDragLeave={handleDragLeave}
        onDrop={handleDrop}
        onKeyDown={handleKeyDown}
        aria-disabled={isDisabled}
        tabIndex={isDisabled ? -1 : 0}
      >
        <input
          ref={inputRef}
          className={styles.uploadDropzoneInput}
          type="file"
          accept="image/*"
          disabled={isDisabled}
          onChange={handleInputChange}
        />
        {imageUrl ? (
          <TemplateSecureMedia
            url={imageUrl}
            kind="image"
            alt={safeFileName}
            width={720}
            height={420}
            className={`${styles.mediaAsset} ${styles.mediaAssetImage}`}
            logContext={{ surface: "template_test_source" }}
          />
        ) : (
          <div className={`${styles.mediaAsset} ${styles.mediaPlaceholder}`}>
            <div className={styles.mediaPlaceholderGlow} aria-hidden="true" />
            <div className={styles.mediaPlaceholderBody}>
              <span>{text.dropzoneTitle}</span>
              <strong>{text.addPetPhoto}</strong>
              <p>{text.dropzoneHint}</p>
            </div>
          </div>
        )}

        {imageUrl ? <span className={styles.uploadDropzoneBadge}>{text.replaceHint}</span> : null}
      </label>

      <div className={styles.sourceUploadFooter}>
        <div className={styles.sourceUploadMeta}>
          <strong>{imageUrl ? safeFileName : text.noPhotoSelected}</strong>
          <span>{imageUrl ? safeFileMeta : text.uploadSupport}</span>
        </div>
        {onReset ? (
          <button type="button" className={styles.sourceUploadReset} onClick={onReset}>
            <RefreshIcon className={styles.inlineIcon} />
            <span>{text.clear}</span>
          </button>
        ) : null}
      </div>
    </section>
  );
}
