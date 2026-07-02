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

export function SupportInfoPanel({ locale, controller }: SupportInfoPanelProps) {
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
    canViewSubjectUserContext,
    lastActivityAtUtc,
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
    text,
    totalPurchases,
    userQuery,
  } = controller;

  const panelText = useMemo(() => getSupportConversationCopy(locale).infoPanel, [locale]);
  const isUserPremium = canViewSubjectUserContext ? (userQuery.data?.isPremium ?? false) : false;
  const {
    attachmentPreviewEntries,
    openAttachmentBlob,
    pendingAttachmentOpenKey,
    recentAttachments,
    remainingAttachmentCount,
  } = useSupportInfoPanelAttachmentActions({
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
    if (!canManageSupportWorkspace) {
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
    if (!canManageSupportWorkspace || !pendingStatusConfirm || statusMutation.isPending) {
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
    if (!canManageSupportWorkspace || statusMutation.isPending || conversation.status === status) {
      return;
    }

    if (status === "Closed") {
      setPendingStatusConfirm(status);
      return;
    }

    statusMutation.mutate(status);
  };

  return (
    <div className={styles.infoPanelFlat}>
      <div className={styles.infoPanel}>
        <SupportInfoPanelTabs
          activeSidePanelTab={activeSidePanelTab}
          panelText={panelText}
          setActiveSidePanelTab={setActiveSidePanelTab}
          sidePanelTabs={sidePanelTabs}
        />

        {activeSidePanelTab === "user" ? (
          <SupportInfoPanelUserTab
            accountCreatedAt={accountCreatedAt}
            analyticsQuery={analyticsQuery}
            attachmentPreviewEntries={attachmentPreviewEntries}
            canManageSupportWorkspace={canManageSupportWorkspace}
            canViewSubjectUserContext={canViewSubjectUserContext}
            confirmPendingStatusChange={confirmPendingStatusChange}
            conversation={conversation}
            destructiveStatusAction={destructiveStatusAction}
            handleAddTag={handleAddTag}
            isTagEditorOpen={isTagEditorOpen}
            isUserPremium={isUserPremium}
            lastActivityAtUtc={lastActivityAtUtc}
            locale={locale}
            openAttachmentBlob={openAttachmentBlob}
            operatorPriority={operatorPriority}
            operatorTags={operatorTags}
            panelText={panelText}
            pendingAttachmentOpenKey={pendingAttachmentOpenKey}
            pendingStatusConfirm={pendingStatusConfirm}
            primaryStatusAction={primaryStatusAction}
            recentAttachments={recentAttachments}
            remainingAttachmentCount={remainingAttachmentCount}
            removeOperatorTag={removeOperatorTag}
            requestStatusChange={requestStatusChange}
            secondaryStatusActions={secondaryStatusActions}
            setActiveSidePanelTab={setActiveSidePanelTab}
            setIsTagEditorOpen={setIsTagEditorOpen}
            setOperatorPriority={setOperatorPriority}
            setPendingStatusConfirm={setPendingStatusConfirm}
            setTagInput={setTagInput}
            statusMutation={statusMutation}
            tagInput={tagInput}
            tagInputRef={tagInputRef}
            text={text}
            totalPurchases={totalPurchases}
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
  );
}
