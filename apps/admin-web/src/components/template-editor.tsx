"use client";

import { AdminMetricStrip, AdminSectionHeader } from "@/components/admin/admin-primitives";
import { ensureAdminSession } from "@/components/admin/admin-session";
import { TemplateBasicFields } from "@/components/templates/template-basic-fields";
import { buildTemplateEditorModel, formatDuration } from "@/components/templates/template-editor-model";
import { TemplateImageModelSection, TemplateReferenceAssetSection, TemplateVideoModelSection } from "@/components/templates/template-editor-sections";
import styles from "@/components/templates/template-editor.module.css";
import {
    IMAGE_MODELS,
    KLING_MODELS,
    PREPROCESSING_MODELS,
    createFormFromTemplate,
    createInitialTemplateForm,
    parseOptionalDecimal,
    saveImageTemplateFromForm,
    saveVideoTemplateFromForm,
} from "@/components/templates/template-form-mappers";
import { TemplatePreviewCard } from "@/components/templates/template-phone-preview-card";
import { TemplatePreviewAssetSection } from "@/components/templates/template-preview-asset-section";
import { type TemplateFormState } from "@/components/templates/types";
import { Button } from "@/components/ui/button";
import { Toast } from "@/components/ui/toast";
import {
    fetchAdminTemplate,
    fetchAdminTemplateCategories,
    fetchAdminTemplates,
    uploadTemplateMedia,
    type AdminTemplate,
    type AdminTemplateListItem,
    type TemplateAssetKind,
    type TemplateStatus,
    type TemplateType
} from "@/lib/api-client";
import { getDictionary, type Dictionary, type Locale } from "@/lib/i18n";
import { useRouter } from "next/navigation";
import { useCallback, useEffect, useState } from "react";

type TemplateEditorProps = {
  locale: Locale;
  templateType: TemplateType;
  initialTemplateId?: string;
};

type ToastState = {
  type: "success" | "error";
  message: string;
};

type EditorVisibilityStatus = Extract<TemplateStatus, "Draft" | "Active">;

export function TemplateEditor({ locale, templateType, initialTemplateId }: TemplateEditorProps) {
  const text = getDictionary(locale);
  const router = useRouter();
  const [templates, setTemplates] = useState<AdminTemplateListItem[]>([]);
  const [categorySuggestions, setCategorySuggestions] = useState<string[]>([]);
  const [selectedTemplate, setSelectedTemplate] = useState<AdminTemplate | null>(null);
  const [form, setForm] = useState<TemplateFormState>(() => createInitialTemplateForm(templateType));
  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  const [previewFile, setPreviewFile] = useState<File | null>(null);
  const [referenceFile, setReferenceFile] = useState<File | null>(null);
  const [uploadingKind, setUploadingKind] = useState<TemplateAssetKind | null>(null);
  const [toast, setToast] = useState<ToastState | null>(null);
  const [editorStatus, setEditorStatus] = useState<EditorVisibilityStatus>("Draft");
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
    try {
      if (!ensureAdminSession(locale, router)) {
        return;
      }

      const [templatesResponse, categoriesResponse] = await Promise.all([
        fetchAdminTemplates(templateType),
        fetchAdminTemplateCategories(false),
      ]);

      setTemplates(templatesResponse);
      setCategorySuggestions(categoriesResponse.map((category) => category.name));
    } catch {
      setToast({ type: "error", message: text.errorLoadingTemplates });
    } finally {
      if (showLoading) {
        setIsLoading(false);
      }
    }
  }

  const loadEditorLookups = useCallback(async (isCancelled: () => boolean) => {
    try {
      const [templatesResponse, categoriesResponse] = await Promise.all([
        fetchAdminTemplates(templateType),
        fetchAdminTemplateCategories(false),
      ]);

      if (!isCancelled()) {
        setTemplates(templatesResponse);
        setCategorySuggestions(categoriesResponse.map((category) => category.name));
      }
    } catch {
      if (!isCancelled()) {
        setToast({ type: "error", message: text.errorLoadingTemplates });
      }
    }
  }, [templateType, text.errorLoadingTemplates]);

  useEffect(() => {
    let isCancelled = false;

    async function initialize() {
      setIsLoading(true);
      try {
        if (!ensureAdminSession(locale, router)) {
          return;
        }

        if (initialTemplateId) {
          const templateResponse = await fetchAdminTemplate(initialTemplateId);
          if (isCancelled) {
            return;
          }

          setSelectedTemplate(templateResponse);
          setForm(createFormFromTemplate(templateResponse));
          setEditorStatus(resolveEditorVisibilityStatus(templateResponse.status));
        }

        if (!isCancelled) {
          setIsLoading(false);
        }

        void loadEditorLookups(() => isCancelled);
      } catch {
        if (!isCancelled) {
          setToast({ type: "error", message: text.errorLoadingTemplates });
        }
      } finally {
        if (!isCancelled) {
          setIsLoading(false);
        }
      }
    }

    void initialize();

    return () => {
      isCancelled = true;
    };
  }, [initialTemplateId, loadEditorLookups, locale, router, templateType, text.errorLoadingTemplates]);

  function resetForm() {
    setSelectedTemplate(null);
    setForm(createInitialTemplateForm(templateType));
    setEditorStatus("Draft");
    setPreviewFile(null);
    setReferenceFile(null);
  }

  async function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    await handleSave(editorStatus);
  }

  async function handleSave(targetStatus: EditorVisibilityStatus) {
    setIsSaving(true);
    let savedTemplate: AdminTemplate | null = null;
    const catalogPath = getTemplateCatalogPath(locale, templateType);

    try {
      const activationReadinessError = getActivationReadinessError(templateType, form, text, targetStatus);
      if (activationReadinessError) {
        setToast({ type: "error", message: activationReadinessError });
        return;
      }

      savedTemplate = templateType === "Video"
        ? await saveVideoTemplateFromForm(selectedTemplate?.templateId, form, targetStatus)
        : await saveImageTemplateFromForm(selectedTemplate?.templateId, form, targetStatus);

      setSelectedTemplate(savedTemplate);
      setForm(createFormFromTemplate(savedTemplate));
      setEditorStatus(resolveEditorVisibilityStatus(savedTemplate.status));
      await loadTemplates(false);
      setToast({
        type: "success",
        message: targetStatus === "Active" ? text.templateActivated : text.templateSavedAsDraft
      });

      router.push(catalogPath);
    } catch (error) {
      if (savedTemplate) {
        setSelectedTemplate(savedTemplate);
        setForm(createFormFromTemplate(savedTemplate));
        setEditorStatus(resolveEditorVisibilityStatus(savedTemplate.status));
        await loadTemplates(false);
      }

      const message = getTemplateSaveErrorMessage(error, text, targetStatus);
      setToast({ type: "error", message });
    } finally {
      setIsSaving(false);
    }
  }

  async function handleUpload(assetKind: TemplateAssetKind) {
    const file = assetKind === "Preview" ? previewFile : referenceFile;
    if (!file) {
      return;
    }

    setUploadingKind(assetKind);
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
        message: text.templateFileUploaded
      });
    } catch {
      setToast({ type: "error", message: text.errorSavingTemplate });
    } finally {
      setUploadingKind(null);
    }
  }

  const mergedCategorySuggestions = getUniqueValues([...categorySuggestions, ...templates.map((template) => template.category)]);
  const isEditMode = selectedTemplate !== null;
  const catalogPath = getTemplateCatalogPath(locale, templateType);
  const editorModel = buildTemplateEditorModel(text, form, selectedTemplate, templateType);
  const catalogLabel = isVideo ? text.navVideoTemplates : text.navImageTemplates;
  const fallbackPreviewTitle = isVideo ? text.videoTemplateCreatePageTitle : text.imageTemplatesTitle;
  const previewTags = form.tags.split(",").map((tag) => tag.trim()).filter(Boolean);

  if (isLoading) {
    return (
      <section className={styles.templateEditorPage}>
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
    <section className={styles.templateEditorPage}>
      <div className={styles.pageTop}>
        <div className={styles.breadcrumbs}>
          <button type="button" className={styles.breadcrumbLink} onClick={() => router.push(catalogPath)}>
            {catalogLabel}
          </button>
          <span className={styles.breadcrumbDivider} aria-hidden="true">
            &gt;
          </span>
          <span className={styles.breadcrumbCurrent}>{isEditMode ? text.updateTemplate : text.createNewTemplate}</span>
        </div>
      </div>

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
                categorySuggestions={mergedCategorySuggestions}
                showMusicDescription={isVideo}
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

                {isVideo ? (
                  <TemplateReferenceAssetSection
                    text={text}
                    form={form}
                    setForm={setForm}
                    referenceFile={referenceFile}
                    setReferenceFile={setReferenceFile}
                    uploadingKind={uploadingKind}
                    onUploadReference={() => void handleUpload("ReferenceMotion")}
                  />
                ) : null}
              </div>

              {isVideo && "referenceDuration" in editorModel ? (
                <AdminMetricStrip
                  className={styles.derivedGrid}
                  items={[
                    { label: text.referenceDurationLabel, value: formatDuration(editorModel.referenceDuration) },
                    { label: text.characterOrientationLabel, value: editorModel.characterOrientation || text.editorMissing },
                  ]}
                />
              ) : null}
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

              {isVideo ? (
                <TemplateVideoModelSection
                  text={text}
                  form={form}
                  setForm={setForm}
                  preprocessingModels={PREPROCESSING_MODELS}
                  klingModels={KLING_MODELS}
                />
              ) : (
                <TemplateImageModelSection
                  text={text}
                  form={form}
                  setForm={setForm}
                  imageModels={IMAGE_MODELS}
                />
              )}
            </section>

          </div>

          <aside className={styles.editorRail}>
            <section className={joinClassNames(styles.railCard, styles.previewRailCard)}>
              <div className={styles.previewCardWrap}>
                <TemplatePreviewCard
                  title={editorModel.title || fallbackPreviewTitle}
                  shortDescription={editorModel.shortDescription || text.editorPreviewRailHint}
                  tags={previewTags}
                  previewUrl={form.previewUrl}
                  previewContentType={form.previewContentType}
                  templateKind={isVideo ? "video" : "image"}
                  templateKindLabel={isVideo ? text.templateKindVideoBadge : text.templateKindImageBadge}
                  tokenCost={editorModel.tokenCost}
                  category={editorModel.category || text.editorDraft}
                  isPremium={form.isPremium}
                  accessLabel={form.isPremium ? text.premiumLabel : text.freeLabel}
                  referenceDurationSeconds={"referenceDuration" in editorModel ? editorModel.referenceDuration : undefined}
                  promoBadge={editorModel.promoBadge}
                  musicDescription={"musicDescription" in editorModel ? editorModel.musicDescription : undefined}
                />
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
                  );
                })}
              </div>
            </section>

          </aside>
        </div>

        <div className={styles.footerBar}>
          <div className={styles.footerStatusPanel}>
            <div className={styles.footerStatusCopy}>
              <span className={styles.footerStatusLabel}>{text.editorVisibilityTitle}</span>
              <p className={styles.footerStatusHint}>
                {editorStatus === "Active" ? text.editorVisibleToUsersHint : text.editorHiddenFromUsersHint}
              </p>
            </div>

            <div className={styles.footerStatusSwitch} role="group" aria-label={text.editorVisibilityTitle}>
              <button
                type="button"
                className={joinClassNames(styles.footerStatusButton, editorStatus === "Draft" ? styles.footerStatusButtonActive : null)}
                aria-pressed={editorStatus === "Draft"}
                onClick={() => setEditorStatus("Draft")}
              >
                {text.editorDraft}
              </button>
              <button
                type="button"
                className={joinClassNames(styles.footerStatusButton, editorStatus === "Active" ? styles.footerStatusButtonActive : null, editorStatus === "Active" ? styles.footerStatusButtonLive : null)}
                aria-pressed={editorStatus === "Active"}
                onClick={() => setEditorStatus("Active")}
              >
                {text.editorActive}
              </button>
            </div>
          </div>

          <div className={styles.footerActions}>
            <Button type="button" variant="secondary" className={styles.adminButton} disabled={isSaving} onClick={() => router.push(catalogPath)}>
              {text.editorCancel}
            </Button>
            <Button type="button" variant="ghost" className={styles.adminButton} disabled={isSaving} onClick={resetForm}>
              {text.resetForm}
            </Button>
            <Button type="submit" variant="primary" className={styles.primaryButton} disabled={isSaving}>
              {text.saveTemplate}
            </Button>
          </div>
        </div>
      </form>

      {toast ? <Toast message={toast.message} type={toast.type} /> : null}
    </section>
  );
}

function getTemplateCatalogPath(locale: Locale, templateType: TemplateType) {
  const slug = templateType === "Video" ? "video" : "image";
  return `/${locale}/templates/${slug}`;
}

function getUniqueValues(values: string[]): string[] {
  return Array.from(new Set(values.map((value) => value.trim()).filter(Boolean))).sort((left, right) => left.localeCompare(right));
}

function joinClassNames(...classes: Array<string | null | undefined | false>) {
  return classes.filter(Boolean).join(" ");
}

function resolveEditorVisibilityStatus(status?: TemplateStatus): EditorVisibilityStatus {
  return status === "Active" ? "Active" : "Draft";
}

function getTemplateSaveErrorMessage(error: unknown, text: Dictionary, targetStatus: EditorVisibilityStatus): string {
  if (error && typeof error === "object" && "validationErrors" in error) {
    const validationErrors = (error as { validationErrors?: string[] }).validationErrors ?? [];
    if (validationErrors.length > 0) {
      return validationErrors.join(" ");
    }
  }

  if (error instanceof Error && error.message && !/^API request failed with status \d+$/i.test(error.message)) {
    return error.message;
  }

  return targetStatus === "Active" ? text.errorActivatingTemplate : text.errorSavingTemplate;
}

function getActivationReadinessError(
  templateType: TemplateType,
  form: TemplateFormState,
  text: Dictionary,
  targetStatus: EditorVisibilityStatus,
): string | null {
  if (targetStatus !== "Active") {
    return null;
  }

  const missingLabels: string[] = [];

  if (!form.previewUrl.trim()) {
    missingLabels.push(text.previewAssetTitle);
  }

  if (templateType === "Video") {
    if (!form.referenceUrl.trim()) {
      missingLabels.push(text.referenceMotionTitle);
    }

    if (parseOptionalDecimal(form.referenceDurationSeconds) === undefined) {
      missingLabels.push(text.referenceDurationLabel);
    }
  } else {
    if (!form.imageModel.trim()) {
      missingLabels.push(text.imageModelLabel);
    }

    if (!form.imagePrompt.trim()) {
      missingLabels.push(text.imagePromptLabel);
    }
  }

  if (missingLabels.length === 0) {
    return null;
  }

  return `${text.activationRequirementsMissing} ${missingLabels.join(", ")}.`;
}
