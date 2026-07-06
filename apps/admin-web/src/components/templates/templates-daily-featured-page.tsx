"use client";

import { RefreshIcon } from "@/components/admin/admin-icons";
import {
  AdminBadge,
  AdminPage,
  AdminPageGrid,
  AdminPageHero,
  AdminStateCard,
} from "@/components/admin/admin-primitives";
import { ConfirmationDialog } from "@/components/admin/confirmation-dialog";
import { safeDisplayText } from "@/components/templates/templates-daily-featured-page.helpers";
import styles from "@/components/templates/templates-daily-featured-page.module.css";
import { TemplateScheduleCard } from "@/components/templates/templates-daily-featured-page.schedule";
import {
  AutoPickSettingsCard,
  CurrentAssignmentCard,
  FeaturedPreviewCard,
  TemplateAssignmentEditorCard,
} from "@/components/templates/templates-daily-featured-page.sections";
import type { TemplatesDailyFeaturedPageProps } from "@/components/templates/templates-daily-featured-page.types";
import { useTemplatesDailyFeaturedController } from "@/components/templates/use-templates-daily-featured-controller";
import { Button } from "@/components/ui/button";

export function TemplatesDailyFeaturedPage({ locale }: TemplatesDailyFeaturedPageProps) {
  const {
    assignmentPendingDelete,
    autoPick,
    canManageTemplates,
    current,
    dateOccupiedWarning,
    debouncedSearch,
    error,
    form,
    handleAutoPick,
    handleDelete,
    handleEditAssignment,
    handleFormChange,
    handleResetForm,
    handleSaveSettings,
    handleSubmit,
    handleTemplateSelectionChange,
    invalidDateRangeWarning,
    isActionLocked,
    isAutoPickDateMissing,
    isAutoPickSettingsDirty,
    isScheduleLoading,
    isTemplateOptionsLoading,
    loadTemplateOptions,
    previewBadge,
    previewMediaUrl,
    previewSubtitle,
    previewTitle,
    previewType,
    refreshPageData,
    schedule,
    search,
    selectedTemplateSnapshot,
    setAssignmentPendingDelete,
    setAutoPick,
    setSearch,
    setTemplateAccessFilter,
    setTemplateTypeFilter,
    settings,
    templateAccessFilter,
    templateOptions,
    templateOptionsError,
    templateTypeFilter,
    text,
    templates,
  } = useTemplatesDailyFeaturedController({ locale });

  return (
    <AdminPage className={styles.page}>
      <AdminPageHero
        eyebrow={text.eyebrow}
        title={text.title}
        description={text.description}
        badge={<AdminBadge tone="info">{text.heroBadge}</AdminBadge>}
        actions={
          <Button
            variant="secondary"
            onClick={() => void refreshPageData()}
            disabled={!canManageTemplates || isActionLocked}
          >
            <RefreshIcon className={styles.buttonIcon} />
            {text.refresh}
          </Button>
        }
        metaItems={[
          `${text.schedule}: ${schedule.length} ${text.assignments}`,
          current
            ? `${text.current}: ${safeDisplayText(current.templateTitle, 120)}`
            : text.noCurrent,
          settings?.autoModeEnabled ? text.autoModeEnabled : text.autoModeDisabled,
        ]}
      />

      {error ? (
        <AdminStateCard
          tone="warning"
          title={error}
          action={
            <Button
              variant="secondary"
              onClick={() => void refreshPageData()}
              disabled={!canManageTemplates || isActionLocked}
            >
              {text.retry}
            </Button>
          }
        />
      ) : null}
      {isScheduleLoading ? <AdminStateCard title={text.loading} /> : null}

      <AdminPageGrid columns="two" className={styles.topGrid}>
        <CurrentAssignmentCard current={current} text={text} locale={locale} />
        <AutoPickSettingsCard
          text={text}
          autoPick={autoPick}
          canManageTemplates={canManageTemplates}
          isActionLocked={isActionLocked}
          isAutoPickSettingsDirty={isAutoPickSettingsDirty}
          isAutoPickDateMissing={isAutoPickDateMissing}
          onAutoModeEnabledChange={(value) =>
            setAutoPick((state) => ({ ...state, autoModeEnabled: value }))
          }
          onAllowedTypesChange={(value) =>
            setAutoPick((state) => ({ ...state, allowedTypes: value }))
          }
          onExcludeRecentDaysChange={(value) =>
            setAutoPick((state) => ({ ...state, excludeRecentDays: value }))
          }
          onDateChange={(value) => setAutoPick((state) => ({ ...state, date: value }))}
          onSaveSettings={() => void handleSaveSettings()}
          onRunAutoPick={() => void handleAutoPick()}
        />
      </AdminPageGrid>

      <AdminPageGrid columns="two" className={styles.editorGrid}>
        <TemplateAssignmentEditorCard
          text={text}
          canManageTemplates={canManageTemplates}
          isActionLocked={isActionLocked}
          search={search}
          templateTypeFilter={templateTypeFilter}
          templateAccessFilter={templateAccessFilter}
          form={form}
          templateOptions={templateOptions}
          isTemplateOptionsLoading={isTemplateOptionsLoading}
          hasTemplateOptions={templates.length > 0}
          templateOptionsError={templateOptionsError}
          dateOccupiedWarning={dateOccupiedWarning}
          invalidDateRangeWarning={invalidDateRangeWarning}
          onSearchChange={setSearch}
          onTemplateTypeFilterChange={setTemplateTypeFilter}
          onTemplateAccessFilterChange={setTemplateAccessFilter}
          onTemplateChange={handleTemplateSelectionChange}
          onRetryTemplateOptions={() => void loadTemplateOptions(debouncedSearch)}
          onFormChange={handleFormChange}
          onReset={handleResetForm}
          onSubmit={handleSubmit}
        />
        <FeaturedPreviewCard
          text={text}
          selectedTemplateSnapshot={selectedTemplateSnapshot}
          previewTitle={previewTitle}
          previewSubtitle={previewSubtitle}
          previewBadge={previewBadge}
          previewType={previewType}
          previewMediaUrl={previewMediaUrl}
        />
      </AdminPageGrid>

      <TemplateScheduleCard
        text={text}
        locale={locale}
        schedule={schedule}
        canManageTemplates={canManageTemplates}
        isActionLocked={isActionLocked}
        onEditAssignment={handleEditAssignment}
        onRequestDeleteAssignment={setAssignmentPendingDelete}
      />

      <ConfirmationDialog
        open={assignmentPendingDelete !== null}
        title={text.deleteConfirmTitle}
        description={
          assignmentPendingDelete
            ? text.deleteConfirmDescription(
                safeDisplayText(assignmentPendingDelete.templateTitle, 120)
              )
            : ""
        }
        confirmLabel={text.delete}
        cancelLabel={text.cancel}
        isSubmitting={Boolean(assignmentPendingDelete && isActionLocked)}
        onCancel={() => {
          if (!isActionLocked) {
            setAssignmentPendingDelete(null);
          }
        }}
        onConfirm={() => {
          if (!assignmentPendingDelete) {
            return;
          }

          void handleDelete(assignmentPendingDelete).then((succeeded) => {
            if (succeeded) {
              setAssignmentPendingDelete(null);
            }
          });
        }}
      />
    </AdminPage>
  );
}
