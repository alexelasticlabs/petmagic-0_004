"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";

import { AdminCard, AdminStateCard, AdminStatusBadge } from "@/components/admin/admin-primitives";
import styles from "@/components/feedback-page.module.css";
import { TemplateSecureMedia } from "@/components/templates/template-secure-media";
import { getAdminErrorMessage } from "@/lib/admin-error-message";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
  ADMIN_FEEDBACK_ADMIN_NOTE_MAX_LENGTH,
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
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

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

function ratingLabel(value: number | null | undefined, text: FeedbackPageText) {
  if (value === 1) return text.ratingLabels.positive;
  if (value === 0) return text.ratingLabels.neutral;
  if (value === -1) return text.ratingLabels.negative;
  return "-";
}

export function FeedbackRow({
  item,
  text,
  locale,
  onOpen,
}: {
  item: AdminFeedbackListItem;
  text: FeedbackPageText;
  locale: Locale;
  onOpen: (id: string) => void;
}) {
  return (
    <tr>
      <td>{formatDateTime(item.createdAtUtc, locale)}</td>
      <td className={styles.mono}>{shortId(item.userId)}</td>
      <td>{optionLabel(text.typeOptions, item.type)}</td>
      <td>{item.category}</td>
      <td>{ratingLabel(item.rating, text)}</td>
      <td>{item.templateTitle ?? shortId(item.templateId)}</td>
      <td>{item.platform ?? "-"}</td>
      <td>
        <AdminStatusBadge color={toneForStatus(item.status)}>
          {optionLabel(text.statusOptions, item.status)}
        </AdminStatusBadge>
      </td>
      <td>
        <AdminStatusBadge color={toneForPriority(item.priority)}>
          {optionLabel(text.priorityOptions, item.priority)}
        </AdminStatusBadge>
      </td>
      <td>
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
        ) : (
          "-"
        )}
      </td>
      <td className={styles.message}>
        {item.message ? sanitizeSensitiveText(item.message, 180) : "-"}
      </td>
      <td>
        <button className={styles.button} type="button" onClick={() => onOpen(item.id)}>
          {text.show}
        </button>
      </td>
    </tr>
  );
}

export function DetailsPanel({
  details,
  isDetailsFetching,
  locale,
}: {
  details: AdminFeedbackDetails;
  isDetailsFetching: boolean;
  locale: Locale;
}) {
  const text = getFeedbackPageText(locale);
  const queryClient = useQueryClient();
  const [status, setStatus] = useState((details.status as FeedbackStatus) || "New");
  const [priority, setPriority] = useState((details.priority as FeedbackPriority) || "Low");
  const [adminNote, setAdminNote] = useState(details.adminNote ?? "");
  const updateMutation = useMutation({
    mutationFn: () => updateAdminFeedback(details.id, { status, priority, adminNote }),
    onSuccess: async () => {
      await Promise.allSettled([
        queryClient.invalidateQueries({ queryKey: adminQueryKeys.feedbackDetails(details.id) }),
        queryClient.invalidateQueries({ queryKey: ["admin", "feedback"] }),
      ]);
    },
  });
  const refundableCredits =
    typeof details.generation?.creditsCharged === "number" &&
    Number.isFinite(details.generation.creditsCharged)
      ? Math.max(0, Math.trunc(details.generation.creditsCharged))
      : 0;
  const refundMutation = useMutation({
    mutationFn: () =>
      refundAdminFeedbackCredits(details.id, {
        amount: refundableCredits,
        reason: `Feedback refund ${details.id}`,
      }),
    onSuccess: async () => {
      const invalidations = [
        queryClient.invalidateQueries({ queryKey: adminQueryKeys.feedbackDetails(details.id) }),
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
    },
  });
  const isFeedbackActionLocked =
    updateMutation.isPending || refundMutation.isPending || isDetailsFetching;
  const isFeedbackDraftDirty =
    status !== ((details.status as FeedbackStatus) || "New") ||
    priority !== ((details.priority as FeedbackPriority) || "Low") ||
    adminNote !== (details.adminNote ?? "");
  const isSaveFeedbackDisabled = !isFeedbackDraftDirty || isFeedbackActionLocked;
  const isRefundFeedbackDisabled =
    !details.canRefund || refundableCredits <= 0 || isFeedbackActionLocked;
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

    refundMutation.mutate();
  };
  const userQuery = useQuery({
    queryKey: details.userId
      ? adminQueryKeys.userDetail(details.userId)
      : adminQueryKeys.userDetailDisabled,
    queryFn: ({ signal }) => fetchAdminUser(details.userId!, signal),
    enabled: Boolean(details.userId),
  });
  const userAnalyticsQuery = useQuery({
    queryKey: details.userId
      ? adminQueryKeys.userAnalytics(details.userId)
      : adminQueryKeys.userAnalyticsDisabled,
    queryFn: ({ signal }) => fetchAdminUserAnalytics(details.userId!, signal),
    enabled: Boolean(details.userId),
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
  // prettier-ignore
  const hasUserContextError =
    Boolean(details.userId) && (userQuery.isError || userAnalyticsQuery.isError);
  const isUserContextFetching = userQuery.isFetching || userAnalyticsQuery.isFetching;

  return (
    <AdminCard title={text.details}>
      <div className={styles.details} aria-busy={isDetailsFetching ? "true" : undefined}>
        <div className={styles.detailsMain}>
          <div className={styles.detailGrid}>
            <Detail label={text.type} value={optionLabel(text.typeOptions, details.type)} />
            <Detail label={text.category} value={details.category} />
            <Detail label={text.rating} value={ratingLabel(details.rating, text)} />
            <Detail label={text.user} value={userQuery.data?.email ?? shortId(details.userId)} />
            <Detail label={text.planCredits} value={`${userPlan} / ${userCredits}`} />
            <Detail label={text.source} value={details.sourceScreen} />
            <Detail label={text.platform} value={details.platform ?? "-"} />
            <Detail label={text.app} value={details.appVersion ?? "-"} />
            <Detail label={text.device} value={details.deviceModel ?? "-"} />
            <Detail
              label={text.provider}
              value={details.providerName ?? details.generation?.providerName ?? "-"}
            />
            <Detail
              label={text.errorCode}
              value={details.errorCode ?? details.generation?.errorCode ?? "-"}
            />
            <Detail label={text.message} value={details.message ?? "-"} />
            <Detail label={text.date} value={formatDateTime(details.createdAtUtc, locale)} />
          </div>
          {hasUserContextError ? (
            <AdminStateCard
              tone="warning"
              title={text.userContextErrorTitle}
              description={getAdminErrorMessage(
                userQuery.error ?? userAnalyticsQuery.error,
                text.userContextErrorDescription
              )}
              action={
                <button
                  className={styles.button}
                  type="button"
                  disabled={isUserContextFetching}
                  onClick={() => {
                    void Promise.allSettled([userQuery.refetch(), userAnalyticsQuery.refetch()]);
                  }}
                >
                  {text.retry}
                </button>
              }
            />
          ) : null}
        </div>
        <div>
          {details.generation ? (
            <>
              <div className={styles.previewGrid}>
                {details.generation.inputPreviewUrl ? (
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
                ) : null}
                {details.generation.resultPreviewUrl ? (
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
                ) : null}
              </div>
              <div className={styles.detailItem}>
                <span>{text.generation}</span>
                <strong>
                  {shortId(details.generation.generationId)} / {details.generation.creditsCharged}{" "}
                  {text.credits}
                </strong>
              </div>
            </>
          ) : null}
          <div className={styles.field}>
            <label className={styles.label}>{text.status}</label>
            <select
              className={styles.select}
              value={status}
              disabled={isFeedbackActionLocked}
              onChange={(event) => setStatus(event.target.value as FeedbackStatus)}
            >
              {statusOptions
                .filter((x) => x !== "All")
                .map((option) => (
                  <option key={option} value={option}>
                    {text.statusOptions[option]}
                  </option>
                ))}
            </select>
          </div>
          <div className={styles.field}>
            <label className={styles.label}>{text.priority}</label>
            <select
              className={styles.select}
              value={priority}
              disabled={isFeedbackActionLocked}
              onChange={(event) => setPriority(event.target.value as FeedbackPriority)}
            >
              {priorityOptions
                .filter((x) => x !== "All")
                .map((option) => (
                  <option key={option} value={option}>
                    {text.priorityOptions[option]}
                  </option>
                ))}
            </select>
          </div>
          <div className={styles.field}>
            <label className={styles.label}>{text.note}</label>
            <textarea
              className={styles.textarea}
              value={adminNote}
              maxLength={ADMIN_FEEDBACK_ADMIN_NOTE_MAX_LENGTH}
              disabled={isFeedbackActionLocked}
              onChange={(event) =>
                setAdminNote(event.target.value.slice(0, ADMIN_FEEDBACK_ADMIN_NOTE_MAX_LENGTH))
              }
            />
          </div>
          {updateMutation.isError ? (
            <AdminStateCard
              tone="warning"
              title={getAdminErrorMessage(updateMutation.error, text.saveError)}
            />
          ) : null}
          {refundMutation.isError ? (
            <AdminStateCard
              tone="warning"
              title={getAdminErrorMessage(refundMutation.error, text.refundError)}
            />
          ) : null}
          <div className={styles.actions}>
            <button
              className={styles.button}
              type="button"
              disabled={isSaveFeedbackDisabled}
              onClick={requestSaveFeedback}
            >
              {text.save}
            </button>
            <button
              className={`${styles.button} ${details.canRefund ? styles.danger : ""}`}
              type="button"
              disabled={isRefundFeedbackDisabled}
              onClick={requestRefundFeedback}
            >
              {details.refund ? text.refunded : text.refund}
            </button>
          </div>
        </div>
      </div>
    </AdminCard>
  );
}

function Detail({ label, value }: { label: string; value: string }) {
  return (
    <div className={styles.detailItem}>
      <span>{label}</span>
      <strong>{sanitizeSensitiveText(value, 220)}</strong>
    </div>
  );
}

export function Field({
  label,
  value,
  type = "text",
  maxLength,
  disabled = false,
  onChange,
}: {
  label: string;
  value: string;
  type?: string;
  maxLength?: number;
  disabled?: boolean;
  onChange: (value: string) => void;
}) {
  return (
    <label className={styles.field}>
      <span className={styles.label}>{label}</span>
      <input
        className={styles.input}
        type={type}
        value={value}
        maxLength={maxLength}
        disabled={disabled}
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

export function Select({
  label,
  value,
  options,
  optionLabels,
  disabled = false,
  onChange,
}: {
  label: string;
  value: string;
  options: readonly string[];
  optionLabels?: Record<string, string>;
  disabled?: boolean;
  onChange: (value: string) => void;
}) {
  return (
    <label className={styles.field}>
      <span className={styles.label}>{label}</span>
      <select
        className={styles.select}
        value={value}
        disabled={disabled}
        onChange={(event) => onChange(event.target.value)}
      >
        {options.map((option) => (
          <option key={option} value={option}>
            {optionLabels?.[option] ?? option}
          </option>
        ))}
      </select>
    </label>
  );
}
