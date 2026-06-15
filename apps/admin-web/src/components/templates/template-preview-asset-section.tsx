import { type DragEvent, useEffect, useMemo, useRef, useState } from "react";

import styles from "@/components/templates/template-editor.module.css";
import { inferTemplateMediaKind } from "@/components/templates/template-media-utils";
import { TemplateSecureMedia } from "@/components/templates/template-secure-media";
import type { SetTemplateFormState, TemplateFormState } from "@/components/templates/types";
import { Button } from "@/components/ui/button";
import type { Dictionary } from "@/lib/i18n";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

const TEMPLATE_PREVIEW_ASSET_MAX_BYTES = 32 * 1024 * 1024;

type TemplatePreviewAssetSectionProps = {
  text: Dictionary;
  form: TemplateFormState;
  setForm: SetTemplateFormState;
  previewFile: File | null;
  setPreviewFile: (file: File | null) => void;
  uploadingKind: "Preview" | "ReferenceMotion" | null;
  onUploadPreview: () => void;
};

export function TemplatePreviewAssetSection({
  text,
  form,
  setForm,
  previewFile,
  setPreviewFile,
  uploadingKind,
  onUploadPreview,
}: TemplatePreviewAssetSectionProps) {
  const fileInputRef = useRef<HTMLInputElement | null>(null);
  const [isDragActive, setIsDragActive] = useState(false);
  const [selectionError, setSelectionError] = useState<string | null>(null);
  const localPreviewUrl = useMemo(
    () => (previewFile ? URL.createObjectURL(previewFile) : null),
    [previewFile]
  );
  const persistedPreviewUrl = form.previewUrl.trim();
  const effectivePreviewUrl = localPreviewUrl ?? persistedPreviewUrl;
  const hasPreview = Boolean(effectivePreviewUrl);
  const previewKind = previewFile
    ? inferTemplateMediaKind(previewFile.type, previewFile.name)
    : inferTemplateMediaKind(form.previewContentType, persistedPreviewUrl);
  const previewFileLabel = sanitizeSensitiveText(
    previewFile?.name || form.previewFileName || text.noFileSelected,
    120
  );
  const previewStateLabel = hasPreview ? text.editorReady : text.editorMissing;

  useEffect(() => {
    return () => {
      if (localPreviewUrl) {
        URL.revokeObjectURL(localPreviewUrl);
      }
    };
  }, [localPreviewUrl]);

  function openFilePicker() {
    fileInputRef.current?.click();
  }

  function handlePreviewFileSelection(file: File | null) {
    if (!file) {
      return;
    }

    if (!file.type.startsWith("image/") && !file.type.startsWith("video/")) {
      setSelectionError(getPreviewSelectionError(text, "type"));
      return;
    }

    if (file.size > TEMPLATE_PREVIEW_ASSET_MAX_BYTES) {
      setSelectionError(getPreviewSelectionError(text, "size"));
      return;
    }

    setSelectionError(null);
    setPreviewFile(file);
  }

  function handlePreviewDrop(event: DragEvent<HTMLDivElement>) {
    event.preventDefault();
    setIsDragActive(false);
    handlePreviewFileSelection(event.dataTransfer.files?.[0] ?? null);
  }

  return (
    <div className={styles.formSection}>
      <h3>{text.previewAssetTitle}</h3>
      <input
        ref={fileInputRef}
        className={styles.filePickerInput}
        type="file"
        accept="image/*,video/*"
        onChange={(event) => handlePreviewFileSelection(event.target.files?.[0] ?? null)}
      />
      <div
        className={`${styles.assetPreview} ${styles.assetPreviewInteractive} ${isDragActive ? styles.assetPreviewDragActive : ""}`}
        role="button"
        tabIndex={0}
        onClick={(event) => {
          const target = event.target as HTMLElement;
          if (target.closest("video")) {
            return;
          }

          openFilePicker();
        }}
        onKeyDown={(event) => {
          if (event.key === "Enter" || event.key === " ") {
            event.preventDefault();
            openFilePicker();
          }
        }}
        onDragEnter={(event) => {
          event.preventDefault();
          setIsDragActive(true);
        }}
        onDragOver={(event) => {
          event.preventDefault();
          event.dataTransfer.dropEffect = "copy";
          setIsDragActive(true);
        }}
        onDragLeave={(event) => {
          event.preventDefault();
          if (!event.currentTarget.contains(event.relatedTarget as Node | null)) {
            setIsDragActive(false);
          }
        }}
        onDrop={handlePreviewDrop}
      >
        <div className={styles.assetPreviewOverlay}>
          <span className={styles.assetPreviewBadge}>
            {previewKind === "video" ? text.previewAssetVideoBadge : text.previewAssetCoverBadge}
          </span>
          <span
            className={`${styles.assetPreviewState} ${hasPreview ? styles.assetPreviewStateReady : styles.assetPreviewStateMissing}`}
          >
            {previewStateLabel}
          </span>
        </div>
        {hasPreview ? (
          previewKind === "video" ? (
            <TemplateSecureMedia
              url={effectivePreviewUrl}
              kind="video"
              className={styles.assetPreviewMedia}
              controls
              playsInline
              logContext={{
                contentType: previewFile?.type || form.previewContentType,
                surface: "template_editor_preview",
              }}
            />
          ) : (
            <TemplateSecureMedia
              url={effectivePreviewUrl}
              kind="image"
              alt={previewFileLabel || text.previewAssetTitle}
              width={480}
              height={600}
              className={styles.assetPreviewMedia}
              logContext={{
                contentType: previewFile?.type || form.previewContentType,
                surface: "template_editor_preview",
              }}
            />
          )
        ) : (
          <div className={styles.assetPreviewPlaceholder}>
            <span className={styles.assetPreviewPlaceholderTitle}>{text.uploadPreview}</span>
            <span className={styles.assetPreviewPlaceholderHint}>{text.mediaDropzoneHint}</span>
          </div>
        )}
      </div>

      <div className={styles.formGrid}>
        <label className={styles.fieldBlock}>
          <span className={styles.fieldHeader}>
            <span>{text.previewUrlLabel}</span>
          </span>
          <input
            value={hasPreview ? `${previewStateLabel}: ${previewFileLabel}` : ""}
            placeholder={text.noFileSelected}
            readOnly
          />
        </label>
        <div className={styles.uploadPanel}>
          <div className={styles.uploadPanelHeader}>
            <div>
              <p className={styles.uploadPanelEyebrow}>{text.selectedFileLabel}</p>
              <p className={styles.uploadPanelTitle}>{previewFileLabel}</p>
            </div>
            <span
              className={`${styles.inlineState} ${hasPreview ? styles.inlineStateReady : styles.inlineStateAttention}`}
            >
              {previewStateLabel}
            </span>
          </div>
          <div className={styles.uploadActions}>
            <Button
              type="button"
              variant="primary"
              className={styles.primaryButton}
              disabled={!previewFile || uploadingKind !== null}
              onClick={onUploadPreview}
            >
              {uploadingKind === "Preview" ? text.uploadingMedia : text.uploadAction}
            </Button>
            <Button
              type="button"
              variant="danger"
              className={styles.dangerButton}
              disabled={!previewFile && !hasPreview}
              onClick={() => {
                setSelectionError(null);
                setPreviewFile(null);
                if (fileInputRef.current) {
                  fileInputRef.current.value = "";
                }
                setForm((current) => ({
                  ...current,
                  previewUrl: "",
                  previewUrlSource: "none",
                  previewFileName: "",
                  previewContentType: "",
                  previewFileSizeBytes: "",
                  previewDurationSeconds: "",
                }));
              }}
            >
              {text.clearAsset}
            </Button>
          </div>
          {selectionError ? <p className={styles.assetSelectionError}>{selectionError}</p> : null}
        </div>
        <p className={styles.muted}>{text.mediaUploadHint}</p>
      </div>
    </div>
  );
}

function getPreviewSelectionError(text: Dictionary, reason: "size" | "type"): string {
  if (reason === "size") {
    return text.previewAssetFileTooLarge;
  }

  return text.previewAssetFileTypeError;
}
