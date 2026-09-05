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
  TemplateEditorNavigation,
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
    isDirty,
    hasCategoriesError,
    isCategoriesLoading,
    refreshCategories,
    navigateCatalog,
    saveError,
    saveProgress,
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
    isSaveReady,
    isSaving,
    isVideo,
    mergedCategorySuggestions,
    previewFile,
    previewObjectUrl,
    previewTags,
    referenceFile,
    resetForm,
    retryInitialization,
    saveReadinessHint,
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
          onNavigateCatalog={navigateCatalog}
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
        onNavigateCatalog={navigateCatalog}
      />

      <TemplateEditorNavigation editorModel={editorModel} text={text} isDirty={isDirty} />
      <form className={styles.editorForm} onSubmit={handleSubmit} aria-busy={isSaving}>
        <fieldset className={styles.editorFieldset} disabled={isSaving}>
          <div className={styles.editorGrid}>
            <div className={styles.editorMain}>
              <section id="template-basics" className={styles.sectionCard}>
                <AdminSectionHeader
                  title={text.editorSectionBasics}
                  description={text.editorBasicsHint}
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

                {hasCategoriesError ? (
                  <div className={styles.inlineFeedback} role="alert">
                    <span>{text.editorCategoryLoadError}</span>
                    <Button
                      type="button"
                      variant="secondary"
                      onClick={() => void refreshCategories()}
                    >
                      {text.adminRetryAction}
                    </Button>
                  </div>
                ) : !isCategoriesLoading && mergedCategorySuggestions.length === 0 ? (
                  <p className={styles.muted}>{text.editorCategoryEmpty}</p>
                ) : null}
                <TemplateBasicFields
                  text={text}
                  form={form}
                  setForm={setForm}
                  categorySuggestions={mergedCategorySuggestions}
                  requireCompleteDetails={editorStatus === "Active"}
                  showMusicDescription={isVideo}
                />
              </section>

              <section id="template-media" className={styles.sectionCard}>
                <AdminSectionHeader
                  title={text.editorSectionMedia}
                  description={isVideo ? text.editorMediaHint : text.editorImageMediaHint}
                  aside={
                    <span
                      className={joinClassNames(
                        styles.inlineState,
                        editorModel.mediaReady
                          ? styles.inlineStateReady
                          : styles.inlineStateAttention
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
                    isBusy={isSaving}
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
                      isBusy={isSaving}
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
                  title={text.editorSectionAi}
                  description={text.editorAiHint}
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
              previewFile={previewFile}
              previewObjectUrl={previewObjectUrl}
              text={text}
            />
          </div>
        </fieldset>

        <TemplateEditorFooter
          catalogPath={catalogPath}
          editorStatus={editorStatus}
          isSaveReady={isSaveReady}
          isSaving={isSaving}
          onCancel={navigateCatalog}
          saveProgress={saveProgress}
          saveError={saveError}
          isQaOnly={form.isQaOnly}
          onReset={resetForm}
          onSetEditorStatus={setEditorStatus}
          saveReadinessHint={saveReadinessHint}
          text={text}
        />
      </form>

      {activeToast ? <Toast message={activeToast.message} type={activeToast.type} /> : null}
    </section>
  );
}
