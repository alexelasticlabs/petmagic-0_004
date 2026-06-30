"use client";

import {
  formatRelativeTime,
  formatSafeSupportDisplay,
} from "@/components/support/support-conversation-helpers";
import { getSupportConversationCopy } from "@/components/support/support-conversation.content";
import styles from "@/components/support/support-info-panel.module.css";
import type { Locale } from "@/lib/i18n";

type SupportInfoPanelActivityTabProps = {
  activityTimeline: Array<{
    id: string;
    title: string;
    subtitle: string;
    occurredAtUtc: string;
  }>;
  canViewSubjectUserContext: boolean;
  locale: Locale;
  panelText: ReturnType<typeof getSupportConversationCopy>["infoPanel"];
  recentFailures: Array<{
    count: number;
    failureCode: string | null;
    lastOccurredAtUtc?: string | null;
  }>;
  recentUserPurchases: Array<{
    orderId: string;
    paymentProvider: string | null;
    priceAmount: number;
    currencyCode: string | null;
    status: string | null;
    confirmedAtUtc?: string | null;
    createdAtUtc: string;
  }>;
};

type SupportInfoPanelDialogTabProps = {
  conversationTimeline: Array<{
    id: string;
    occurredAtUtc: string;
    subtitle: string;
    title: string;
  }>;
  locale: Locale;
  panelText: ReturnType<typeof getSupportConversationCopy>["infoPanel"];
};

export function SupportInfoPanelActivityTab({
  activityTimeline,
  canViewSubjectUserContext,
  locale,
  panelText,
  recentFailures,
  recentUserPurchases,
}: SupportInfoPanelActivityTabProps) {
  return (
    <div className={styles.infoPanelSection}>
      <div className={styles.infoPanelSectionHeader}>
        <span className={styles.infoPanelSectionTitle}>{panelText.activity}</span>
      </div>
      <div className={styles.sidePanelContent}>
        {canViewSubjectUserContext && recentUserPurchases.length > 0 ? (
          <div className={styles.sectionBlock}>
            <div className={styles.sectionHeaderCompact}>
              <strong>{panelText.purchases}</strong>
            </div>
            <div className={styles.timelineList}>
              {recentUserPurchases.slice(0, 4).map((purchase) => (
                <article key={purchase.orderId} className={styles.timelineCard}>
                  <div className={styles.timelineCardHeader}>
                    <strong>{formatSafeSupportDisplay(purchase.paymentProvider, "—", 48)}</strong>
                    <span>
                      {formatRelativeTime(purchase.confirmedAtUtc ?? purchase.createdAtUtc, locale)}
                    </span>
                  </div>
                  <p className={styles.timelineCardBody}>
                    {`${purchase.priceAmount} ${formatSafeSupportDisplay(
                      purchase.currencyCode,
                      "—",
                      12
                    )} · ${formatSafeSupportDisplay(purchase.status, "—", 48)}`}
                  </p>
                </article>
              ))}
            </div>
          </div>
        ) : null}

        {recentFailures.length > 0 ? (
          <div className={styles.sectionBlock}>
            <div className={styles.sectionHeaderCompact}>
              <strong>{panelText.failures}</strong>
            </div>
            <div className={styles.timelineList}>
              {recentFailures.map((item) => (
                <article key={item.failureCode} className={styles.timelineCard}>
                  <div className={styles.timelineCardHeader}>
                    <strong>{formatSafeSupportDisplay(item.failureCode, "—", 120)}</strong>
                    <span>{formatRelativeTime(item.lastOccurredAtUtc, locale)}</span>
                  </div>
                  <p className={styles.timelineCardBody}>{panelText.occurrences(item.count)}</p>
                </article>
              ))}
            </div>
          </div>
        ) : null}

        <div className={styles.sectionBlock}>
          <div className={styles.sectionHeaderCompact}>
            <strong>{panelText.recentEvents}</strong>
          </div>
          <div className={styles.timelineList}>
            {activityTimeline.length > 0 ? (
              activityTimeline.slice(0, 6).map((item) => (
                <article key={item.id} className={styles.timelineCard}>
                  <div className={styles.timelineCardHeader}>
                    <strong>{item.title}</strong>
                    <span>{formatRelativeTime(item.occurredAtUtc, locale)}</span>
                  </div>
                  <p className={styles.timelineCardBody}>{item.subtitle}</p>
                </article>
              ))
            ) : (
              <span className={styles.subtle}>{panelText.noActivityData}</span>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

export function SupportInfoPanelDialogTab({
  conversationTimeline,
  locale,
  panelText,
}: SupportInfoPanelDialogTabProps) {
  return (
    <div className={styles.infoPanelSection}>
      <div className={styles.infoPanelSectionHeader}>
        <span className={styles.infoPanelSectionTitle}>{panelText.conversationHistory}</span>
      </div>
      <div className={styles.sidePanelContent}>
        <div className={styles.sectionBlock}>
          <div className={styles.sectionHeaderCompact}>
            <strong>{panelText.timeline}</strong>
          </div>
          <div className={styles.timelineList}>
            {conversationTimeline.length > 0 ? (
              conversationTimeline.map((item) => (
                <article key={item.id} className={styles.timelineCard}>
                  <div className={styles.timelineCardHeader}>
                    <strong>{item.title}</strong>
                    <span>{formatRelativeTime(item.occurredAtUtc, locale)}</span>
                  </div>
                  <p className={styles.timelineCardBody}>{item.subtitle}</p>
                </article>
              ))
            ) : (
              <span className={styles.subtle}>{panelText.timelineEmpty}</span>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
