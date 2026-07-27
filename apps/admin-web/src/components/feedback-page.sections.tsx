"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import Link from "next/link";
import { useEffect, useRef, useState, type ReactNode } from "react";

import { CancelCircleIcon } from "@/components/admin/admin-icons";
import { AdminCard, AdminStateCard, AdminStatusBadge } from "@/components/admin/admin-primitives";
import { ConfirmationDialog } from "@/components/admin/confirmation-dialog";
import styles from "@/components/feedback-page.module.css";
import { TemplateSecureMedia } from "@/components/templates/template-secure-media";
import { Button } from "@/components/ui/button";
import { Select, type SelectOption } from "@/components/ui/select";
import { getAdminErrorMessage } from "@/lib/admin-error-message";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
  ADMIN_FEEDBACK_ADMIN_NOTE_MAX_LENGTH,
  ADMIN_FEEDBACK_REFUND_REASON_MAX_LENGTH,
  fetchAdminUser,
  fetchAdminUserAnalytics,
  refundAdminFeedbackCredits,
  updateAdminFeedback,
  type AdminFeedbackDetails,
  type AdminFeedbackListItem,
  type FeedbackPriority,
  type FeedbackStatus,
  type FeedbackType,
} from "@/lib/api-client";
import { formatDateTime } from "@/lib/format-date-time";
import { type Locale } from "@/lib/i18n";
import {
  maskEmail,
  sanitizeSensitiveMultilineText,
  sanitizeSensitiveText,
} from "@/lib/sensitive-display";

import { getFeedbackPageText, type FeedbackPageText } from "./feedback-page.content";

export const statusOptions: Array<FeedbackStatus | "All"> = [
  "All",
  "New",
  "InReview",
  "Resolved",
  "Dismissed",
];

export const priorityOptions: Array<FeedbackPriority | "All"> = [
  "All",
  "Low",
  "Medium",
  "High",
  "Critical",
];

export const typeOptions: Array<FeedbackType | "All"> = [
  "All",
  "GenerationResult",
  "GenerationFailure",
  "BugReport",
  "FeatureRequest",
  "PaymentIssue",
  "General",
];

function toneForPriority(priority: string) {
  if (priority === "Critical") return "var(--danger)";
  if (priority === "High") return "var(--warning)";
  if (priority === "Medium") return "var(--info)";
  return "var(--neutral)";
}

function toneForStatus(status: string) {
  if (status === "Resolved") return "var(--success)";
  if (status === "Dismissed") return "var(--neutral)";
  if (status === "InReview") return "var(--info)";
  return "var(--warning)";
}

function toneForRating(rating: number | null | undefined) {
  if (rating === -1) return "var(--danger)";
  if (rating === 1) return "var(--success)";
  return "var(--neutral)";
}

function shortId(value?: string | null) {
  if (!value) return "-";
  const safe = sanitizeSensitiveText(value, 40);
  return safe.length > 14 ? `${safe.slice(0, 8)}...${safe.slice(-4)}` : safe;
}

function optionLabel<T extends string>(labels: Record<T | "All", string>, value?: T | null) {
  if (!value) {
    return "-";
  }

  return labels[value] ?? value;
}

function knownLabel(value: string | null | undefined, labels: Record<string, string>) {
  if (!value) {
    return "-";
  }

  const safe = sanitizeSensitiveText(value, 120);
  return labels[safe] ?? safe.replace(/[_-]+/g, " ");
}

function ratingLabel(value: number | null | undefined, text: FeedbackPageText) {
  if (value === 1) return text.ratingLabels.positive;
  if (value === 0) return text.ratingLabels.neutral;
  if (value === -1) return text.ratingLabels.negative;
  return "-";
}

export function FeedbackSelectField({
  label,
  value,
  options,
  menuMode = "overlay",
  disabled = false,
  onChange,
}: {
  label: string;
  value: string;
  options: readonly SelectOption[];
  menuMode?: "overlay" | "inline";
  disabled?: boolean;
  onChange: (value: string) => void;
}) {
  return (
    <div className={styles.field}>
      <span className={styles.label}>{label}</span>
      <Select
        value={value}
        options={options}
        disabled={disabled}
        ariaLabel={label}
        showSelectedDescription={false}
        menuMode={menuMode}
        onChange={onChange}
      />
    </div>
  );
}

export function FeedbackTextField({
  label,
  value,
  type = "text",
  min,
  max,
  maxLength,
  invalid = false,
  describedBy,
  disabled = false,
  placeholder,
  onChange,
}: {
  label: string;
  value: string;
  type?: "text" | "date";
  min?: string;
  max?: string;
  maxLength?: number;
  invalid?: boolean;
  describedBy?: string;
  disabled?: boolean;
  placeholder?: string;
  onChange: (value: string) => void;
}) {
  return (
    <label className={styles.field}>
      <span className={styles.label}>{label}</span>
      <input
        className={styles.input}
        type={type}
        value={value}
        min={min}
        max={max}
        maxLength={maxLength}
        aria-invalid={invalid || undefined}
        aria-describedby={describedBy}
        disabled={disabled}
        placeholder={placeholder}
        onChange={(event) =>
          onChange(
            typeof maxLength === "number"
              ? event.target.value.slice(0, maxLength)
              : event.target.value
          )
        }
      />
    </label>
  );
}

export function FeedbackQueue({
  disabled,
  isBusy,
  items,
  locale,
  selectedId,
  text,
  onSelect,
}: {
  disabled: boolean;
  isBusy: boolean;
  items: AdminFeedbackListItem[];
  locale: Locale;
  selectedId: string | null;
  text: FeedbackPageText;
  onSelect: (id: string) => void;
}) {
  return (
    <ul className={styles.queue} aria-label={text.queue} aria-busy={isBusy || undefined}>
      {items.map((item) => {
        const isSelected = item.id === selectedId;
        const category = knownLabel(item.category, text.categoryLabels);
        const source = knownLabel(item.sourceScreen, text.sourceLabels);
        const queueMessage = item.message ? sanitizeSensitiveText(item.message, 180) : null;
        const queueTitle = queueMessage ? optionLabel(text.typeOptions, item.type) : category;

        return (
          <li key={item.id}>
            <button
              type="button"
              className={`${styles.queueItem} ${isSelected ? styles.queueItemSelected : ""}`.trim()}
              aria-current={isSelected ? "true" : undefined}
              disabled={disabled}
              onClick={() => onSelect(item.id)}
            >
              <div className={styles.queueItemBody}>
                <div className={styles.queueItemHeader}>
                  <span className={styles.queueItemType}>{queueTitle}</span>
                  <span className={styles.queueItemDate}>
                    {formatDateTime(item.createdAtUtc, locale)}
                  </span>
                </div>
                {queueMessage ? <p className={styles.queueItemMessage}>{queueMessage}</p> : null}
                <div className={styles.queueItemMeta}>
                  {queueMessage ? <span>{category}</span> : null}
                  <span>{source}</span>
                  <span className={styles.mono}>{shortId(item.userId)}</span>
                  {item.templateTitle ? (
                    <span>{sanitizeSensitiveText(item.templateTitle, 80)}</span>
                  ) : null}
                </div>
              </div>
              <div className={styles.queueItemAside}>
                {item.previewUrl ? (
                  <TemplateSecureMedia
                    className={styles.preview}
                    url={item.previewUrl}
                    kind="image"
                    alt=""
                    ariaHidden
                    width={72}
                    height={72}
                    logContext={{ surface: "feedback-list-preview" }}
                  />
                ) : null}
                <div className={styles.queueItemBadges}>
                  {item.rating !== null && item.rating !== undefined ? (
                    <AdminStatusBadge color={toneForRating(item.rating)}>
                      {ratingLabel(item.rating, text)}
                    </AdminStatusBadge>
                  ) : null}
                  <AdminStatusBadge color={toneForStatus(item.status)}>
                    {optionLabel(text.statusOptions, item.status)}
                  </AdminStatusBadge>
                  <AdminStatusBadge color={toneForPriority(item.priority)}>
                    {optionLabel(text.priorityOptions, item.priority)}
                  </AdminStatusBadge>
                </div>
              </div>
            </button>
          </li>
        );
      })}
    </ul>
  );
}

export function DetailsPanel({
  canViewUserProfile,
  details,
  detailsRefreshError,
  isDetailsFetching,
  locale,
  onDismiss,
  onDraftStateChange,
  onNotify,
  onRetryDetails,
  relatedFeedbackActions,
}: {
  canViewUserProfile: boolean;
  details: AdminFeedbackDetails;
  detailsRefreshError: string | null;
  isDetailsFetching: boolean;
  locale: Locale;
  onDismiss: () => void;
  onDraftStateChange: (isDirty: boolean) => void;
  onNotify: (message: string, type: "success" | "error") => void;
  onRetryDetails: () => void;
  relatedFeedbackActions: ReadonlyArray<{
    id: "user" | "generation" | "template";
    label: string;
    onClick: () => void;
  }>;
}) {
  const text = getFeedbackPageText(locale);
  const queryClient = useQueryClient();
  const [status, setStatus] = useState((details.status as FeedbackStatus) || "New");
  const [priority, setPriority] = useState((details.priority as FeedbackPriority) || "Low");
  const [adminNote, setAdminNote] = useState(details.adminNote ?? "");
  const [isNoteExpanded, setIsNoteExpanded] = useState(Boolean(details.adminNote));
  const [isRefundDialogOpen, setIsRefundDialogOpen] = useState(false);
  const refundableCredits =
    typeof details.generation?.creditsCharged === "number" &&
    Number.isFinite(details.generation.creditsCharged)
      ? Math.max(0, Math.trunc(details.generation.creditsCharged))
      : 0;
  const [refundAmountInput, setRefundAmountInput] = useState(String(refundableCredits));
  const [refundReason, setRefundReason] = useState("");
  const refundReasonRef = useRef<HTMLTextAreaElement>(null);
  const refundAmountErrorId = `feedback-refund-amount-error-${details.id}`;
  const refundReasonHintId = `feedback-refund-reason-hint-${details.id}`;
  const refundReasonErrorId = `feedback-refund-reason-error-${details.id}`;
  const updateMutation = useMutation({
    mutationFn: () => updateAdminFeedback(details.id, { status, priority, adminNote }),
    onSuccess: async (updatedDetails) => {
      queryClient.setQueryData<AdminFeedbackDetails>(
        adminQueryKeys.feedbackDetails(updatedDetails.id),
        updatedDetails
      );
      setStatus((updatedDetails.status as FeedbackStatus) || "New");
      setPriority((updatedDetails.priority as FeedbackPriority) || "Low");
      setAdminNote(updatedDetails.adminNote ?? "");
      setIsNoteExpanded(Boolean(updatedDetails.adminNote));
      await queryClient.invalidateQueries({ queryKey: ["admin", "feedback"] });
      onNotify(text.saved, "success");
    },
    onError: (error) => {
      onNotify(getAdminErrorMessage(error, text.error), "error");
    },
  });
  const refundMutation = useMutation({
    mutationFn: (payload: { amount: number; reason: string }) =>
      refundAdminFeedbackCredits(details.id, payload),
    onSuccess: async (refund) => {
      queryClient.setQueryData<AdminFeedbackDetails>(
        adminQueryKeys.feedbackDetails(details.id),
        (cachedDetails) => {
          const currentDetails = cachedDetails ?? details;
          return {
            ...currentDetails,
            status: "Resolved",
            reviewedAtUtc: refund.createdAtUtc,
            reviewedByAdminId: refund.adminId,
            refund,
            refundUnavailableReason: "feedback.refund_already_issued",
            canRefund: false,
            generation: currentDetails.generation
              ? { ...currentDetails.generation, refundedAtUtc: refund.createdAtUtc }
              : currentDetails.generation,
          };
        }
      );
      setStatus("Resolved");
      const invalidations = [
        queryClient.invalidateQueries({ queryKey: ["admin", "feedback"] }),
        queryClient.invalidateQueries({ queryKey: ["admin", "economy", "ledger"] }),
        queryClient.invalidateQueries({ queryKey: adminQueryKeys.economyDashboardMetrics }),
      ];
      if (details.userId) {
        invalidations.push(
          queryClient.invalidateQueries({ queryKey: adminQueryKeys.userDetail(details.userId) }),
          queryClient.invalidateQueries({ queryKey: adminQueryKeys.userAnalytics(details.userId) }),
          queryClient.invalidateQueries({ queryKey: adminQueryKeys.usersRoot }),
          queryClient.invalidateQueries({ queryKey: adminQueryKeys.userDashboardMetrics })
        );
      }

      await Promise.allSettled(invalidations);
      setIsRefundDialogOpen(false);
      setRefundAmountInput(String(refundableCredits));
      setRefundReason("");
      onNotify(text.refundSuccess(refund.amount), "success");
    },
    onError: (error) => {
      onNotify(getAdminErrorMessage(error, text.refundError), "error");
    },
  });
  const isFeedbackActionLocked =
    updateMutation.isPending || refundMutation.isPending || isDetailsFetching;
  const isFeedbackDraftDirty =
    status !== ((details.status as FeedbackStatus) || "New") ||
    priority !== ((details.priority as FeedbackPriority) || "Low") ||
    adminNote !== (details.adminNote ?? "");
  const isSaveFeedbackDisabled = !isFeedbackDraftDirty || isFeedbackActionLocked;
  const parsedRefundAmount = Number(refundAmountInput);
  const isRefundAmountValid =
    /^[1-9]\d*$/.test(refundAmountInput.trim()) &&
    Number.isSafeInteger(parsedRefundAmount) &&
    parsedRefundAmount <= refundableCredits;
  const refundAmount = isRefundAmountValid ? parsedRefundAmount : 0;
  const refundDisabledReason = getRefundDisabledReason({
    canViewUserProfile,
    details,
    refundableCredits,
    text,
  });
  const isRefundFeedbackDisabled = Boolean(refundDisabledReason) || isFeedbackActionLocked;
  const isRefundConfirmationDisabled =
    isRefundFeedbackDisabled || !isRefundAmountValid || !refundReason.trim();
  useEffect(() => {
    onDraftStateChange(isFeedbackDraftDirty);
    return () => onDraftStateChange(false);
  }, [isFeedbackDraftDirty, onDraftStateChange]);

  const resetFeedbackDraft = () => {
    setStatus((details.status as FeedbackStatus) || "New");
    setPriority((details.priority as FeedbackPriority) || "Low");
    setAdminNote(details.adminNote ?? "");
    setIsNoteExpanded(Boolean(details.adminNote));
  };
  const requestSaveFeedback = () => {
    if (isSaveFeedbackDisabled) {
      return;
    }

    updateMutation.mutate();
  };
  const requestRefundFeedback = () => {
    if (isRefundFeedbackDisabled) {
      return;
    }

    setIsRefundDialogOpen(true);
  };
  const requestRefundConfirmation = () => {
    if (isRefundConfirmationDisabled) {
      return;
    }

    refundMutation.mutate({ amount: refundAmount, reason: refundReason.trim() });
  };
  const canLoadUserContext = canViewUserProfile && Boolean(details.userId);
  const shouldFetchUserProfile =
    canLoadUserContext &&
    (!details.userEmail || details.userPlan === null || details.userPlan === undefined);
  const shouldFetchUserAnalytics =
    canLoadUserContext && (details.userCredits === null || details.userCredits === undefined);
  const userQuery = useQuery({
    queryKey: details.userId
      ? adminQueryKeys.userDetail(details.userId)
      : adminQueryKeys.userDetailDisabled,
    queryFn: ({ signal }) => fetchAdminUser(details.userId!, signal),
    enabled: shouldFetchUserProfile,
  });
  const userAnalyticsQuery = useQuery({
    queryKey: details.userId
      ? adminQueryKeys.userAnalytics(details.userId)
      : adminQueryKeys.userAnalyticsDisabled,
    queryFn: ({ signal }) => fetchAdminUserAnalytics(details.userId!, signal),
    enabled: shouldFetchUserAnalytics,
  });
  const userPlan =
    details.userPlan ??
    (userQuery.isLoading
      ? text.userContextLoading
      : userQuery.data
        ? userQuery.data.isPremium
          ? text.userPlanPremium
          : text.userPlanFree
        : "-");
  const userCredits =
    details.userCredits ??
    (userAnalyticsQuery.isLoading
      ? text.userContextLoading
      : (userAnalyticsQuery.data?.summary.walletBalance ?? "-"));
  const hasUserContextError =
    (shouldFetchUserProfile && userQuery.isError) ||
    (shouldFetchUserAnalytics && userAnalyticsQuery.isError);
  const isUserContextFetching =
    (shouldFetchUserProfile && userQuery.isFetching) ||
    (shouldFetchUserAnalytics && userAnalyticsQuery.isFetching);
  const userLabel = details.userEmail
    ? maskEmail(details.userEmail)
    : userQuery.data?.email
      ? maskEmail(userQuery.data.email)
      : shortId(details.userId);
  const requestUserContextRetry = () => {
    const retries: Array<Promise<unknown>> = [];
    if (shouldFetchUserProfile) {
      retries.push(userQuery.refetch());
    }
    if (shouldFetchUserAnalytics) {
      retries.push(userAnalyticsQuery.refetch());
    }

    void Promise.allSettled(retries);
  };
  const technicalDetails = [
    { label: text.category, value: knownLabel(details.category, text.categoryLabels) },
    { label: text.source, value: knownLabel(details.sourceScreen, text.sourceLabels) },
    { label: text.platform, value: details.platform ?? "" },
    { label: text.app, value: details.appVersion ?? "" },
    { label: text.device, value: details.deviceModel ?? "" },
    { label: text.provider, value: details.providerName ?? details.generation?.providerName ?? "" },
    { label: text.errorCode, value: details.errorCode ?? details.generation?.errorCode ?? "" },
    {
      label: text.template,
      value: details.generation?.templateTitle ?? details.generation?.templateId ?? "",
    },
    { label: text.generation, value: details.generation?.generationId ?? "" },
  ].filter((item) => item.value);
  const auditDetails = [
    details.reviewedAtUtc
      ? { label: text.reviewedAt, value: formatDateTime(details.reviewedAtUtc, locale) }
      : null,
    details.refund
      ? {
          label: text.refundAudit(
            details.refund.amount,
            formatDateTime(details.refund.createdAtUtc, locale)
          ),
          value: details.refund.reason,
        }
      : null,
  ].filter((item): item is { label: string; value: string } => Boolean(item));

  return (
    <AdminCard
      title={text.selectedFeedback}
      className={styles.inspectorCard}
      action={
        <div className={styles.inspectorHeaderActions}>
          <span className={styles.inspectorDate}>
            {formatDateTime(details.createdAtUtc, locale)}
          </span>
          <Button variant="ghost" size="sm" onClick={onDismiss}>
            <CancelCircleIcon aria-hidden="true" />
            <span>{text.closeSelection}</span>
          </Button>
        </div>
      }
    >
      <div className={styles.inspector} aria-busy={isDetailsFetching ? "true" : undefined}>
        <div className={styles.inspectorSummary}>
          <strong className={styles.inspectorType}>
            {optionLabel(text.typeOptions, details.type)} ·{" "}
            {knownLabel(details.category, text.categoryLabels)}
          </strong>
        </div>

        {detailsRefreshError ? (
          <div className={styles.detailsRefreshError} role="alert">
            <span>{detailsRefreshError}</span>
            <Button variant="ghost" size="sm" disabled={isDetailsFetching} onClick={onRetryDetails}>
              {text.retry}
            </Button>
          </div>
        ) : null}

        <section className={styles.messagePanel} aria-labelledby={`feedback-message-${details.id}`}>
          <span id={`feedback-message-${details.id}`} className={styles.sectionLabel}>
            {text.message}
          </span>
          <p className={styles.messageText}>
            {details.message
              ? sanitizeSensitiveMultilineText(details.message, 2_000)
              : text.noMessage}
          </p>
        </section>

        <div className={styles.contextGrid}>
          <Detail label={text.user} value={userLabel} />
          <Detail label={text.planCredits} value={`${userPlan} / ${userCredits}`} />
          <Detail label={text.rating} value={ratingLabel(details.rating, text)} />
        </div>

        {(canViewUserProfile && Boolean(details.userId)) || relatedFeedbackActions.length > 0 ? (
          <div className={styles.contextActions} aria-label={text.relatedFeedback}>
            {canViewUserProfile && details.userId ? (
              <Link
                href={`/${locale}/users/${encodeURIComponent(details.userId)}`}
                className={styles.userLink}
              >
                {text.viewUser}
              </Link>
            ) : null}
            {relatedFeedbackActions.map((action) => (
              <Button key={action.id} variant="ghost" size="sm" onClick={action.onClick}>
                {action.label}
              </Button>
            ))}
          </div>
        ) : null}

        {hasUserContextError ? (
          <AdminStateCard
            tone="warning"
            title={text.userContextErrorTitle}
            description={getAdminErrorMessage(
              userQuery.error ?? userAnalyticsQuery.error,
              text.userContextErrorDescription
            )}
            action={
              <Button
                variant="secondary"
                size="sm"
                disabled={isUserContextFetching}
                onClick={requestUserContextRetry}
              >
                {text.retry}
              </Button>
            }
          />
        ) : null}

        <section
          className={styles.decisionPanel}
          aria-labelledby={`feedback-decision-${details.id}`}
        >
          <span id={`feedback-decision-${details.id}`} className={styles.sectionLabel}>
            {text.decision}
          </span>
          <div className={styles.decisionFields}>
            <FeedbackSelectField
              label={text.status}
              value={status}
              menuMode="inline"
              disabled={isFeedbackActionLocked}
              options={statusOptions
                .filter((option) => option !== "All")
                .map((option) => ({ value: option, label: text.statusOptions[option] }))}
              onChange={(value) => setStatus(value as FeedbackStatus)}
            />
            <FeedbackSelectField
              label={text.priority}
              value={priority}
              menuMode="inline"
              disabled={isFeedbackActionLocked}
              options={priorityOptions
                .filter((option) => option !== "All")
                .map((option) => ({ value: option, label: text.priorityOptions[option] }))}
              onChange={(value) => setPriority(value as FeedbackPriority)}
            />
          </div>
          {isNoteExpanded ? (
            <label className={styles.field}>
              <span className={styles.label}>{text.note}</span>
              <textarea
                className={styles.textarea}
                value={adminNote}
                maxLength={ADMIN_FEEDBACK_ADMIN_NOTE_MAX_LENGTH}
                disabled={isFeedbackActionLocked}
                onChange={(event) =>
                  setAdminNote(event.target.value.slice(0, ADMIN_FEEDBACK_ADMIN_NOTE_MAX_LENGTH))
                }
              />
            </label>
          ) : (
            <Button
              variant="ghost"
              size="sm"
              disabled={isFeedbackActionLocked}
              onClick={() => setIsNoteExpanded(true)}
            >
              {text.addNote}
            </Button>
          )}
          {isFeedbackDraftDirty ? (
            <div className={styles.draftBar} role="status">
              <span className={styles.draftNotice}>{text.unsavedChanges}</span>
              <div className={styles.draftActions}>
                <Button
                  variant="ghost"
                  size="sm"
                  disabled={isFeedbackActionLocked}
                  onClick={resetFeedbackDraft}
                >
                  {text.discardChanges}
                </Button>
                <Button
                  variant="primary"
                  size="sm"
                  disabled={isSaveFeedbackDisabled}
                  onClick={requestSaveFeedback}
                >
                  {text.save}
                </Button>
              </div>
            </div>
          ) : null}
          {updateMutation.isError ? (
            <AdminStateCard
              tone="warning"
              title={getAdminErrorMessage(updateMutation.error, text.saveError)}
            />
          ) : null}
        </section>

        {details.generation?.inputPreviewUrl || details.generation?.resultPreviewUrl ? (
          <details className={styles.supportingDetails}>
            <summary>{text.generation}</summary>
            <div className={styles.previewGrid}>
              {details.generation.inputPreviewUrl ? (
                <figure className={styles.previewTile}>
                  <TemplateSecureMedia
                    className={styles.largePreview}
                    url={details.generation.inputPreviewUrl}
                    kind="image"
                    alt={text.input}
                    width={512}
                    height={512}
                    logContext={{
                      surface: "feedback-generation-input-preview",
                      templateId: details.generation.templateId,
                    }}
                  />
                  <figcaption className={styles.previewCaption}>{text.input}</figcaption>
                </figure>
              ) : null}
              {details.generation.resultPreviewUrl ? (
                <figure className={styles.previewTile}>
                  <TemplateSecureMedia
                    className={styles.largePreview}
                    url={details.generation.resultPreviewUrl}
                    kind="image"
                    alt={text.result}
                    width={512}
                    height={512}
                    logContext={{
                      surface: "feedback-generation-result-preview",
                      templateId: details.generation.templateId,
                    }}
                  />
                  <figcaption className={styles.previewCaption}>{text.result}</figcaption>
                </figure>
              ) : null}
            </div>
          </details>
        ) : null}

        {auditDetails.length > 0 ? (
          <section className={styles.auditPanel} aria-labelledby={`feedback-audit-${details.id}`}>
            <span id={`feedback-audit-${details.id}`} className={styles.sectionLabel}>
              {text.audit}
            </span>
            <div className={styles.auditGrid}>
              {auditDetails.map((item) => (
                <Detail key={item.label} label={item.label} value={item.value} />
              ))}
            </div>
          </section>
        ) : null}

        {canViewUserProfile && !details.refund ? (
          <details className={styles.operationDetails}>
            <summary>{text.refund}</summary>
            <div className={styles.operationBody}>
              <p className={styles.refundHint}>
                {refundDisabledReason ?? text.refundDescription(refundableCredits)}
              </p>
              {!refundDisabledReason ? (
                <Button
                  variant="danger"
                  size="sm"
                  disabled={isRefundFeedbackDisabled}
                  onClick={requestRefundFeedback}
                >
                  {text.refund}
                </Button>
              ) : null}
            </div>
          </details>
        ) : null}

        {technicalDetails.length > 0 ? (
          <details className={styles.technicalDetails}>
            <summary>{text.technical}</summary>
            <div className={styles.technicalGrid}>
              {technicalDetails.map((item) => (
                <Detail key={item.label} label={item.label} value={item.value} />
              ))}
            </div>
          </details>
        ) : null}
      </div>

      <ConfirmationDialog
        open={isRefundDialogOpen}
        title={text.refundTitle}
        description={
          isRefundAmountValid
            ? text.refundDescription(refundAmount)
            : text.refundAmountInvalid(refundableCredits)
        }
        confirmLabel={text.refundConfirm}
        cancelLabel={text.cancel}
        confirmDisabled={isRefundConfirmationDisabled}
        isSubmitting={refundMutation.isPending}
        tone="danger"
        initialFocusRef={refundReasonRef}
        onCancel={() => {
          if (!refundMutation.isPending) {
            setIsRefundDialogOpen(false);
          }
        }}
        onConfirm={requestRefundConfirmation}
      >
        <div className={styles.refundDialogFields}>
          <label className={styles.field}>
            <span className={styles.label}>{text.credits}</span>
            <input
              className={styles.input}
              type="number"
              min={1}
              max={refundableCredits}
              step={1}
              value={refundAmountInput}
              disabled={refundMutation.isPending}
              aria-invalid={!isRefundAmountValid}
              aria-describedby={!isRefundAmountValid ? refundAmountErrorId : undefined}
              onChange={(event) => setRefundAmountInput(event.target.value)}
            />
          </label>
          <label className={styles.field}>
            <span className={styles.label}>{text.refundReason}</span>
            <textarea
              ref={refundReasonRef}
              className={styles.textarea}
              value={refundReason}
              maxLength={ADMIN_FEEDBACK_REFUND_REASON_MAX_LENGTH}
              disabled={refundMutation.isPending}
              aria-invalid={!refundReason.trim() || undefined}
              aria-describedby={`${refundReasonHintId}${
                !refundReason.trim() ? ` ${refundReasonErrorId}` : ""
              }`}
              placeholder={text.refundReasonPlaceholder}
              onChange={(event) =>
                setRefundReason(
                  event.target.value.slice(0, ADMIN_FEEDBACK_REFUND_REASON_MAX_LENGTH)
                )
              }
            />
            <span id={refundReasonHintId} className={styles.fieldHint}>
              {text.refundReasonLength(
                refundReason.length,
                ADMIN_FEEDBACK_REFUND_REASON_MAX_LENGTH
              )}
            </span>
          </label>
          {!isRefundAmountValid ? (
            <p id={refundAmountErrorId} className={styles.validationHint}>
              {text.refundAmountInvalid(refundableCredits)}
            </p>
          ) : null}
          {!refundReason.trim() ? (
            <p id={refundReasonErrorId} className={styles.validationHint}>
              {text.refundReasonRequired}
            </p>
          ) : null}
          {refundMutation.isError ? (
            <AdminStateCard
              tone="warning"
              title={getAdminErrorMessage(refundMutation.error, text.refundError)}
            />
          ) : null}
        </div>
      </ConfirmationDialog>
    </AdminCard>
  );
}

function getRefundDisabledReason({
  canViewUserProfile,
  details,
  refundableCredits,
  text,
}: {
  canViewUserProfile: boolean;
  details: AdminFeedbackDetails;
  refundableCredits: number;
  text: FeedbackPageText;
}) {
  if (!canViewUserProfile) {
    return text.refundAdminOnly;
  }

  if (details.refund || details.generation?.refundedAtUtc) {
    return text.refundAlreadyIssued;
  }

  if (details.refundUnavailableReason) {
    return details.refundUnavailableReason.includes("already_issued")
      ? text.refundAlreadyIssued
      : text.refundUnavailable;
  }

  if (refundableCredits <= 0) {
    return text.refundNoCredits;
  }

  if (!details.canRefund) {
    return text.refundUnavailable;
  }

  return null;
}

function Detail({ label, value }: { label: string; value: ReactNode }) {
  return (
    <div className={styles.detailItem}>
      <span>{label}</span>
      <strong>{typeof value === "string" ? sanitizeSensitiveText(value, 220) : value}</strong>
    </div>
  );
}
