"use client";

import {
  AdminBadge,
  AdminCard,
  AdminStateCard,
  adminTableStyles,
} from "@/components/admin/admin-primitives";
import {
  formatDateRange,
  safeDisplayText,
  statusTone,
} from "@/components/templates/templates-daily-featured-page.helpers";
import styles from "@/components/templates/templates-daily-featured-page.module.css";
import type {
  CurrentAssignmentCardProps,
  TemplateScheduleCardProps,
} from "@/components/templates/templates-daily-featured-page.types";
import { Button } from "@/components/ui/button";
import type { AdminTemplateOfTheDay } from "@/lib/api-client";

export function TemplateScheduleCard({
  text,
  locale,
  schedule,
  schedulePage,
  schedulePageSize,
  scheduleTotalCount,
  scheduleHasMore,
  canManageTemplates,
  isActionLocked,
  isScheduleNavigationLocked,
  onEditAssignment,
  onRequestDeleteAssignment,
  onPreviousPage,
  onNextPage,
}: TemplateScheduleCardProps) {
  const totalSchedulePages = Math.max(
    1,
    Math.ceil(scheduleTotalCount / Math.max(schedulePageSize, 1))
  );
  const visibleSchedulePage = Math.min(schedulePage + 1, totalSchedulePages);
  const showSchedulePager = scheduleTotalCount > schedulePageSize;

  return (
    <AdminCard
      title={text.schedule}
      description={text.scheduleCount(scheduleTotalCount)}
      action={
        showSchedulePager ? (
          <div className={styles.schedulePager} aria-label={text.schedulePaginationLabel}>
            <span className={styles.schedulePageInfo} aria-live="polite">
              {text.schedulePage(visibleSchedulePage, totalSchedulePages)}
            </span>
            <Button
              type="button"
              variant="secondary"
              size="sm"
              disabled={
                !canManageTemplates ||
                isActionLocked ||
                isScheduleNavigationLocked ||
                schedulePage === 0
              }
              onClick={onPreviousPage}
            >
              {text.previousPage}
            </Button>
            <Button
              type="button"
              variant="secondary"
              size="sm"
              disabled={
                !canManageTemplates ||
                isActionLocked ||
                isScheduleNavigationLocked ||
                !scheduleHasMore
              }
              onClick={onNextPage}
            >
              {text.nextPage}
            </Button>
          </div>
        ) : undefined
      }
    >
      {schedule.length === 0 ? (
        <AdminStateCard tone="info" description={text.noSchedule} />
      ) : (
        <div className={adminTableStyles.tableWrap}>
          <table className={`${adminTableStyles.table} ${styles.scheduleTable}`}>
            <thead>
              <tr>
                <th>{text.template}</th>
                <th>{text.date}</th>
                <th>{text.mode}</th>
                <th>{text.status}</th>
                <th>{text.priority}</th>
                <th>{text.actions}</th>
              </tr>
            </thead>
            <tbody>
              {schedule.map((assignment) => (
                <tr key={assignment.id}>
                  <td>
                    <strong className={styles.templateTitle}>
                      {safeDisplayText(assignment.templateTitle, 120)}
                    </strong>
                    <span className={styles.templateMeta}>
                      {safeDisplayText(assignment.templateType, 32)} ·{" "}
                      {safeDisplayText(assignment.category, 72)} ·{" "}
                      {assignment.isPremium ? text.premium : text.free}
                    </span>
                  </td>
                  <td data-label={text.date}>{formatDateRange(assignment, locale)}</td>
                  <td data-label={text.mode}>
                    <AdminBadge tone={statusTone(assignment)}>
                      {assignment.isManual ? text.manual : text.auto}
                    </AdminBadge>
                  </td>
                  <td data-label={text.status}>
                    {assignment.isActive ? text.active : text.inactive}
                  </td>
                  <td data-label={text.priority}>{assignment.priority}</td>
                  <td data-label={text.actions}>
                    <div className={styles.tableActions}>
                      <Button
                        type="button"
                        size="sm"
                        variant="secondary"
                        disabled={!canManageTemplates || isActionLocked}
                        aria-label={text.editAssignmentLabel(
                          safeDisplayText(assignment.templateTitle, 80)
                        )}
                        title={text.editAssignmentLabel(
                          safeDisplayText(assignment.templateTitle, 80)
                        )}
                        onClick={() => onEditAssignment(assignment)}
                      >
                        {text.edit}
                      </Button>
                      <Button
                        type="button"
                        size="sm"
                        variant="danger"
                        disabled={!canManageTemplates || isActionLocked}
                        aria-label={text.deleteAssignmentLabel(
                          safeDisplayText(assignment.templateTitle, 80)
                        )}
                        title={text.deleteAssignmentLabel(
                          safeDisplayText(assignment.templateTitle, 80)
                        )}
                        onClick={() => onRequestDeleteAssignment(assignment)}
                      >
                        {text.delete}
                      </Button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </AdminCard>
  );
}

export function AssignmentSummary({
  assignment,
  text,
  locale,
}: {
  assignment: AdminTemplateOfTheDay;
  text: CurrentAssignmentCardProps["text"];
  locale: CurrentAssignmentCardProps["locale"];
}) {
  return (
    <div className={styles.assignmentSummary}>
      <strong>{safeDisplayText(assignment.templateTitle, 120)}</strong>
      <span>
        {formatDateRange(assignment, locale)} · {safeDisplayText(assignment.templateType, 32)} ·{" "}
        {safeDisplayText(assignment.category, 72)}
      </span>
      <span>
        <AdminBadge tone={statusTone(assignment)}>
          {assignment.isManual ? text.manual : text.auto}
        </AdminBadge>{" "}
        {assignment.isPremium ? text.premium : text.free}
      </span>
      {assignment.titleOverride ? (
        <span>
          {text.titleLabel}: {safeDisplayText(assignment.titleOverride, 120)}
        </span>
      ) : null}
      {assignment.subtitleOverride ? (
        <span>
          {text.subtitleLabel}: {safeDisplayText(assignment.subtitleOverride, 220)}
        </span>
      ) : null}
      {assignment.badgeTextOverride ? (
        <span>
          {text.badgeLabel}: {safeDisplayText(assignment.badgeTextOverride, 64)}
        </span>
      ) : null}
    </div>
  );
}
