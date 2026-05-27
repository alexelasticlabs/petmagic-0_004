"use client";

import Link from "next/link";

import { AdminBadge } from "@/components/admin/admin-primitives";
import {
  formatAccountAge,
  formatDateTime,
  initialsFor,
  shortId,
} from "@/components/support/support-conversation-helpers";
import { SidePanelAsyncState } from "@/components/support/support-conversation-ui-primitives";
import styles from "@/components/support/support-page.module.css";
import {
  sourceLabel,
  statusLabel,
  toneForStatus,
} from "@/components/support/support-status-helpers";
import { useSupportConversationController } from "@/components/support/use-support-conversation-controller";
import { type Locale } from "@/lib/i18n";

type SupportInfoPanelProps = {
  locale: Locale;
  controller: ReturnType<typeof useSupportConversationController>;
};

export function SupportInfoPanel({ locale, controller }: SupportInfoPanelProps) {
  const {
    accountCreatedAt,
    analyticsQuery,
    conversation,
    conversationSla,
    lastUserPurchaseAtUtc,
    purchasesQuery,
    subscriptionQuery,
    text,
    totalPurchases,
    userDisplayName,
    userQuery,
  } = controller;

  if (!conversation) {
    return null;
  }

  const isUserPremium = userQuery.data?.isPremium ?? false;
  const contextLoadFailed =
    analyticsQuery.isError || purchasesQuery.isError || subscriptionQuery.isError;

  return (
    <div className={styles.infoPanelFlat}>
      <div className={styles.infoPanel}>
        {/* ── Информация об обращении ── */}
        <div className={styles.infoPanelSection}>
          <span className={styles.infoPanelSectionLabel}>
            {locale === "ru" ? "Обращение" : "Conversation"}
          </span>
          <div className={styles.infoPanelKvRow}>
            <span>{locale === "ru" ? "Статус" : "Status"}</span>
            <AdminBadge tone={toneForStatus(conversation.status)}>
              {statusLabel(conversation.status, text)}
            </AdminBadge>
          </div>
          <div className={styles.infoPanelKvRow}>
            <span>{text.supportAssistantSourceLabel}</span>
            <strong>{sourceLabel(conversation.source, text)}</strong>
          </div>
          <div className={styles.infoPanelKvRow}>
            <span>{text.createdAtLabel}</span>
            <strong>{formatDateTime(conversation.createdAtUtc, locale)}</strong>
          </div>
          {conversationSla.waitLabel ? (
            <div className={styles.infoPanelKvRow}>
              <span>{text.supportWaitingLabel}</span>
              <strong
                className={
                  conversationSla.level === "critical" ? styles.chatMetaSlaUrgent : undefined
                }
              >
                ⏱ {conversationSla.waitLabel}
              </strong>
            </div>
          ) : null}
          <div className={styles.infoPanelKvRow}>
            <span>{text.supportAssignedTo}</span>
            <strong>
              {conversation.assignedAdminDisplayName?.trim() || text.supportUnassigned}
            </strong>
          </div>
        </div>

        {/* ── Пользователь ── */}
        <div className={styles.infoPanelSection}>
          <span className={styles.infoPanelSectionLabel}>
            {locale === "ru" ? "Пользователь" : "User"}
          </span>
          <div className={styles.infoPanelUserCard}>
            <span className={styles.spAvatarMd} aria-hidden="true">
              {initialsFor(userDisplayName)}
            </span>
            <div className={styles.infoPanelUserMeta}>
              <strong className={styles.infoPanelUserName}>{userDisplayName}</strong>
              <span className={styles.infoPanelUserEmail}>{conversation.userEmail}</span>
              <span className={styles.infoPanelUserUserId}>
                ID: #{shortId(conversation.initiatorUserId)}
              </span>
            </div>
          </div>
          <div className={styles.infoPanelStatsGrid}>
            <div className={styles.infoPanelStatTile}>
              <span>{text.supportPlanLabel}</span>
              <strong>{isUserPremium ? text.premiumLabel : text.freeLabel}</strong>
            </div>
            <div className={styles.infoPanelStatTile}>
              <span>{locale === "ru" ? "Токены" : "Tokens"}</span>
              <strong>{String(analyticsQuery.data?.summary.walletBalance ?? 0)}</strong>
            </div>
            <div className={styles.infoPanelStatTile}>
              <span>{text.supportAccountAgeLabel}</span>
              <strong>{formatAccountAge(accountCreatedAt, locale)}</strong>
            </div>
            <div className={styles.infoPanelStatTile}>
              <span>{locale === "ru" ? "Покупки" : "Purchases"}</span>
              <strong>{String(totalPurchases)}</strong>
            </div>
          </div>
        </div>

        {/* ── Контекст PetMagic ── */}
        <div className={styles.infoPanelSection}>
          <span className={styles.infoPanelSectionLabel}>{text.supportAiContextTitle}</span>
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
            retryLabel={text.supportRetryAction}
            onRetry={() => {
              void Promise.all([
                analyticsQuery.refetch(),
                purchasesQuery.refetch(),
                subscriptionQuery.refetch(),
              ]);
            }}
            emptyTitle={text.supportHistoryEmpty}
          >
            <div className={styles.infoPanelKvRow}>
              <span>{locale === "ru" ? "Связанная генерация" : "Related generation"}</span>
              <strong>
                {conversation.relatedGenerationId
                  ? shortId(conversation.relatedGenerationId)
                  : "—"}
              </strong>
            </div>
            <div className={styles.infoPanelKvRow}>
              <span>{text.supportLastGenerationLabel}</span>
              <strong>
                {formatDateTime(analyticsQuery.data?.summary.lastGenerationAtUtc, locale)}
              </strong>
            </div>
            <div className={styles.infoPanelKvRow}>
              <span>{text.supportGenerationErrorsTitle}</span>
              <strong>{String(analyticsQuery.data?.summary.failedGenerations ?? 0)}</strong>
            </div>
            <div className={styles.infoPanelKvRow}>
              <span>{text.supportLastPaymentLabel}</span>
              <strong>{formatDateTime(lastUserPurchaseAtUtc, locale)}</strong>
            </div>
            <div className={styles.infoPanelKvRow}>
              <span>Premium</span>
              <AdminBadge tone={isUserPremium ? "success" : "neutral"}>
                {isUserPremium
                  ? locale === "ru"
                    ? "Активен"
                    : "Active"
                  : locale === "ru"
                    ? "Неактивен"
                    : "Inactive"}
              </AdminBadge>
            </div>
            <div className={styles.infoPanelKvRow}>
              <span>{locale === "ru" ? "Провайдер подписки" : "Subscription provider"}</span>
              <strong>{subscriptionQuery.data?.planName ?? "—"}</strong>
            </div>
          </SidePanelAsyncState>
        </div>

        <Link
          href={`/${locale}/users/${conversation.initiatorUserId}`}
          className={styles.infoPanelProfileLink}
        >
          {locale === "ru" ? "Открыть профиль пользователя" : "Open user profile"} ↗
        </Link>
      </div>
    </div>
  );
}
