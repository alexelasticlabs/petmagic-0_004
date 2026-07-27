"use client";

import { CalendarIcon, PencilIcon, TemplatesIcon } from "@/components/admin/admin-icons";
import {
  AdminBadge,
  AdminCard,
  AdminIconTile,
  AdminSelectField,
  AdminStateCard,
} from "@/components/admin/admin-primitives";
import { TemplateSecureMedia } from "@/components/templates/template-secure-media";
import {
  isVideoTemplate,
  safeDisplayText,
} from "@/components/templates/templates-daily-featured-page.helpers";
import styles from "@/components/templates/templates-daily-featured-page.module.css";
import { AssignmentSummary } from "@/components/templates/templates-daily-featured-page.schedule";
import type {
  AutoPickSettingsCardProps,
  CurrentAssignmentCardProps,
  FeaturedPreviewCardProps,
  TemplateAssignmentEditorCardProps,
} from "@/components/templates/templates-daily-featured-page.types";
import { Button } from "@/components/ui/button";

export function CurrentAssignmentCard({ current, text, locale }: CurrentAssignmentCardProps) {
  return (
    <AdminCard title={text.current}>
      {current ? (
        <AssignmentSummary assignment={current} text={text} locale={locale} />
      ) : (
        <AdminStateCard title={text.noCurrent} description={text.noCurrentDescription} />
      )}
    </AdminCard>
  );
}

export function AutoPickSettingsCard({
  text,
  autoPick,
  canManageTemplates,
  isActionLocked,
  isSettingsReady,
  settingsLoadError,
  isAutoPickSettingsDirty,
  isExcludeRecentDaysInvalid,
  isAutoPickDateMissing,
  isAutoPickRunAvailable,
  onAutoModeEnabledChange,
  onAllowedTypesChange,
  onExcludeRecentDaysChange,
  onDateChange,
  onSaveSettings,
  onRetrySettings,
  onRunAutoPick,
}: AutoPickSettingsCardProps) {
  return (
    <AdminCard title={text.autoPick} description={text.autoPickDescription}>
      {!isSettingsReady ? (
        <AdminStateCard
          tone={settingsLoadError ? "warning" : "info"}
          description={settingsLoadError ? text.autoPickSettingsUnavailable : text.loading}
          action={
            settingsLoadError ? (
              <Button
                type="button"
                variant="secondary"
                disabled={!canManageTemplates || isActionLocked}
                onClick={onRetrySettings}
              >
                {text.retry}
              </Button>
            ) : undefined
          }
        />
      ) : (
        <div className={styles.autoPickWorkspace}>
          <fieldset
            className={styles.autoPickFieldset}
            disabled={!canManageTemplates || isActionLocked}
          >
            <legend className={styles.sectionLabel}>{text.autoModeSettings}</legend>
            <div className={styles.autoPickStatusRow}>
              <div className={styles.assignmentSummary}>
                <strong>{text.autoModeStatus}</strong>
                <span>
                  {autoPick.autoModeEnabled ? text.autoModeEnabled : text.autoModeDisabled}
                </span>
              </div>
              <label className={`${styles.checkboxField} ${styles.autoModeToggle}`}>
                <input
                  type="checkbox"
                  checked={autoPick.autoModeEnabled}
                  onChange={(event) => onAutoModeEnabledChange(event.target.checked)}
                />
                <span>{text.autoMode}</span>
              </label>
            </div>
            <div className={styles.compactGrid}>
              <AdminSelectField
                label={text.allowedTypes}
                value={autoPick.allowedTypes}
                disabled={!canManageTemplates || isActionLocked}
                onChange={(value) =>
                  onAllowedTypesChange(
                    value as AutoPickSettingsCardProps["autoPick"]["allowedTypes"]
                  )
                }
                options={[
                  { value: "both", label: text.allowedBoth },
                  { value: "image", label: text.image },
                  { value: "video", label: text.video },
                ]}
              />
              <label className={styles.field}>
                <span>{text.excludeRecent}</span>
                <input
                  className={styles.control}
                  type="number"
                  min={0}
                  max={365}
                  step={1}
                  inputMode="numeric"
                  value={autoPick.excludeRecentDays}
                  aria-invalid={isExcludeRecentDaysInvalid || undefined}
                  aria-describedby={
                    isExcludeRecentDaysInvalid
                      ? "daily-featured-exclude-recent-validation"
                      : undefined
                  }
                  onChange={(event) => onExcludeRecentDaysChange(event.target.value)}
                />
              </label>
            </div>
            {isExcludeRecentDaysInvalid ? (
              <div id="daily-featured-exclude-recent-validation">
                <AdminStateCard tone="warning" description={text.excludeRecentDaysInvalid} />
              </div>
            ) : null}
            <div className={styles.actionRow}>
              <Button
                type="button"
                variant="secondary"
                onClick={onSaveSettings}
                disabled={
                  !canManageTemplates ||
                  isActionLocked ||
                  !isAutoPickSettingsDirty ||
                  isExcludeRecentDaysInvalid
                }
              >
                {text.autoModeSave}
              </Button>
            </div>
          </fieldset>

          <section className={styles.autoPickRun} aria-labelledby="daily-featured-auto-pick-run">
            <div className={styles.autoPickRunHeader}>
              <strong id="daily-featured-auto-pick-run">{text.autoPickRunSection}</strong>
              <p>{text.autoPickRunDescription}</p>
            </div>
            <label className={styles.field}>
              <span>{text.autoPickDate}</span>
              <input
                className={styles.control}
                type="date"
                required
                value={autoPick.date}
                disabled={!canManageTemplates || isActionLocked}
                onChange={(event) => onDateChange(event.target.value)}
              />
            </label>
            {isAutoPickDateMissing ? (
              <AdminStateCard tone="warning" description={text.autoPickDateRequired} />
            ) : null}
            {!isAutoPickRunAvailable ? (
              <AdminStateCard tone="info" description={text.autoPickRequiresSavedSettings} />
            ) : null}
            <div className={styles.actionRow}>
              <Button
                type="button"
                variant="primary"
                onClick={onRunAutoPick}
                disabled={
                  !canManageTemplates ||
                  isActionLocked ||
                  isAutoPickDateMissing ||
                  isExcludeRecentDaysInvalid ||
                  !isAutoPickRunAvailable
                }
              >
                <CalendarIcon className={styles.buttonIcon} />
                {text.autoPickRun}
              </Button>
            </div>
          </section>
        </div>
      )}
    </AdminCard>
  );
}

export function TemplateAssignmentEditorCard({
  text,
  canManageTemplates,
  isActionLocked,
  search,
  templateTypeFilter,
  templateAccessFilter,
  form,
  templateOptions,
  isTemplateOptionsLoading,
  hasTemplateOptions,
  templateOptionsError,
  dateOccupiedWarning,
  invalidDateRangeWarning,
  isStartDateMissing,
  isPriorityInvalid,
  onSearchChange,
  onTemplateTypeFilterChange,
  onTemplateAccessFilterChange,
  onTemplateChange,
  onRetryTemplateOptions,
  onFormChange,
  onReset,
  onSubmit,
}: TemplateAssignmentEditorCardProps) {
  const dateValidationId = "daily-featured-date-validation";
  const priorityValidationId = "daily-featured-priority-validation";
  const hasDateValidationError =
    dateOccupiedWarning || invalidDateRangeWarning || isStartDateMissing;
  const isEditingAutoAssignment = Boolean(form.id && !form.isManual);

  return (
    <AdminCard
      title={isEditingAutoAssignment ? text.editAutoAssignment : text.form}
      description={
        canManageTemplates
          ? isEditingAutoAssignment
            ? text.editAutoAssignmentDescription
            : text.formDescription
          : text.formAdminOnly
      }
    >
      <form onSubmit={onSubmit} className={styles.form} aria-busy={isActionLocked}>
        <label className={styles.field}>
          <span>{text.templateSearch}</span>
          <input
            className={styles.control}
            value={search}
            maxLength={80}
            placeholder={text.templateSearchPlaceholder}
            disabled={!canManageTemplates || isActionLocked}
            onChange={(event) => onSearchChange(event.target.value.slice(0, 80))}
          />
        </label>
        <div className={styles.compactGrid}>
          <AdminSelectField
            label={text.templateTypeFilter}
            value={templateTypeFilter}
            disabled={!canManageTemplates || isActionLocked}
            onChange={(value) => onTemplateTypeFilterChange(value as typeof templateTypeFilter)}
            options={[
              { value: "", label: text.allTemplateTypes },
              { value: "Image", label: text.image },
              { value: "Video", label: text.video },
            ]}
          />
          <AdminSelectField
            label={text.templateAccessFilter}
            value={templateAccessFilter}
            disabled={!canManageTemplates || isActionLocked}
            onChange={(value) => onTemplateAccessFilterChange(value as typeof templateAccessFilter)}
            options={[
              { value: "", label: text.allAccessLevels },
              { value: "free", label: text.free },
              { value: "premium", label: text.premium },
            ]}
          />
          <div className={styles.inlineStatus}>{text.activeTemplatesOnly}</div>
        </div>
        <label className={styles.field}>
          <span>{text.template}</span>
          <select
            className={styles.control}
            value={form.templateId}
            disabled={!canManageTemplates || isActionLocked}
            onChange={(event) => onTemplateChange(event.target.value)}
          >
            <option value="">
              {isTemplateOptionsLoading ? text.loadingTemplates : text.selectTemplate}
            </option>
            {templateOptions.map((template) => (
              <option key={template.templateId} value={template.templateId}>
                {safeDisplayText(template.title, 120)} ·{" "}
                {safeDisplayText(template.templateType, 32)} ·{" "}
                {safeDisplayText(template.category, 72)} ·{" "}
                {template.isPremium ? text.premium : text.free}
              </option>
            ))}
          </select>
        </label>
        {templateOptionsError ? (
          <AdminStateCard
            tone="warning"
            description={templateOptionsError}
            action={
              <Button
                type="button"
                variant="secondary"
                disabled={!canManageTemplates || isActionLocked}
                onClick={onRetryTemplateOptions}
              >
                {text.retry}
              </Button>
            }
          />
        ) : null}
        {!isTemplateOptionsLoading && !hasTemplateOptions ? (
          <AdminStateCard tone="info" description={text.noTemplates} />
        ) : null}
        {hasDateValidationError ? (
          <div id={dateValidationId}>
            {isStartDateMissing ? (
              <AdminStateCard tone="danger" description={text.startDateRequired} />
            ) : null}
            {dateOccupiedWarning ? (
              <AdminStateCard tone="warning" description={text.dateOccupiedWarning} />
            ) : null}
            {invalidDateRangeWarning ? (
              <AdminStateCard tone="danger" description={text.invalidDateRangeWarning} />
            ) : null}
          </div>
        ) : null}
        <div className={styles.compactGrid}>
          <label className={styles.field}>
            <span>{text.startDate}</span>
            <input
              className={styles.control}
              type="date"
              required
              value={form.startDate}
              aria-invalid={hasDateValidationError || undefined}
              aria-describedby={hasDateValidationError ? dateValidationId : undefined}
              disabled={!canManageTemplates || isActionLocked}
              onChange={(event) => onFormChange({ startDate: event.target.value })}
            />
          </label>
          <label className={styles.field}>
            <span>{text.endDate}</span>
            <input
              className={styles.control}
              type="date"
              value={form.endDate}
              aria-invalid={hasDateValidationError || undefined}
              aria-describedby={hasDateValidationError ? dateValidationId : undefined}
              disabled={!canManageTemplates || isActionLocked}
              onChange={(event) => onFormChange({ endDate: event.target.value })}
            />
          </label>
          <label className={styles.field}>
            <span>{text.priority}</span>
            <input
              className={styles.control}
              type="number"
              step={1}
              inputMode="numeric"
              value={form.priority}
              aria-invalid={isPriorityInvalid || undefined}
              aria-describedby={isPriorityInvalid ? priorityValidationId : undefined}
              disabled={!canManageTemplates || isActionLocked}
              onChange={(event) => onFormChange({ priority: event.target.value })}
            />
          </label>
          <label className={styles.checkboxField}>
            <input
              type="checkbox"
              checked={form.isActive}
              disabled={!canManageTemplates || isActionLocked}
              onChange={(event) => onFormChange({ isActive: event.target.checked })}
            />
            <span>{text.active}</span>
          </label>
        </div>
        {isPriorityInvalid ? (
          <div id={priorityValidationId}>
            <AdminStateCard tone="danger" description={text.priorityInvalid} />
          </div>
        ) : null}
        <label className={styles.field}>
          <span>{text.titleOverride}</span>
          <input
            className={styles.control}
            value={form.titleOverride}
            maxLength={120}
            disabled={!canManageTemplates || isActionLocked}
            onChange={(event) =>
              onFormChange({
                titleOverride: event.target.value.slice(0, 120),
              })
            }
          />
        </label>
        <label className={styles.field}>
          <span>{text.subtitleOverride}</span>
          <textarea
            className={`${styles.control} ${styles.textarea}`}
            value={form.subtitleOverride}
            maxLength={240}
            disabled={!canManageTemplates || isActionLocked}
            onChange={(event) =>
              onFormChange({
                subtitleOverride: event.target.value.slice(0, 240),
              })
            }
          />
        </label>
        <label className={styles.field}>
          <span>{text.badgeOverride}</span>
          <input
            className={styles.control}
            value={form.badgeTextOverride}
            maxLength={64}
            disabled={!canManageTemplates || isActionLocked}
            onChange={(event) =>
              onFormChange({
                badgeTextOverride: event.target.value.slice(0, 64),
              })
            }
          />
        </label>
        <div className={styles.actionRow}>
          <Button
            type="submit"
            variant="primary"
            disabled={
              !canManageTemplates ||
              isActionLocked ||
              !form.templateId ||
              isStartDateMissing ||
              invalidDateRangeWarning ||
              dateOccupiedWarning ||
              isPriorityInvalid
            }
          >
            <PencilIcon className={styles.buttonIcon} />
            {form.id ? text.save : text.create}
          </Button>
          <Button
            type="button"
            variant="secondary"
            onClick={onReset}
            disabled={!canManageTemplates || isActionLocked}
          >
            {text.reset}
          </Button>
        </div>
      </form>
    </AdminCard>
  );
}

export function FeaturedPreviewCard({
  text,
  selectedTemplateSnapshot,
  previewTitle,
  previewSubtitle,
  previewBadge,
  previewType,
  previewMediaUrl,
}: FeaturedPreviewCardProps) {
  return (
    <AdminCard title={text.preview}>
      <div className={styles.previewCard}>
        {previewMediaUrl ? (
          <TemplateSecureMedia
            url={previewMediaUrl}
            kind={isVideoTemplate(previewType) ? "video" : "image"}
            alt={previewTitle}
            muted
            playsInline
            controls={isVideoTemplate(previewType)}
            className={styles.previewMedia}
            logContext={{
              templateId: selectedTemplateSnapshot?.templateId,
              contentType: selectedTemplateSnapshot?.previewAsset?.contentType,
              surface: "daily-featured-preview",
            }}
          />
        ) : (
          <div className={styles.previewEmpty}>
            <AdminIconTile icon={<TemplatesIcon />} tone="info" />
          </div>
        )}
        <div className={styles.previewOverlay}>
          <span className={styles.previewBadge}>
            <AdminBadge tone="success">{previewBadge}</AdminBadge>
          </span>
          <h3>{previewTitle || text.previewEmptyTitle}</h3>
          <p>{previewSubtitle || text.previewEmptySubtitle}</p>
        </div>
      </div>
    </AdminCard>
  );
}
