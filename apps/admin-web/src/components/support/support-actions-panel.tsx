"use client";

import { useState } from "react";

import styles from "@/components/support/support-page.module.css";
import { useSupportConversationController } from "@/components/support/use-support-conversation-controller";
import { Button } from "@/components/ui/button";
import { type Locale } from "@/lib/i18n";

type SupportActionsPanelProps = {
  locale: Locale;
  controller: ReturnType<typeof useSupportConversationController>;
};

export function SupportActionsPanel({ locale, controller }: SupportActionsPanelProps) {
  const [showResolveConfirm, setShowResolveConfirm] = useState(false);
  const [dangerOpen, setDangerOpen] = useState(false);

  const {
    assignmentMutation,
    conversation,
    destructiveStatusAction,
    isAssignedToCurrentAdmin,
    primaryStatusAction,
    secondaryStatusActions,
    sessionUserId,
    setUserActiveMutation,
    setUserPremiumMutation,
    statusMutation,
    text,
    userQuery,
  } = controller;

  if (!conversation) {
    return null;
  }

  const isUserActive = userQuery.data?.isActive ?? true;
  const isUserPremium = userQuery.data?.isPremium ?? false;
  const isModerationPending = setUserActiveMutation.isPending || setUserPremiumMutation.isPending;

  return (
    <div className={styles.actionsPanelFlat}>
      <div className={styles.actionsPanel}>
        <span className={styles.actionsPanelTitle}>
          {locale === "ru" ? "Действия" : "Actions"}
        </span>

        {/* ── Status actions ── */}
        <div className={styles.actionsPanelGroup}>
          {showResolveConfirm ? (
            <div className={styles.spConfirmBox}>
              <span className={styles.spConfirmText}>
                {locale === "ru" ? "Закрыть обращение?" : "Close conversation?"}
              </span>
              <div className={styles.spConfirmActions}>
                <Button
                  variant="primary"
                  size="sm"
                  onClick={() => {
                    setShowResolveConfirm(false);
                    if (primaryStatusAction) {
                      statusMutation.mutate(primaryStatusAction.status);
                    }
                  }}
                  disabled={statusMutation.isPending}
                >
                  {locale === "ru" ? "Закрыть" : "Close"}
                </Button>
                <Button variant="secondary" size="sm" onClick={() => setShowResolveConfirm(false)}>
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
                  setShowResolveConfirm(true);
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
                  setShowResolveConfirm(true);
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
                statusMutation.isPending ||
                conversation.status === destructiveStatusAction.status
              }
            >
              {destructiveStatusAction.label}
            </Button>
          ) : null}
        </div>

        {/* ── Assignment ── */}
        <div className={styles.actionsPanelGroup}>
          <button
            type="button"
            className={`ui-button ui-button--secondary ui-button--md ${styles.actionsPanelBtn}`}
            onClick={() =>
              assignmentMutation.mutate(isAssignedToCurrentAdmin ? null : sessionUserId)
            }
            disabled={assignmentMutation.isPending || !sessionUserId}
          >
            👤 {isAssignedToCurrentAdmin ? text.supportUnassign : text.supportAssignToMe}
          </button>
        </div>

        {/* ── Опасные действия (accordion) ── */}
        <div className={styles.actionsPanelGroup}>
          <button
            type="button"
            className={styles.dangerAccordionToggle}
            onClick={() => setDangerOpen((prev) => !prev)}
          >
            {locale === "ru" ? "Опасные действия" : "Dangerous actions"}
            <span
              className={`${styles.dangerAccordionChevron} ${dangerOpen ? styles.dangerAccordionChevronOpen : ""}`}
            >
              ▾
            </span>
          </button>
          {dangerOpen ? (
            <>
              <button
                type="button"
                className={styles.actionsPanelDangerBtn}
                onClick={() => setUserActiveMutation.mutate(!isUserActive)}
                disabled={isModerationPending}
              >
                🔒 {isUserActive ? text.deactivate : text.activate}
              </button>
              <button
                type="button"
                className={styles.actionsPanelDangerBtn}
                onClick={() => setUserPremiumMutation.mutate(!isUserPremium)}
                disabled={isModerationPending}
              >
                👑 {isUserPremium ? text.removePremium : text.makePremium}
              </button>
            </>
          ) : null}
        </div>
      </div>
    </div>
  );
}

