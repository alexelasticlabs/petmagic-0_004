import { type DragEvent, useEffect, useMemo, useRef, useState } from "react";

import styles from "@/components/templates/template-editor.module.css";
import { TemplateSecureMedia } from "@/components/templates/template-secure-media";
import type { SetTemplateFormState, TemplateFormState } from "@/components/templates/types";
import { Button } from "@/components/ui/button";
import { Select, type SelectOption } from "@/components/ui/select";
import type { Dictionary } from "@/lib/i18n";
import { formatPrice, getImageModelPrice, getMotionModelPrice } from "@/lib/model-pricing";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

const referenceMotionAccept = ".mp4,video/mp4,application/mp4";
const promptMaxLength = 2000;

type TemplateReferenceAssetSectionProps = {
  text: Dictionary;
  form: TemplateFormState;
  setForm: SetTemplateFormState;
  referenceFile: File | null;
  setReferenceFile: (file: File | null) => void;
  uploadingKind: "Preview" | "ReferenceMotion" | null;
  onUploadReference: () => void;
};

type TemplateVideoModelSectionProps = {
  text: Dictionary;
  form: TemplateFormState;
  setForm: SetTemplateFormState;
  preprocessingModels: readonly string[];
  klingModels: readonly string[];
};

type TemplateImageModelSectionProps = {
  text: Dictionary;
  form: TemplateFormState;
  setForm: SetTemplateFormState;
  imageModels: readonly string[];
};

export function TemplateReferenceAssetSection({
  text,
  form,
  setForm,
  referenceFile,
  setReferenceFile,
  uploadingKind,
  onUploadReference,
}: TemplateReferenceAssetSectionProps) {
  const fileInputRef = useRef<HTMLInputElement | null>(null);
  const [isDragActive, setIsDragActive] = useState(false);
  const localReferenceUrl = useMemo(
    () => (referenceFile ? URL.createObjectURL(referenceFile) : null),
    [referenceFile]
  );
  const persistedReferenceUrl = form.referenceUrl.trim();
  const effectiveReferenceUrl = localReferenceUrl ?? persistedReferenceUrl;
  const hasReference = Boolean(effectiveReferenceUrl);
  const referenceFileLabel = sanitizeSensitiveText(
    referenceFile?.name || form.referenceFileName || text.noFileSelected,
    120
  );
  const referenceStateLabel = hasReference ? text.editorReady : text.editorMissing;

  useEffect(() => {
    return () => {
      if (localReferenceUrl) {
        URL.revokeObjectURL(localReferenceUrl);
      }
    };
  }, [localReferenceUrl]);

  function openFilePicker() {
    fileInputRef.current?.click();
  }

  function handleReferenceFileSelection(file: File | null) {
    if (!file || !isSupportedReferenceMotionFile(file)) {
      return;
    }

    setReferenceFile(file);
  }

  function handleReferenceDrop(event: DragEvent<HTMLDivElement>) {
    event.preventDefault();
    setIsDragActive(false);
    handleReferenceFileSelection(event.dataTransfer.files?.[0] ?? null);
  }

  return (
    <div className={styles.formSection}>
      <h3>{text.referenceMotionTitle}</h3>
      <input
        ref={fileInputRef}
        className={styles.filePickerInput}
        type="file"
        accept={referenceMotionAccept}
        onChange={(event) => handleReferenceFileSelection(event.target.files?.[0] ?? null)}
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
        onDrop={handleReferenceDrop}
      >
        <div className={styles.assetPreviewOverlay}>
          <span className={styles.assetPreviewBadge}>Motion source</span>
          <span
            className={`${styles.assetPreviewState} ${hasReference ? styles.assetPreviewStateReady : styles.assetPreviewStateMissing}`}
          >
            {referenceStateLabel}
          </span>
        </div>
        {hasReference ? (
          <TemplateSecureMedia
            url={effectiveReferenceUrl}
            kind="video"
            className={styles.assetPreviewMedia}
            controls
            playsInline
            logContext={{
              contentType: referenceFile?.type || form.referenceContentType,
              surface: "template_editor_reference_motion",
            }}
          />
        ) : (
          <div className={styles.assetPreviewPlaceholder}>
            <span className={styles.assetPreviewPlaceholderTitle}>{text.uploadReference}</span>
            <span className={styles.assetPreviewPlaceholderHint}>{text.mediaDropzoneHint}</span>
          </div>
        )}
      </div>

      <div className={styles.formGrid}>
        <label className={styles.fieldBlock}>
          <span className={styles.fieldHeader}>
            <span>{text.referenceUrlLabel}</span>
          </span>
          <input
            value={hasReference ? `${referenceStateLabel}: ${referenceFileLabel}` : ""}
            placeholder={text.noFileSelected}
            readOnly
          />
        </label>
        <div className={styles.uploadPanel}>
          <div className={styles.uploadPanelHeader}>
            <div>
              <p className={styles.uploadPanelEyebrow}>{text.selectedFileLabel}</p>
              <p className={styles.uploadPanelTitle}>{referenceFileLabel}</p>
            </div>
            <span
              className={`${styles.inlineState} ${hasReference ? styles.inlineStateReady : styles.inlineStateAttention}`}
            >
              {referenceStateLabel}
            </span>
          </div>
          <div className={styles.uploadActions}>
            <Button
              type="button"
              variant="primary"
              className={styles.primaryButton}
              disabled={!referenceFile || uploadingKind !== null}
              onClick={onUploadReference}
            >
              {uploadingKind === "ReferenceMotion" ? text.uploadingMedia : text.uploadAction}
            </Button>
            <Button
              type="button"
              variant="danger"
              className={styles.dangerButton}
              disabled={!referenceFile && !hasReference}
              onClick={() => {
                setReferenceFile(null);
                if (fileInputRef.current) {
                  fileInputRef.current.value = "";
                }
                setForm((current) => ({
                  ...current,
                  referenceUrl: "",
                  referenceFileName: "",
                  referenceContentType: "",
                  referenceFileSizeBytes: "",
                  referenceDurationSeconds: "",
                }));
              }}
            >
              {text.clearAsset}
            </Button>
          </div>
        </div>
        <p className={styles.muted}>{text.referenceMotionUploadHint}</p>
      </div>
    </div>
  );
}

function isSupportedReferenceMotionFile(file: File): boolean {
  const normalizedType = file.type.trim().toLowerCase();

  if (normalizedType === "video/mp4" || normalizedType === "application/mp4") {
    return true;
  }

  if (normalizedType && normalizedType !== "application/octet-stream") {
    return false;
  }

  return file.name.toLowerCase().endsWith(".mp4");
}

export function TemplateVideoModelSection({
  text,
  form,
  setForm,
  preprocessingModels,
  klingModels,
}: TemplateVideoModelSectionProps) {
  const preprocessingOptions = preprocessingModels.map((model) =>
    buildModelOption(model, "preprocess")
  );
  const klingOptions = klingModels.map((model) => buildModelOption(model, "motion"));

  return (
    <div className={styles.formSection}>
      <div className={styles.modelGrid}>
        <div className={styles.modelCard}>
          <div className={styles.modelCardHeader}>
            <p className={styles.modelCardEyebrow}>Input shaping</p>
            <p className={styles.modelCardTitle}>{text.preprocessingModelLabel}</p>
          </div>
          <label className={styles.fieldBlock}>
            <span className={styles.fieldHeader}>
              <span>{text.preprocessingModelLabel}</span>
              <span className={styles.fieldMeta}>fal.ai</span>
            </span>
            <Select
              value={form.preprocessingModel}
              options={preprocessingOptions}
              ariaLabel={text.preprocessingModelLabel}
              onChange={(value) =>
                setForm((current) => ({ ...current, preprocessingModel: value }))
              }
            />
          </label>
          <label className={styles.fieldBlock}>
            <span className={styles.fieldHeader}>
              <span>{text.preprocessingPromptLabel}</span>
              <span className={styles.fieldCounter}>
                {form.preprocessingPrompt.length}/{promptMaxLength}
              </span>
            </span>
            <textarea
              value={form.preprocessingPrompt}
              maxLength={promptMaxLength}
              onChange={(event) =>
                setForm((current) => ({ ...current, preprocessingPrompt: event.target.value }))
              }
              rows={7}
            />
          </label>
        </div>

        <div className={styles.modelCard}>
          <div className={styles.modelCardHeader}>
            <p className={styles.modelCardEyebrow}>Motion pass</p>
            <p className={styles.modelCardTitle}>{text.klingModelLabel}</p>
          </div>
          <label className={styles.fieldBlock}>
            <span className={styles.fieldHeader}>
              <span>{text.klingModelLabel}</span>
              <span className={styles.fieldMeta}>fal.ai</span>
            </span>
            <Select
              value={form.klingModel}
              options={klingOptions}
              ariaLabel={text.klingModelLabel}
              onChange={(value) => setForm((current) => ({ ...current, klingModel: value }))}
            />
          </label>
          <label className={styles.fieldBlock}>
            <span className={styles.fieldHeader}>
              <span>{text.klingPromptLabel}</span>
              <span className={styles.fieldCounter}>
                {form.klingPrompt.length}/{promptMaxLength}
              </span>
            </span>
            <textarea
              value={form.klingPrompt}
              maxLength={promptMaxLength}
              onChange={(event) =>
                setForm((current) => ({ ...current, klingPrompt: event.target.value }))
              }
              rows={7}
            />
          </label>
        </div>
      </div>

      <label className={styles.switchCard}>
        <input
          type="checkbox"
          checked={form.keepOriginalSound}
          onChange={(event) =>
            setForm((current) => ({ ...current, keepOriginalSound: event.target.checked }))
          }
        />
        <span className={styles.switchCopy}>{text.keepOriginalSoundLabel}</span>
      </label>
    </div>
  );
}

export function TemplateImageModelSection({
  text,
  form,
  setForm,
  imageModels,
}: TemplateImageModelSectionProps) {
  const imageOptions = imageModels.map((model) => buildModelOption(model, "preprocess"));

  return (
    <div className={styles.formSection}>
      <div className={styles.modelGrid}>
        <div className={styles.modelCard}>
          <div className={styles.modelCardHeader}>
            <p className={styles.modelCardEyebrow}>Image pass</p>
            <p className={styles.modelCardTitle}>{text.imageModelLabel}</p>
          </div>
          <label className={styles.fieldBlock}>
            <span className={styles.fieldHeader}>
              <span>{text.imageModelLabel}</span>
              <span className={styles.fieldMeta}>fal.ai</span>
            </span>
            <Select
              value={form.imageModel}
              options={imageOptions}
              ariaLabel={text.imageModelLabel}
              onChange={(value) => setForm((current) => ({ ...current, imageModel: value }))}
            />
          </label>
          <label className={styles.fieldBlock}>
            <span className={styles.fieldHeader}>
              <span>{text.imagePromptLabel}</span>
              <span className={styles.fieldCounter}>
                {form.imagePrompt.length}/{promptMaxLength}
              </span>
            </span>
            <textarea
              value={form.imagePrompt}
              maxLength={promptMaxLength}
              onChange={(event) =>
                setForm((current) => ({ ...current, imagePrompt: event.target.value }))
              }
              rows={7}
            />
          </label>
        </div>
      </div>
    </div>
  );
}

function buildModelOption(model: string, kind: "preprocess" | "motion"): SelectOption {
  const lower = model.toLowerCase();

  if (kind === "motion") {
    const price = getMotionModelPrice(model);
    const priceStr = price !== null ? `${formatPrice(price)}/sec` : null;

    if (lower.includes("/pro/")) {
      return {
        value: model,
        label: model,
        description: "Motion control for highest-fidelity generation.",
        badge: "Premium",
        tone: "premium",
        price: priceStr ?? undefined,
      };
    }

    return {
      value: model,
      label: model,
      description: "Motion control tuned for quicker iteration.",
      badge: "Fast",
      tone: "fast",
      price: priceStr ?? undefined,
    };
  }

  const price = getImageModelPrice(model);
  const priceStr = price !== null ? formatPrice(price) : null;

  if (lower.includes("gpt-image-2") || lower.includes("nano-banana-2")) {
    return {
      value: model,
      label: model,
      description: "Image edit pass for balanced fidelity and consistency.",
      badge: "Recommended",
      tone: "recommended",
      price: priceStr ?? undefined,
    };
  }

  if (lower.includes("pro") || lower.includes("flux-2-pro")) {
    return {
      value: model,
      label: model,
      description: "Image edit pass focused on premium detail retention.",
      badge: "Premium",
      tone: "premium",
      price: priceStr ?? undefined,
    };
  }

  return {
    value: model,
    label: model,
    description: "Image edit pass optimized for faster turnaround.",
    badge: "Fast",
    tone: "fast",
    price: priceStr ?? undefined,
  };
}
