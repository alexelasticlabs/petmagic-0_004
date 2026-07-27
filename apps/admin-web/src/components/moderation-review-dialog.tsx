"use client";

import { useId, useRef } from "react";

import { AdminBadge, AdminStatusBadge } from "@/components/admin/admin-primitives";
import { ConfirmationDialog } from "@/components/admin/confirmation-dialog";
import { type ModerationPageText } from "@/components/moderation-page.content";
import styles from "@/components/moderation-page.module.css";
import {
  MODERATION_DECISION_REASON_MAX_LENGTH,
  type AdminModerationQueueItem,
} from "@/lib/api-client";
import { formatDateTime } from "@/lib/format-date-time";
import { type Locale } from "@/lib/i18n";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

export type ModerationDecisionAction = "approve" | "reject";

type ModerationReviewDialogProps = {
  locale: Locale;
  text: ModerationPageText;
  item: AdminModerationQueueItem | null;
  action: ModerationDecisionAction | null;
  reason: string;
  reasonError: string | null;
  isSubmitting: boolean;
  canModerate: boolean;
  onActionChange: (action: ModerationDecisionAction) => void;
  onReasonChange: (reason: string) => void;
  onCancel: () => void;
  onConfirm: () => void;
};

function statusColor(status: string) {
  if (status === "approved") return "var(--success)";
  if (status === "rejected") return "var(--danger)";
  return "var(--warning)";
}

function formatStatus(item: AdminModerationQueueItem, text: ModerationPageText) {
  if (item.status === "approved") return text.statusApproved;
  if (item.status === "rejected") return text.statusRejected;
  return text.statusPending;
}

function formatEvent(item: AdminModerationQueueItem, text: ModerationPageText) {
  return item.eventType === "complaint" ? text.eventComplaint : text.eventFeedback;
}

function safeText(value: string | null | undefined, fallback = "-", maxLength = 600) {
  return sanitizeSensitiveText(value?.trim() || fallback, maxLength);
}

function shortId(value: string | null | undefined) {
  const safeValue = safeText(value, "-", 64);
  return safeValue === "-" ? safeValue : safeValue.slice(0, 12);
}

export function ModerationReviewDialog({
  locale,
  text,
  item,
  action,
  reason,
  reasonError,
  isSubmitting,
  canModerate,
  onActionChange,
  onReasonChange,
  onCancel,
  onConfirm,
}: ModerationReviewDialogProps) {
  const reasonHintId = useId();
  const reasonErrorId = useId();
  const approveButtonRef = useRef<HTMLButtonElement>(null);
  const normalizedReasonLength = reason.trim().length;
  const isPending = item?.status === "pending";
  const canSubmit = canModerate && isPending && action !== null && normalizedReasonLength >= 3;
  const reasonDescribedBy = reasonError ? `${reasonHintId} ${reasonErrorId}` : reasonHintId;

  return (
    <ConfirmationDialog
      open={Boolean(item)}
      title={text.reviewTitle}
      description={text.reviewDescription}
      confirmLabel={
        action === "approve"
          ? text.confirmApprove
          : action === "reject"
            ? text.confirmReject
            : text.saveDecision
      }
      cancelLabel={text.cancel}
      tone={action === "reject" ? "danger" : "primary"}
      initialFocusRef={approveButtonRef}
      isSubmitting={isSubmitting}
      size="large"
      confirmDisabled={!canSubmit}
      onCancel={onCancel}
      onConfirm={onConfirm}
    >
      {item ? (
        <div className={styles.review}>
          <div className={styles.reviewBadges}>
            <AdminBadge tone={item.eventType === "complaint" ? "danger" : "info"}>
              {formatEvent(item, text)}
            </AdminBadge>
            <AdminStatusBadge color={statusColor(item.status)}>
              {formatStatus(item, text)}
            </AdminStatusBadge>
          </div>

          <section className={styles.reviewSection} aria-labelledby={`${reasonHintId}-context`}>
            <h3 id={`${reasonHintId}-context`} className={styles.reviewSectionTitle}>
              {text.contextTitle}
            </h3>
            <dl className={styles.reviewFacts}>
              <div>
                <dt>{text.template}</dt>
                <dd>{safeText(item.templateTitle, "-", 160)}</dd>
              </div>
              <div>
                <dt>{text.templateId}</dt>
                <dd title={safeText(item.templateId, "-", 80)}>{shortId(item.templateId)}</dd>
              </div>
              <div>
                <dt>{text.created}</dt>
                <dd>{formatDateTime(item.createdAtUtc, locale)}</dd>
              </div>
              <div>
                <dt>{text.source}</dt>
                <dd>{safeText(item.source, "-", 80)}</dd>
              </div>
              <div>
                <dt>{text.device}</dt>
                <dd>{safeText(item.deviceClass, "-", 48)}</dd>
              </div>
              <div>
                <dt>{text.country}</dt>
                <dd>{safeText(item.countryCode, "-", 12)}</dd>
              </div>
              <div>
                <dt>{text.userId}</dt>
                <dd title={safeText(item.userId, "-", 80)}>{shortId(item.userId)}</dd>
              </div>
              <div>
                <dt>{text.generationId}</dt>
                <dd title={safeText(item.generationId, "-", 80)}>{shortId(item.generationId)}</dd>
              </div>
            </dl>
          </section>

          <section className={styles.reviewSection} aria-labelledby={`${reasonHintId}-message`}>
            <h3 id={`${reasonHintId}-message`} className={styles.reviewSectionTitle}>
              {text.message}
            </h3>
            <p className={styles.reviewMessage}>{safeText(item.message, text.noMessage, 1_200)}</p>
          </section>

          <fieldset className={styles.decisionFieldset} disabled={isSubmitting || !isPending}>
            <legend className={styles.reviewSectionTitle}>{text.decisionTitle}</legend>
            <p className={styles.decisionHelp}>{text.decisionHelp}</p>
            <div className={styles.decisionOptions}>
              <button
                ref={approveButtonRef}
                type="button"
                className={`${styles.decisionOption} ${
                  action === "approve" ? styles.decisionOptionSelected : ""
                }`}
                aria-pressed={action === "approve"}
                onClick={() => onActionChange("approve")}
              >
                <span className={styles.decisionOptionTitle}>{text.approve}</span>
                <span>{text.approveHelp}</span>
              </button>
              <button
                type="button"
                className={`${styles.decisionOption} ${styles.decisionOptionDanger} ${
                  action === "reject" ? styles.decisionOptionSelected : ""
                }`}
                aria-pressed={action === "reject"}
                onClick={() => onActionChange("reject")}
              >
                <span className={styles.decisionOptionTitle}>{text.reject}</span>
                <span>{text.rejectHelp}</span>
              </button>
            </div>
          </fieldset>

          <label className={styles.field}>
            <span className={styles.label}>{text.reason}</span>
            <textarea
              className={styles.textarea}
              value={reason}
              onChange={(event) =>
                onReasonChange(event.target.value.slice(0, MODERATION_DECISION_REASON_MAX_LENGTH))
              }
              maxLength={MODERATION_DECISION_REASON_MAX_LENGTH}
              placeholder={text.reasonPlaceholder}
              disabled={isSubmitting || !isPending}
              aria-invalid={Boolean(reasonError)}
              aria-describedby={reasonDescribedBy}
            />
          </label>
          <div className={styles.reasonMeta}>
            <span id={reasonHintId}>{text.reasonHint}</span>
            <span aria-label={text.characterCountLabel}>
              {reason.length}/{MODERATION_DECISION_REASON_MAX_LENGTH}
            </span>
          </div>
          {reasonError ? (
            <p id={reasonErrorId} className={styles.validationError} role="alert">
              {reasonError}
            </p>
          ) : null}

          {item.moderationComment ? (
            <section className={styles.previousDecision}>
              <strong>{text.previousDecision}</strong>
              <span>{safeText(item.moderationComment, "-", 600)}</span>
            </section>
          ) : null}
        </div>
      ) : null}
    </ConfirmationDialog>
  );
}
