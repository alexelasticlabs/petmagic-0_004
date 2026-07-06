"use client";

import { FileIcon, PaperclipIcon, ReplyIcon, UploadIcon } from "@/components/admin/admin-icons";
import { AdminCard } from "@/components/admin/admin-primitives";
import {
  SupportConversationChatHeader,
  SupportConversationMessages,
} from "@/components/support/support-conversation-chat-content";
import styles from "@/components/support/support-conversation-chat-pane.module.css";
import {
  formatFileSize,
  formatSafeSupportDisplay,
  groupSupportConversationFeed,
} from "@/components/support/support-conversation-helpers";
import type {
  FullscreenImage,
  SupportMessage,
  SupportMessageAttachment,
} from "@/components/support/support-conversation-page.types";
import { getSupportConversationCopy } from "@/components/support/support-conversation.content";
import sharedStyles from "@/components/support/support-page.module.css";
import { SupportSecureMedia } from "@/components/support/support-secure-media";
import { statusHint, statusLabel } from "@/components/support/support-status-helpers";
import { SUPPORT_REPLY_MAX_LENGTH } from "@/components/support/use-support-conversation-controller";
import { Button } from "@/components/ui/button";
import type { AdminSupportConversation, SupportConversationStatus } from "@/lib/api-client";
import { getDictionary, type Locale } from "@/lib/i18n";

import type { ReactNode, RefObject } from "react";

type AttachmentTileOptions = {
  overlayCount?: number;
  single?: boolean;
};

type SupportConversationChatPaneProps = {
  attachmentInputRef: RefObject<HTMLInputElement | null>;
  attachmentPreviewUrl: string | null;
  canManageSupportWorkspace: boolean;
  composerPlaceholder: string;
  composerValue: string;
  conversation: AdminSupportConversation;
  conversationQueryIsFetching: boolean;
  conversationSla: {
    level: "good" | "warning" | "risk" | "critical";
    waitLabel: string | null;
  };
  copy: ReturnType<typeof getSupportConversationCopy>;
  groupedConversationFeed: ReturnType<typeof groupSupportConversationFeed>;
  hasComposerAttachment: boolean;
  highlightedMessageId: string | null;
  isComposerBusy: boolean;
  isComposerDisabled: boolean;
  isConversationClosed: boolean;
  isConversationReadOnly: boolean;
  isDragging: boolean;
  locale: Locale;
  messageLabels: ReturnType<typeof getSupportConversationCopy>["page"]["message"];
  messagesById: Map<string, SupportMessage>;
  messagesEndRef: RefObject<HTMLDivElement | null>;
  jumpToMessage: (messageId: string) => void;
  readOnlyComposerTitle: string;
  reply: string;
  replyComposerAttachment: SupportMessageAttachment | null | undefined;
  replyComposerPreview: string;
  replyToMessage: SupportMessage | null;
  replyToPreview: string | null;
  requestOlderMessagesLoad: () => void;
  requestReopenConversation: () => void;
  reopenStatusAction: { status: SupportConversationStatus; label: string } | null;
  renderAttachmentTile: (
    message: SupportMessage,
    attachment: SupportMessageAttachment,
    attachmentIndex: number,
    options?: AttachmentTileOptions
  ) => ReactNode;
  renderReplyThumbnail: (attachment: SupportMessageAttachment | null | undefined) => ReactNode;
  resetSelectedAttachment: () => void;
  searchInputRef: RefObject<HTMLInputElement | null>;
  searchQuery: string;
  selectedAttachment: File | null;
  selectReplyToMessage: (messageId: string | null) => void;
  setFullscreenImage: (image: FullscreenImage | null) => void;
  setIsDragging: (value: boolean) => void;
  setReply: (value: string) => void;
  setSearchQuery: (value: string) => void;
  setSelectedAttachment: (file: File | null) => void;
  startReplyToMessage: (message: SupportMessage) => void;
  statusMutationIsPending: boolean;
  submitReply: () => void;
  supportWorkspaceSubtitle: string;
  text: ReturnType<typeof getDictionary>;
  userDisplayName: string;
  userEmailDisplay: string;
};

export function SupportConversationChatPane({
  attachmentInputRef,
  attachmentPreviewUrl,
  canManageSupportWorkspace,
  composerPlaceholder,
  composerValue,
  conversation,
  conversationQueryIsFetching,
  conversationSla,
  copy,
  groupedConversationFeed,
  hasComposerAttachment,
  highlightedMessageId,
  isComposerBusy,
  isComposerDisabled,
  isConversationClosed,
  isConversationReadOnly,
  isDragging,
  jumpToMessage,
  locale,
  messageLabels,
  messagesById,
  messagesEndRef,
  readOnlyComposerTitle,
  reply,
  replyComposerAttachment,
  replyComposerPreview,
  replyToMessage,
  replyToPreview,
  requestOlderMessagesLoad,
  requestReopenConversation,
  reopenStatusAction,
  renderAttachmentTile,
  renderReplyThumbnail,
  resetSelectedAttachment,
  searchInputRef,
  searchQuery,
  selectedAttachment,
  selectReplyToMessage,
  setFullscreenImage,
  setIsDragging,
  setReply,
  setSearchQuery,
  setSelectedAttachment,
  startReplyToMessage,
  statusMutationIsPending,
  submitReply,
  supportWorkspaceSubtitle,
  text,
  userDisplayName,
  userEmailDisplay,
}: SupportConversationChatPaneProps) {
  return (
    <>
      <SupportConversationChatHeader
        conversation={conversation}
        conversationSla={conversationSla}
        deletedUserEmail={copy.shared.deletedUserEmail}
        locale={locale}
        searchInputRef={searchInputRef}
        searchQuery={searchQuery}
        setSearchQuery={setSearchQuery}
        supportWorkspaceSubtitle={supportWorkspaceSubtitle}
        text={text}
        userDisplayName={userDisplayName}
        userEmailDisplay={userEmailDisplay}
      />

      <div
        className={styles.chatPane}
        onDragOver={(event) => {
          event.preventDefault();
          if (!isComposerDisabled) setIsDragging(true);
        }}
        onDragEnter={(event) => {
          event.preventDefault();
          if (!isComposerDisabled) setIsDragging(true);
        }}
        onDragLeave={(event) => {
          if (!event.currentTarget.contains(event.relatedTarget as Node)) {
            setIsDragging(false);
          }
        }}
        onDrop={(event) => {
          event.preventDefault();
          setIsDragging(false);
          if (isComposerDisabled) return;
          const droppedFile = event.dataTransfer.files[0];
          if (droppedFile) {
            setSelectedAttachment(droppedFile);
          }
        }}
      >
        <AdminCard className={`${styles.chatShell} ${isDragging ? styles.chatShellDragging : ""}`}>
          {isDragging ? (
            <div className={styles.dropOverlay}>
              <div className={styles.dropOverlayContent}>
                <UploadIcon className={styles.dropOverlayIcon} />
                <span>{copy.page.dragAndDropImage}</span>
              </div>
            </div>
          ) : null}
          <SupportConversationMessages
            canManageSupportWorkspace={canManageSupportWorkspace}
            conversation={conversation}
            conversationQueryIsFetching={conversationQueryIsFetching}
            copy={copy}
            groupedConversationFeed={groupedConversationFeed}
            highlightedMessageId={highlightedMessageId}
            jumpToMessage={jumpToMessage}
            locale={locale}
            messageLabels={messageLabels}
            messagesById={messagesById}
            messagesEndRef={messagesEndRef}
            renderAttachmentTile={renderAttachmentTile}
            renderReplyThumbnail={renderReplyThumbnail}
            requestOlderMessagesLoad={requestOlderMessagesLoad}
            startReplyToMessage={startReplyToMessage}
            text={text}
          />

          <div className={styles.composerShell}>
            {isConversationReadOnly ? (
              <div className={styles.closedComposerNotice}>
                <div className={styles.closedComposerCopy}>
                  <span className={styles.closedConversationPill}>
                    {statusLabel(conversation.status, text)}
                  </span>
                  <strong>{readOnlyComposerTitle}</strong>
                  {!isConversationClosed ? (
                    <span>{statusHint(conversation.status, text)}</span>
                  ) : null}
                </div>
                {reopenStatusAction ? (
                  <div className={styles.closedComposerActions}>
                    <Button
                      variant="primary"
                      onClick={requestReopenConversation}
                      disabled={!canManageSupportWorkspace || statusMutationIsPending}
                    >
                      {text.supportReopenConversationAction}
                    </Button>
                  </div>
                ) : null}
              </div>
            ) : (
              <>
                <input
                  ref={attachmentInputRef}
                  type="file"
                  className={styles.hiddenFileInput}
                  accept="image/jpeg,image/png,image/webp"
                  disabled={isComposerDisabled}
                  onChange={(event) => {
                    if (isComposerDisabled) {
                      event.currentTarget.value = "";
                      return;
                    }

                    const nextFile = event.target.files?.[0] ?? null;
                    setSelectedAttachment(nextFile);
                  }}
                />
                {replyToMessage || replyToPreview ? (
                  <div className={styles.composerReplyPreview}>
                    <span className={styles.composerReplyAccent} aria-hidden="true" />
                    <span className={styles.composerReplyIcon} aria-hidden="true">
                      <ReplyIcon className={styles.composerReplySvg} />
                    </span>
                    <span className={styles.composerReplyThumbSlot}>
                      {renderReplyThumbnail(replyComposerAttachment)}
                    </span>
                    <div className={styles.composerReplyPreviewContent}>
                      <span className={styles.composerReplyPreviewLabel}>
                        {text.supportReplyToLabel}
                      </span>
                      <strong>{replyComposerPreview}</strong>
                    </div>
                    <div className={styles.composerReplyActions}>
                      {replyToMessage?.messageId ? (
                        <button
                          type="button"
                          className={styles.attachmentActionButton}
                          onClick={() => jumpToMessage(replyToMessage.messageId)}
                        >
                          {messageLabels.jump}
                        </button>
                      ) : null}
                      {/* prettier-ignore */}
                      <button
                        type="button"
                        className={styles.composerReplyClose}
                              onClick={() => selectReplyToMessage(null)}
                              disabled={isComposerDisabled}
                        aria-label={messageLabels.cancelReply}
                        title={messageLabels.cancelReply}
                      >
                        ×
                      </button>
                    </div>
                  </div>
                ) : null}
                {selectedAttachment ? (
                  <div className={styles.attachmentPreviewCard}>
                    {attachmentPreviewUrl ? (
                      <button
                        type="button"
                        className={styles.attachmentPreviewImageButton}
                        onClick={() =>
                          setFullscreenImage({
                            attachmentFileUrl: attachmentPreviewUrl,
                            fileName: selectedAttachment.name,
                            fileSizeBytes: selectedAttachment.size,
                          })
                        }
                      >
                        <SupportSecureMedia
                          url={attachmentPreviewUrl}
                          kind="image"
                          alt={formatSafeSupportDisplay(
                            selectedAttachment.name,
                            messageLabels.fileFallback,
                            120
                          )}
                          width={72}
                          height={72}
                          className={styles.attachmentPreviewImage}
                        />
                      </button>
                    ) : (
                      <div className={styles.attachmentPreviewFileIcon}>
                        <FileIcon className={sharedStyles.supportFileIcon} />
                      </div>
                    )}
                    <div className={styles.attachmentPreviewMeta}>
                      <span className={sharedStyles.subtle}>{text.selectedFileLabel}</span>
                      <strong>
                        {formatSafeSupportDisplay(
                          selectedAttachment.name,
                          messageLabels.fileFallback,
                          120
                        )}
                      </strong>
                      <span className={sharedStyles.subtle}>
                        {formatFileSize(selectedAttachment.size, locale)}
                      </span>
                    </div>
                    <div className={styles.attachmentPreviewActions}>
                      {attachmentPreviewUrl ? (
                        <button
                          type="button"
                          className={styles.attachmentActionButton}
                          onClick={() =>
                            setFullscreenImage({
                              attachmentFileUrl: attachmentPreviewUrl,
                              fileName: selectedAttachment.name,
                              fileSizeBytes: selectedAttachment.size,
                            })
                          }
                        >
                          {text.supportAttachmentOpenAction}
                        </button>
                      ) : null}
                      <Button
                        variant="ghost"
                        size="sm"
                        onClick={resetSelectedAttachment}
                        disabled={isComposerDisabled}
                      >
                        {text.supportAttachmentRemoveAction}
                      </Button>
                    </div>
                  </div>
                ) : null}

                <div className={styles.composerInputBar}>
                  <button
                    type="button"
                    className={styles.composerIconBtn}
                    onClick={() => attachmentInputRef.current?.click()}
                    disabled={isComposerDisabled}
                    aria-label={messageLabels.attachFile}
                    title={messageLabels.attachFile}
                  >
                    <PaperclipIcon className={styles.composerIconSvg} />
                  </button>
                  <textarea
                    className={`${sharedStyles.textarea} ${styles.composerTextarea}`}
                    value={composerValue}
                    onChange={(event) =>
                      setReply(event.target.value.slice(0, SUPPORT_REPLY_MAX_LENGTH))
                    }
                    maxLength={SUPPORT_REPLY_MAX_LENGTH}
                    onKeyDown={(event) => {
                      if (
                        event.key === "Enter" &&
                        !event.shiftKey &&
                        !isComposerDisabled &&
                        (reply.trim() || hasComposerAttachment)
                      ) {
                        event.preventDefault();
                        submitReply();
                      }
                    }}
                    placeholder={composerPlaceholder}
                    disabled={isComposerDisabled}
                    rows={1}
                  />
                  <div className={styles.composerSendGroup}>
                    <Button
                      variant="primary"
                      size="sm"
                      onClick={submitReply}
                      className={styles.composerSendPrimary}
                      disabled={isComposerDisabled || (!reply.trim() && !hasComposerAttachment)}
                    >
                      {isComposerBusy ? text.supportReplySending : text.supportReplyAction}
                    </Button>
                  </div>
                </div>
              </>
            )}
          </div>
        </AdminCard>
      </div>
    </>
  );
}
