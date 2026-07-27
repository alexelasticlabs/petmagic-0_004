"use client";

import { RefreshIcon, TrendUpIcon, UserRegisterIcon } from "@/components/admin/admin-icons";
import { SupportAssignmentControl } from "@/components/support/support-assignment-control";
import {
  formatAccountAge,
  formatDateTime,
  formatSafeSupportDisplay,
} from "@/components/support/support-conversation-helpers";
import { getSupportConversationCopy } from "@/components/support/support-conversation.content";
import styles from "@/components/support/support-info-panel.module.css";
import type {
  SupportConversationController,
  SupportConversationText,
} from "@/components/support/support-info-panel.types";
import { Button } from "@/components/ui/button";
import { Select } from "@/components/ui/select";
import type { SupportConversationStatus } from "@/lib/api-client";
import type { Locale } from "@/lib/i18n";

import type { RefObject } from "react";

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
  canManageSupportWorkspace: boolean;
  canMutateConversation: boolean;
  canViewSubjectUserContext: boolean;
  confirmPendingStatusChange: () => Promise<void>;
  conversation: NonNullable<SupportConversationController["conversation"]>;
  isAssignedToCurrentAdmin: boolean;
  sessionUserId: string | null;
  sessionUserRoles: string[];
  destructiveStatusAction: SupportConversationController["destructiveStatusAction"];
  handleAddTag: () => void;
  isTagEditorOpen: boolean;
  isUserPremium: boolean;
  locale: Locale;
  operatorPriority: SupportConversationController["operatorPriority"];
  operatorTags: SupportConversationController["operatorTags"];
  panelText: SupportInfoPanelCopy;
  pendingStatusConfirm: SupportConversationStatus | null;
  primaryStatusAction: SupportConversationController["primaryStatusAction"];
  removeOperatorTag: SupportConversationController["removeOperatorTag"];
  requestStatusChange: (status: SupportConversationStatus) => void;
  secondaryStatusActions: SupportConversationController["secondaryStatusActions"];
  setIsTagEditorOpen: (value: boolean | ((current: boolean) => boolean)) => void;
  setOperatorPriority: SupportConversationController["setOperatorPriority"];
  setPendingStatusConfirm: (status: SupportConversationStatus | null) => void;
  setTagInput: (value: string) => void;
  statusMutation: SupportConversationController["statusMutation"];
  tagInput: string;
  tagInputRef: RefObject<HTMLInputElement | null>;
  text: SupportConversationText;
};

export function SupportInfoPanelTabs({
  activeSidePanelTab,
  panelText,
  setActiveSidePanelTab,
  sidePanelTabs,
}: SupportInfoPanelTabsProps) {
  return (
    <div className={`${styles.infoPanelSection} ${styles.infoPanelTabsSection}`}>
      <div
        className={styles.sidePanelTabs}
        data-testid="support-info-tabs"
        role="tablist"
        aria-label={panelText.panelTabsLabel}
      >
        {sidePanelTabs.map((tab) => (
          <button
            key={tab.value}
            type="button"
            role="tab"
            id={`support-panel-tab-${tab.value}`}
            aria-controls={`support-panel-tabpanel-${tab.value}`}
            aria-selected={activeSidePanelTab === tab.value}
            tabIndex={activeSidePanelTab === tab.value ? 0 : -1}
            className={`${styles.spTabBtn} ${activeSidePanelTab === tab.value ? styles.spTabBtnActive : ""}`}
            onClick={() => setActiveSidePanelTab(tab.value)}
            onKeyDown={(event) => {
              const currentIndex = sidePanelTabs.findIndex((item) => item.value === tab.value);
              let nextIndex = currentIndex;

              if (event.key === "ArrowRight") {
                nextIndex = (currentIndex + 1) % sidePanelTabs.length;
              } else if (event.key === "ArrowLeft") {
                nextIndex = (currentIndex - 1 + sidePanelTabs.length) % sidePanelTabs.length;
              } else if (event.key === "Home") {
                nextIndex = 0;
              } else if (event.key === "End") {
                nextIndex = sidePanelTabs.length - 1;
              } else {
                return;
              }

              event.preventDefault();
              const nextTab = sidePanelTabs[nextIndex];
              setActiveSidePanelTab(nextTab.value);
              document.getElementById(`support-panel-tab-${nextTab.value}`)?.focus();
            }}
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
  canManageSupportWorkspace,
  canMutateConversation,
  canViewSubjectUserContext,
  confirmPendingStatusChange,
  conversation,
  isAssignedToCurrentAdmin,
  sessionUserId,
  sessionUserRoles,
  destructiveStatusAction,
  handleAddTag,
  isTagEditorOpen,
  isUserPremium,
  locale,
  operatorPriority,
  operatorTags,
  panelText,
  pendingStatusConfirm,
  primaryStatusAction,
  removeOperatorTag,
  requestStatusChange,
  secondaryStatusActions,
  setIsTagEditorOpen,
  setOperatorPriority,
  setPendingStatusConfirm,
  setTagInput,
  statusMutation,
  tagInput,
  tagInputRef,
  text,
}: SupportInfoPanelUserTabProps) {
  return (
    <>
      <div className={`${styles.infoPanelSection} ${styles.infoPanelTicketSummary}`}>
        <div className={styles.infoPanelSectionHeader}>
          <span className={styles.infoPanelSectionTitle}>{panelText.ticketInformation}</span>
        </div>
        <div className={styles.infoPanelKvRow}>
          <span className={styles.infoPanelKvLabel}>
            <span className={styles.infoPanelKvIcon} aria-hidden="true">
              <UserRegisterIcon />
            </span>
            <span>{panelText.assignedOperator}</span>
          </span>
          <strong>
            {conversation.assignedAdminId
              ? (conversation.assignedAdminDisplayName ?? panelText.ownedByAnotherOperator)
              : panelText.unassignedOperator}
          </strong>
        </div>
        <div className={styles.infoPanelAssignmentActions}>
          <SupportAssignmentControl
            key={conversation.conversationId}
            conversation={conversation}
            canManageSupportWorkspace={canManageSupportWorkspace}
            sessionUserId={sessionUserId}
            sessionUserRoles={sessionUserRoles}
            locale={locale}
          />
          {conversation.assignedAdminId &&
          !isAssignedToCurrentAdmin &&
          !sessionUserRoles.includes("Admin") ? (
            <span className={styles.subtle}>{panelText.ownedByAnotherOperator}</span>
          ) : null}
        </div>
        <div className={styles.infoPanelKvRow}>
          <span className={styles.infoPanelKvLabel}>
            <span className={styles.infoPanelKvIcon} aria-hidden="true">
              <TrendUpIcon />
            </span>
            <span>{text.supportPriorityLabel}</span>
          </span>
          <div className={styles.infoPanelSelectWrap}>
            <Select
              value={operatorPriority}
              ariaLabel={text.supportPriorityLabel}
              onChange={(value) => setOperatorPriority(value as typeof operatorPriority)}
              disabled={!canMutateConversation}
              showSelectedDescription={false}
              options={[
                { value: "Low", label: text.supportPriorityLow },
                { value: "Normal", label: text.supportPriorityNormal },
                { value: "High", label: text.supportPriorityHigh },
                { value: "Urgent", label: text.supportPriorityUrgent },
              ]}
            />
          </div>
        </div>
        <div className={styles.infoPanelKvRow}>
          <span className={styles.infoPanelKvLabel}>
            <span className={styles.infoPanelKvIcon} aria-hidden="true">
              <RefreshIcon />
            </span>
            <span>{panelText.updated}</span>
          </span>
          <strong>{formatDateTime(conversation.updatedAtUtc, locale)}</strong>
        </div>
      </div>

      {conversation.status !== "Closed" &&
      (primaryStatusAction || secondaryStatusActions.length > 0 || destructiveStatusAction) ? (
        <div className={styles.infoPanelSection} data-testid="support-ticket-actions">
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
                    disabled={!canMutateConversation || statusMutation.isPending}
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
                  !canMutateConversation ||
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
                  !canMutateConversation ||
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
                  !canMutateConversation ||
                  statusMutation.isPending ||
                  conversation.status === destructiveStatusAction.status
                }
              >
                {destructiveStatusAction.label}
              </Button>
            ) : null}
          </div>
        </div>
      ) : null}

      {typeof conversation.feedbackRating === "number" ? (
        <div className={styles.infoPanelSection}>
          <div className={styles.infoPanelSectionHeader}>
            <span className={styles.infoPanelSectionTitle}>{panelText.feedbackTitle}</span>
          </div>
          <>
            <div className={styles.infoPanelKvRow}>
              <span>{panelText.feedbackRating(conversation.feedbackRating)}</span>
              <strong aria-label={panelText.feedbackRating(conversation.feedbackRating)}>
                {"★".repeat(conversation.feedbackRating)}
                {"☆".repeat(5 - conversation.feedbackRating)}
              </strong>
            </div>
            {conversation.feedbackComment?.trim() ? (
              <div className={styles.infoPanelFeedbackComment}>
                <span>{panelText.feedbackComment}</span>
                <strong>
                  {formatSafeSupportDisplay(conversation.feedbackComment, panelText.noData, 1000)}
                </strong>
              </div>
            ) : null}
          </>
        </div>
      ) : null}

      <div className={styles.infoPanelSection}>
        <div className={styles.infoPanelSectionHeader}>
          <span className={styles.infoPanelSectionTitle}>{panelText.operatorTags}</span>
          <button
            type="button"
            className={styles.infoPanelTagAddChip}
            onClick={() => {
              if (!canMutateConversation) {
                return;
              }

              if (isTagEditorOpen) {
                setIsTagEditorOpen(false);
                return;
              }

              setIsTagEditorOpen(true);
              window.setTimeout(() => tagInputRef.current?.focus(), 0);
            }}
            disabled={!canMutateConversation}
            aria-label={panelText.addTag}
            aria-controls="support-operator-tag-editor"
            aria-expanded={isTagEditorOpen}
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
                disabled={!canMutateConversation}
                title={panelText.removeTag}
              >
                {formatSafeSupportDisplay(tag, panelText.tagFallback, 40)}{" "}
                <span aria-hidden="true">×</span>
              </button>
            ))}
          </div>
        ) : null}
        {isTagEditorOpen ? (
          <div id="support-operator-tag-editor" className={styles.infoPanelTagInputRow}>
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
              disabled={!canMutateConversation}
            />
            <Button
              type="button"
              size="sm"
              variant="secondary"
              onClick={handleAddTag}
              disabled={!canMutateConversation || !tagInput.trim()}
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
          <div className={styles.infoPanelStatsGrid} data-testid="support-user-stats">
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
      </div>
    </>
  );
}
