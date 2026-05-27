import Image from "next/image";
import Link from "next/link";
import { useMemo, useState } from "react";

import { AdminBadge, AdminCard, AdminStateCard } from "@/components/admin/admin-primitives";
import {
  formatAccountAge,
  formatDateTime,
  formatFileSize,
  formatMoney,
  formatRelativeTime,
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
import {
  priorityLabel,
  statusLabel,
  toneForGeneration,
  toneForStatus,
} from "@/components/support/support-status-helpers";
import { useSupportConversationController } from "@/components/support/use-support-conversation-controller";
import { Button } from "@/components/ui/button";
import { type AdminSupportMessage } from "@/lib/api-client";
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

export function SupportConversationSidePanel({
  locale,
  controller,
  onJumpToMessage,
  onOpenAttachmentPreview,
}: SupportConversationSidePanelProps) {
  const [showAdvancedActions, setShowAdvancedActions] = useState(false);
  const [showResolveConfirm, setShowResolveConfirm] = useState(false);

  const {
    activeSidePanelTab,
    accountCreatedAt,
    analyticsQuery,
    assignmentMutation,
    conversation,
    conversationTimeline,
    destructiveStatusAction,
    failedGenerations,
    isAssignedToCurrentAdmin,
    isSidePanelOpen,
    purchasesQuery,
    primaryStatusAction,
    recentFailures,
    recentUserPurchases,
    lastUserPurchaseAtUtc,
    lastActivityAtUtc,
    sessionUserId,
    secondaryStatusActions,
    setUserActiveMutation,
    setUserPremiumMutation,
    subscriptionQuery,
    setActiveSidePanelTab,
    sidePanelDescription,
    sidePanelTabs,
    sidePanelTitle,
    statusMutation,
    text,
    totalPurchases,
    userDisplayName,
    userQuery,
  } = controller;

  const attachmentItems = useMemo(
    () =>
      (conversation?.messages ?? [])
        .filter((message) => hasAttachment(message))
        .slice()
        .reverse(),
    [conversation?.messages]
  );

  if (!isSidePanelOpen || !conversation) {
    return null;
  }

  const responderState = getResponderState(conversation.status, locale);
  const hasAdvancedActions = secondaryStatusActions.length > 0 || Boolean(destructiveStatusAction);
  const isUserActive = userQuery.data?.isActive ?? true;
  const isUserPremium = userQuery.data?.isPremium ?? false;
  const isModerationPending = setUserActiveMutation.isPending || setUserPremiumMutation.isPending;
  const subscriptionStatusLabel =
    subscriptionQuery.data?.status ?? (locale === "ru" ? "Нет подписки" : "No subscription");
  const tokenBalanceLabel = locale === "ru" ? "Баланс токенов" : "Token balance";

  return (
    <div className={styles.sidePane}>
      <AdminCard className={`${styles.sideCard} ${styles.sidePanelCard}`}>
        <div className={styles.sidePanelTopbar}>
          <div className={styles.paneTitleGroup}>
            <span className={styles.paneEyebrow}>{text.supportConversationDetailsTitle}</span>
            <h2 className={styles.paneTitle}>{sidePanelTitle}</h2>
            {sidePanelDescription ? (
              <p className={styles.paneDescription}>{sidePanelDescription}</p>
            ) : null}
          </div>
          <div className={styles.sidePanelTabs}>
            {sidePanelTabs.map(({ value, label }) => (
              <button
                key={value}
                type="button"
                className={`${styles.sidePanelTab} ${activeSidePanelTab === value ? styles.sidePanelTabActive : ""}`}
                onClick={() => setActiveSidePanelTab(value)}
              >
                {label}
              </button>
            ))}
          </div>
        </div>

        {activeSidePanelTab === "user" ? (
          <div className={styles.sidePanelContent}>
            <div className={styles.statusOverviewCard}>
              <div className={styles.statusOverviewHeader}>
                <AdminBadge tone={toneForStatus(conversation.status)}>
                  {statusLabel(conversation.status, text)}
                </AdminBadge>
              </div>
              <div className={styles.workflowPrimaryRow}>
                <Button
                  variant="secondary"
                  className={styles.workflowSecondaryButton}
                  onClick={() =>
                    assignmentMutation.mutate(isAssignedToCurrentAdmin ? null : sessionUserId)
                  }
                  disabled={assignmentMutation.isPending || !sessionUserId}
                >
                  {isAssignedToCurrentAdmin ? text.supportUnassign : text.supportAssignToMe}
                </Button>
                {primaryStatusAction ? (
                  showResolveConfirm ? (
                    <div className={styles.resolveConfirmBox}>
                      <span className={styles.resolveConfirmText}>
                        {locale === "ru" ? "Закрыть обращение?" : "Close conversation?"}
                      </span>
                      <div className={styles.resolveConfirmActions}>
                        <Button
                          variant="primary"
                          size="sm"
                          onClick={() => {
                            setShowResolveConfirm(false);
                            statusMutation.mutate(primaryStatusAction.status);
                          }}
                          disabled={statusMutation.isPending}
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
                    <Button
                      variant="primary"
                      className={styles.workflowPrimaryButton}
                      onClick={() => {
                        const isDestructive =
                          primaryStatusAction.status === "Resolved" ||
                          primaryStatusAction.status === "Closed";
                        if (isDestructive) {
                          setShowResolveConfirm(true);
                        } else {
                          statusMutation.mutate(primaryStatusAction.status);
                        }
                      }}
                      disabled={
                        statusMutation.isPending ||
                        conversation.status === primaryStatusAction.status
                      }
                    >
                      {primaryStatusAction.label}
                    </Button>
                  )
                ) : null}
              </div>
              {hasAdvancedActions ? (
                <div className={styles.workflowSecondaryGrid}>
                  <Button
                    variant="ghost"
                    className={styles.workflowSecondaryButton}
                    onClick={() => setShowAdvancedActions((current) => !current)}
                  >
                    {showAdvancedActions
                      ? locale === "ru"
                        ? "Скрыть дополнительные действия"
                        : "Hide additional actions"
                      : locale === "ru"
                        ? "Показать дополнительные действия"
                        : "Show additional actions"}
                  </Button>
                </div>
              ) : null}
              {showAdvancedActions && secondaryStatusActions.length ? (
                <div className={styles.workflowSecondaryGrid}>
                  {secondaryStatusActions.map((action) => (
                    <Button
                      key={action.status}
                      variant="secondary"
                      className={styles.workflowSecondaryButton}
                      onClick={() => statusMutation.mutate(action.status)}
                      disabled={statusMutation.isPending || conversation.status === action.status}
                    >
                      {action.label}
                    </Button>
                  ))}
                </div>
              ) : null}
              {showAdvancedActions && destructiveStatusAction ? (
                <div className={styles.workflowDangerZone}>
                  <Button
                    variant="danger"
                    className={styles.workflowDangerButton}
                    onClick={() => statusMutation.mutate(destructiveStatusAction.status)}
                    disabled={
                      statusMutation.isPending ||
                      conversation.status === destructiveStatusAction.status
                    }
                  >
                    {destructiveStatusAction.label}
                  </Button>
                </div>
              ) : null}
            </div>

            {conversation.source === "MobileAssistant" ? (
              <div className={styles.metricsGrid}>
                <div className={styles.metricTile}>
                  <span>{text.supportAssistantSourceLabel}</span>
                  <strong>{text.supportAssistantMobileLabel}</strong>
                </div>
                {conversation.assistantScenario ? (
                  <div className={styles.metricTile}>
                    <span>{text.supportAssistantScenarioLabel}</span>
                    <strong>{conversation.assistantScenario}</strong>
                  </div>
                ) : null}
              </div>
            ) : null}

            <div className={styles.userSummaryHeader}>
              <div className={styles.userCard}>
                <span className={styles.avatarHero}>{initialsFor(userDisplayName)}</span>
                <div className={styles.userCardBody}>
                  <strong>{userDisplayName}</strong>
                  <span>{conversation.userEmail}</span>
                  <span>{`User ID: ${shortId(conversation.initiatorUserId)}`}</span>
                </div>
              </div>
            </div>

            <div className={styles.quickLinksRow}>
              <Link
                href={`/${locale}/users/${conversation.initiatorUserId}`}
                className="ui-button ui-button--secondary ui-button--sm"
              >
                {locale === "ru" ? "Открыть профиль" : "Open profile"}
              </Link>
              <Link
                href={`/${locale}/economy`}
                className="ui-button ui-button--secondary ui-button--sm"
              >
                {locale === "ru" ? "Открыть платежи" : "Open payments"}
              </Link>
              <button
                type="button"
                className="ui-button ui-button--ghost ui-button--sm"
                onClick={() => setActiveSidePanelTab("activity")}
              >
                {locale === "ru"
                  ? "Покупки / Генерации / Ошибки"
                  : "Purchases / Generations / Errors"}
              </button>
            </div>

            <div className={styles.dangerActionBlock}>
              <span>{locale === "ru" ? "Опасные действия" : "Danger zone"}</span>
              <div className={styles.quickLinksRow}>
                <button
                  type="button"
                  className="ui-button ui-button--danger ui-button--sm"
                  onClick={() => setUserActiveMutation.mutate(!isUserActive)}
                  disabled={isModerationPending}
                >
                  {isUserActive ? text.deactivate : text.activate}
                </button>
                <button
                  type="button"
                  className="ui-button ui-button--secondary ui-button--sm"
                  onClick={() => setUserPremiumMutation.mutate(!isUserPremium)}
                  disabled={isModerationPending}
                >
                  {isUserPremium ? text.removePremium : text.makePremium}
                </button>
              </div>
            </div>

            <div className={styles.metricsGrid}>
              <div className={styles.metricTile}>
                <span>{text.supportPlanLabel}</span>
                <strong>{userQuery.data?.isPremium ? text.premiumLabel : text.freeLabel}</strong>
              </div>
              <div className={styles.metricTile}>
                <span>{text.supportAccountAgeLabel}</span>
                <strong>{formatAccountAge(accountCreatedAt, locale)}</strong>
              </div>
              <div className={styles.metricTile}>
                <span>{text.supportMessagesCount}</span>
                <strong>{String(conversation.messages.length)}</strong>
              </div>
              <div className={styles.metricTile}>
                <span>{text.supportPurchasesLabel}</span>
                <strong>{String(totalPurchases)}</strong>
              </div>
              <div className={styles.metricTile}>
                <span>{tokenBalanceLabel}</span>
                <strong>{String(analyticsQuery.data?.summary.walletBalance ?? 0)}</strong>
              </div>
              <div className={styles.metricTile}>
                <span>{text.supportGenerationErrorsTitle}</span>
                <strong>{String(analyticsQuery.data?.summary.failedGenerations ?? 0)}</strong>
              </div>
            </div>

            <SectionBlock title={text.supportAiContextTitle}>
              <SidePanelAsyncState
                isLoading={
                  analyticsQuery.isLoading || purchasesQuery.isLoading || subscriptionQuery.isLoading
                }
                isError={
                  analyticsQuery.isError || purchasesQuery.isError || subscriptionQuery.isError
                }
                hasContent={Boolean(analyticsQuery.data)}
                loadingTitle={text.loading}
                errorTitle={text.supportLoadError}
                emptyTitle={text.supportHistoryEmpty}
              >
                <div className={styles.detailGrid}>
                  <div className={styles.detailRow}>
                    <span>{text.supportLastPaymentLabel}</span>
                    <strong>{formatDateTime(lastUserPurchaseAtUtc, locale)}</strong>
                  </div>
                  <div className={styles.detailRow}>
                    <span>{text.supportLastGenerationLabel}</span>
                    <strong>
                      {formatDateTime(analyticsQuery.data?.summary.lastGenerationAtUtc, locale)}
                    </strong>
                  </div>
                  <div className={styles.detailRow}>
                    <span>{locale === "ru" ? "Статус подписки" : "Subscription status"}</span>
                    <strong>{subscriptionStatusLabel}</strong>
                  </div>
                  <div className={styles.detailRow}>
                    <span>{locale === "ru" ? "План подписки" : "Subscription plan"}</span>
                    <strong>
                      {subscriptionQuery.data?.planName ??
                        (userQuery.data?.isPremium ? text.premiumLabel : text.freeLabel)}
                    </strong>
                  </div>
                </div>
              </SidePanelAsyncState>
            </SectionBlock>

            <SectionBlock title={text.supportConversationMetaTitle}>
              <div className={styles.detailGrid}>
                <div className={styles.detailRow}>
                  <span>{text.supportAssignedTo}</span>
                  <strong>
                    {conversation.assignedAdminDisplayName?.trim() || text.supportUnassigned}
                  </strong>
                </div>
                <div className={styles.detailRow}>
                  <span>{text.createdAtLabel}</span>
                  <strong>{formatDateTime(conversation.createdAtUtc, locale)}</strong>
                </div>
                <div className={styles.detailRow}>
                  <span>{locale === "ru" ? "Дата регистрации" : "Registration date"}</span>
                  <strong>{formatDateTime(accountCreatedAt, locale)}</strong>
                </div>
              </div>
            </SectionBlock>
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
                  {(analyticsQuery.data?.recentGenerations ?? []).slice(0, 4).map((generation) => (
                    <TimelineCard
                      key={generation.generationId}
                      title={generation.templateTitle}
                      timestampLabel={formatRelativeTime(
                        generation.completedAtUtc ?? generation.createdAtUtc,
                        locale
                      )}
                      meta={
                        <>
                          <AdminBadge tone={toneForGeneration(generation.status)}>
                            {generation.status}
                          </AdminBadge>
                          <span className={styles.subtle}>{`${generation.tokenCost} spark`}</span>
                        </>
                      }
                      details={generation.failureMessage || undefined}
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
                        title={item.failureCode}
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
                        title={generation.templateTitle}
                        timestampLabel={formatRelativeTime(
                          generation.completedAtUtc ?? generation.createdAtUtc,
                          locale
                        )}
                        details={
                          generation.failureMessage ?? generation.failureCode ?? generation.status
                        }
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
                            {purchase.status}
                          </AdminBadge>
                          <span className={styles.subtle}>{`${purchase.sparkToGrant} spark`}</span>
                        </>
                      }
                      details={purchase.paymentProvider}
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
                    {conversation.assignedAdminDisplayName?.trim() || text.supportUnassigned}
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
                        <Image
                          src={message.attachmentUrl!}
                          alt={message.attachmentFileName ?? message.body}
                          width={76}
                          height={76}
                          className={styles.attachmentListThumb}
                          unoptimized
                        />
                      </button>
                    ) : (
                      <span className={styles.attachmentPreviewFileIcon}>FILE</span>
                    )}
                    <div className={styles.attachmentListMeta}>
                      <strong>{message.attachmentFileName ?? message.body ?? "Attachment"}</strong>
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
                        <a
                          href={message.attachmentUrl!}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="ui-button ui-button--secondary ui-button--sm"
                        >
                          {locale === "ru" ? "Открыть" : "Open"}
                        </a>
                      )}
                      <a
                        href={message.attachmentUrl!}
                        download={message.attachmentFileName ?? "attachment"}
                        className="ui-button ui-button--ghost ui-button--sm"
                      >
                        {locale === "ru" ? "Скачать" : "Download"}
                      </a>
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
    case "WaitingForSupport":
      return {
        label: isRu ? "Требуется ответ администратора" : "Admin reply required",
        tone: "danger",
      };
    case "WaitingForUser":
      return {
        label: isRu ? "Ожидаем пользователя" : "Waiting for user",
        tone: "success",
      };
    default:
      return {
        label: isRu ? "Диалог в обработке" : "Conversation in progress",
        tone: "neutral",
      };
  }
}
