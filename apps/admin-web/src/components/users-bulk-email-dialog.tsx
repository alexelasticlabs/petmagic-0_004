"use client";

import { useMemo, useRef, useState } from "react";

import { MailIcon, UsersIcon } from "@/components/admin/admin-icons";
import { ConfirmationDialog } from "@/components/admin/confirmation-dialog";
import { getEmailBroadcastComposerText } from "@/components/email-broadcast-composer.content";
import { EmailRecipientPicker } from "@/components/email-recipient-picker";
import { Button } from "@/components/ui/button";
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
  const text = getEmailBroadcastComposerText(locale);
  const [previewDevice, setPreviewDevice] = useState<"desktop" | "mobile">("desktop");
  const [discardOpen, setDiscardOpen] = useState(false);
  const [recipientIds, setRecipientIds] = useState(selectedUserIds);
  const normalizedSelectedUserIds = useMemo(
    () => [...new Set(recipientIds.map((userId) => userId.trim()).filter(Boolean))],
    [recipientIds]
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
      if (subject || body || JSON.stringify(recipientIds) !== JSON.stringify(selectedUserIds))
        setDiscardOpen(true);
      else onClose();
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
    } catch (queueError) {
      setError(getAdminErrorMessage(queueError, copy.error));
    } finally {
      setIsSubmitting(false);
    }
  }

  const reviewDialog =
    stage === "review" ? (
      <ConfirmationDialog
        size="large"
        stickyActions
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
    ) : null;

  return (
    <section className={styles.composer} aria-labelledby="email-composer-title">
      <div className={styles.composerHeader}>
        <div>
          <Button variant="ghost" size="sm" className={styles.back} onClick={closeDialog}>
            <span aria-hidden="true">←</span> {text.back}
          </Button>
          <h2 id="email-composer-title">{text.title}</h2>
        </div>
        <div className={styles.headerActions}>
          <Button onClick={closeDialog}>{copy.cancel}</Button>
          <Button variant="primary" disabled={!canReview} onClick={() => setStage("review")}>
            {text.review}
            <span aria-hidden="true">→</span>
          </Button>
        </div>
      </div>
      <ol className={styles.steps} aria-label={text.title}>
        {[copy.audienceLabel, text.letter, text.check].map((label, index) => (
          <li
            key={label}
            data-complete={
              index === 0
                ? isSelectedAudienceValid
                : index === 1
                  ? Boolean(normalizedSubject && normalizedBody)
                  : stage === "review"
            }
          >
            <span>{index + 1}</span>
            {label}
          </li>
        ))}
      </ol>
      <div className={styles.composerGrid}>
        <div className={styles.dialogBody}>
          <header className={styles.sectionHeading}>
            <UsersIcon />
            <div>
              <h3>{text.recipients}</h3>
              <p>{text.audienceHint}</p>
            </div>
          </header>
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

          {audience === "selected" ? (
            <EmailRecipientPicker
              locale={locale}
              selectedIds={normalizedSelectedUserIds}
              onChange={(ids) => {
                markCampaignPayloadChanged();
                setRecipientIds(ids);
              }}
            />
          ) : null}

          <header className={styles.sectionHeading + " " + styles.contentHeading}>
            <MailIcon />
            <div>
              <h3>{text.content}</h3>
              <p>{text.contentHint}</p>
            </div>
          </header>
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
            {text.eligible}
          </p>

          <label className={styles.policyRow}>
            <input
              type="checkbox"
              checked={policyConfirmed}
              onChange={(event) => setPolicyConfirmed(event.target.checked)}
            />
            <span>{copy.policyConfirmation}</span>
          </label>
          <div className={styles.editorActions}>
            <Button variant="primary" disabled={!canReview} onClick={() => setStage("review")}>
              {text.review}
              <span aria-hidden="true">→</span>
            </Button>
          </div>
        </div>
        <aside className={styles.preview} aria-label={text.preview}>
          <header className={styles.previewToolbar}>
            <h3>{text.preview}</h3>
            <div className={styles.deviceSwitch} role="group" aria-label={text.preview}>
              {(["desktop", "mobile"] as const).map((device) => (
                <button
                  key={device}
                  type="button"
                  aria-pressed={previewDevice === device}
                  onClick={() => setPreviewDevice(device)}
                >
                  {text[device]}
                </button>
              ))}
            </div>
          </header>
          <div className={styles.previewCanvas}>
            <article className={styles.mailSheet} data-device={previewDevice}>
              <header className={styles.mailHeader}>
                <span className={styles.mailAvatar}>
                  <MailIcon />
                </span>
                <div>
                  <strong>PetMagic</strong>
                  <span>
                    {text.to}: {audienceLabel}
                  </span>
                </div>
              </header>
              <h4 className={!normalizedSubject ? styles.placeholder : undefined}>
                {normalizedSubject || text.subjectEmpty}
              </h4>
              <p className={[styles.mailBody, !normalizedBody ? styles.placeholder : ""].join(" ")}>
                {normalizedBody || text.bodyEmpty}
              </p>
            </article>
          </div>
          <p className={styles.previewHint}>{text.previewHint}</p>
          <div className={styles.readiness} data-ready={canReview}>
            <span className={styles.readinessDot} />
            {canReview ? text.ready : text.incomplete}
          </div>
        </aside>
      </div>
      {reviewDialog}
      <ConfirmationDialog
        open={discardOpen}
        title={text.discardTitle}
        description={text.discardDescription}
        confirmLabel={text.discard}
        cancelLabel={text.keepEditing}
        tone="danger"
        onCancel={() => setDiscardOpen(false)}
        onConfirm={onClose}
      />
    </section>
  );
}
