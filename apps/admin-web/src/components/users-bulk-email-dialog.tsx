"use client";

import { useMemo, useRef, useState } from "react";

import { ConfirmationDialog } from "@/components/admin/confirmation-dialog";
import styles from "@/components/users-bulk-email-dialog.module.css";
import { getUsersManagementPageText } from "@/components/users-management-page.content";
import { createAdminCorrelationId } from "@/lib/admin-correlation-id";
import { getAdminErrorMessage } from "@/lib/admin-error-message";
import {
  ADMIN_BULK_EMAIL_BODY_MAX_LENGTH,
  ADMIN_BULK_EMAIL_SUBJECT_MAX_LENGTH,
  queueAdminBulkEmail,
  type AdminBulkEmailAudience,
  type AdminEmailBroadcastAccepted,
} from "@/lib/api-client";
import type { Locale } from "@/lib/i18n";

type UsersBulkEmailDialogProps = {
  locale: Locale;
  selectedUserIds: readonly string[];
  onClose: () => void;
  onQueued: (broadcast: AdminEmailBroadcastAccepted) => void;
};

type DialogStage = "compose" | "review";

export function UsersBulkEmailDialog({
  locale,
  selectedUserIds,
  onClose,
  onQueued,
}: UsersBulkEmailDialogProps) {
  const copy = useMemo(() => getUsersManagementPageText(locale).bulkEmail, [locale]);
  const normalizedSelectedUserIds = useMemo(
    () => [...new Set(selectedUserIds.map((userId) => userId.trim()).filter(Boolean))],
    [selectedUserIds]
  );
  const [stage, setStage] = useState<DialogStage>("compose");
  const [audience, setAudience] = useState<AdminBulkEmailAudience>(
    normalizedSelectedUserIds.length > 0 ? "selected" : "premium"
  );
  const [subject, setSubject] = useState("");
  const [body, setBody] = useState("");
  const [policyConfirmed, setPolicyConfirmed] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const subjectInputRef = useRef<HTMLInputElement>(null);
  const deliveryIdempotencyKeyRef = useRef<string | null>(null);

  const normalizedSubject = subject.trim();
  const normalizedBody = body.trim();
  const isSelectedAudienceValid = audience !== "selected" || normalizedSelectedUserIds.length > 0;
  const canReview =
    normalizedSubject.length > 0 &&
    normalizedSubject.length <= ADMIN_BULK_EMAIL_SUBJECT_MAX_LENGTH &&
    normalizedBody.length > 0 &&
    normalizedBody.length <= ADMIN_BULK_EMAIL_BODY_MAX_LENGTH &&
    isSelectedAudienceValid &&
    policyConfirmed;

  const audienceLabel =
    audience === "all-active"
      ? copy.audienceAllActive
      : audience === "premium"
        ? copy.audiencePremium
        : `${copy.audienceSelected} (${normalizedSelectedUserIds.length})`;

  function closeDialog() {
    if (!isSubmitting) {
      onClose();
    }
  }

  function markCampaignPayloadChanged() {
    deliveryIdempotencyKeyRef.current = null;
    setError(null);
  }

  async function queueDelivery() {
    if (!canReview || isSubmitting) {
      return;
    }

    setIsSubmitting(true);
    setError(null);
    const idempotencyKey =
      deliveryIdempotencyKeyRef.current ?? `bulk-email:${createAdminCorrelationId()}`;
    deliveryIdempotencyKeyRef.current = idempotencyKey;

    try {
      const broadcast = await queueAdminBulkEmail(
        {
          audience,
          subject: normalizedSubject,
          body: normalizedBody,
          userIds: audience === "selected" ? normalizedSelectedUserIds : [],
        },
        idempotencyKey
      );
      onQueued(broadcast);
      onClose();
    } catch (queueError) {
      setError(getAdminErrorMessage(queueError, copy.error));
    } finally {
      setIsSubmitting(false);
    }
  }

  if (stage === "review") {
    return (
      <ConfirmationDialog
        open
        title={copy.reviewTitle}
        description={copy.reviewDescription}
        confirmLabel={copy.queueAction}
        cancelLabel={copy.cancel}
        confirmDisabled={!canReview}
        isSubmitting={isSubmitting}
        tone="primary"
        onCancel={() => {
          if (!isSubmitting) {
            setError(null);
            setStage("compose");
          }
        }}
        onConfirm={() => void queueDelivery()}
      >
        <dl className={styles.reviewGrid}>
          <div className={styles.reviewRow}>
            <dt>{copy.reviewAudienceLabel}</dt>
            <dd>{audienceLabel}</dd>
          </div>
          <div className={styles.reviewRow}>
            <dt>{copy.reviewSubjectLabel}</dt>
            <dd>{normalizedSubject}</dd>
          </div>
          <div className={styles.reviewRow}>
            <dt>{copy.reviewBodyLabel}</dt>
            <dd className={styles.reviewBody}>{normalizedBody}</dd>
          </div>
        </dl>
        {error ? (
          <p className={styles.error} role="alert">
            {error}
          </p>
        ) : null}
      </ConfirmationDialog>
    );
  }

  return (
    <ConfirmationDialog
      open
      title={copy.composerTitle}
      description={copy.composerDescription}
      confirmLabel={copy.reviewAction}
      cancelLabel={copy.cancel}
      confirmDisabled={!canReview}
      initialFocusRef={subjectInputRef}
      tone="primary"
      onCancel={closeDialog}
      onConfirm={() => {
        if (canReview) {
          setError(null);
          setStage("review");
        }
      }}
    >
      <div className={styles.dialogBody}>
        <fieldset className={styles.audienceFieldset}>
          <legend>{copy.audienceLabel}</legend>
          <div className={styles.audienceGrid}>
            <label className={styles.audienceCard}>
              <input
                type="radio"
                name="bulk-email-audience"
                value="premium"
                checked={audience === "premium"}
                onChange={() => {
                  markCampaignPayloadChanged();
                  setAudience("premium");
                }}
              />
              <span>
                <strong>{copy.audiencePremium}</strong>
                <small>{copy.audiencePremiumHint}</small>
              </span>
            </label>
            <label className={styles.audienceCard}>
              <input
                type="radio"
                name="bulk-email-audience"
                value="selected"
                checked={audience === "selected"}
                disabled={normalizedSelectedUserIds.length === 0}
                onChange={() => {
                  markCampaignPayloadChanged();
                  setAudience("selected");
                }}
              />
              <span>
                <strong>{copy.audienceSelected}</strong>
                <small>
                  {normalizedSelectedUserIds.length > 0
                    ? copy.audienceSelectedHint(normalizedSelectedUserIds.length)
                    : copy.noSelectedUsers}
                </small>
              </span>
            </label>
            <label className={styles.audienceCard}>
              <input
                type="radio"
                name="bulk-email-audience"
                value="all-active"
                checked={audience === "all-active"}
                onChange={() => {
                  markCampaignPayloadChanged();
                  setAudience("all-active");
                }}
              />
              <span>
                <strong>{copy.audienceAllActive}</strong>
                <small>{copy.audienceAllActiveHint}</small>
              </span>
            </label>
          </div>
        </fieldset>

        <label className={styles.field}>
          <span>{copy.subjectLabel}</span>
          <input
            ref={subjectInputRef}
            value={subject}
            maxLength={ADMIN_BULK_EMAIL_SUBJECT_MAX_LENGTH}
            placeholder={copy.subjectPlaceholder}
            aria-label={copy.subjectLabel}
            onChange={(event) => {
              markCampaignPayloadChanged();
              setSubject(event.target.value);
            }}
          />
          <small className={styles.counter}>
            {subject.length} / {ADMIN_BULK_EMAIL_SUBJECT_MAX_LENGTH}
          </small>
        </label>

        <label className={styles.field}>
          <span>{copy.bodyLabel}</span>
          <textarea
            value={body}
            rows={8}
            maxLength={ADMIN_BULK_EMAIL_BODY_MAX_LENGTH}
            placeholder={copy.bodyPlaceholder}
            aria-label={copy.bodyLabel}
            onChange={(event) => {
              markCampaignPayloadChanged();
              setBody(event.target.value);
            }}
          />
          <small className={styles.counter}>
            {body.length} / {ADMIN_BULK_EMAIL_BODY_MAX_LENGTH}
          </small>
        </label>

        <p className={styles.warning} role="note">
          {copy.operationalWarning}
        </p>

        <label className={styles.policyRow}>
          <input
            type="checkbox"
            checked={policyConfirmed}
            onChange={(event) => setPolicyConfirmed(event.target.checked)}
          />
          <span>{copy.policyConfirmation}</span>
        </label>
      </div>
    </ConfirmationDialog>
  );
}
