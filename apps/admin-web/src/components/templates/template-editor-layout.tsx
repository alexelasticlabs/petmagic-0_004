"use client";

import { type TemplateEditorModel } from "@/components/templates/template-editor-model";
import styles from "@/components/templates/template-editor.module.css";
import { TemplatePreviewCard } from "@/components/templates/template-phone-preview-card";
import { type TemplateFormState } from "@/components/templates/types";
import { Button } from "@/components/ui/button";
import { type Dictionary } from "@/lib/i18n";
import { joinClassNames } from "@/lib/join-class-names";

import { focusTemplateEditorField } from "./template-editor-readiness";

type EditorVisibilityStatus = "Draft" | "Active";

export function TemplateEditorLoadingState() {
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

export function TemplateEditorHeader({
  catalogLabel,
  currentLabel,
  onNavigateCatalog,
}: {
  catalogLabel: string;
  currentLabel: string;
  onNavigateCatalog: () => void;
}) {
  return (
    <div className={styles.pageTop}>
      <div className={styles.breadcrumbs}>
        <button type="button" className={styles.breadcrumbLink} onClick={onNavigateCatalog}>
          {catalogLabel}
        </button>
        <span className={styles.breadcrumbDivider} aria-hidden="true">
          &gt;
        </span>
        <span className={styles.breadcrumbCurrent}>{currentLabel}</span>
      </div>
    </div>
  );
}

export function TemplateEditorNavigation({
  editorModel,
  text,
  isDirty,
}: {
  editorModel: TemplateEditorModel;
  text: Dictionary;
  isDirty: boolean;
}) {
  const sections = [
    { id: "template-basics", label: text.editorSectionBasics },
    { id: "template-media", label: text.editorSectionMedia },
    { id: "template-ai", label: text.editorSectionAi },
  ];
  return (
    <div className={styles.editorNavigation}>
      <nav aria-label={text.editorNavigationLabel}>
        {sections.map((section, index) => {
          const items = editorModel.checklist.filter((item) => item.sectionId === section.id);
          const ready = items.filter((item) => item.ready).length;
          return (
            <button
              key={section.id}
              type="button"
              onClick={() => focusTemplateEditorField(section.id)}
            >
              <span className={styles.stepNumber}>{index + 1}</span>
              <span>{section.label}</span>
              <span className={styles.stepCount}>
                {ready}/{items.length}
              </span>
            </button>
          );
        })}
      </nav>
      <span className={styles.dirtyIndicator}>
        {isDirty ? text.editorUnsaved : text.editorSavedState}
      </span>
    </div>
  );
}

export function TemplateEditorRail({
  editorModel,
  fallbackPreviewTitle,
  form,
  isVideo,
  previewTags,
  previewFile,
  previewObjectUrl,
  text,
}: {
  editorModel: TemplateEditorModel;
  fallbackPreviewTitle: string;
  form: TemplateFormState;
  isVideo: boolean;
  previewTags: string[];
  previewFile: File | null;
  previewObjectUrl: string | null;
  text: Dictionary;
}) {
  const readyCount = editorModel.checklist.filter((item) => item.ready).length;
  const missingCount = editorModel.checklist.length - readyCount;

  return (
    <aside className={styles.editorRail}>
      <section className={joinClassNames(styles.railCard, styles.previewRailCard)}>
        <h2 className={styles.railTitle}>{text.editorPreviewTitle}</h2>
        <div className={styles.previewCardWrap}>
          <TemplatePreviewCard
            title={editorModel.title || fallbackPreviewTitle}
            shortDescription={editorModel.shortDescription || text.editorPreviewRailHint}
            tags={previewTags}
            previewUrl={previewObjectUrl ?? form.previewUrl}
            previewContentType={previewFile?.type || form.previewContentType}
            templateKind={isVideo ? "video" : "image"}
            templateKindLabel={isVideo ? text.templateKindVideoBadge : text.templateKindImageBadge}
            tokenCost={editorModel.tokenCost}
            category={editorModel.category || text.editorDraft}
            isPremium={form.isPremium}
            accessLabel={form.isPremium ? text.premiumLabel : text.editorAllUsersAccess}
            referenceDurationSeconds={
              "referenceDuration" in editorModel ? editorModel.referenceDuration : undefined
            }
            promoBadge={editorModel.promoBadge}
            musicDescription={
              "musicDescription" in editorModel ? editorModel.musicDescription : undefined
            }
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
            <strong className={styles.railStatValue}>{readyCount}</strong>
          </div>
          <div className={joinClassNames(styles.railStatCard, styles.railStatCardMissing)}>
            <span className={styles.railStatLabel}>{text.editorMissing}</span>
            <strong className={styles.railStatValue}>{missingCount}</strong>
          </div>
        </div>

        <div className={styles.checklist}>
          {editorModel.checklist.map((item) => {
            const stateLabel = item.pending
              ? text.editorFilePending
              : item.ready
                ? text.editorReady
                : text.editorMissing;
            const showDetail = item.detail !== stateLabel;

            return (
              <button
                type="button"
                onClick={() => focusTemplateEditorField(item.targetId)}
                key={item.label}
                className={joinClassNames(
                  styles.checklistItem,
                  item.ready ? styles.checklistItemReady : styles.checklistItemMissing
                )}
              >
                <span
                  className={joinClassNames(
                    styles.checkIndicator,
                    item.ready ? styles.checkReady : styles.checkMissing
                  )}
                  aria-hidden="true"
                />
                <span className={styles.checklistCopy}>
                  <span className={styles.checklistLabel}>{item.label}</span>
                  {showDetail ? (
                    <span className={styles.checklistDetail}>{item.detail}</span>
                  ) : null}
                </span>
                <span
                  className={joinClassNames(
                    styles.checklistState,
                    item.ready ? styles.checklistStateReady : styles.checklistStateMissing
                  )}
                >
                  {stateLabel}
                </span>
              </button>
            );
          })}
        </div>
      </section>
    </aside>
  );
}

export function TemplateEditorFooter({
  catalogPath,
  editorStatus,
  isSaveReady,
  isSaving,
  onCancel,
  onReset,
  onSetEditorStatus,
  saveReadinessHint,
  saveProgress,
  saveError,
  isQaOnly,
  text,
}: {
  catalogPath: string;
  editorStatus: EditorVisibilityStatus;
  isSaveReady: boolean;
  isSaving: boolean;
  onCancel: (path: string) => void;
  onReset: () => void;
  onSetEditorStatus: (status: EditorVisibilityStatus) => void;
  saveReadinessHint: string | null;
  saveProgress: string | null;
  saveError: string | null;
  isQaOnly: boolean;
  text: Dictionary;
}) {
  return (
    <div className={styles.footerBar}>
      {saveError ? (
        <p className={styles.saveError} role="alert">
          {saveError}
        </p>
      ) : null}
      {saveProgress ? (
        <p className={styles.saveProgress} role="status">
          {saveProgress}
        </p>
      ) : null}
      <div className={styles.footerStatusPanel}>
        <div className={styles.footerStatusCopy}>
          <span className={styles.footerStatusLabel}>{text.editorVisibilityTitle}</span>
          <p id="template-save-hint" className={styles.footerStatusHint}>
            {saveReadinessHint ??
              (editorStatus === "Active"
                ? isQaOnly
                  ? text.editorQaPublishHint
                  : text.editorVisibleToUsersHint
                : text.editorHiddenFromUsersHint)}
          </p>
        </div>

        <div
          className={styles.footerStatusSwitch}
          role="group"
          aria-label={text.editorVisibilityTitle}
        >
          <button
            type="button"
            className={joinClassNames(
              styles.footerStatusButton,
              editorStatus === "Draft" ? styles.footerStatusButtonActive : null
            )}
            aria-pressed={editorStatus === "Draft"}
            disabled={isSaving}
            onClick={() => onSetEditorStatus("Draft")}
          >
            {text.editorDraft}
          </button>
          <button
            type="button"
            className={joinClassNames(
              styles.footerStatusButton,
              editorStatus === "Active" ? styles.footerStatusButtonActive : null,
              editorStatus === "Active" ? styles.footerStatusButtonLive : null
            )}
            aria-pressed={editorStatus === "Active"}
            disabled={isSaving}
            onClick={() => onSetEditorStatus("Active")}
          >
            {text.editorActive}
          </button>
        </div>
      </div>

      <div className={styles.footerActions}>
        <Button
          type="button"
          variant="secondary"
          className={styles.adminButton}
          disabled={isSaving}
          onClick={() => onCancel(catalogPath)}
        >
          {text.editorCancel}
        </Button>
        <Button
          type="button"
          variant="ghost"
          className={styles.adminButton}
          disabled={isSaving}
          onClick={onReset}
        >
          {text.resetForm}
        </Button>
        <Button
          type="submit"
          variant="primary"
          className={styles.primaryButton}
          disabled={isSaving || !isSaveReady}
          aria-describedby="template-save-hint"
        >
          {isSaving
            ? text.editorSavingProgress
            : editorStatus === "Active"
              ? text.editorSaveAndActivate
              : text.editorSaveDraft}
        </Button>
      </div>
    </div>
  );
}
