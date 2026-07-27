"use client";

import { RefreshIcon } from "@/components/admin/admin-icons";
import {
  AdminBadge,
  AdminPage,
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
    isAutoPickConfirmationOpen,
    isAutoPickDateMissing,
    isAutoPickRunAvailable,
    isAutoPickSettingsDirty,
    isExcludeRecentDaysInvalid,
    isPriorityInvalid,
    isScheduleLoading,
    isScheduleNavigationLocked,
    isSettingsReady,
    isStartDateMissing,
    isTemplateOptionsLoading,
    loadTemplateOptions,
    previewBadge,
    previewMediaUrl,
    previewSubtitle,
    previewTitle,
    previewType,
    notice,
    refreshPageData,
    requestSchedulePage,
    schedule,
    scheduleHasMore,
    schedulePage,
    schedulePageSize,
    scheduleTotalCount,
    search,
    selectedTemplateSnapshot,
    setAssignmentPendingDelete,
    setAutoPick,
    setIsAutoPickConfirmationOpen,
    setSearch,
    setTemplateAccessFilter,
    setTemplateTypeFilter,
    settings,
    settingsLoadError,
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
          `${text.schedule}: ${scheduleTotalCount} ${text.assignments}`,
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
      {notice ? <AdminStateCard tone="success" description={notice} /> : null}
      {isScheduleLoading ? <AdminStateCard title={text.loading} /> : null}

      <div className={styles.workspace}>
        <div className={styles.workspaceColumn}>
          <CurrentAssignmentCard current={current} text={text} locale={locale} />
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
            isStartDateMissing={isStartDateMissing}
            isPriorityInvalid={isPriorityInvalid}
            onSearchChange={setSearch}
            onTemplateTypeFilterChange={setTemplateTypeFilter}
            onTemplateAccessFilterChange={setTemplateAccessFilter}
            onTemplateChange={handleTemplateSelectionChange}
            onRetryTemplateOptions={() => void loadTemplateOptions(debouncedSearch)}
            onFormChange={handleFormChange}
            onReset={handleResetForm}
            onSubmit={handleSubmit}
          />
        </div>
        <div className={styles.workspaceColumn}>
          <AutoPickSettingsCard
            text={text}
            autoPick={autoPick}
            canManageTemplates={canManageTemplates}
            isActionLocked={isActionLocked}
            isSettingsReady={isSettingsReady}
            settingsLoadError={settingsLoadError}
            isAutoPickSettingsDirty={isAutoPickSettingsDirty}
            isExcludeRecentDaysInvalid={isExcludeRecentDaysInvalid}
            isAutoPickDateMissing={isAutoPickDateMissing}
            isAutoPickRunAvailable={isAutoPickRunAvailable}
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
            onRetrySettings={() => void refreshPageData()}
            onRunAutoPick={() => setIsAutoPickConfirmationOpen(true)}
          />
          <div className={styles.previewPanel}>
            <FeaturedPreviewCard
              text={text}
              selectedTemplateSnapshot={selectedTemplateSnapshot}
              previewTitle={previewTitle}
              previewSubtitle={previewSubtitle}
              previewBadge={previewBadge}
              previewType={previewType}
              previewMediaUrl={previewMediaUrl}
            />
          </div>
        </div>
      </div>

      <TemplateScheduleCard
        text={text}
        locale={locale}
        schedule={schedule}
        schedulePage={schedulePage}
        schedulePageSize={schedulePageSize}
        scheduleTotalCount={scheduleTotalCount}
        scheduleHasMore={scheduleHasMore}
        canManageTemplates={canManageTemplates}
        isActionLocked={isActionLocked}
        isScheduleNavigationLocked={isScheduleNavigationLocked}
        onEditAssignment={handleEditAssignment}
        onRequestDeleteAssignment={setAssignmentPendingDelete}
        onPreviousPage={() => requestSchedulePage(schedulePage - 1)}
        onNextPage={() => requestSchedulePage(schedulePage + 1)}
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
      <ConfirmationDialog
        open={isAutoPickConfirmationOpen}
        title={text.autoPickConfirmTitle}
        description={text.autoPickConfirmDescription(autoPick.date)}
        confirmLabel={text.autoPickRun}
        cancelLabel={text.cancel}
        isSubmitting={isAutoPickConfirmationOpen && isActionLocked}
        onCancel={() => {
          if (!isActionLocked) {
            setIsAutoPickConfirmationOpen(false);
          }
        }}
        onConfirm={() => {
          void handleAutoPick().then((succeeded) => {
            if (succeeded) {
              setIsAutoPickConfirmationOpen(false);
            }
          });
        }}
      />
    </AdminPage>
  );
}
