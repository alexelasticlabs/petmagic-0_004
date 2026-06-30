"use client";

import type { RefObject } from "react";

import {
  formatAccountAge,
  formatDateTime,
  formatSafeSupportDisplay,
} from "@/components/support/support-conversation-helpers";
import { getSupportConversationCopy } from "@/components/support/support-conversation.content";
import {
  SupportInfoPanelAttachmentPreviewSection,
  type SupportInfoAttachment,
  type SupportInfoAttachmentEntry,
} from "@/components/support/support-info-panel-attachments";
import type {
  SupportConversationController,
  SupportConversationText,
} from "@/components/support/support-info-panel.types";
import styles from "@/components/support/support-page.module.css";
import { Button } from "@/components/ui/button";
import { Select } from "@/components/ui/select";
import type { SupportConversationStatus } from "@/lib/api-client";
import type { Locale } from "@/lib/i18n";

type SupportInfoPanelCopy = ReturnType<typeof getSupportConversationCopy>["infoPanel"];

type SupportInfoPanelTabsProps = {
  activeSidePanelTab: SupportConversationController["activeSidePanelTab"];
  panelText: SupportInfoPanelCopy;
  setActiveSidePanelTab: SupportConversationController["setActiveSidePanelTab"];
  sidePanelTabs: SupportConversationController["sidePanelTabs"];
};

type SupportInfoPanelUserTabProps = {
  accountCreatedAt: SupportConversationController["accountCreatedAt"];
  analyticsQuery: SupportConversationController["analyticsQuery"];
  attachmentPreviewEntries: SupportInfoAttachmentEntry[];
  canManageSupportWorkspace: boolean;
  canViewSubjectUserContext: boolean;
  confirmPendingStatusChange: () => Promise<void>;
  conversation: NonNullable<SupportConversationController["conversation"]>;
  destructiveStatusAction: SupportConversationController["destructiveStatusAction"];
  handleAddTag: () => void;
  isTagEditorOpen: boolean;
  isUserPremium: boolean;
  lastActivityAtUtc: SupportConversationController["lastActivityAtUtc"];
  locale: Locale;
  openAttachmentBlob: (
    messageId: string,
    createdAtUtc: string,
    attachment: SupportInfoAttachment,
    index: number
  ) => Promise<void>;
  operatorPriority: SupportConversationController["operatorPriority"];
  operatorTags: SupportConversationController["operatorTags"];
  panelText: SupportInfoPanelCopy;
  pendingAttachmentOpenKey: string | null;
  pendingStatusConfirm: SupportConversationStatus | null;
  primaryStatusAction: SupportConversationController["primaryStatusAction"];
  recentAttachments: SupportInfoAttachmentEntry[];
  remainingAttachmentCount: number;
  removeOperatorTag: SupportConversationController["removeOperatorTag"];
  requestStatusChange: (status: SupportConversationStatus) => void;
  secondaryStatusActions: SupportConversationController["secondaryStatusActions"];
  setActiveSidePanelTab: SupportConversationController["setActiveSidePanelTab"];
  setIsTagEditorOpen: (value: boolean | ((current: boolean) => boolean)) => void;
  setOperatorPriority: SupportConversationController["setOperatorPriority"];
  setPendingStatusConfirm: (status: SupportConversationStatus | null) => void;
  setTagInput: (value: string) => void;
  statusMutation: SupportConversationController["statusMutation"];
  tagInput: string;
  tagInputRef: RefObject<HTMLInputElement | null>;
  text: SupportConversationText;
  totalPurchases: SupportConversationController["totalPurchases"];
};

export function SupportInfoPanelTabs({
  activeSidePanelTab,
  panelText,
  setActiveSidePanelTab,
  sidePanelTabs,
}: SupportInfoPanelTabsProps) {
  return (
    <div className={styles.infoPanelSection}>
      <div className={styles.sidePanelTabs} role="tablist" aria-label={panelText.panelTabsLabel}>
        {sidePanelTabs
          .filter((tab) => tab.value !== "activity" && tab.value !== "dialog")
          .map((tab) => (
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
    </div>
  );
}

export function SupportInfoPanelUserTab({
  accountCreatedAt,
  analyticsQuery,
  attachmentPreviewEntries,
  canManageSupportWorkspace,
  canViewSubjectUserContext,
  confirmPendingStatusChange,
  conversation,
  destructiveStatusAction,
  handleAddTag,
  isTagEditorOpen,
  isUserPremium,
  lastActivityAtUtc,
  locale,
  openAttachmentBlob,
  operatorPriority,
  operatorTags,
  panelText,
  pendingAttachmentOpenKey,
  pendingStatusConfirm,
  primaryStatusAction,
  recentAttachments,
  remainingAttachmentCount,
  removeOperatorTag,
  requestStatusChange,
  secondaryStatusActions,
  setActiveSidePanelTab,
  setIsTagEditorOpen,
  setOperatorPriority,
  setPendingStatusConfirm,
  setTagInput,
  statusMutation,
  tagInput,
  tagInputRef,
  text,
  totalPurchases,
}: SupportInfoPanelUserTabProps) {
  return (
    <>
      <div className={styles.infoPanelSection}>
        <div className={styles.infoPanelSectionHeader}>
          <span className={styles.infoPanelSectionTitle}>{panelText.ticketInformation}</span>
        </div>
        <div className={styles.infoPanelKvRow}>
          <span className={styles.infoPanelKvLabel}>
            <span className={styles.infoPanelKvIcon} aria-hidden="true">
              ⚑
            </span>
            <span>{text.supportPriorityLabel}</span>
          </span>
          <div className={styles.infoPanelSelectWrap}>
            <Select
              value={operatorPriority}
              onChange={(value) => setOperatorPriority(value as typeof operatorPriority)}
              disabled={!canManageSupportWorkspace}
              showSelectedDescription={false}
              options={[
                { value: "Low", label: text.supportPriorityLow },
                { value: "Normal", label: text.supportPriorityNormal },
                { value: "High", label: text.supportPriorityHigh },
              ]}
            />
          </div>
        </div>
        <div className={styles.infoPanelKvRow}>
          <span className={styles.infoPanelKvLabel}>
            <span className={styles.infoPanelKvIcon} aria-hidden="true">
              ↻
            </span>
            <span>{panelText.updated}</span>
          </span>
          <strong>{formatDateTime(conversation.updatedAtUtc, locale)}</strong>
        </div>
      </div>

      <SupportInfoPanelAttachmentPreviewSection
        attachmentPreviewEntries={attachmentPreviewEntries}
        canManageSupportWorkspace={canManageSupportWorkspace}
        locale={locale}
        openAttachmentBlob={openAttachmentBlob}
        panelText={panelText}
        pendingAttachmentOpenKey={pendingAttachmentOpenKey}
        recentAttachments={recentAttachments}
        remainingAttachmentCount={remainingAttachmentCount}
        setActiveSidePanelTab={setActiveSidePanelTab}
      />

      <div className={styles.infoPanelSection}>
        <div className={styles.infoPanelSectionHeader}>
          <span className={styles.infoPanelSectionTitle}>{panelText.operatorTags}</span>
          <button
            type="button"
            className={styles.infoPanelTagAddChip}
            onClick={() => {
              if (!canManageSupportWorkspace) {
                return;
              }
              setIsTagEditorOpen((current) => !current);
              window.setTimeout(() => tagInputRef.current?.focus(), 0);
            }}
            disabled={!canManageSupportWorkspace}
            aria-label={panelText.addTag}
            title={panelText.addTag}
          >
            +
          </button>
        </div>
        {operatorTags.length > 0 ? (
          <div className={styles.infoPanelTagsWrap}>
            {operatorTags.map((tag) => (
              <button
                key={tag}
                type="button"
                className={styles.infoPanelTagChip}
                onClick={() => removeOperatorTag(tag)}
                disabled={!canManageSupportWorkspace}
                title={panelText.removeTag}
              >
                {formatSafeSupportDisplay(tag, panelText.tagFallback, 40)}{" "}
                <span aria-hidden="true">×</span>
              </button>
            ))}
          </div>
        ) : null}
        {isTagEditorOpen || operatorTags.length === 0 ? (
          <div className={styles.infoPanelTagInputRow}>
            <input
              ref={tagInputRef}
              className={styles.infoPanelTagInput}
              value={tagInput}
              onChange={(event) => setTagInput(event.target.value.slice(0, 40))}
              onKeyDown={(event) => {
                if (event.key === "Enter" || event.key === ",") {
                  event.preventDefault();
                  handleAddTag();
                }
              }}
              maxLength={40}
              placeholder={text.tagsLabel}
              disabled={!canManageSupportWorkspace}
            />
            <Button
              type="button"
              size="sm"
              variant="secondary"
              onClick={handleAddTag}
              disabled={!canManageSupportWorkspace || !tagInput.trim()}
            >
              {panelText.add}
            </Button>
          </div>
        ) : null}
        <span className={styles.subtle}>{panelText.tagHint}</span>
      </div>

      <div className={styles.infoPanelSection}>
        <div className={styles.infoPanelSectionHeader}>
          <span className={styles.infoPanelSectionTitle}>{panelText.user}</span>
        </div>
        {canViewSubjectUserContext ? (
          <div className={styles.infoPanelStatsGrid}>
            <div className={styles.infoPanelStatTile}>
              <span>{text.supportPlanLabel}</span>
              <strong>{isUserPremium ? text.premiumLabel : text.freeLabel}</strong>
            </div>
            <div className={styles.infoPanelStatTile}>
              <span>{panelText.walletLabel}</span>
              <strong>{String(analyticsQuery.data?.summary.walletBalance ?? 0)}</strong>
            </div>
            <div className={styles.infoPanelStatTile}>
              <span>{text.supportAccountAgeLabel}</span>
              <strong>{formatAccountAge(accountCreatedAt, locale)}</strong>
            </div>
          </div>
        ) : null}
        <div className={styles.infoPanelStatsSecondaryGrid}>
          {canViewSubjectUserContext ? (
            <button
              type="button"
              className={`${styles.infoPanelStatTileFull} ${styles.infoPanelStatTileButton}`}
              onClick={() => setActiveSidePanelTab("activity")}
            >
              <span>{panelText.purchases}</span>
              <strong>{String(totalPurchases)}</strong>
            </button>
          ) : null}
          <button
            type="button"
            className={`${styles.infoPanelStatTileFull} ${styles.infoPanelStatTileButton}`}
            onClick={() => setActiveSidePanelTab("dialog")}
          >
            <span>{text.supportLastSeenLabel}</span>
            <strong>
              {lastActivityAtUtc ? formatDateTime(lastActivityAtUtc, locale) : panelText.noData}
            </strong>
          </button>
        </div>
      </div>

      <div className={styles.infoPanelSection}>
        <div className={styles.infoPanelSectionHeader}>
          <span className={styles.infoPanelSectionTitle}>{panelText.ticketActions}</span>
        </div>

        <div className={styles.infoPanelActionStack}>
          {pendingStatusConfirm ? (
            <div className={styles.spConfirmBox}>
              <span className={styles.spConfirmText}>{panelText.closeConversationPrompt}</span>
              <div className={styles.spConfirmActions}>
                <Button
                  variant="primary"
                  size="sm"
                  onClick={() => void confirmPendingStatusChange()}
                  disabled={!canManageSupportWorkspace || statusMutation.isPending}
                >
                  {panelText.close}
                </Button>
                <Button
                  variant="secondary"
                  size="sm"
                  onClick={() => setPendingStatusConfirm(null)}
                  disabled={statusMutation.isPending}
                >
                  {panelText.cancel}
                </Button>
              </div>
            </div>
          ) : primaryStatusAction ? (
            <button
              type="button"
              className={`ui-button ui-button--primary ui-button--md ${styles.actionsPanelBtn}`}
              onClick={() => requestStatusChange(primaryStatusAction.status)}
              disabled={
                !canManageSupportWorkspace ||
                statusMutation.isPending ||
                conversation.status === primaryStatusAction.status
              }
            >
              {primaryStatusAction.label}
            </button>
          ) : null}

          {secondaryStatusActions.map((action) => (
            <button
              key={action.status}
              type="button"
              className={`ui-button ui-button--secondary ui-button--md ${styles.actionsPanelBtn}`}
              onClick={() => requestStatusChange(action.status)}
              disabled={
                !canManageSupportWorkspace ||
                statusMutation.isPending ||
                conversation.status === action.status
              }
            >
              {action.label}
            </button>
          ))}

          {destructiveStatusAction ? (
            <Button
              variant="danger"
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
      </div>
    </>
  );
}
