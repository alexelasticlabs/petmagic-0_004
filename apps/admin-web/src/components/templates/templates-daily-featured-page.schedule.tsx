"use client";

import { AdminBadge, AdminCard, adminTableStyles } from "@/components/admin/admin-primitives";
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
  schedule,
  canManageTemplates,
  isActionLocked,
  onEditAssignment,
  onRequestDeleteAssignment,
}: TemplateScheduleCardProps) {
  return (
    <AdminCard title={text.schedule}>
      {schedule.length === 0 ? null : (
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
                  <td>{formatDateRange(assignment)}</td>
                  <td>
                    <AdminBadge tone={statusTone(assignment)}>
                      {assignment.isManual ? text.manual : text.auto}
                    </AdminBadge>
                  </td>
                  <td>{assignment.isActive ? text.active : text.inactive}</td>
                  <td>{assignment.priority}</td>
                  <td>
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
}: {
  assignment: AdminTemplateOfTheDay;
  text: CurrentAssignmentCardProps["text"];
}) {
  return (
    <div className={styles.assignmentSummary}>
      <strong>{safeDisplayText(assignment.templateTitle, 120)}</strong>
      <span>
        {formatDateRange(assignment)} · {safeDisplayText(assignment.templateType, 32)} ·{" "}
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
