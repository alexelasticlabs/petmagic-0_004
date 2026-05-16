"use client";

import { AdminMetricStrip, AdminPageHero, AdminSectionHeader } from "@/components/admin/admin-primitives";
import { TemplateBasicFields } from "@/components/templates/template-basic-fields";
import { inferTemplateMediaKind } from "@/components/templates/template-media-utils";
import { TemplatePreviewAssetSection } from "@/components/templates/template-preview-asset-section";
import { TemplateReferenceAssetSection, TemplateVideoModelSection } from "@/components/templates/template-video-sections";
import styles from "@/components/templates/templates-admin.module.css";
import { TemplatesListCard } from "@/components/templates/templates-list-card";
import { type TemplateFormState } from "@/components/templates/types";
import { Button } from "@/components/ui/button";
import { Toast } from "@/components/ui/toast";
import {
    changeTemplateStatus,
    createImageTemplate,
    createVideoTemplate,
    deleteTemplate,
    fetchAdminTemplate,
    fetchAdminTemplates,
    getSession,
    updateImageTemplate,
    updateVideoTemplate,
    uploadTemplateMedia,
    type AdminTemplate,
    type AdminTemplateListItem,
    type ImageTemplatePayload,
    type TemplateAssetInput,
    type TemplateAssetKind,
    type TemplatePromoBadgeMode,
    type TemplateStatus,
    type TemplateType,
    type VideoTemplatePayload
} from "@/lib/api-client";
import { getDictionary, type Dictionary, type Locale } from "@/lib/i18n";
import Image from "next/image";
import { useRouter } from "next/navigation";
import { useEffect, useEffectEvent, useState } from "react";

type TemplatesManagerProps = {
  locale: Locale;
  templateType: TemplateType;
  initialTemplateId?: string;
};

type ToastState = {
  type: "success" | "error";
  message: string;
};

type ChecklistItem = {
  label: string;
  detail: string;
  ready: boolean;
};

type VideoEditorModel = {
  title: string;
  shortDescription: string;
  musicDescription: string;
  category: string;
  promoBadge?: Exclude<TemplatePromoBadgeMode, "Auto">;
  tokenCost: string;
  previewReady: boolean;
  referenceReady: boolean;
  referenceDuration?: number;
  characterOrientation: string;
  basicInfoReady: boolean;
  mediaReady: boolean;
  aiReady: boolean;
  reviewReady: boolean;
  checklist: ChecklistItem[];
};

const DEFAULT_PREPROCESSING_PROMPT = "Keep the same pet, same face, same fur, same colors, same background, same lighting and camera angle. Adjust the pet into an upright pose standing on its two hind legs like a human, with the front paws naturally positioned like arms. Make the full body clearly visible and suitable for motion transfer. Do not change the pet’s identity, breed, facial features, background, or image style.";
const DEFAULT_KLING_PROMPT = "A cute pet performing a funny viral dance, smooth animation, high quality.";

const PREPROCESSING_MODELS = [
  "openai/gpt-image-2/edit",
  "fal-ai/nano-banana-pro/edit",
  "fal-ai/flux-2-pro/edit",
  "fal-ai/gpt-image-1.5/edit",
  "fal-ai/bytedance/seedream/v5/lite/edit",
  "fal-ai/nano-banana-2/edit"
] as const;

const KLING_MODELS = [
  "fal-ai/kling-video/v3/pro/motion-control",
  "fal-ai/kling-video/v3/standard/motion-control"
] as const;

export function TemplatesManager({ locale, templateType, initialTemplateId }: TemplatesManagerProps) {
  const text = getDictionary(locale);
  const router = useRouter();
  const [templates, setTemplates] = useState<AdminTemplateListItem[]>([]);
  const [selectedTemplate, setSelectedTemplate] = useState<AdminTemplate | null>(null);
  const [form, setForm] = useState<TemplateFormState>(() => createInitialForm(templateType));
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  const [busyTemplateId, setBusyTemplateId] = useState<string | null>(null);
  const [previewFile, setPreviewFile] = useState<File | null>(null);
  const [referenceFile, setReferenceFile] = useState<File | null>(null);
  const [uploadingKind, setUploadingKind] = useState<TemplateAssetKind | null>(null);
  const [toast, setToast] = useState<ToastState | null>(null);
  const isVideo = templateType === "Video";

  useEffect(() => {
    if (!toast) {
      return;
    }

    const timer = window.setTimeout(() => setToast(null), 2600);
    return () => window.clearTimeout(timer);
  }, [toast]);

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
      setToast({ type: "error", message: text.errorLoadingTemplates });
    } finally {
      if (showLoading) {
        setIsLoading(false);
      }
    }
  }

  async function openTemplate(templateId: string) {
    setBusyTemplateId(templateId);
    setError(null);

    try {
      const response = await fetchAdminTemplate(templateId);
      setSelectedTemplate(response);
      setForm(createFormFromTemplate(response));
    } catch {
      setError(text.errorLoadingTemplates);
      setToast({ type: "error", message: text.errorLoadingTemplates });
    } finally {
      setBusyTemplateId(null);
    }
  }

  const loadTemplatesOnMount = useEffectEvent(async () => {
    setIsLoading(true);
    await loadTemplates(false);

    if (initialTemplateId) {
      await openTemplate(initialTemplateId);
    }

    setIsLoading(false);
  });

  useEffect(() => {
    queueMicrotask(() => {
      void loadTemplatesOnMount();
    });
  }, []);

  function resetForm() {
    setSelectedTemplate(null);
    setForm(createInitialForm(templateType));
    setPreviewFile(null);
    setReferenceFile(null);
    setError(null);
  }

  async function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setIsSaving(true);
    setError(null);

    try {
      const response = templateType === "Video"
        ? await saveVideoTemplate(selectedTemplate?.templateId, form)
        : await saveImageTemplate(selectedTemplate?.templateId, form);

      setSelectedTemplate(response);
      setForm(createFormFromTemplate(response));
      await loadTemplates(false);
      setToast({
        type: "success",
        message: locale === "ru" ? "Шаблон сохранен" : "Template saved"
      });
    } catch {
      setError(text.errorSavingTemplate);
      setToast({ type: "error", message: text.errorSavingTemplate });
    } finally {
      setIsSaving(false);
    }
  }

  async function handleStatusChange(templateId: string, status: TemplateStatus) {
    setBusyTemplateId(templateId);
    setError(null);

    try {
      const response = await changeTemplateStatus(templateId, status);
      setSelectedTemplate(response);
      setForm(createFormFromTemplate(response));
      await loadTemplates(false);
      setToast({
        type: "success",
        message: locale === "ru" ? "Статус обновлен" : "Status updated"
      });
    } catch {
      setError(text.errorSavingTemplate);
      setToast({ type: "error", message: text.errorSavingTemplate });
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

      if (selectedTemplate?.templateId === templateId) {
        resetForm();
      }

      await loadTemplates(false);
      setToast({
        type: "success",
        message: locale === "ru" ? "Шаблон удален" : "Template deleted"
      });
    } catch {
      setError(text.errorDeletingTemplate);
      setToast({ type: "error", message: text.errorDeletingTemplate });
    } finally {
      setBusyTemplateId(null);
    }
  }

  async function handleUpload(assetKind: TemplateAssetKind) {
    const file = assetKind === "Preview" ? previewFile : referenceFile;
    if (!file) {
      return;
    }

    setUploadingKind(assetKind);
    setError(null);

    try {
      const asset = await uploadTemplateMedia(file, assetKind);
      setForm((current) => assetKind === "Preview"
        ? {
            ...current,
            previewUrl: asset.url,
            previewFileName: asset.fileName,
            previewContentType: asset.contentType,
            previewFileSizeBytes: asset.fileSizeBytes?.toString() ?? ""
          }
        : {
            ...current,
            referenceUrl: asset.url,
            referenceFileName: asset.fileName,
            referenceContentType: asset.contentType,
            referenceFileSizeBytes: asset.fileSizeBytes?.toString() ?? "",
            referenceDurationSeconds: asset.durationSeconds?.toString() ?? ""
          });

      if (assetKind === "Preview") {
        setPreviewFile(null);
      } else {
        setReferenceFile(null);
      }
      setToast({
        type: "success",
        message: locale === "ru" ? "Файл загружен" : "File uploaded"
      });
    } catch {
      setError(text.errorSavingTemplate);
      setToast({ type: "error", message: text.errorSavingTemplate });
    } finally {
      setUploadingKind(null);
    }
  }

  if (isLoading) {
    if (isVideo) {
      return (
        <section className={styles.videoEditorPage}>
          <div className={styles.loadingShell}>
            <div className={styles.loadingHero} aria-busy="true" aria-live="polite">
              <div className={styles.skeletonStack}>
                {Array.from({ length: 4 }).map((_, index) => (
                  <div key={index} className={styles.skeletonLine} />
                ))}
              </div>
            </div>
            <div className={styles.loadingGrid}>
              {[0, 1].map((column) => (
                <div key={column} className={styles.loadingCard} aria-busy="true" aria-live="polite">
                  <div className={styles.skeletonStack}>
                    {Array.from({ length: column === 0 ? 10 : 6 }).map((_, index) => (
                      <div key={index} className={styles.skeletonLine} />
                    ))}
                  </div>
                </div>
              ))}
            </div>
          </div>
        </section>
      );
    }

    return (
      <section className={styles.layout}>
        {[4, 8].map((rows) => (
          <div key={rows} className={styles.formCard} aria-busy="true" aria-live="polite">
            <div className={styles.skeletonStack}>
              {Array.from({ length: rows }).map((_, index) => (
                <div key={index} className={styles.skeletonLine} />
              ))}
            </div>
          </div>
        ))}
      </section>
    );
  }

  const sectionTitle = templateType === "Video" ? text.videoTemplatesTitle : text.imageTemplatesTitle;
  const categorySuggestions = getUniqueValues(templates.map((template) => template.category));

  if (isVideo) {
    const isEditMode = selectedTemplate !== null;
    const catalogPath = getTemplateCatalogPath(locale, templateType);
    const editorModel = buildVideoEditorModel(text, form, selectedTemplate);
    const pageTitle = isEditMode ? text.videoTemplateEditPageTitle : text.videoTemplateCreatePageTitle;
    const badgeLabel = isEditMode ? selectedTemplate?.status ?? text.editorDraft : text.editorDraft;

    return (
      <section className={styles.videoEditorPage}>
        <div className={styles.pageTop}>
          <div className={styles.breadcrumbs}>
            <button type="button" className={styles.breadcrumbLink} onClick={() => router.push(catalogPath)}>
              {text.navVideoTemplates}
            </button>
            <span className={styles.breadcrumbDivider} aria-hidden="true">
              &gt;
            </span>
            <span className={styles.breadcrumbCurrent}>{isEditMode ? text.updateTemplate : text.createNewTemplate}</span>
          </div>

          <div className={styles.headerActions}>
            <Button type="button" variant="ghost" className={styles.adminButton} disabled={isSaving} onClick={resetForm}>
              {text.resetForm}
            </Button>
          </div>
        </div>

        <AdminPageHero
          title={pageTitle}
        />

        {error ? <div className={styles.error}>{error}</div> : null}

        <form className={styles.editorForm} onSubmit={handleSubmit}>
          <div className={styles.editorGrid}>
            <div className={styles.editorMain}>
              <section id="template-basics" className={styles.sectionCard}>
                <AdminSectionHeader
                  title={text.editorStepBasics}
                  aside={(
                    <span className={joinClassNames(styles.inlineState, editorModel.basicInfoReady ? styles.inlineStateReady : styles.inlineStateAttention)}>
                      {editorModel.basicInfoReady ? text.editorReady : text.editorMissing}
                    </span>
                  )}
                />

                <TemplateBasicFields
                  text={text}
                  form={form}
                  setForm={setForm}
                  categorySuggestions={categorySuggestions}
                  showMusicDescription
                />
              </section>

              <section id="template-media" className={styles.sectionCard}>
                <AdminSectionHeader
                  title={text.editorStepMedia}
                  aside={(
                    <span className={joinClassNames(styles.inlineState, editorModel.mediaReady ? styles.inlineStateReady : styles.inlineStateAttention)}>
                      {editorModel.mediaReady ? text.editorReady : text.editorMissing}
                    </span>
                  )}
                />

                <div className={styles.mediaGrid}>
                  <TemplatePreviewAssetSection
                    text={text}
                    form={form}
                    setForm={setForm}
                    previewFile={previewFile}
                    setPreviewFile={setPreviewFile}
                    uploadingKind={uploadingKind}
                    onUploadPreview={() => void handleUpload("Preview")}
                  />

                  <TemplateReferenceAssetSection
                    text={text}
                    form={form}
                    setForm={setForm}
                    referenceFile={referenceFile}
                    setReferenceFile={setReferenceFile}
                    uploadingKind={uploadingKind}
                    onUploadReference={() => void handleUpload("ReferenceMotion")}
                  />
                </div>

                <AdminMetricStrip
                  className={styles.derivedGrid}
                  items={[
                    { label: text.referenceDurationLabel, value: formatDuration(editorModel.referenceDuration) },
                    { label: text.characterOrientationLabel, value: editorModel.characterOrientation || text.editorMissing },
                  ]}
                />
              </section>

              <section id="template-ai" className={styles.sectionCard}>
                <AdminSectionHeader
                  title={text.editorStepAi}
                  aside={(
                    <span className={joinClassNames(styles.inlineState, editorModel.aiReady ? styles.inlineStateReady : styles.inlineStateAttention)}>
                      {editorModel.aiReady ? text.editorReady : text.editorMissing}
                    </span>
                  )}
                />

                <TemplateVideoModelSection
                  text={text}
                  form={form}
                  setForm={setForm}
                  preprocessingModels={PREPROCESSING_MODELS}
                  klingModels={KLING_MODELS}
                />
              </section>

            </div>

            <aside className={styles.editorRail}>
              <section className={joinClassNames(styles.railCard, styles.previewRailCard)}>
                <div className={styles.previewCardWrap}>
                  <div className={styles.phoneMedia}>
                    {renderPhonePreview(form.previewUrl, form.previewContentType, editorModel.title || text.videoTemplateCreatePageTitle, styles.phoneMediaAsset, styles.phonePlaceholder)}
                    {editorModel.promoBadge ? (
                      <div className={styles.phoneTopRow}>
                        <span className={joinClassNames(styles.phoneHeroBadge, getPromoBadgeClassName(editorModel.promoBadge, styles))}>
                          {formatPromoBadge(editorModel.promoBadge)}
                        </span>
                      </div>
                    ) : null}
                    <div className={styles.phoneCardShade} />

                    <div className={styles.phoneBottomContent}>
                      <div className={styles.phoneMetricRow}>
                        <span className={styles.phoneMetricBadge}>
                          <span className={styles.phoneMetricIcon} aria-hidden="true">
                            <svg viewBox="0 0 16 16" focusable="false">
                              <path d="M3.35 7.55c.62 0 1.12-.59 1.12-1.32 0-.72-.5-1.31-1.12-1.31s-1.12.59-1.12 1.31c0 .73.5 1.32 1.12 1.32Zm9.3 0c.62 0 1.12-.59 1.12-1.32 0-.72-.5-1.31-1.12-1.31s-1.12.59-1.12 1.31c0 .73.5 1.32 1.12 1.32ZM5.8 5.45c.67 0 1.22-.67 1.22-1.5s-.55-1.5-1.22-1.5-1.22.67-1.22 1.5.55 1.5 1.22 1.5Zm4.4 0c.67 0 1.22-.67 1.22-1.5s-.55-1.5-1.22-1.5-1.22.67-1.22 1.5.55 1.5 1.22 1.5Zm-2.23 1.3c-1.88 0-3.67 1.22-3.67 2.94 0 1.09.83 1.86 2.02 1.86.56 0 1-.11 1.41-.21.35-.09.68-.17 1.02-.17s.67.08 1.02.17c.41.1.85.21 1.41.21 1.19 0 2.02-.77 2.02-1.86 0-1.72-1.79-2.94-3.67-2.94H7.97Z" fill="currentColor" />
                            </svg>
                          </span>
                          <span>{editorModel.tokenCost}</span>
                        </span>
                      </div>

                      <h3 className={styles.phoneTitle}>{editorModel.title || text.videoTemplateCreatePageTitle}</h3>
                      <p className={styles.phoneDescription}>{editorModel.shortDescription || text.editorPreviewRailHint}</p>
                      {editorModel.musicDescription ? (
                        <p className={styles.phoneMusicDescription}>
                          <span className={styles.phoneMusicLabel} aria-hidden="true">
                            <svg viewBox="0 0 16 16" focusable="false">
                              <path d="M10.7 2.15a.55.55 0 0 1 .7.53v7.05a2.2 2.2 0 1 1-1.1-1.92V5.08L6.2 6.1v5.03a2.2 2.2 0 1 1-1.1-1.92V5.67c0-.25.17-.47.41-.53l5.19-1.3Z" fill="currentColor" />
                            </svg>
                          </span>
                          <span className={styles.phoneMusicText}>{editorModel.musicDescription}</span>
                        </p>
                      ) : null}

                      <div className={styles.phoneMetaRow}>
                        <span>{formatDuration(editorModel.referenceDuration)}</span>
                        <span className={styles.phoneMetaDot} aria-hidden="true" />
                        <span>{editorModel.category || text.editorDraft}</span>
                        <span className={styles.phoneMetaSpacer} />
                        <span className={joinClassNames(styles.phoneAccessTag, form.isPremium ? styles.phoneAccessTagPremium : styles.phoneAccessTagFree)}>
                          <span className={joinClassNames(styles.phoneAccessIcon, form.isPremium ? styles.phoneAccessIconPremium : styles.phoneAccessIconFree)} aria-hidden="true">
                            <svg viewBox="0 0 16 16" focusable="false">
                              <path d="M8 1.75 13 4.6v5.8L8 13.25 3 10.4V4.6l5-2.85Zm0 1.72L4.5 5.45v4.1L8 11.53l3.5-1.98v-4.1L8 3.47Z" fill="currentColor" />
                            </svg>
                          </span>
                          <span>{form.isPremium ? text.premiumLabel : text.freeLabel}</span>
                        </span>
                      </div>
                    </div>
                  </div>
                </div>
              </section>

              <section className={styles.railCard}>
                <div className={styles.railHeader}>
                  <h2 className={styles.railTitle}>{text.editorChecklistTitle}</h2>
                </div>

                <div className={styles.railStats}>
                  <div className={joinClassNames(styles.railStatCard, styles.railStatCardReady)}>
                    <span className={styles.railStatLabel}>{text.editorReady}</span>
                    <strong className={styles.railStatValue}>{editorModel.checklist.filter((item) => item.ready).length}</strong>
                  </div>
                  <div className={joinClassNames(styles.railStatCard, styles.railStatCardMissing)}>
                    <span className={styles.railStatLabel}>{text.editorMissing}</span>
                    <strong className={styles.railStatValue}>{editorModel.checklist.filter((item) => !item.ready).length}</strong>
                  </div>
                </div>

                <div className={styles.checklist}>
                  {editorModel.checklist.map((item) => {
                    const stateLabel = item.ready ? text.editorReady : text.editorMissing;
                    const showDetail = item.detail !== stateLabel;

                    return (
                    <div key={item.label} className={joinClassNames(styles.checklistItem, item.ready ? styles.checklistItemReady : styles.checklistItemMissing)}>
                      <span className={joinClassNames(styles.checkIndicator, item.ready ? styles.checkReady : styles.checkMissing)} aria-hidden="true" />
                      <div className={styles.checklistCopy}>
                        <div className={styles.checklistLabel}>{item.label}</div>
                        {showDetail ? <div className={styles.checklistDetail}>{item.detail}</div> : null}
                      </div>
                      <span className={joinClassNames(styles.checklistState, item.ready ? styles.checklistStateReady : styles.checklistStateMissing)}>{stateLabel}</span>
                    </div>
                  );})}
                </div>
              </section>

            </aside>
          </div>

          <div className={styles.footerBar}>
            <div className={styles.footerActions}>
              <Button type="button" variant="secondary" className={styles.adminButton} disabled={isSaving} onClick={() => router.push(catalogPath)}>
                {text.editorCancel}
              </Button>
              <Button type="submit" variant="primary" className={styles.primaryButton} disabled={isSaving}>
                {isEditMode ? text.saveTemplate : text.editorSaveAndContinue}
              </Button>
            </div>
          </div>
        </form>

        {toast ? <Toast message={toast.message} type={toast.type} /> : null}
      </section>
    );
  }

  return (
    <section className={styles.layout}>
      <TemplatesListCard
        text={text}
        sectionTitle={sectionTitle}
        isVideo={isVideo}
        templates={templates}
        busyTemplateId={busyTemplateId}
        error={error}
        onCreateNew={resetForm}
        onOpenTemplate={openTemplate}
        onChangeStatus={handleStatusChange}
        onDeleteTemplate={handleDelete}
      />

      <form className={styles.formCard} onSubmit={handleSubmit}>
        <div className={styles.headerRow}>
          <div>
            <h2 className={styles.title}>{selectedTemplate ? text.updateTemplate : text.createTemplate}</h2>
            <p className={styles.muted}>
              {selectedTemplate ? `${text.statusLabel}: ${selectedTemplate.status}` : text.computedValueHint}
            </p>
          </div>
        </div>

        <TemplateBasicFields text={text} form={form} setForm={setForm} />
        <TemplatePreviewAssetSection
          text={text}
          form={form}
          setForm={setForm}
          previewFile={previewFile}
          setPreviewFile={setPreviewFile}
          uploadingKind={uploadingKind}
          onUploadPreview={() => void handleUpload("Preview")}
        />

        {isVideo ? (
          <>
            <TemplateReferenceAssetSection
              text={text}
              form={form}
              setForm={setForm}
              referenceFile={referenceFile}
              setReferenceFile={setReferenceFile}
              uploadingKind={uploadingKind}
              onUploadReference={() => void handleUpload("ReferenceMotion")}
            />
            <TemplateVideoModelSection
              text={text}
              form={form}
              setForm={setForm}
              preprocessingModels={PREPROCESSING_MODELS}
              klingModels={KLING_MODELS}
            />
          </>
        ) : null}

        <div className={styles.actions}>
          <Button type="submit" variant="primary" className={styles.primaryButton} disabled={isSaving}>
            {text.saveTemplate}
          </Button>
          <Button type="button" variant="secondary" className={styles.adminButton} disabled={isSaving} onClick={resetForm}>
            {text.resetForm}
          </Button>
        </div>
      </form>
      {toast ? <Toast message={toast.message} type={toast.type} /> : null}
    </section>
  );
}

function buildVideoEditorModel(text: Dictionary, form: TemplateFormState, selectedTemplate: AdminTemplate | null): VideoEditorModel {
  const title = form.title.trim();
  const shortDescription = form.shortDescription.trim();
  const musicDescription = form.musicDescription.trim();
  const category = form.category.trim();
  const promoBadge = resolveEffectivePromoBadge(form, selectedTemplate);
  const tokenCost = normalizeIntegerString(form.tokenCost) || "0";
  const previewReady = Boolean(form.previewUrl.trim());
  const referenceReady = Boolean(form.referenceUrl.trim());
  const referenceDuration = selectedTemplate?.referenceVideoDurationSeconds ?? parseOptionalDecimal(form.referenceDurationSeconds);
  const characterOrientation = selectedTemplate?.characterOrientation ?? inferCharacterOrientation(referenceDuration);
  const preprocessingReady = Boolean(form.preprocessingModel.trim() && form.preprocessingPrompt.trim());
  const klingReady = Boolean(form.klingModel.trim() && form.klingPrompt.trim());
  const basicInfoReady = Boolean(title && shortDescription && category && parseNumber(tokenCost) > 0);
  const mediaReady = Boolean(previewReady && referenceReady && referenceDuration !== undefined && characterOrientation);
  const aiReady = Boolean(preprocessingReady && klingReady);
  const reviewReady = Boolean(basicInfoReady && mediaReady && aiReady);

  return {
    title,
    shortDescription,
    musicDescription,
    category,
    promoBadge,
    tokenCost,
    previewReady,
    referenceReady,
    referenceDuration,
    characterOrientation,
    basicInfoReady,
    mediaReady,
    aiReady,
    reviewReady,
    checklist: buildChecklist(text, {
      previewReady,
      referenceReady,
      referenceDuration,
      characterOrientation,
      preprocessingReady,
      klingReady,
    }),
  };
}

function buildChecklist(
  text: Dictionary,
  signals: {
    previewReady: boolean;
    referenceReady: boolean;
    referenceDuration?: number;
    characterOrientation: string;
    preprocessingReady: boolean;
    klingReady: boolean;
  },
): ChecklistItem[] {
  return [
    {
      label: text.previewAssetTitle,
      detail: signals.previewReady ? text.editorReady : text.editorMissing,
      ready: signals.previewReady,
    },
    {
      label: text.referenceMotionTitle,
      detail: signals.referenceReady ? text.editorReady : text.editorMissing,
      ready: signals.referenceReady,
    },
    {
      label: text.referenceDurationLabel,
      detail: signals.referenceDuration === undefined ? text.editorMissing : formatDuration(signals.referenceDuration),
      ready: signals.referenceDuration !== undefined,
    },
    {
      label: text.characterOrientationLabel,
      detail: signals.characterOrientation || text.editorMissing,
      ready: Boolean(signals.characterOrientation),
    },
    {
      label: text.preprocessingModelLabel,
      detail: signals.preprocessingReady ? text.editorReady : text.editorMissing,
      ready: signals.preprocessingReady,
    },
    {
      label: text.klingModelLabel,
      detail: signals.klingReady ? text.editorReady : text.editorMissing,
      ready: signals.klingReady,
    },
  ];
}

function renderPhonePreview(
  url: string,
  contentType: string,
  alt: string,
  mediaClassName: string,
  placeholderClassName: string,
) {
  const trimmedUrl = url.trim();
  if (!trimmedUrl) {
    return <div className={placeholderClassName} aria-hidden="true" />;
  }

  if (inferTemplateMediaKind(contentType, trimmedUrl) === "video") {
    return <video src={trimmedUrl} className={mediaClassName} muted autoPlay loop playsInline preload="metadata" />;
  }

  return <Image src={trimmedUrl} alt={alt} width={320} height={568} unoptimized className={mediaClassName} />;
}

function getStatusColor(status?: TemplateStatus): string {
  switch (status) {
    case "Active":
      return "#22c55e";
    case "Archived":
      return "#f59e0b";
    default:
      return "#38bdf8";
  }
}

function getTemplateCatalogPath(locale: Locale, templateType: TemplateType) {
  const slug = templateType === "Video" ? "video" : "image";
  return `/${locale}/templates/${slug}`;
}

function getUniqueValues(values: string[]): string[] {
  return Array.from(new Set(values.map((value) => value.trim()).filter(Boolean))).sort((left, right) => left.localeCompare(right));
}

function inferCharacterOrientation(duration?: number): string {
  if (duration === undefined) {
    return "";
  }

  return duration <= 10 ? "image" : "video";
}

function formatDuration(seconds?: number): string {
  if (seconds === undefined) {
    return "--:--";
  }

  const totalSeconds = Math.max(0, Math.round(seconds));
  const minutes = Math.floor(totalSeconds / 60);
  const remainderSeconds = totalSeconds % 60;
  return `${minutes.toString().padStart(2, "0")}:${remainderSeconds.toString().padStart(2, "0")}`;
}

function formatPromoBadge(value: Exclude<TemplatePromoBadgeMode, "Auto">): string {
  return value.toUpperCase();
}

function getPromoBadgeClassName(
  value: Exclude<TemplatePromoBadgeMode, "Auto">,
  classNames: Record<string, string>
): string | null {
  switch (value) {
    case "Trending":
      return classNames.phoneHeroBadgeTrending;
    case "Popular":
      return classNames.phoneHeroBadgePopular;
    case "Funny":
      return classNames.phoneHeroBadgeFunny;
    default:
      return classNames.phoneHeroBadgeNew;
  }
}

function resolveEffectivePromoBadge(
  form: TemplateFormState,
  selectedTemplate: AdminTemplate | null
): Exclude<TemplatePromoBadgeMode, "Auto"> | undefined {
  if (form.promoBadgeMode !== "Auto") {
    return form.promoBadgeMode as Exclude<TemplatePromoBadgeMode, "Auto">;
  }

  if (selectedTemplate) {
    const createdAt = new Date(selectedTemplate.createdAtUtc).getTime();
    const updatedAt = new Date(selectedTemplate.updatedAtUtc).getTime();
    const now = Date.now();

    if (createdAt >= now - 30 * 24 * 60 * 60 * 1000) {
      return "New";
    }

    if (selectedTemplate.status === "Active" && updatedAt >= now - 14 * 24 * 60 * 60 * 1000) {
      return "Trending";
    }
  }

  const searchText = [form.title, form.shortDescription, form.category, form.tags, form.musicDescription, form.klingPrompt]
    .join(" ")
    .toLowerCase();

  if (parseNumber(form.tokenCost) >= 60 || form.isPremium) {
    return "Popular";
  }

  if (searchText.includes("funny") || searchText.includes("meme") || searchText.includes("viral") || searchText.includes("dance")) {
    return "Funny";
  }

  return "New";
}

function joinClassNames(...classes: Array<string | null | undefined | false>) {
  return classes.filter(Boolean).join(" ");
}

function createInitialForm(templateType: TemplateType): TemplateFormState {
  return {
    title: "",
    shortDescription: "",
    category: "",
    promoBadgeMode: "Auto",
    tags: "",
    isPremium: false,
    tokenCost: templateType === "Video" ? "60" : "20",
    previewUrl: "",
    previewFileName: "",
    previewContentType: templateType === "Video" ? "video/mp4" : "image/jpeg",
    previewFileSizeBytes: "",
    musicDescription: "",
    referenceUrl: "",
    referenceFileName: "",
    referenceContentType: "video/mp4",
    referenceFileSizeBytes: "",
    referenceDurationSeconds: "",
    preprocessingModel: PREPROCESSING_MODELS[0],
    preprocessingPrompt: DEFAULT_PREPROCESSING_PROMPT,
    klingModel: KLING_MODELS[0],
    klingPrompt: DEFAULT_KLING_PROMPT,
    keepOriginalSound: true
  };
}

function createFormFromTemplate(template: AdminTemplate): TemplateFormState {
  return {
    title: template.title,
    shortDescription: template.shortDescription,
    category: template.category,
    promoBadgeMode: template.promoBadgeMode,
    tags: template.tags.join(", "),
    isPremium: template.isPremium,
    tokenCost: template.tokenCost.toString(),
    previewUrl: template.previewAsset?.url ?? "",
    previewFileName: template.previewAsset?.fileName ?? "",
    previewContentType: template.previewAsset?.contentType ?? (template.templateType === "Video" ? "video/mp4" : "image/jpeg"),
    previewFileSizeBytes: template.previewAsset?.fileSizeBytes?.toString() ?? "",
    musicDescription: template.musicDescription ?? "",
    referenceUrl: template.referenceMotionAsset?.url ?? "",
    referenceFileName: template.referenceMotionAsset?.fileName ?? "",
    referenceContentType: template.referenceMotionAsset?.contentType ?? "video/mp4",
    referenceFileSizeBytes: template.referenceMotionAsset?.fileSizeBytes?.toString() ?? "",
    referenceDurationSeconds: template.referenceMotionAsset?.durationSeconds?.toString() ?? "",
    preprocessingModel: template.preprocessingModel ?? PREPROCESSING_MODELS[0],
    preprocessingPrompt: template.preprocessingPrompt ?? DEFAULT_PREPROCESSING_PROMPT,
    klingModel: template.klingModel ?? KLING_MODELS[0],
    klingPrompt: template.klingPrompt ?? DEFAULT_KLING_PROMPT,
    keepOriginalSound: template.keepOriginalSound ?? true
  };
}

async function saveImageTemplate(templateId: string | undefined, form: TemplateFormState): Promise<AdminTemplate> {
  const payload: ImageTemplatePayload = {
    title: form.title,
    shortDescription: form.shortDescription,
    category: form.category,
    promoBadgeMode: form.promoBadgeMode as TemplatePromoBadgeMode,
    tags: normalizeTags(form.tags),
    isPremium: form.isPremium,
    tokenCost: parseNumber(form.tokenCost),
    previewAsset: buildAsset(form.previewUrl, form.previewFileName, form.previewContentType, form.previewFileSizeBytes)
  };

  return templateId ? updateImageTemplate(templateId, payload) : createImageTemplate(payload);
}

async function saveVideoTemplate(templateId: string | undefined, form: TemplateFormState): Promise<AdminTemplate> {
  const payload: VideoTemplatePayload = {
    title: form.title,
    shortDescription: form.shortDescription,
    category: form.category,
    promoBadgeMode: form.promoBadgeMode as TemplatePromoBadgeMode,
    tags: normalizeTags(form.tags),
    isPremium: form.isPremium,
    tokenCost: parseNumber(form.tokenCost),
    musicDescription: form.musicDescription,
    previewAsset: buildAsset(form.previewUrl, form.previewFileName, form.previewContentType, form.previewFileSizeBytes),
    referenceMotionAsset: buildAsset(
      form.referenceUrl,
      form.referenceFileName,
      form.referenceContentType,
      form.referenceFileSizeBytes,
      form.referenceDurationSeconds
    ),
    preprocessingModel: form.preprocessingModel,
    preprocessingPrompt: form.preprocessingPrompt,
    klingModel: form.klingModel,
    klingPrompt: form.klingPrompt,
    keepOriginalSound: form.keepOriginalSound
  };

  return templateId ? updateVideoTemplate(templateId, payload) : createVideoTemplate(payload);
}

function buildAsset(
  url: string,
  fileName: string,
  contentType: string,
  fileSizeBytes: string,
  durationSeconds?: string
): TemplateAssetInput | undefined {
  if (!url.trim()) {
    return undefined;
  }

  const size = parseOptionalNumber(fileSizeBytes);
  const duration = parseOptionalDecimal(durationSeconds);

  return {
    url: url.trim(),
    fileName: fileName.trim() || inferFileName(url),
    contentType: contentType.trim() || inferContentType(url),
    fileSizeBytes: size,
    durationSeconds: duration
  };
}

function normalizeTags(raw: string): string[] {
  return raw
    .split(",")
    .map((tag) => tag.trim())
    .filter(Boolean);
}

function parseNumber(raw: string): number {
  const value = Number.parseInt(normalizeIntegerString(raw), 10);
  return Number.isNaN(value) ? 0 : value;
}

function parseOptionalNumber(raw: string): number | undefined {
  const value = Number.parseInt(normalizeIntegerString(raw), 10);
  return Number.isNaN(value) ? undefined : value;
}

function normalizeIntegerString(raw: string): string {
  return raw.replace(/\D+/g, "");
}

function parseOptionalDecimal(raw?: string): number | undefined {
  if (!raw) {
    return undefined;
  }

  const value = Number.parseFloat(raw);
  return Number.isNaN(value) ? undefined : value;
}

function inferFileName(url: string): string {
  const parts = url.split("/");
  return parts.at(-1) || "asset";
}

function inferContentType(url: string): string {
  const lower = url.toLowerCase();

  if (lower.endsWith(".mp4")) {
    return "video/mp4";
  }

  if (lower.endsWith(".webm")) {
    return "video/webm";
  }

  if (lower.endsWith(".png")) {
    return "image/png";
  }

  return "image/jpeg";
}
