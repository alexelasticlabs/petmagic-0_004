"use client";

import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useRef, useState } from "react";

import { AdminBadge, AdminCard, AdminStateCard } from "@/components/admin/admin-primitives";
import { ConfirmationDialog } from "@/components/admin/confirmation-dialog";
import { Button } from "@/components/ui/button";
import type { UserDetailWorkspaceText } from "@/components/users/user-detail-page.content";
import styles from "@/components/users/user-detail-page.module.css";
import {
  PREMIUM_REVOKE_REASON_MAX_LENGTH,
  resolvePremiumRevokeEligibility,
  type PremiumRevokeEligibility,
} from "@/components/users/user-premium-revoke";
import { getUserRoleLabel, getUserRoleTone } from "@/components/users-management-page.helpers";
import { getAdminErrorMessage } from "@/lib/admin-error-message";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
  assignRole,
  deleteAdminUser,
  fetchAdminUserDashboardMetrics,
  revokePremium,
  revokeRole,
  setActive,
  type AdminUserDetail,
} from "@/lib/api-client";
import { fetchAdminEconomyUserSubscriptionSummary } from "@/lib/api-client.economy";
import { clientLogger } from "@/lib/client-logger";
import { formatDateTime } from "@/lib/format-date-time";
import type { Dictionary, Locale } from "@/lib/i18n";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

type AccessAction =
  | { description: string; kind: "active"; label: string }
  | {
      description: string;
      kind: "role";
      label: string;
      role: "Admin" | "Moderator";
      revoke: boolean;
    }
  | { description: string; kind: "premium"; label: string }
  | { description: string; kind: "delete"; label: string };

type AccessFeedback = {
  canRetryRefresh?: boolean;
  message: string;
  tone: "danger" | "success" | "warning";
};

const premiumStatusLabels: Record<string, Record<Locale, string>> = {
  active: { ru: "Активна", en: "Active" },
  canceled: { ru: "Отменена", en: "Canceled" },
  expired: { ru: "Истекла", en: "Expired" },
  graceperiod: { ru: "Льготный период", en: "Grace period" },
  grace_period: { ru: "Льготный период", en: "Grace period" },
  none: { ru: "Нет активной подписки", en: "No active subscription" },
  pastdue: { ru: "Просрочена", en: "Past due" },
  past_due: { ru: "Просрочена", en: "Past due" },
  revoked: { ru: "Отозвана", en: "Revoked" },
  trialing: { ru: "Пробный период", en: "Trialing" },
};

type UserAccessControlPanelProps = {
  locale: Locale;
  onDeleted: () => void;
  onUpdated: () => Promise<void> | void;
  text: Dictionary;
  user: AdminUserDetail;
  workspaceText: UserDetailWorkspaceText;
};

function getAccessActionErrorDetails(error: unknown) {
  return {
    errorName: error instanceof Error ? error.name : "UnknownError",
    errorDigest:
      error && typeof error === "object" && "digest" in error
        ? sanitizeSensitiveText(String((error as { digest?: unknown }).digest ?? ""), 80)
        : undefined,
  };
}

function getPremiumProviderLabel(provider: string): string {
  if (provider === "stripe") {
    return "Stripe";
  }
  if (provider === "app_store") {
    return "Apple App Store";
  }
  if (provider === "google_play") {
    return "Google Play";
  }

  return sanitizeSensitiveText(provider, 80) || "—";
}

function getPremiumStatusLabel(status: string, locale: Locale): string {
  return premiumStatusLabels[status]?.[locale] ?? (sanitizeSensitiveText(status, 48) || "—");
}

function getPremiumGuidance(
  eligibility: PremiumRevokeEligibility,
  providerLabel: string,
  statusLabel: string,
  workspaceText: UserDetailWorkspaceText
): string {
  if (eligibility.kind === "cancellable") {
    return workspaceText.accessPremiumStripeCancellable;
  }
  if (eligibility.kind === "recovery-pending") {
    return workspaceText.accessPremiumRecoveryPending;
  }
  if (eligibility.kind === "store-managed") {
    return workspaceText.accessPremiumStoreManaged.replace("{provider}", providerLabel);
  }
  if (eligibility.kind === "cancellation-scheduled") {
    return workspaceText.accessPremiumCancellationScheduled;
  }
  if (eligibility.kind === "inactive") {
    return workspaceText.accessPremiumInactive.replace("{status}", statusLabel);
  }

  return workspaceText.accessPremiumUnavailable;
}

function ConsentValue({
  accepted,
  disabledLabel,
  enabledLabel,
}: {
  accepted: boolean;
  disabledLabel: string;
  enabledLabel: string;
}) {
  return (
    <AdminBadge tone={accepted ? "success" : "neutral"}>
      {accepted ? enabledLabel : disabledLabel}
    </AdminBadge>
  );
}

export function UserAccessControlPanel({
  locale,
  onDeleted,
  onUpdated,
  text,
  user,
  workspaceText,
}: UserAccessControlPanelProps) {
  const queryClient = useQueryClient();
  const [pendingAction, setPendingAction] = useState<AccessAction | null>(null);
  const [premiumRevokeReason, setPremiumRevokeReason] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [feedback, setFeedback] = useState<AccessFeedback | null>(null);
  const premiumRevokeReasonRef = useRef<HTMLTextAreaElement>(null);
  const subscriptionSummaryQuery = useQuery({
    queryKey: adminQueryKeys.economyUserSubscriptionSummary(user.userId),
    queryFn: ({ signal }) => fetchAdminEconomyUserSubscriptionSummary(user.userId, signal),
    enabled: Boolean(user.userId),
    staleTime: 30_000,
  });
  const dashboardMetricsQuery = useQuery({
    enabled: user.roles.includes("Admin"),
    queryKey: adminQueryKeys.userDashboardMetrics,
    queryFn: ({ signal }) => fetchAdminUserDashboardMetrics(signal),
    staleTime: 60_000,
  });
  const hasAdminRole = user.roles.includes("Admin");
  const isAdminCountCheckPending = hasAdminRole && dashboardMetricsQuery.isPending;
  const isAdminCountCheckFailed = hasAdminRole && dashboardMetricsQuery.isError;
  const isLastAdmin =
    hasAdminRole &&
    dashboardMetricsQuery.data?.adminUsers !== undefined &&
    dashboardMetricsQuery.data.adminUsers <= 1;
  const isAdminRoleMutationProtected =
    hasAdminRole && (isLastAdmin || isAdminCountCheckPending || isAdminCountCheckFailed);
  const adminProtectionHint = isAdminCountCheckPending
    ? workspaceText.accessAdminCheckPending
    : isAdminCountCheckFailed
      ? workspaceText.accessAdminCheckError
      : workspaceText.lastAdminProtected;
  const isBlockProtected = user.isActive && isAdminRoleMutationProtected;
  const isDeleteProtected = isAdminRoleMutationProtected;
  const subscriptionSummary = subscriptionSummaryQuery.data;
  const premiumEligibility = resolvePremiumRevokeEligibility(subscriptionSummary);
  const premiumProviderLabel = getPremiumProviderLabel(premiumEligibility.provider);
  const premiumStatusLabel = getPremiumStatusLabel(premiumEligibility.status, locale);
  const isPremium = subscriptionSummary?.isPremium ?? user.isPremium;
  const normalizedPremiumRevokeReason = premiumRevokeReason.trim();
  const canRevokePremium =
    !subscriptionSummaryQuery.isError &&
    !subscriptionSummaryQuery.isFetching &&
    (premiumEligibility.kind === "cancellable" || premiumEligibility.kind === "recovery-pending");
  const premiumGuidance = subscriptionSummaryQuery.isPending
    ? workspaceText.accessPremiumLoading
    : subscriptionSummaryQuery.isError
      ? workspaceText.accessPremiumLoadError
      : getPremiumGuidance(
          premiumEligibility,
          premiumProviderLabel,
          premiumStatusLabel,
          workspaceText
        );

  function requestAction(action: AccessAction) {
    if (isSubmitting) {
      return;
    }

    if (
      (action.kind === "delete" && isDeleteProtected) ||
      (action.kind === "active" && user.isActive && isBlockProtected)
    ) {
      return;
    }

    setFeedback(null);
    if (action.kind === "premium") {
      setPremiumRevokeReason("");
    }
    setPendingAction(action);
  }

  async function confirmAction() {
    if (!pendingAction || isSubmitting) {
      return;
    }

    setIsSubmitting(true);
    setFeedback(null);

    try {
      if (pendingAction.kind === "active") {
        await setActive(user.userId, !user.isActive);
      } else if (pendingAction.kind === "role") {
        if (pendingAction.revoke) {
          await revokeRole(user.userId, pendingAction.role);
        } else {
          await assignRole(user.userId, pendingAction.role);
        }
      } else if (pendingAction.kind === "premium") {
        if (!normalizedPremiumRevokeReason) {
          setIsSubmitting(false);
          return;
        }

        const latestSubscriptionResult = await subscriptionSummaryQuery.refetch();
        if (latestSubscriptionResult.isError || !latestSubscriptionResult.data) {
          setFeedback({
            tone: "danger",
            message: workspaceText.accessPremiumLoadError,
          });
          setIsSubmitting(false);
          return;
        }

        const latestEligibility = resolvePremiumRevokeEligibility(latestSubscriptionResult.data);
        if (
          latestEligibility.kind !== "cancellable" &&
          latestEligibility.kind !== "recovery-pending"
        ) {
          setFeedback({
            tone: "warning",
            message: workspaceText.accessPremiumStateChanged,
          });
          setPendingAction(null);
          setIsSubmitting(false);
          return;
        }

        const updatedSummary = await revokePremium(
          user.userId,
          latestEligibility.provider,
          normalizedPremiumRevokeReason
        );
        queryClient.setQueryData(
          adminQueryKeys.economyUserSubscriptionSummary(user.userId),
          updatedSummary
        );
      } else {
        await deleteAdminUser(user.userId);
      }
    } catch (error) {
      clientLogger.error("users.access_action_failed", {
        userId: sanitizeSensitiveText(user.userId, 80),
        action: pendingAction.kind,
        ...getAccessActionErrorDetails(error),
      });
      setFeedback({
        tone: "danger",
        message: getAdminErrorMessage(error, workspaceText.actionError),
      });
      if (pendingAction.kind !== "premium") {
        setPendingAction(null);
      }
      setIsSubmitting(false);
      return;
    }

    setPendingAction(null);
    setPremiumRevokeReason("");
    if (pendingAction.kind === "delete") {
      onDeleted();
      setIsSubmitting(false);
      return;
    }

    try {
      await onUpdated();
      setFeedback({ tone: "success", message: workspaceText.actionSuccess });
    } catch (error) {
      clientLogger.warn("users.access_refresh_failed", {
        userId: sanitizeSensitiveText(user.userId, 80),
        action: pendingAction.kind,
        ...getAccessActionErrorDetails(error),
      });
      setFeedback({
        tone: "warning",
        message: workspaceText.actionRefreshWarning,
        canRetryRefresh: true,
      });
    } finally {
      setIsSubmitting(false);
    }
  }

  async function retryProfileRefresh() {
    if (isSubmitting) {
      return;
    }

    setIsSubmitting(true);
    setFeedback(null);

    try {
      await onUpdated();
      setFeedback({ tone: "success", message: workspaceText.actionSuccess });
    } catch (error) {
      clientLogger.warn("users.access_retry_refresh_failed", {
        userId: sanitizeSensitiveText(user.userId, 80),
        ...getAccessActionErrorDetails(error),
      });
      setFeedback({
        tone: "warning",
        message: workspaceText.actionRefreshWarning,
        canRetryRefresh: true,
      });
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <AdminCard title={workspaceText.accessTitle} description={workspaceText.accessDescription}>
      {feedback ? (
        <AdminStateCard
          tone={feedback.tone}
          title={feedback.message}
          action={
            feedback.canRetryRefresh ? (
              <Button
                variant="secondary"
                size="sm"
                disabled={isSubmitting}
                onClick={() => void retryProfileRefresh()}
              >
                {text.supportRetryAction}
              </Button>
            ) : undefined
          }
        />
      ) : null}

      <div className={styles.accessLayout}>
        <div className={styles.accessWorkspace}>
          <section className={`${styles.accessSection} ${styles.accessOperationSection}`}>
            <div className={styles.accessSectionHeader}>
              <h3>{workspaceText.accessAccountState}</h3>
              <p className={styles.accessSectionText}>{workspaceText.accessAccountHint}</p>
            </div>
            <div className={styles.accessSectionBody}>
              <div className={styles.accessValueRow}>
                <AdminBadge tone={user.isActive ? "success" : "danger"}>
                  {user.isActive ? text.activeLabel : text.blockedLabel}
                </AdminBadge>
                <Button
                  variant={user.isActive ? "secondary" : "primary"}
                  size="sm"
                  disabled={isSubmitting || isBlockProtected}
                  title={isBlockProtected ? adminProtectionHint : undefined}
                  onClick={() =>
                    requestAction({
                      kind: "active",
                      label: user.isActive ? workspaceText.block : workspaceText.unblock,
                      description: user.isActive
                        ? workspaceText.confirmBlockDescription
                        : workspaceText.confirmUnblockDescription,
                    })
                  }
                >
                  {user.isActive ? workspaceText.block : workspaceText.unblock}
                </Button>
              </div>
              {isBlockProtected ? (
                <div
                  className={`${styles.roleProtection} ${styles.accessSectionFooter}`}
                  role="status"
                >
                  <span>{adminProtectionHint}</span>
                  {isAdminCountCheckFailed ? (
                    <Button
                      variant="ghost"
                      size="sm"
                      disabled={dashboardMetricsQuery.isFetching}
                      onClick={() => void dashboardMetricsQuery.refetch().catch(() => undefined)}
                    >
                      {text.supportRetryAction}
                    </Button>
                  ) : null}
                </div>
              ) : null}
            </div>
          </section>

          <section className={`${styles.accessSection} ${styles.accessOperationSection}`}>
            <div className={styles.accessSectionHeader}>
              <h3>{workspaceText.accessRoles}</h3>
              <p className={styles.accessSectionText}>{workspaceText.accessRolesHint}</p>
            </div>
            <div className={styles.accessSectionBody}>
              <div className={`${styles.roleActions} ${styles.roleActionList}`}>
                {(["Admin", "Moderator"] as const).map((role) => {
                  const hasRole = user.roles.includes(role);
                  const isProtected = role === "Admin" && hasRole && isAdminRoleMutationProtected;
                  const actionLabel =
                    role === "Admin"
                      ? hasRole
                        ? text.revokeAdmin
                        : text.assignAdmin
                      : hasRole
                        ? text.revokeModerator
                        : text.assignModerator;

                  return (
                    <div key={role} className={styles.roleAction}>
                      <div className={styles.roleActionCopy}>
                        <AdminBadge tone={hasRole ? getUserRoleTone(role) : "neutral"}>
                          {getUserRoleLabel(role, text)} ·{" "}
                          {hasRole
                            ? workspaceText.accessRoleAssigned
                            : workspaceText.accessRoleNotAssigned}
                        </AdminBadge>
                        {isProtected ? (
                          <div className={styles.roleProtection}>
                            <span>{adminProtectionHint}</span>
                            {isAdminCountCheckFailed ? (
                              <Button
                                variant="ghost"
                                size="sm"
                                disabled={dashboardMetricsQuery.isFetching}
                                onClick={() =>
                                  void dashboardMetricsQuery.refetch().catch(() => undefined)
                                }
                              >
                                {text.supportRetryAction}
                              </Button>
                            ) : null}
                          </div>
                        ) : null}
                      </div>
                      <Button
                        variant="secondary"
                        size="sm"
                        disabled={isSubmitting || isProtected}
                        title={isProtected ? adminProtectionHint : undefined}
                        onClick={() =>
                          requestAction({
                            kind: "role",
                            label: actionLabel,
                            description: hasRole
                              ? workspaceText.confirmRevokeRoleDescription
                              : workspaceText.confirmAssignRoleDescription,
                            role,
                            revoke: hasRole,
                          })
                        }
                      >
                        {actionLabel}
                      </Button>
                    </div>
                  );
                })}
              </div>
            </div>
          </section>
        </div>

        <aside className={styles.accessInformationRail} aria-label={workspaceText.accessTitle}>
          <section className={`${styles.accessSection} ${styles.accessInfoSection}`}>
            <div className={styles.accessSectionHeader}>
              <h3>{workspaceText.accessPremium}</h3>
              <p className={styles.accessSectionText}>{workspaceText.accessPremiumHint}</p>
            </div>
            <div className={styles.accessSectionBody}>
              <div className={styles.accessValueRow}>
                <AdminBadge tone={isPremium ? "warning" : "neutral"}>
                  {isPremium ? text.premiumLabel : text.freeLabel}
                </AdminBadge>
                {subscriptionSummary ? (
                  <>
                    <AdminBadge tone="neutral">
                      {workspaceText.accessPremiumProvider}: {premiumProviderLabel}
                    </AdminBadge>
                    <AdminBadge tone="neutral">
                      {workspaceText.accessPremiumStatus}: {premiumStatusLabel}
                    </AdminBadge>
                  </>
                ) : null}
                {canRevokePremium ? (
                  <Button
                    variant="secondary"
                    size="sm"
                    disabled={isSubmitting || subscriptionSummaryQuery.isFetching}
                    onClick={() =>
                      requestAction({
                        kind: "premium",
                        label: workspaceText.revokePremium,
                        description: workspaceText.confirmRevokePremiumDescription,
                      })
                    }
                  >
                    {workspaceText.revokePremium}
                  </Button>
                ) : null}
              </div>
              <div
                className={`${styles.roleProtection} ${styles.accessSectionFooter}`}
                role="status"
              >
                <span>{premiumGuidance}</span>
                {subscriptionSummaryQuery.isError ? (
                  <Button
                    variant="ghost"
                    size="sm"
                    disabled={subscriptionSummaryQuery.isFetching}
                    onClick={() => void subscriptionSummaryQuery.refetch().catch(() => undefined)}
                  >
                    {text.supportRetryAction}
                  </Button>
                ) : null}
              </div>
            </div>
          </section>

          <section className={`${styles.accessSection} ${styles.accessInfoSection}`}>
            <div className={styles.accessSectionHeader}>
              <h3>{workspaceText.accessConsent}</h3>
              <p className={styles.accessSectionText}>{workspaceText.accessConsentHint}</p>
            </div>
            <div className={styles.accessSectionBody}>
              <dl className={styles.consentList}>
                <div>
                  <dt>{workspaceText.accessTerms}</dt>
                  <dd>
                    <ConsentValue
                      accepted={user.termsOfUseAccepted}
                      disabledLabel={workspaceText.consentMissing}
                      enabledLabel={workspaceText.consentAccepted}
                    />
                    {user.legalAcceptance.termsOfUseAcceptedAtUtc ? (
                      <span>
                        {formatDateTime(user.legalAcceptance.termsOfUseAcceptedAtUtc, locale)}
                      </span>
                    ) : null}
                  </dd>
                </div>
                <div>
                  <dt>{workspaceText.accessPrivacy}</dt>
                  <dd>
                    <ConsentValue
                      accepted={user.privacyPolicyAccepted}
                      disabledLabel={workspaceText.consentMissing}
                      enabledLabel={workspaceText.consentAccepted}
                    />
                    {user.legalAcceptance.privacyPolicyAcceptedAtUtc ? (
                      <span>
                        {formatDateTime(user.legalAcceptance.privacyPolicyAcceptedAtUtc, locale)}
                      </span>
                    ) : null}
                  </dd>
                </div>
                <div>
                  <dt>{workspaceText.accessMarketing}</dt>
                  <dd>
                    <ConsentValue
                      accepted={user.marketingEmailsEnabled}
                      disabledLabel={workspaceText.consentDisabled}
                      enabledLabel={workspaceText.consentEnabled}
                    />
                  </dd>
                </div>
              </dl>
              {user.legalAcceptance.requiresAcceptance ? (
                <AdminStateCard tone="warning" title={workspaceText.requiredAcceptance} />
              ) : null}
            </div>
          </section>
        </aside>
      </div>

      <section className={`${styles.deleteZone} ${styles.dangerZone}`}>
        <div>
          <h3>{workspaceText.deleteTitle}</h3>
          <p>{workspaceText.deleteDescription}</p>
          {isDeleteProtected ? (
            <div className={styles.roleProtection} role="status">
              <span>{adminProtectionHint}</span>
              {isAdminCountCheckFailed ? (
                <Button
                  variant="ghost"
                  size="sm"
                  disabled={dashboardMetricsQuery.isFetching}
                  onClick={() => void dashboardMetricsQuery.refetch().catch(() => undefined)}
                >
                  {text.supportRetryAction}
                </Button>
              ) : null}
            </div>
          ) : null}
        </div>
        <Button
          variant="danger"
          size="sm"
          disabled={isSubmitting || isDeleteProtected}
          title={isDeleteProtected ? adminProtectionHint : undefined}
          onClick={() =>
            requestAction({
              kind: "delete",
              label: workspaceText.deleteUser,
              description: workspaceText.confirmDeleteDescription,
            })
          }
        >
          {workspaceText.deleteUser}
        </Button>
      </section>

      <ConfirmationDialog
        open={pendingAction !== null}
        title={pendingAction?.label ?? workspaceText.confirmTitle}
        description={pendingAction?.description ?? workspaceText.confirmDescription}
        confirmLabel={pendingAction?.label ?? workspaceText.confirmTitle}
        cancelLabel={workspaceText.confirmCancel}
        confirmDisabled={pendingAction?.kind === "premium" && !normalizedPremiumRevokeReason}
        initialFocusRef={pendingAction?.kind === "premium" ? premiumRevokeReasonRef : undefined}
        isSubmitting={isSubmitting}
        tone={
          pendingAction?.kind === "delete" || pendingAction?.kind === "active"
            ? "danger"
            : "primary"
        }
        onCancel={() => {
          if (!isSubmitting) {
            setPendingAction(null);
            setPremiumRevokeReason("");
          }
        }}
        onConfirm={() => void confirmAction()}
      >
        {pendingAction?.kind === "premium" ? (
          <>
            {feedback ? <AdminStateCard tone={feedback.tone} title={feedback.message} /> : null}
            <label className={styles.confirmReasonField}>
              <span>{workspaceText.premiumRevokeReasonLabel}</span>
              <textarea
                ref={premiumRevokeReasonRef}
                className={styles.confirmReasonTextarea}
                value={premiumRevokeReason}
                maxLength={PREMIUM_REVOKE_REASON_MAX_LENGTH}
                required
                aria-describedby="premium-revoke-reason-hint"
                onChange={(event) =>
                  setPremiumRevokeReason(
                    event.target.value.slice(0, PREMIUM_REVOKE_REASON_MAX_LENGTH)
                  )
                }
                placeholder={workspaceText.premiumRevokeReasonPlaceholder}
              />
              <small id="premium-revoke-reason-hint">
                {workspaceText.premiumRevokeReasonHint} {premiumRevokeReason.length}/
                {PREMIUM_REVOKE_REASON_MAX_LENGTH}
              </small>
            </label>
          </>
        ) : null}
      </ConfirmationDialog>
    </AdminCard>
  );
}
