import Link from "next/link";
import { useEffect, useMemo, useRef, useState } from "react";

import { AdminBadge, AdminCard, AdminStateCard } from "@/components/admin/admin-primitives";
import { ConfirmationDialog } from "@/components/admin/confirmation-dialog";
import {
  formatAccountAge,
  formatDateTime,
  formatFileSize,
  formatMoney,
  formatRelativeTime,
  formatSafeSupportDownloadName,
  formatSafeSupportDisplay,
  getMessageAttachments,
  hasAttachment,
  hasImageAttachment,
  initialsFor,
  shortId,
} from "@/components/support/support-conversation-helpers";
import {
  SectionBlock,
  SidePanelAsyncState,
  TimelineCard,
} from "@/components/support/support-conversation-ui-primitives";
import styles from "@/components/support/support-page.module.css";
import { SupportSecureMedia } from "@/components/support/support-secure-media";
import {
  priorityLabel,
  sourceLabel,
  statusLabel,
  toneForGeneration,
  toneForStatus,
} from "@/components/support/support-status-helpers";
import { useSupportConversationController } from "@/components/support/use-support-conversation-controller";
import { Button } from "@/components/ui/button";
import { type AdminSupportMessage } from "@/lib/api-client";
import { clientLogger } from "@/lib/client-logger";
import { fetchWithTimeout } from "@/lib/fetch-with-timeout";
import { type Locale } from "@/lib/i18n";

type SupportConversationSidePanelProps = {
  locale: Locale;
  controller: ReturnType<typeof useSupportConversationController>;
  onJumpToMessage?: (messageId: string) => void;
  onOpenAttachmentPreview?: (message: AdminSupportMessage) => void;
};

type ResponderState = {
  label: string;
  tone: "success" | "danger" | "neutral";
};

type PendingUserAction = "activate" | "deactivate" | "grantPremium" | "revokePremium";

export function SupportConversationSidePanel({
  locale,
  controller,
  onJumpToMessage,
  onOpenAttachmentPreview,
}: SupportConversationSidePanelProps) {
  const [showDangerousActions, setShowDangerousActions] = useState(false);
  const [showResolveConfirm, setShowResolveConfirm] = useState(false);
  const [pendingUserAction, setPendingUserAction] = useState<PendingUserAction | null>(null);
  const [pendingAttachmentActionKey, setPendingAttachmentActionKey] = useState<string | null>(null);
  const attachmentActionAbortControllerRef = useRef<AbortController | null>(null);

  const {
    activeSidePanelTab,
    accountCreatedAt,
    analyticsQuery,
    conversation,
    conversationSla,
    conversationTimeline,
    destructiveStatusAction,
    failedGenerations,
    isSidePanelOpen,
    isSubjectUserDeleted,
    canManageSupportWorkspace,
    canViewSubjectUserContext,
    purchasesQuery,
    primaryStatusAction,
    recentFailures,
    recentUserPurchases,
    lastUserPurchaseAtUtc,
    lastActivityAtUtc,
    secondaryStatusActions,
    setUserActiveMutation,
    setUserPremiumMutation,
    subscriptionQuery,
    sessionUserRoles,
    setActiveSidePanelTab,
    sidePanelTabs,
    statusMutation,
    text,
    totalPurchases,
    userEmailDisplay,
    userDisplayName,
    userQuery,
  } = controller;

  const attachmentItems = useMemo(
    () =>
      (conversation?.messages ?? [])
        .filter(
          (message) =>
            hasAttachment(message) &&
            getMessageAttachments(message).some(
              (attachment) => !attachment.isDeleted && Boolean(attachment.fileUrl?.trim())
            )
        )
        .slice()
        .reverse(),
    [conversation?.messages]
  );

  const contextLoadFailed =
    !isSubjectUserDeleted &&
    (analyticsQuery.isError ||
      (canViewSubjectUserContext && (purchasesQuery.isError || subscriptionQuery.isError)));

  useEffect(
    () => () => {
      attachmentActionAbortControllerRef.current?.abort();
    },
    []
  );

  useEffect(() => {
    if (!contextLoadFailed || !conversation) {
      return;
    }

    clientLogger.error("support.user_context_load_failed", {
      analyticsError: analyticsQuery.error,
      purchasesError: purchasesQuery.error,
      subscriptionError: subscriptionQuery.error,
      conversationId: conversation.conversationId,
      initiatorUserId: conversation.initiatorUserId,
    });
  }, [
    analyticsQuery.error,
    analyticsQuery.isError,
    contextLoadFailed,
    conversation,
    conversation?.conversationId,
    conversation?.initiatorUserId,
    purchasesQuery.error,
    purchasesQuery.isError,
    subscriptionQuery.error,
    subscriptionQuery.isError,
  ]);

  const getAttachmentActionKey = (message: AdminSupportMessage, action: "open" | "download") =>
    `${message.messageId}:${message.attachmentFileName ?? ""}:${message.attachmentFileSizeBytes ?? 0}:${action}`;

  const getPrimaryAttachmentMimeType = (message: AdminSupportMessage) =>
    getMessageAttachments(message).find((attachment) => !attachment.isDeleted)?.mimeType;

  const fetchAttachmentBlob = async (
    message: AdminSupportMessage,
    action: "open" | "download",
    signal: AbortSignal
  ): Promise<Blob | null> => {
    if (!message.attachmentUrl?.trim()) {
      return null;
    }

    try {
      const response = await fetchWithTimeout(message.attachmentUrl, {
        credentials: "include",
        signal,
      });
      if (!response.ok) {
        clientLogger.warn("support.side_panel_attachment_fetch_failed", {
          action,
          messageId: message.messageId,
          status: response.status,
          mimeType: getPrimaryAttachmentMimeType(message),
        });
        return null;
      }

      return response.blob();
    } catch (error) {
      if (signal.aborted) {
        return null;
      }

      clientLogger.warn("support.side_panel_attachment_fetch_failed", {
        action,
        messageId: message.messageId,
        mimeType: getPrimaryAttachmentMimeType(message),
        error,
      });
      return null;
    }
  };

  const openAttachmentBlob = async (message: AdminSupportMessage) => {
    const actionKey = getAttachmentActionKey(message, "open");
    if (!canManageSupportWorkspace || pendingAttachmentActionKey !== null) {
      return;
    }

    setPendingAttachmentActionKey(actionKey);
    attachmentActionAbortControllerRef.current?.abort();
    const controller = new AbortController();
    attachmentActionAbortControllerRef.current = controller;
    try {
      const blob = await fetchAttachmentBlob(message, "open", controller.signal);
      if (!blob || controller.signal.aborted) {
        return;
      }

      const objectUrl = URL.createObjectURL(blob);
      const opened = window.open(objectUrl, "_blank", "noopener,noreferrer");
      if (!opened) {
        URL.revokeObjectURL(objectUrl);
        return;
      }

      window.setTimeout(() => URL.revokeObjectURL(objectUrl), 60_000);
    } finally {
      if (attachmentActionAbortControllerRef.current === controller) {
        attachmentActionAbortControllerRef.current = null;
        setPendingAttachmentActionKey(null);
      }
    }
  };

  const downloadAttachmentBlob = async (message: AdminSupportMessage) => {
    const actionKey = getAttachmentActionKey(message, "download");
    if (!canManageSupportWorkspace || pendingAttachmentActionKey !== null) {
      return;
    }

    setPendingAttachmentActionKey(actionKey);
    attachmentActionAbortControllerRef.current?.abort();
    const controller = new AbortController();
    attachmentActionAbortControllerRef.current = controller;
    try {
      const blob = await fetchAttachmentBlob(message, "download", controller.signal);
      if (!blob || controller.signal.aborted) {
        return;
      }

      const objectUrl = URL.createObjectURL(blob);
      const link = document.createElement("a");
      link.href = objectUrl;
      link.download = formatSafeSupportDownloadName(message.attachmentFileName);
      document.body.append(link);
      link.click();
      link.remove();
      window.setTimeout(() => URL.revokeObjectURL(objectUrl), 1000);
    } finally {
      if (attachmentActionAbortControllerRef.current === controller) {
        attachmentActionAbortControllerRef.current = null;
        setPendingAttachmentActionKey(null);
      }
    }
  };

  if (!isSidePanelOpen || !conversation) {
    return null;
  }

  const responderState = getResponderState(conversation.status, locale);
  const isUserActive = userQuery.data?.isActive ?? true;
  const isUserPremium = canViewSubjectUserContext ? (userQuery.data?.isPremium ?? false) : false;
  const canManageSubjectUser = canViewSubjectUserContext && sessionUserRoles.includes("Admin");
  const canRetrySubjectUserContext = canViewSubjectUserContext && !isSubjectUserDeleted;
  const isModerationPending = setUserActiveMutation.isPending || setUserPremiumMutation.isPending;
  const pendingUserActionCopy = pendingUserAction
    ? getPendingUserActionCopy(pendingUserAction, userDisplayName, locale)
    : null;
  const requestStatusChange = (status: typeof conversation.status) => {
    if (!canManageSupportWorkspace) {
      return;
    }

    if (status === "Closed") {
      setShowResolveConfirm(true);
      return;
    }

    if (!statusMutation.isPending) {
      statusMutation.mutate(status);
    }
  };
  const confirmResolveConversation = async () => {
    if (!canManageSupportWorkspace || !primaryStatusAction || statusMutation.isPending) {
      return;
    }

    try {
      await statusMutation.mutateAsync(primaryStatusAction.status);
      setShowResolveConfirm(false);
    } catch {
      // The controller mutation already routes sanitized errors to support notifications.
    }
  };
  const confirmPendingUserAction = async () => {
    if (!pendingUserAction || isModerationPending) {
      return;
    }

    const action = pendingUserAction;
    try {
      if (action === "activate" || action === "deactivate") {
        await setUserActiveMutation.mutateAsync(action === "activate");
      } else {
        await setUserPremiumMutation.mutateAsync(action === "grantPremium");
      }
      setPendingUserAction(null);
    } catch {
      // The controller mutation already routes sanitized errors to support notifications.
    }
  };
  const subscriptionStatusLabel =
    subscriptionQuery.data?.status ?? (locale === "ru" ? "Нет подписки" : "No subscription");
  const tokenBalanceLabel = locale === "ru" ? "Баланс PawSpark" : "PawSpark balance";
  const hasTopMetrics = Boolean(conversation.assistantScenario || conversation.relatedGenerationId);

  return (
    <>
      <div className={styles.sidePane}>
        <AdminCard className={`${styles.sideCard} ${styles.sidePanelCard}`}>
          {/* ── User identity ─────────────────────────────────── */}
          <div className={styles.spIdentity}>
            <span className={styles.spAvatarMd}>{initialsFor(userDisplayName)}</span>
            <div className={styles.spIdentityInfo}>
              <div className={styles.spNameRow}>
                <strong className={styles.spNameText}>{userDisplayName}</strong>
                {canViewSubjectUserContext ? (
                  <span
                    className={`${styles.spPlanChip} ${isUserPremium ? styles.spPlanChipPremium : ""}`}
                  >
                    {isUserPremium ? text.premiumLabel : text.freeLabel}
                  </span>
                ) : null}
              </div>
              <span className={styles.spUserEmail}>
                {userEmailDisplay || (locale === "ru" ? "Пользователь удален" : "User deleted")}
              </span>
            </div>
          </div>

          {/* ── Status strip ─────────────────────────────────── */}
          <div className={styles.spStatusStrip}>
            <AdminBadge tone={toneForStatus(conversation.status)}>
              {statusLabel(conversation.status, text)}
            </AdminBadge>
            <span className={styles.spStatusDivider}>·</span>
            <span className={styles.spStatusMeta}>{sourceLabel(conversation.source, text)}</span>
            {conversationSla.waitLabel ? (
              <>
                <span className={styles.spStatusDivider}>·</span>
                <span
                  className={`${styles.spStatusMeta} ${conversationSla.level === "critical" || conversationSla.level === "risk" ? styles.spStatusMetaUrgent : ""}`}
                >
                  ⏱ {conversationSla.waitLabel}
                </span>
              </>
            ) : null}
          </div>

          {/* ── Workflow actions ─────────────────────────────── */}
          <div className={styles.spActionsBlock}>
            {showResolveConfirm ? (
              <div className={styles.spConfirmBox}>
                <span className={styles.spConfirmText}>
                  {locale === "ru" ? "Закрыть обращение?" : "Close conversation?"}
                </span>
                <div className={styles.spConfirmActions}>
                  <Button
                    variant="primary"
                    size="sm"
                    onClick={() => void confirmResolveConversation()}
                    disabled={!canManageSupportWorkspace || statusMutation.isPending}
                  >
                    {locale === "ru" ? "Закрыть" : "Close"}
                  </Button>
                  <Button
                    variant="secondary"
                    size="sm"
                    onClick={() => setShowResolveConfirm(false)}
                  >
                    {locale === "ru" ? "Отмена" : "Cancel"}
                  </Button>
                </div>
              </div>
            ) : (
              <div className={styles.spActionGrid}>
                {primaryStatusAction ? (
                  <Button
                    variant="primary"
                    size="sm"
                    className={styles.spActionFull}
                    onClick={() => {
                      requestStatusChange(primaryStatusAction.status);
                    }}
                    disabled={
                      !canManageSupportWorkspace ||
                      statusMutation.isPending ||
                      conversation.status === primaryStatusAction.status
                    }
                  >
                    {primaryStatusAction.label}
                  </Button>
                ) : null}
              </div>
            )}
            {secondaryStatusActions.length ? (
              <div className={styles.spActionGrid}>
                {secondaryStatusActions.map((action) => (
                  <Button
                    key={action.status}
                    variant="secondary"
                    size="sm"
                    className={styles.spActionFull}
                    onClick={() => requestStatusChange(action.status)}
                    disabled={
                      !canManageSupportWorkspace ||
                      statusMutation.isPending ||
                      conversation.status === action.status
                    }
                  >
                    {action.label}
                  </Button>
                ))}
              </div>
            ) : null}
            {destructiveStatusAction ? (
              <Button
                variant="danger"
                size="sm"
                className={styles.spActionFull}
                onClick={() => requestStatusChange(destructiveStatusAction.status)}
                disabled={
                  !canManageSupportWorkspace ||
                  statusMutation.isPending ||
                  conversation.status === destructiveStatusAction.status
                }
              >
                {destructiveStatusAction.label}
              </Button>
            ) : null}
          </div>

          {/* ── Tab navigation ───────────────────────────────── */}
          <div className={styles.spTabNav} role="tablist">
            {sidePanelTabs.map((tab) => (
              <button
                key={tab.value}
                type="button"
                role="tab"
                aria-selected={activeSidePanelTab === tab.value}
                className={`${styles.spTabBtn} ${activeSidePanelTab === tab.value ? styles.spTabBtnActive : ""}`}
                onClick={() => setActiveSidePanelTab(tab.value)}
              >
                {tab.label}
              </button>
            ))}
          </div>

          {/* ── Overview tab ─────────────────────────────────── */}
          {activeSidePanelTab === "user" ? (
            <div className={styles.spContent}>
              {/* Scenario / generation context pills */}
              {hasTopMetrics ? (
                <div className={styles.spSection}>
                  <span className={styles.spSectionLabel}>{text.supportAiContextTitle}</span>
                  <div className={styles.spKvList}>
                    {conversation.assistantScenario ? (
                      <div className={styles.spKvRow}>
                        <span>{text.supportAssistantScenarioLabel}</span>
                        <strong>
                          {formatSafeSupportDisplay(conversation.assistantScenario, "—", 120)}
                        </strong>
                      </div>
                    ) : null}
                    {conversation.relatedGenerationId ? (
                      <div className={styles.spKvRow}>
                        <span>{locale === "ru" ? "Генерация" : "Generation"}</span>
                        <strong>{shortId(conversation.relatedGenerationId)}</strong>
                      </div>
                    ) : null}
                  </div>
                </div>
              ) : null}

              {/* User stats */}
              <div className={styles.spSection}>
                <span className={styles.spSectionLabel}>
                  {locale === "ru" ? "Пользователь" : "User"}
                </span>
                <div className={styles.spKvList}>
                  {canViewSubjectUserContext ? (
                    <>
                      <div className={styles.spKvRow}>
                        <span>{text.supportPlanLabel}</span>
                        <strong>{isUserPremium ? text.premiumLabel : text.freeLabel}</strong>
                      </div>
                      <div className={styles.spKvRow}>
                        <span>{text.supportAccountAgeLabel}</span>
                        <strong>{formatAccountAge(accountCreatedAt, locale)}</strong>
                      </div>
                    </>
                  ) : null}
                  <div className={styles.spKvRow}>
                    <span>{text.supportMessagesCount}</span>
                    <strong>{String(conversation.messages.length)}</strong>
                  </div>
                  {canViewSubjectUserContext ? (
                    <>
                      <div className={styles.spKvRow}>
                        <span>{text.supportPurchasesLabel}</span>
                        <strong>{String(totalPurchases)}</strong>
                      </div>
                      <div className={styles.spKvRow}>
                        <span>{tokenBalanceLabel}</span>
                        <strong>{String(analyticsQuery.data?.summary.walletBalance ?? 0)}</strong>
                      </div>
                      <div className={styles.spKvRow}>
                        <span>{text.supportGenerationErrorsTitle}</span>
                        <strong>
                          {String(analyticsQuery.data?.summary.failedGenerations ?? 0)}
                        </strong>
                      </div>
                    </>
                  ) : null}
                </div>
              </div>

              {/* Quick links */}
              <div className={styles.spLinksRow}>
                {canViewSubjectUserContext ? (
                  <>
                    <Link
                      href={
                        isSubjectUserDeleted
                          ? `/${locale}/support/${encodeURIComponent(conversation.conversationId)}`
                          : `/${locale}/users/${encodeURIComponent(conversation.initiatorUserId)}`
                      }
                      className={styles.spLinkBtn}
                      aria-disabled={isSubjectUserDeleted}
                      onClick={(event) => {
                        if (isSubjectUserDeleted) {
                          event.preventDefault();
                        }
                      }}
                    >
                      ↗{" "}
                      {isSubjectUserDeleted
                        ? locale === "ru"
                          ? "Профиль недоступен"
                          : "Profile unavailable"
                        : locale === "ru"
                          ? "Профиль"
                          : "Profile"}
                    </Link>
                    <Link href={`/${locale}/economy`} className={styles.spLinkBtn}>
                      ↗ {locale === "ru" ? "Платежи" : "Payments"}
                    </Link>
                  </>
                ) : null}
                <button
                  type="button"
                  className={styles.spLinkBtn}
                  onClick={() => setActiveSidePanelTab("activity")}
                >
                  {locale === "ru" ? "Активность →" : "Activity →"}
                </button>
              </div>

              {/* Conversation meta */}
              <div className={styles.spSection}>
                <span className={styles.spSectionLabel}>{text.supportConversationMetaTitle}</span>
                <div className={styles.spKvList}>
                  <div className={styles.spKvRow}>
                    <span>{text.supportAssistantSourceLabel}</span>
                    <strong>{sourceLabel(conversation.source, text)}</strong>
                  </div>
                  <div className={styles.spKvRow}>
                    <span>{text.supportAssignedTo}</span>
                    <strong>
                      {formatSafeSupportDisplay(
                        conversation.assignedAdminDisplayName,
                        text.supportUnassigned,
                        72
                      )}
                    </strong>
                  </div>
                  <div className={styles.spKvRow}>
                    <span>{text.createdAtLabel}</span>
                    <strong>{formatDateTime(conversation.createdAtUtc, locale)}</strong>
                  </div>
                  <div className={styles.spKvRow}>
                    <span>{text.supportWaitingLabel}</span>
                    <strong>{conversationSla.waitLabel}</strong>
                  </div>
                  {accountCreatedAt ? (
                    <div className={styles.spKvRow}>
                      <span>{locale === "ru" ? "Дата регистрации" : "Registered"}</span>
                      <strong>{formatDateTime(accountCreatedAt, locale)}</strong>
                    </div>
                  ) : null}
                </div>
              </div>

              {/* PetMagic context */}
              {canViewSubjectUserContext ? (
                <div className={styles.spSection}>
                  <span className={styles.spSectionLabel}>{text.supportAiContextTitle}</span>
                  <SidePanelAsyncState
                    isLoading={
                      analyticsQuery.isLoading ||
                      purchasesQuery.isLoading ||
                      subscriptionQuery.isLoading
                    }
                    isError={contextLoadFailed}
                    hasContent={Boolean(analyticsQuery.data)}
                    loadingTitle={text.loading}
                    errorTitle={text.supportContextLoadError}
                    isRetrying={
                      !canRetrySubjectUserContext ||
                      analyticsQuery.isFetching ||
                      purchasesQuery.isFetching ||
                      subscriptionQuery.isFetching
                    }
                    retryLabel={text.supportRetryAction}
                    onRetry={() => {
                      if (!canRetrySubjectUserContext) {
                        return;
                      }

                      void Promise.all([
                        analyticsQuery.refetch(),
                        purchasesQuery.refetch(),
                        subscriptionQuery.refetch(),
                      ]).catch(() => undefined);
                    }}
                    emptyTitle={text.supportHistoryEmpty}
                  >
                    <div className={styles.spKvList}>
                      <div className={styles.spKvRow}>
                        <span>{text.supportLastPaymentLabel}</span>
                        <strong>{formatDateTime(lastUserPurchaseAtUtc, locale)}</strong>
                      </div>
                      <div className={styles.spKvRow}>
                        <span>{text.supportLastGenerationLabel}</span>
                        <strong>
                          {formatDateTime(analyticsQuery.data?.summary.lastGenerationAtUtc, locale)}
                        </strong>
                      </div>
                      <div className={styles.spKvRow}>
                        <span>{locale === "ru" ? "Статус подписки" : "Subscription"}</span>
                        <strong>{subscriptionStatusLabel}</strong>
                      </div>
                      <div className={styles.spKvRow}>
                        <span>{locale === "ru" ? "Тариф" : "Plan"}</span>
                        <strong>
                          {formatSafeSupportDisplay(
                            subscriptionQuery.data?.planName,
                            isUserPremium ? text.premiumLabel : text.freeLabel,
                            96
                          )}
                        </strong>
                      </div>
                    </div>
                  </SidePanelAsyncState>
                </div>
              ) : null}

              {canManageSubjectUser ? (
                <div className={styles.spDangerDisclosure}>
                  <button
                    type="button"
                    className={styles.spDangerTrigger}
                    onClick={() => setShowDangerousActions((v) => !v)}
                    disabled={isSubjectUserDeleted}
                  >
                    <span>{showDangerousActions ? "▾" : "▸"}</span>
                    {locale === "ru" ? "Опасные действия" : "Dangerous actions"}
                  </button>
                  {isSubjectUserDeleted ? (
                    <span className={styles.subtle}>
                      {locale === "ru"
                        ? "Пользователь удален: действия модерации недоступны."
                        : "User is deleted: moderation actions are unavailable."}
                    </span>
                  ) : null}
                  {showDangerousActions ? (
                    <div className={styles.spDangerActions}>
                      <button
                        type="button"
                        className="ui-button ui-button--danger ui-button--sm"
                        onClick={() =>
                          setPendingUserAction(isUserActive ? "deactivate" : "activate")
                        }
                        disabled={isModerationPending}
                      >
                        {isUserActive ? text.deactivate : text.activate}
                      </button>
                      <button
                        type="button"
                        className="ui-button ui-button--secondary ui-button--sm"
                        onClick={() =>
                          setPendingUserAction(isUserPremium ? "revokePremium" : "grantPremium")
                        }
                        disabled={isModerationPending}
                      >
                        {isUserPremium ? text.removePremium : text.makePremium}
                      </button>
                    </div>
                  ) : null}
                </div>
              ) : null}
            </div>
          ) : null}

          {activeSidePanelTab === "activity" ? (
            <div className={styles.sidePanelContent}>
              <SectionBlock title={text.supportRecentGenerationsTitle}>
                <SidePanelAsyncState
                  isLoading={analyticsQuery.isLoading}
                  isError={analyticsQuery.isError}
                  hasContent={Boolean(analyticsQuery.data?.recentGenerations.length)}
                  loadingTitle={text.loading}
                  errorTitle={text.supportLoadError}
                  emptyTitle={text.userNoGenerations}
                >
                  <div className={styles.timelineList}>
                    {(analyticsQuery.data?.recentGenerations ?? [])
                      .slice(0, 4)
                      .map((generation) => (
                        <TimelineCard
                          key={generation.generationId}
                          title={formatSafeSupportDisplay(generation.templateTitle, "—", 120)}
                          timestampLabel={formatRelativeTime(
                            generation.completedAtUtc ?? generation.createdAtUtc,
                            locale
                          )}
                          meta={
                            <>
                              <AdminBadge tone={toneForGeneration(generation.status)}>
                                {formatSafeSupportDisplay(generation.status, "—", 48)}
                              </AdminBadge>
                              <span
                                className={styles.subtle}
                              >{`${generation.tokenCost} spark`}</span>
                            </>
                          }
                          details={
                            generation.failureCode
                              ? formatSafeSupportDisplay(generation.failureCode, "—", 120)
                              : undefined
                          }
                        />
                      ))}
                  </div>
                </SidePanelAsyncState>
              </SectionBlock>

              <SectionBlock title={text.supportGenerationErrorsTitle}>
                <SidePanelAsyncState
                  isLoading={analyticsQuery.isLoading}
                  isError={analyticsQuery.isError}
                  hasContent={recentFailures.length > 0 || failedGenerations.length > 0}
                  loadingTitle={text.loading}
                  errorTitle={text.supportLoadError}
                  emptyTitle={text.supportNoGenerationErrors}
                >
                  {recentFailures.length ? (
                    <div className={styles.timelineList}>
                      {recentFailures.map((item) => (
                        <TimelineCard
                          key={item.failureCode}
                          title={formatSafeSupportDisplay(item.failureCode, "—", 120)}
                          timestampLabel={formatRelativeTime(item.lastOccurredAtUtc, locale)}
                          details={`${text.supportOccurrencesLabel}: ${item.count}`}
                        />
                      ))}
                    </div>
                  ) : (
                    <div className={styles.timelineList}>
                      {failedGenerations.slice(0, 3).map((generation) => (
                        <TimelineCard
                          key={generation.generationId}
                          title={formatSafeSupportDisplay(generation.templateTitle, "—", 120)}
                          timestampLabel={formatRelativeTime(
                            generation.completedAtUtc ?? generation.createdAtUtc,
                            locale
                          )}
                          details={formatSafeSupportDisplay(
                            generation.failureCode ?? generation.status,
                            "—",
                            120
                          )}
                        />
                      ))}
                    </div>
                  )}
                </SidePanelAsyncState>
              </SectionBlock>

              <SectionBlock title={text.supportRecentPurchasesTitle}>
                <SidePanelAsyncState
                  isLoading={purchasesQuery.isLoading}
                  isError={purchasesQuery.isError}
                  hasContent={recentUserPurchases.length > 0}
                  loadingTitle={text.loading}
                  errorTitle={text.supportLoadError}
                  emptyTitle={text.supportNoPurchases}
                >
                  <div className={styles.timelineList}>
                    {recentUserPurchases.slice(0, 6).map((purchase) => (
                      <TimelineCard
                        key={purchase.orderId}
                        title={formatMoney(purchase.priceAmount, purchase.currencyCode, locale)}
                        timestampLabel={formatRelativeTime(
                          purchase.confirmedAtUtc ?? purchase.createdAtUtc,
                          locale
                        )}
                        meta={
                          <>
                            <AdminBadge tone={purchaseStatusTone(purchase.status)}>
                              {formatSafeSupportDisplay(purchase.status, "—", 48)}
                            </AdminBadge>
                            <span
                              className={styles.subtle}
                            >{`${purchase.sparkToGrant} spark`}</span>
                          </>
                        }
                        details={formatSafeSupportDisplay(purchase.paymentProvider, "—", 48)}
                      />
                    ))}
                  </div>
                </SidePanelAsyncState>
              </SectionBlock>
            </div>
          ) : null}

          {activeSidePanelTab === "dialog" ? (
            <div className={styles.sidePanelContent}>
              <div className={styles.statusOverviewCard}>
                <div className={styles.statusOverviewHeader}>
                  <AdminBadge tone={responderState.tone}>{responderState.label}</AdminBadge>
                  <AdminBadge tone="neutral">
                    {`${text.supportPriorityLabel}: ${priorityLabel(conversation.priority, text)}`}
                  </AdminBadge>
                </div>
                <div className={styles.detailGrid}>
                  <div className={styles.detailRow}>
                    <span>{text.supportAssignedTo}</span>
                    <strong>
                      {formatSafeSupportDisplay(
                        conversation.assignedAdminDisplayName,
                        text.supportUnassigned,
                        72
                      )}
                    </strong>
                  </div>
                  <div className={styles.detailRow}>
                    <span>{text.createdAtLabel}</span>
                    <strong>{formatDateTime(conversation.createdAtUtc, locale)}</strong>
                  </div>
                  <div className={styles.detailRow}>
                    <span>{text.supportLastMessage}</span>
                    <strong>
                      {formatDateTime(
                        conversation.lastMessageAtUtc ?? conversation.createdAtUtc,
                        locale
                      )}
                    </strong>
                  </div>
                  <div className={styles.detailRow}>
                    <span>{text.supportLastSeenLabel}</span>
                    <strong>{formatRelativeTime(lastActivityAtUtc, locale)}</strong>
                  </div>
                </div>
              </div>

              <SectionBlock title={text.supportTimelineTitle}>
                {conversationTimeline.length ? (
                  <div className={styles.timelineList}>
                    {conversationTimeline.map((item) => (
                      <TimelineCard
                        key={item.id}
                        title={item.title}
                        timestampLabel={formatRelativeTime(item.occurredAtUtc, locale)}
                        meta={
                          <AdminBadge tone={item.tone}>
                            {formatDateTime(item.occurredAtUtc, locale)}
                          </AdminBadge>
                        }
                        details={item.subtitle}
                      />
                    ))}
                  </div>
                ) : (
                  <AdminStateCard tone="info" title={text.supportHistoryEmpty} />
                )}
              </SectionBlock>
            </div>
          ) : null}

          {activeSidePanelTab === "attachments" ? (
            <div className={styles.sidePanelContent}>
              {attachmentItems.length === 0 ? (
                <AdminStateCard
                  tone="info"
                  title={locale === "ru" ? "Вложений пока нет." : "No attachments yet."}
                />
              ) : (
                <div className={styles.attachmentList}>
                  {attachmentItems.map((message) => (
                    <div key={message.messageId} className={styles.attachmentListItem}>
                      {hasImageAttachment(message) ? (
                        <button
                          type="button"
                          className={styles.attachmentListThumbButton}
                          onClick={() => onOpenAttachmentPreview?.(message)}
                        >
                          <SupportSecureMedia
                            url={message.attachmentUrl!}
                            kind="image"
                            alt={formatSafeSupportDisplay(
                              message.attachmentFileName ?? message.body,
                              "Attachment",
                              120
                            )}
                            width={76}
                            height={76}
                            className={styles.attachmentListThumb}
                            logContext={{
                              messageId: message.messageId,
                              mimeType: getPrimaryAttachmentMimeType(message),
                            }}
                          />
                        </button>
                      ) : (
                        <span className={styles.attachmentPreviewFileIcon}>FILE</span>
                      )}
                      <div className={styles.attachmentListMeta}>
                        <strong>
                          {formatSafeSupportDisplay(
                            message.attachmentFileName ?? message.body,
                            "Attachment",
                            120
                          )}
                        </strong>
                        <span>{formatDateTime(message.createdAtUtc, locale)}</span>
                        <span>{formatFileSize(message.attachmentFileSizeBytes, locale)}</span>
                      </div>
                      <div className={styles.attachmentListActions}>
                        {hasImageAttachment(message) ? (
                          <button
                            type="button"
                            className="ui-button ui-button--secondary ui-button--sm"
                            onClick={() => onOpenAttachmentPreview?.(message)}
                          >
                            {locale === "ru" ? "Просмотр" : "Preview"}
                          </button>
                        ) : (
                          <button
                            type="button"
                            onClick={() => void openAttachmentBlob(message)}
                            disabled={!canManageSupportWorkspace || pendingAttachmentActionKey !== null}
                            className="ui-button ui-button--secondary ui-button--sm"
                          >
                            {locale === "ru" ? "Открыть" : "Open"}
                          </button>
                        )}
                        <button
                          type="button"
                          onClick={() => void downloadAttachmentBlob(message)}
                          disabled={!canManageSupportWorkspace || pendingAttachmentActionKey !== null}
                          className="ui-button ui-button--ghost ui-button--sm"
                        >
                          {locale === "ru" ? "Скачать" : "Download"}
                        </button>
                        <button
                          type="button"
                          className="ui-button ui-button--ghost ui-button--sm"
                          onClick={() => onJumpToMessage?.(message.messageId)}
                        >
                          {locale === "ru" ? "К сообщению" : "Jump"}
                        </button>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          ) : null}
        </AdminCard>
      </div>
      <ConfirmationDialog
        open={pendingUserActionCopy !== null}
        title={pendingUserActionCopy?.title ?? ""}
        description={pendingUserActionCopy?.description ?? ""}
        confirmLabel={pendingUserActionCopy?.confirmLabel ?? ""}
        cancelLabel={locale === "ru" ? "Отмена" : "Cancel"}
        isSubmitting={isModerationPending}
        tone={
          pendingUserAction === "activate" || pendingUserAction === "grantPremium"
            ? "primary"
            : "danger"
        }
        onCancel={() => {
          if (!isModerationPending) {
            setPendingUserAction(null);
          }
        }}
        onConfirm={confirmPendingUserAction}
      />
    </>
  );
}

function purchaseStatusTone(status: string) {
  const normalized = status.trim().toLowerCase();
  if (normalized === "succeeded" || normalized === "paid" || normalized === "completed") {
    return "success" as const;
  }

  if (normalized === "failed" || normalized === "canceled" || normalized === "cancelled") {
    return "danger" as const;
  }

  if (normalized === "pending") {
    return "warning" as const;
  }

  return "neutral" as const;
}

function getResponderState(status: string, locale: Locale): ResponderState {
  const isRu = locale === "ru";
  switch (status) {
    case "New":
      return {
        label: isRu ? "Нужен ответ оператора" : "Operator reply required",
        tone: "danger",
      };
    case "InProgress":
      return {
        label: isRu ? "Диалог в работе" : "Conversation in progress",
        tone: "neutral",
      };
    case "WaitingForUser":
      return {
        label: isRu ? "Ожидаем пользователя" : "Waiting for user",
        tone: "success",
      };
    case "Closed":
      return {
        label: isRu ? "Диалог закрыт" : "Conversation closed",
        tone: "neutral",
      };
    default:
      return {
        label: isRu ? "Требуется ответ оператора" : "Operator reply required",
        tone: "neutral",
      };
  }
}

function getPendingUserActionCopy(action: PendingUserAction, userLabel: string, locale: Locale) {
  const target = userLabel.trim() || (locale === "ru" ? "пользователя" : "this user");

  if (locale === "ru") {
    switch (action) {
      case "activate":
        return {
          title: "Разблокировать пользователя?",
          description: `Доступ для ${target} будет восстановлен. Действие будет записано в audit log.`,
          confirmLabel: "Разблокировать",
        };
      case "deactivate":
        return {
          title: "Заблокировать пользователя?",
          description: `Пользователь ${target} потеряет доступ к приложению. Действие будет записано в audit log.`,
          confirmLabel: "Заблокировать",
        };
      case "grantPremium":
        return {
          title: "Включить premium?",
          description: `Premium для ${target} будет включен через admin-инструменты. Проверьте основание перед подтверждением.`,
          confirmLabel: "Включить",
        };
      case "revokePremium":
        return {
          title: "Отключить premium?",
          description: `Premium для ${target} будет отключен через admin-инструменты. Действие будет записано в audit log.`,
          confirmLabel: "Отключить",
        };
    }
  }

  switch (action) {
    case "activate":
      return {
        title: "Unblock user?",
        description: `Access for ${target} will be restored. The audit log will record this action.`,
        confirmLabel: "Unblock",
      };
    case "deactivate":
      return {
        title: "Block user?",
        description: `${target} will lose app access. The audit log will record this action.`,
        confirmLabel: "Block",
      };
    case "grantPremium":
      return {
        title: "Grant premium?",
        description: `Premium for ${target} will be granted through admin tools. Verify the reason before confirming.`,
        confirmLabel: "Grant",
      };
    case "revokePremium":
      return {
        title: "Revoke premium?",
        description: `Premium for ${target} will be revoked through admin tools. The audit log will record this action.`,
        confirmLabel: "Revoke",
      };
  }
}
