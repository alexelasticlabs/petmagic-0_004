"use client";

import { useEffect, useMemo, useRef, useState } from "react";

import { getSupportConversationCopy } from "@/components/support/support-conversation.content";
import { useSupportInfoPanelAttachmentActions } from "@/components/support/support-info-panel-attachment-actions";
import { SupportInfoPanelAttachmentsTab } from "@/components/support/support-info-panel-attachments";
import {
  SupportInfoPanelActivityTab,
  SupportInfoPanelDialogTab,
} from "@/components/support/support-info-panel-history-sections";
import {
  SupportInfoPanelTabs,
  SupportInfoPanelUserTab,
} from "@/components/support/support-info-panel-user-tab";
import styles from "@/components/support/support-info-panel.module.css";
import { type SupportInfoPanelProps } from "@/components/support/support-info-panel.types";
import { type SupportConversationStatus } from "@/lib/api-client";

export function SupportInfoPanel({
  locale,
  controller,
  claimRequestId = 0,
}: SupportInfoPanelProps) {
  const [pendingStatusConfirm, setPendingStatusConfirm] =
    useState<SupportConversationStatus | null>(null);
  const [tagInput, setTagInput] = useState("");
  const [isTagEditorOpen, setIsTagEditorOpen] = useState(false);
  const tagInputRef = useRef<HTMLInputElement>(null);
  const previousConversationIdRef = useRef<string | null>(null);

  const {
    activeSidePanelTab,
    accountCreatedAt,
    addOperatorTag,
    activityTimeline,
    analyticsQuery,
    conversation,
    conversationTimeline,
    destructiveStatusAction,
    canManageSupportWorkspace,
    canMutateConversation,
    canViewSubjectUserContext,
    operatorPriority,
    operatorTags,
    primaryStatusAction,
    recentFailures,
    recentUserPurchases,
    removeOperatorTag,
    secondaryStatusActions,
    setActiveSidePanelTab,
    setOperatorPriority,
    sidePanelTabs,
    statusMutation,
    isAssignedToCurrentAdmin,
    sessionUserId,
    sessionUserRoles,
    text,
    userQuery,
  } = controller;

  const panelText = useMemo(() => getSupportConversationCopy(locale).infoPanel, [locale]);
  const isUserPremium = canViewSubjectUserContext ? (userQuery.data?.isPremium ?? false) : false;
  const { openAttachmentBlob, pendingAttachmentOpenKey, recentAttachments } =
    useSupportInfoPanelAttachmentActions({
      canManageSupportWorkspace,
      conversationMessages: conversation?.messages,
    });

  useEffect(() => {
    let isActive = true;
    const previousConversationId = previousConversationIdRef.current;
    previousConversationIdRef.current = conversation?.conversationId ?? null;

    if (!pendingStatusConfirm || statusMutation.isPending) {
      return;
    }

    if (
      !conversation ||
      conversation.status === pendingStatusConfirm ||
      (previousConversationId !== null && previousConversationId !== conversation.conversationId)
    ) {
      queueMicrotask(() => {
        if (isActive) {
          setPendingStatusConfirm(null);
        }
      });
    }

    return () => {
      isActive = false;
    };
  }, [conversation, pendingStatusConfirm, statusMutation.isPending]);

  if (!conversation) {
    return null;
  }

  const handleAddTag = () => {
    if (!canMutateConversation) {
      return;
    }

    const nextTag = tagInput.trim();
    if (!nextTag) {
      return;
    }

    const added = addOperatorTag(nextTag);
    if (added) {
      setTagInput("");
      setIsTagEditorOpen(false);
    }
  };

  const confirmPendingStatusChange = async () => {
    if (!canMutateConversation || !pendingStatusConfirm || statusMutation.isPending) {
      return;
    }

    try {
      await statusMutation.mutateAsync(pendingStatusConfirm);
      setPendingStatusConfirm(null);
    } catch {
      // The controller mutation already routes sanitized errors to support notifications.
    }
  };

  const requestStatusChange = (status: SupportConversationStatus) => {
    if (!canMutateConversation || statusMutation.isPending || conversation.status === status) {
      return;
    }

    if (status === "Closed") {
      setPendingStatusConfirm(status);
      return;
    }

    statusMutation.mutate(status);
  };

  return (
    <div className={styles.infoPanelFlat} data-testid="support-info-panel">
      <div className={styles.infoPanel}>
        <SupportInfoPanelTabs
          activeSidePanelTab={activeSidePanelTab}
          panelText={panelText}
          setActiveSidePanelTab={setActiveSidePanelTab}
          sidePanelTabs={sidePanelTabs}
        />

        <div
          id={`support-panel-tabpanel-${activeSidePanelTab}`}
          role="tabpanel"
          aria-labelledby={`support-panel-tab-${activeSidePanelTab}`}
          className={styles.infoPanelTabContent}
        >
          {activeSidePanelTab === "user" ? (
            <SupportInfoPanelUserTab
              accountCreatedAt={accountCreatedAt}
              analyticsQuery={analyticsQuery}
              canManageSupportWorkspace={canManageSupportWorkspace}
              canMutateConversation={canMutateConversation}
              canViewSubjectUserContext={canViewSubjectUserContext}
              confirmPendingStatusChange={confirmPendingStatusChange}
              conversation={conversation}
              claimRequestId={claimRequestId}
              isAssignedToCurrentAdmin={isAssignedToCurrentAdmin}
              sessionUserId={sessionUserId}
              sessionUserRoles={sessionUserRoles}
              destructiveStatusAction={destructiveStatusAction}
              handleAddTag={handleAddTag}
              isTagEditorOpen={isTagEditorOpen}
              isUserPremium={isUserPremium}
              locale={locale}
              operatorPriority={operatorPriority}
              operatorTags={operatorTags}
              panelText={panelText}
              pendingStatusConfirm={pendingStatusConfirm}
              primaryStatusAction={primaryStatusAction}
              removeOperatorTag={removeOperatorTag}
              requestStatusChange={requestStatusChange}
              secondaryStatusActions={secondaryStatusActions}
              setIsTagEditorOpen={setIsTagEditorOpen}
              setOperatorPriority={setOperatorPriority}
              setPendingStatusConfirm={setPendingStatusConfirm}
              setTagInput={setTagInput}
              statusMutation={statusMutation}
              tagInput={tagInput}
              tagInputRef={tagInputRef}
              text={text}
            />
          ) : null}

          {activeSidePanelTab === "attachments" ? (
            <SupportInfoPanelAttachmentsTab
              canManageSupportWorkspace={canManageSupportWorkspace}
              locale={locale}
              openAttachmentBlob={openAttachmentBlob}
              panelText={panelText}
              pendingAttachmentOpenKey={pendingAttachmentOpenKey}
              recentAttachments={recentAttachments}
            />
          ) : null}

          {activeSidePanelTab === "activity" ? (
            <SupportInfoPanelActivityTab
              activityTimeline={activityTimeline}
              canViewSubjectUserContext={canViewSubjectUserContext}
              locale={locale}
              panelText={panelText}
              recentFailures={recentFailures}
              recentUserPurchases={recentUserPurchases}
            />
          ) : null}

          {activeSidePanelTab === "dialog" ? (
            <SupportInfoPanelDialogTab
              conversationTimeline={conversationTimeline}
              locale={locale}
              panelText={panelText}
            />
          ) : null}
        </div>
      </div>
    </div>
  );
}
