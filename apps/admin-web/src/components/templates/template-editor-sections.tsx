import { type DragEvent, useEffect, useRef, useState } from "react";

import assetStyles from "@/components/templates/template-editor-assets.module.css";
import styles from "@/components/templates/template-editor.module.css";
import { normalizeTemplateTextInput } from "@/components/templates/template-form-mappers";
import { TemplateSecureMedia } from "@/components/templates/template-secure-media";
import type { SetTemplateFormState, TemplateFormState } from "@/components/templates/types";
import { Button } from "@/components/ui/button";
import { Select, type SelectOption } from "@/components/ui/select";
import type { Dictionary } from "@/lib/i18n";
import { formatPrice, getImageModelPrice, getMotionModelPrice } from "@/lib/model-pricing";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

const referenceMotionAccept = ".mp4,video/mp4,application/mp4";
const TEMPLATE_REFERENCE_MOTION_MAX_BYTES = 100 * 1024 * 1024;
const promptMaxLength = 1000;

type TemplateReferenceAssetSectionProps = {
  text: Dictionary;
  form: TemplateFormState;
  setForm: SetTemplateFormState;
  referenceFile: File | null;
  isBusy: boolean;
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
  isBusy,
  setReferenceFile,
  uploadingKind,
  onUploadReference,
}: TemplateReferenceAssetSectionProps) {
  const fileInputRef = useRef<HTMLInputElement | null>(null);
  const [isDragActive, setIsDragActive] = useState(false);
  const [selectionError, setSelectionError] = useState<string | null>(null);
  const [localReference, setLocalReference] = useState<{ file: File; url: string } | null>(null);
  const localReferenceUrl = localReference?.file === referenceFile ? localReference.url : null;
  const persistedReferenceUrl = form.referenceUrl.trim();
  const effectiveReferenceUrl = localReferenceUrl ?? persistedReferenceUrl;
  const hasReference = Boolean(effectiveReferenceUrl);
  const referenceFileLabel = sanitizeSensitiveText(
    referenceFile?.name || form.referenceFileName || text.noFileSelected,
    120
  );
  const referenceStateLabel =
    uploadingKind === "ReferenceMotion"
      ? text.uploadingMedia
      : referenceFile
        ? text.editorFilePending
        : hasReference
          ? text.editorFileUploaded
          : text.editorMissing;

  useEffect(() => {
    return () => {
      if (localReferenceUrl) {
        URL.revokeObjectURL(localReferenceUrl);
      }
    };
  }, [localReferenceUrl]);

  function clearLocalReferenceUrl() {
    if (localReference?.url) {
      URL.revokeObjectURL(localReference.url);
    }

    setLocalReference(null);
  }

  function openFilePicker() {
    if (isBusy) return;
    fileInputRef.current?.click();
  }

  function handleReferenceFileSelection(file: File | null) {
    if (isBusy) return;
    if (!file || !isSupportedReferenceMotionFile(file)) {
      if (file) {
        setSelectionError(getReferenceSelectionError(text, "type"));
      }
      return;
    }

    if (file.size > TEMPLATE_REFERENCE_MOTION_MAX_BYTES) {
      setSelectionError(getReferenceSelectionError(text, "size"));
      return;
    }

    setSelectionError(null);
    clearLocalReferenceUrl();
    const objectUrl = URL.createObjectURL(file);
    try {
      setLocalReference({ file, url: objectUrl });
      setReferenceFile(file);
    } catch (error) {
      URL.revokeObjectURL(objectUrl);
      throw error;
    }
  }

  function handleReferenceDrop(event: DragEvent<HTMLDivElement>) {
    event.preventDefault();
    setIsDragActive(false);
    handleReferenceFileSelection(event.dataTransfer.files?.[0] ?? null);
  }

  return (
    <div id="template-reference" className={styles.formSection}>
      <h3>{text.referenceMotionTitle}</h3>
      <input
        ref={fileInputRef}
        className={assetStyles.filePickerInput}
        type="file"
        aria-label={text.uploadReference}
        disabled={isBusy}
        accept={referenceMotionAccept}
        onChange={(event) => {
          handleReferenceFileSelection(event.target.files?.[0] ?? null);
          event.target.value = "";
        }}
      />
      <div
        className={`${assetStyles.assetPreview} ${assetStyles.assetPreviewInteractive} ${isDragActive ? assetStyles.assetPreviewDragActive : ""}`}
        role="button"
        aria-disabled={isBusy}
        aria-label={text.uploadReference}
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
        onDrop={handleReferenceDrop}
      >
        <div className={assetStyles.assetPreviewOverlay}>
          <span className={assetStyles.assetPreviewBadge}>{text.referenceMotionSourceBadge}</span>
          <span
            className={`${assetStyles.assetPreviewState} ${hasReference && !referenceFile ? assetStyles.assetPreviewStateReady : assetStyles.assetPreviewStateMissing}`}
          >
            {referenceStateLabel}
          </span>
        </div>
        {hasReference ? (
          <TemplateSecureMedia
            url={effectiveReferenceUrl}
            kind="video"
            className={assetStyles.assetPreviewMedia}
            controls
            playsInline
            logContext={{
              contentType: referenceFile?.type || form.referenceContentType,
              surface: "template_editor_reference_motion",
            }}
          />
        ) : (
          <div className={assetStyles.assetPreviewPlaceholder}>
            <span className={assetStyles.assetPreviewPlaceholderTitle}>{text.uploadReference}</span>
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
              <p className={assetStyles.uploadPanelTitle}>{referenceFileLabel}</p>
            </div>
            <span
              className={`${styles.inlineState} ${hasReference && !referenceFile ? styles.inlineStateReady : styles.inlineStateAttention}`}
            >
              {referenceStateLabel}
            </span>
          </div>
          <div className={assetStyles.uploadActions}>
            <Button type="button" variant="secondary" disabled={isBusy} onClick={openFilePicker}>
              {hasReference ? text.editorReplaceFile : text.editorChooseFile}
            </Button>
            <Button
              type="button"
              variant="secondary"
              className={`${styles.primaryButton} ${assetStyles.uploadPrimaryButton}`}
              disabled={!referenceFile || isBusy}
              onClick={onUploadReference}
            >
              {uploadingKind === "ReferenceMotion" ? text.uploadingMedia : text.uploadAction}
            </Button>
            <Button
              type="button"
              variant="danger"
              className={`${styles.dangerButton} ${assetStyles.uploadDangerButton}`}
              disabled={isBusy || (!referenceFile && !hasReference)}
              onClick={() => {
                setSelectionError(null);
                setReferenceFile(null);
                if (fileInputRef.current) {
                  fileInputRef.current.value = "";
                }
                setForm((current) => ({
                  ...current,
                  referenceUrl: "",
                  referenceUrlSource: "none",
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
          {referenceFile ? <p className={styles.muted}>{text.editorUploadOnSaveHint}</p> : null}
          {selectionError ? (
            <p role="alert" className={assetStyles.assetSelectionError}>
              {selectionError}
            </p>
          ) : null}
        </div>
        <p className={styles.muted}>{text.editorReferenceFormats}</p>
      </div>
    </div>
  );
}

function getReferenceSelectionError(text: Dictionary, reason: "size" | "type"): string {
  if (reason === "size") {
    return text.referenceMotionFileTooLarge;
  }

  return text.referenceMotionFileTypeError;
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
  const preprocessingOptions = withCurrentModel(form.preprocessingModel, preprocessingModels).map(
    (model) => buildModelOption(text, model, "preprocess")
  );
  const klingOptions = withCurrentModel(form.klingModel, klingModels).map((model) =>
    buildModelOption(text, model, "motion")
  );

  return (
    <div className={styles.formSection}>
      <div className={styles.modelGrid}>
        <div className={styles.modelCard}>
          <div className={styles.modelCardHeader}>
            <p className={styles.modelCardEyebrow}>{text.preprocessingModelEyebrow}</p>
            <p className={styles.modelCardTitle}>{text.preprocessingModelLabel}</p>
          </div>
          <label id="template-preprocessing-model" className={styles.fieldBlock}>
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
          {!preprocessingModels.includes(form.preprocessingModel) ? (
            <p className={styles.muted}>{text.editorUnknownModel}</p>
          ) : null}
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
                setForm((current) => ({
                  ...current,
                  preprocessingPrompt: normalizeTemplateTextInput(
                    event.target.value,
                    promptMaxLength
                  ),
                }))
              }
              rows={7}
            />
          </label>
        </div>

        <div className={styles.modelCard}>
          <div className={styles.modelCardHeader}>
            <p className={styles.modelCardEyebrow}>{text.klingModelEyebrow}</p>
            <p className={styles.modelCardTitle}>{text.klingModelLabel}</p>
          </div>
          <label id="template-motion-model" className={styles.fieldBlock}>
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
          {!klingModels.includes(form.klingModel) ? (
            <p className={styles.muted}>{text.editorUnknownModel}</p>
          ) : null}
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
                setForm((current) => ({
                  ...current,
                  klingPrompt: normalizeTemplateTextInput(event.target.value, promptMaxLength),
                }))
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
  const imageOptions = withCurrentModel(form.imageModel, imageModels).map((model) =>
    buildModelOption(text, model, "preprocess")
  );

  return (
    <div className={styles.formSection}>
      <div className={styles.modelGrid}>
        <div className={styles.modelCard}>
          <div className={styles.modelCardHeader}>
            <p className={styles.modelCardEyebrow}>{text.imageModelEyebrow}</p>
            <p className={styles.modelCardTitle}>{text.imageModelLabel}</p>
          </div>
          <label id="template-image-model" className={styles.fieldBlock}>
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
          {!imageModels.includes(form.imageModel) ? (
            <p className={styles.muted}>{text.editorUnknownModel}</p>
          ) : null}
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
                setForm((current) => ({
                  ...current,
                  imagePrompt: normalizeTemplateTextInput(event.target.value, promptMaxLength),
                }))
              }
              rows={7}
            />
          </label>
        </div>
      </div>
    </div>
  );
}

function buildModelOption(
  text: Dictionary,
  model: string,
  kind: "preprocess" | "motion"
): SelectOption {
  const lower = model.toLowerCase();

  if (kind === "motion") {
    const price = getMotionModelPrice(model);
    const priceStr = price !== null ? `${formatPrice(price)}/sec` : null;

    if (lower.includes("/pro/")) {
      return {
        value: model,
        label: model,
        description: text.motionModelPremiumDescription,
        badge: text.modelBadgePremium,
        tone: "premium",
        price: priceStr ?? undefined,
      };
    }

    return {
      value: model,
      label: model,
      description: text.motionModelFastDescription,
      badge: text.modelBadgeFast,
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
      description: text.imageModelRecommendedDescription,
      badge: text.modelBadgeRecommended,
      tone: "recommended",
      price: priceStr ?? undefined,
    };
  }

  if (lower.includes("pro") || lower.includes("flux-2-pro")) {
    return {
      value: model,
      label: model,
      description: text.imageModelPremiumDescription,
      badge: text.modelBadgePremium,
      tone: "premium",
      price: priceStr ?? undefined,
    };
  }

  return {
    value: model,
    label: model,
    description: text.imageModelFastDescription,
    badge: text.modelBadgeFast,
    tone: "fast",
    price: priceStr ?? undefined,
  };
}

function withCurrentModel(current: string, models: readonly string[]): readonly string[] {
  return current && !models.includes(current) ? [current, ...models] : models;
}
