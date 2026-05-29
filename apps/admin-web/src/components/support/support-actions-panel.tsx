"use client";

import { useState } from "react";

import styles from "@/components/support/support-page.module.css";
import { useSupportConversationController } from "@/components/support/use-support-conversation-controller";
import { Button } from "@/components/ui/button";
import { type SupportConversationStatus } from "@/lib/api-client";
import { type Locale } from "@/lib/i18n";

type SupportActionsPanelProps = {
  locale: Locale;
  controller: ReturnType<typeof useSupportConversationController>;
};

export function SupportActionsPanel({ locale, controller }: SupportActionsPanelProps) {
  const [pendingStatusConfirm, setPendingStatusConfirm] =
    useState<SupportConversationStatus | null>(null);

  const {
    conversation,
    destructiveStatusAction,
    primaryStatusAction,
    secondaryStatusActions,
    statusMutation,
  } = controller;

  if (!conversation) {
    return null;
  }

  return (
    <div className={styles.actionsPanelFlat}>
      <div className={styles.actionsPanel}>
        <span className={styles.actionsPanelTitle}>{locale === "ru" ? "Действия" : "Actions"}</span>

        {/* ── Status actions ── */}
        <div className={styles.actionsPanelGroup}>
          {pendingStatusConfirm ? (
            <div className={styles.spConfirmBox}>
              <span className={styles.spConfirmText}>
                {locale === "ru" ? "Закрыть обращение?" : "Close conversation?"}
              </span>
              <div className={styles.spConfirmActions}>
                <Button
                  variant="primary"
                  size="sm"
                  onClick={() => {
                    const nextStatus = pendingStatusConfirm;
                    setPendingStatusConfirm(null);
                    if (nextStatus) {
                      statusMutation.mutate(nextStatus);
                    }
                  }}
                  disabled={statusMutation.isPending}
                >
                  {locale === "ru" ? "Закрыть" : "Close"}
                </Button>
                <Button variant="secondary" size="sm" onClick={() => setPendingStatusConfirm(null)}>
                  {locale === "ru" ? "Отмена" : "Cancel"}
                </Button>
              </div>
            </div>
          ) : primaryStatusAction ? (
            <button
              type="button"
              className={`ui-button ui-button--primary ui-button--md ${styles.actionsPanelBtn}`}
              onClick={() => {
                if (primaryStatusAction.status === "Closed") {
                  setPendingStatusConfirm(primaryStatusAction.status);
                } else {
                  statusMutation.mutate(primaryStatusAction.status);
                }
              }}
              disabled={
                statusMutation.isPending || conversation.status === primaryStatusAction.status
              }
            >
              {primaryStatusAction.status === "InProgress"
                ? "▶ "
                : primaryStatusAction.status === "WaitingForUser"
                  ? "⏳ "
                  : primaryStatusAction.status === "Closed"
                    ? "✕ "
                    : ""}
              {primaryStatusAction.label}
            </button>
          ) : null}

          {secondaryStatusActions.map((action) => (
            <button
              key={action.status}
              type="button"
              className={`ui-button ui-button--secondary ui-button--md ${styles.actionsPanelBtn}`}
              onClick={() => {
                if (action.status === "Closed") {
                  setPendingStatusConfirm(action.status);
                } else {
                  statusMutation.mutate(action.status);
                }
              }}
              disabled={statusMutation.isPending || conversation.status === action.status}
            >
              {action.status === "Closed" ? "✕ " : action.status === "InProgress" ? "↩ " : ""}
              {action.label}
            </button>
          ))}

          {destructiveStatusAction ? (
            <Button
              variant="danger"
              onClick={() => statusMutation.mutate(destructiveStatusAction.status)}
              disabled={
                statusMutation.isPending || conversation.status === destructiveStatusAction.status
              }
            >
              {destructiveStatusAction.label}
            </Button>
          ) : null}
        </div>
      </div>
    </div>
  );
}
