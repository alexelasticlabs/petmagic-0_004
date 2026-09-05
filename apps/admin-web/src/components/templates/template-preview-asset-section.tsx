import { type DragEvent, useEffect, useRef, useState } from "react";

import assetStyles from "@/components/templates/template-editor-assets.module.css";
import styles from "@/components/templates/template-editor.module.css";
import { inferTemplateMediaKind } from "@/components/templates/template-media-utils";
import { TemplateSecureMedia } from "@/components/templates/template-secure-media";
import type { SetTemplateFormState, TemplateFormState } from "@/components/templates/types";
import { Button } from "@/components/ui/button";
import type { Dictionary } from "@/lib/i18n";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

const templatePreviewAccept = [
  ".jpg",
  ".jpeg",
  ".png",
  ".webp",
  ".gif",
  ".mp4",
  ".mov",
  ".webm",
  "image/jpeg",
  "image/jpg",
  "image/png",
  "image/webp",
  "image/gif",
  "video/mp4",
  "application/mp4",
  "video/quicktime",
  "video/webm",
].join(",");
const supportedPreviewContentTypes = new Set([
  "image/jpeg",
  "image/jpg",
  "image/png",
  "image/webp",
  "image/gif",
  "video/mp4",
  "application/mp4",
  "video/quicktime",
  "video/webm",
]);
const supportedPreviewFileNamePattern = /\.(?:jpe?g|png|webp|gif|mp4|mov|webm)$/i;
const TEMPLATE_PREVIEW_ASSET_MAX_BYTES = 25 * 1024 * 1024;

type TemplatePreviewAssetSectionProps = {
  text: Dictionary;
  form: TemplateFormState;
  setForm: SetTemplateFormState;
  previewFile: File | null;
  isBusy: boolean;
  setPreviewFile: (file: File | null) => void;
  uploadingKind: "Preview" | "ReferenceMotion" | null;
  onUploadPreview: () => void;
};

export function TemplatePreviewAssetSection({
  text,
  form,
  setForm,
  previewFile,
  isBusy,
  setPreviewFile,
  uploadingKind,
  onUploadPreview,
}: TemplatePreviewAssetSectionProps) {
  const fileInputRef = useRef<HTMLInputElement | null>(null);
  const [isDragActive, setIsDragActive] = useState(false);
  const [selectionError, setSelectionError] = useState<string | null>(null);
  const [localPreview, setLocalPreview] = useState<{ file: File; url: string } | null>(null);
  const localPreviewUrl = localPreview?.file === previewFile ? localPreview.url : null;
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
  const previewStateLabel =
    uploadingKind === "Preview"
      ? text.uploadingMedia
      : previewFile
        ? text.editorFilePending
        : hasPreview
          ? text.editorFileUploaded
          : text.editorMissing;

  useEffect(() => {
    return () => {
      if (localPreviewUrl) {
        URL.revokeObjectURL(localPreviewUrl);
      }
    };
  }, [localPreviewUrl]);

  function clearLocalPreviewUrl() {
    if (localPreview?.url) {
      URL.revokeObjectURL(localPreview.url);
    }

    setLocalPreview(null);
  }

  function openFilePicker() {
    if (isBusy) return;
    fileInputRef.current?.click();
  }

  function handlePreviewFileSelection(file: File | null) {
    if (isBusy) return;
    if (!file) {
      return;
    }

    if (!isSupportedPreviewFile(file)) {
      setSelectionError(getPreviewSelectionError(text, "type"));
      return;
    }

    if (file.size > TEMPLATE_PREVIEW_ASSET_MAX_BYTES) {
      setSelectionError(getPreviewSelectionError(text, "size"));
      return;
    }

    setSelectionError(null);
    clearLocalPreviewUrl();
    const objectUrl = URL.createObjectURL(file);
    try {
      setLocalPreview({ file, url: objectUrl });
      setPreviewFile(file);
    } catch (error) {
      URL.revokeObjectURL(objectUrl);
      throw error;
    }
  }

  function handlePreviewDrop(event: DragEvent<HTMLDivElement>) {
    event.preventDefault();
    setIsDragActive(false);
    handlePreviewFileSelection(event.dataTransfer.files?.[0] ?? null);
  }

  return (
    <div id="template-preview" className={styles.formSection}>
      <h3>{text.previewAssetTitle}</h3>
      <input
        ref={fileInputRef}
        className={assetStyles.filePickerInput}
        type="file"
        aria-label={text.uploadPreview}
        disabled={isBusy}
        accept={templatePreviewAccept}
        onChange={(event) => {
          handlePreviewFileSelection(event.target.files?.[0] ?? null);
          event.target.value = "";
        }}
      />
      <div
        className={`${assetStyles.assetPreview} ${assetStyles.assetPreviewInteractive} ${isDragActive ? assetStyles.assetPreviewDragActive : ""}`}
        role="button"
        aria-disabled={isBusy}
        aria-label={text.uploadPreview}
        tabIndex={isBusy ? -1 : 0}
        onClick={(event) => {
          const target = event.target as HTMLElement;
          if (target.closest("video")) {
            return;
          }

          openFilePicker();
        }}
        onKeyDown={(event) => {
          if (event.target !== event.currentTarget) return;
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
        <div className={assetStyles.assetPreviewOverlay}>
          <span className={assetStyles.assetPreviewBadge}>
            {previewKind === "video" ? text.previewAssetVideoBadge : text.previewAssetCoverBadge}
          </span>
          <span
            className={`${assetStyles.assetPreviewState} ${hasPreview && !previewFile ? assetStyles.assetPreviewStateReady : assetStyles.assetPreviewStateMissing}`}
          >
            {previewStateLabel}
          </span>
        </div>
        {hasPreview ? (
          previewKind === "video" ? (
            <TemplateSecureMedia
              url={effectivePreviewUrl}
              kind="video"
              className={assetStyles.assetPreviewMedia}
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
              className={assetStyles.assetPreviewMedia}
              logContext={{
                contentType: previewFile?.type || form.previewContentType,
                surface: "template_editor_preview",
              }}
            />
          )
        ) : (
          <div className={assetStyles.assetPreviewPlaceholder}>
            <span className={assetStyles.assetPreviewPlaceholderTitle}>{text.uploadPreview}</span>
            <span className={assetStyles.assetPreviewPlaceholderHint}>
              {text.mediaDropzoneHint}
            </span>
          </div>
        )}
      </div>

      <div className={styles.formGrid}>
        <div className={assetStyles.uploadPanel}>
          <div className={assetStyles.uploadPanelHeader}>
            <div>
              <p className={assetStyles.uploadPanelEyebrow}>{text.selectedFileLabel}</p>
              <p className={assetStyles.uploadPanelTitle}>{previewFileLabel}</p>
            </div>
            <span
              className={`${styles.inlineState} ${hasPreview && !previewFile ? styles.inlineStateReady : styles.inlineStateAttention}`}
            >
              {previewStateLabel}
            </span>
          </div>
          <div className={assetStyles.uploadActions}>
            <Button type="button" variant="secondary" disabled={isBusy} onClick={openFilePicker}>
              {hasPreview ? text.editorReplaceFile : text.editorChooseFile}
            </Button>
            <Button
              type="button"
              variant="secondary"
              className={`${styles.primaryButton} ${assetStyles.uploadPrimaryButton}`}
              disabled={!previewFile || isBusy}
              onClick={onUploadPreview}
            >
              {uploadingKind === "Preview" ? text.uploadingMedia : text.uploadAction}
            </Button>
            <Button
              type="button"
              variant="danger"
              className={`${styles.dangerButton} ${assetStyles.uploadDangerButton}`}
              disabled={isBusy || (!previewFile && !hasPreview)}
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
                  thumbnailAsset: null,
                  animatedPreviewAsset: null,
                  feedLoopLowAsset: null,
                  feedLoopMediumAsset: null,
                  detailPreviewAsset: null,
                }));
              }}
            >
              {text.clearAsset}
            </Button>
          </div>
          {previewFile ? <p className={styles.muted}>{text.editorUploadOnSaveHint}</p> : null}
          {selectionError ? (
            <p role="alert" className={assetStyles.assetSelectionError}>
              {selectionError}
            </p>
          ) : null}
        </div>
        <p className={styles.muted}>{text.editorPreviewFormats}</p>
      </div>
    </div>
  );
}

function isSupportedPreviewFile(file: File): boolean {
  const normalizedType = file.type.split(";", 1)[0].trim().toLowerCase();
  if (supportedPreviewContentTypes.has(normalizedType)) {
    return true;
  }

  if (normalizedType && normalizedType !== "application/octet-stream") {
    return false;
  }

  return supportedPreviewFileNamePattern.test(file.name);
}

function getPreviewSelectionError(text: Dictionary, reason: "size" | "type"): string {
  if (reason === "size") {
    return text.previewAssetFileTooLarge;
  }

  return text.previewAssetFileTypeError;
}
