"use client";

import {
  AdminMetricStrip,
  AdminSectionHeader,
  AdminStateCard,
} from "@/components/admin/admin-primitives";
import { TemplateBasicFields } from "@/components/templates/template-basic-fields";
import {
  TemplateEditorFooter,
  TemplateEditorHeader,
  TemplateEditorLoadingState,
  TemplateEditorRail,
} from "@/components/templates/template-editor-layout";
import { formatDuration } from "@/components/templates/template-editor-model";
import {
  TemplateImageModelSection,
  TemplateReferenceAssetSection,
  TemplateVideoModelSection,
} from "@/components/templates/template-editor-sections";
import styles from "@/components/templates/template-editor.module.css";
import {
  IMAGE_MODELS,
  KLING_MODELS,
  PREPROCESSING_MODELS,
} from "@/components/templates/template-form-mappers";
import { TemplatePreviewAssetSection } from "@/components/templates/template-preview-asset-section";
import { useTemplateEditorController } from "@/components/templates/use-template-editor-controller";
import { Button } from "@/components/ui/button";
import { Toast } from "@/components/ui/toast";
import { type TemplateType } from "@/lib/api-client";
import { type Locale } from "@/lib/i18n";
import { joinClassNames } from "@/lib/join-class-names";

type TemplateEditorProps = {
  locale: Locale;
  templateType: TemplateType;
  initialTemplateId?: string;
};

export function TemplateEditor({ locale, templateType, initialTemplateId }: TemplateEditorProps) {
  const {
    activeToast,
    catalogLabel,
    catalogPath,
    editorModel,
    editorStatus,
    fallbackPreviewTitle,
    form,
    handleSubmit,
    handleUpload,
    initializationError,
    isEditMode,
    isLoading,
    isSaving,
    isVideo,
    mergedCategorySuggestions,
    previewFile,
    previewTags,
    referenceFile,
    resetForm,
    retryInitialization,
    router,
    setEditorStatus,
    setForm,
    setPreviewFile,
    setReferenceFile,
    text,
    uploadingKind,
  } = useTemplateEditorController({ initialTemplateId, locale, templateType });

  if (isLoading) {
    return <TemplateEditorLoadingState />;
  }

  if (initializationError) {
    return (
      <section className={styles.templateEditorPage}>
        <TemplateEditorHeader
          catalogLabel={catalogLabel}
          currentLabel={text.updateTemplate}
          onNavigateCatalog={() => router.push(catalogPath)}
        />
        <AdminStateCard
          tone="danger"
          title={initializationError}
          action={
            <Button type="button" variant="secondary" onClick={retryInitialization}>
              {text.adminRetryAction}
            </Button>
          }
        />
        {activeToast ? <Toast message={activeToast.message} type={activeToast.type} /> : null}
      </section>
    );
  }

  return (
    <section className={styles.templateEditorPage}>
      <TemplateEditorHeader
        catalogLabel={catalogLabel}
        currentLabel={isEditMode ? text.updateTemplate : text.createNewTemplate}
        onNavigateCatalog={() => router.push(catalogPath)}
      />

      <form className={styles.editorForm} onSubmit={handleSubmit}>
        <div className={styles.editorGrid}>
          <div className={styles.editorMain}>
            <section id="template-basics" className={styles.sectionCard}>
              <AdminSectionHeader
                title={text.editorStepBasics}
                aside={
                  <span
                    className={joinClassNames(
                      styles.inlineState,
                      editorModel.basicInfoReady
                        ? styles.inlineStateReady
                        : styles.inlineStateAttention
                    )}
                  >
                    {editorModel.basicInfoReady ? text.editorReady : text.editorMissing}
                  </span>
                }
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
                aside={
                  <span
                    className={joinClassNames(
                      styles.inlineState,
                      editorModel.mediaReady ? styles.inlineStateReady : styles.inlineStateAttention
                    )}
                  >
                    {editorModel.mediaReady ? text.editorReady : text.editorMissing}
                  </span>
                }
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
                    {
                      label: text.referenceDurationLabel,
                      value: formatDuration(editorModel.referenceDuration),
                    },
                    {
                      label: text.characterOrientationLabel,
                      value: editorModel.characterOrientation || text.editorMissing,
                    },
                  ]}
                />
              ) : null}
            </section>

            <section id="template-ai" className={styles.sectionCard}>
              <AdminSectionHeader
                title={text.editorStepAi}
                aside={
                  <span
                    className={joinClassNames(
                      styles.inlineState,
                      editorModel.aiReady ? styles.inlineStateReady : styles.inlineStateAttention
                    )}
                  >
                    {editorModel.aiReady ? text.editorReady : text.editorMissing}
                  </span>
                }
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

          <TemplateEditorRail
            editorModel={editorModel}
            fallbackPreviewTitle={fallbackPreviewTitle}
            form={form}
            isVideo={isVideo}
            previewTags={previewTags}
            text={text}
          />
        </div>

        <TemplateEditorFooter
          catalogPath={catalogPath}
          editorStatus={editorStatus}
          isSaving={isSaving}
          onCancel={(path) => router.push(path)}
          onReset={resetForm}
          onSetEditorStatus={setEditorStatus}
          text={text}
        />
      </form>

      {activeToast ? <Toast message={activeToast.message} type={activeToast.type} /> : null}
    </section>
  );
}
