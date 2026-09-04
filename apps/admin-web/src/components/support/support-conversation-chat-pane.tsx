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
import { SupportReplyTemplates } from "@/components/support/support-reply-templates";
import { SupportSecureMedia } from "@/components/support/support-secure-media";
import { statusHint, statusLabel } from "@/components/support/support-status-helpers";
import { SUPPORT_REPLY_MAX_LENGTH } from "@/components/support/use-support-conversation-controller";
import { Button } from "@/components/ui/button";
import {
  SUPPORT_ATTACHMENT_ACCEPT,
  type AdminSupportConversation,
  type SupportConversationStatus,
} from "@/lib/api-client";
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
  canClaimConversation: boolean;
  canManageReplyTemplates: boolean;
  canRetryAttachment: boolean;
  composerPlaceholder: string;
  composerValue: string;
  conversation: AdminSupportConversation;
  conversationQueryIsFetching: boolean;
  conversationSla: {
    level: "good" | "warning" | "risk" | "critical";
    waitLabel: string | null;
  };
  copy: ReturnType<typeof getSupportConversationCopy>;
  detailsAction?: ReactNode;
  groupedConversationFeed: ReturnType<typeof groupSupportConversationFeed>;
  hasComposerAttachment: boolean;
  highlightedMessageId: string | null;
  isComposerBusy: boolean;
  isComposerDisabled: boolean;
  isOwnershipComposerNoticeVisible: boolean;
  isOwnershipRequired: boolean;
  isAttachmentRetrySubmitting: boolean;
  isLoadingOlderMessages: boolean;
  isConversationClosed: boolean;
  isConversationReadOnly: boolean;
  isDragging: boolean;
  locale: Locale;
  messageLabels: ReturnType<typeof getSupportConversationCopy>["page"]["message"];
  messagesById: Map<string, SupportMessage>;
  messagesEndRef: RefObject<HTMLDivElement | null>;
  jumpToMessage: (messageId: string) => void;
  onClaimConversation: () => void;
  onOwnershipRequired: () => void;
  readOnlyComposerTitle: string;
  reply: string;
  replyComposerAttachment: SupportMessageAttachment | null | undefined;
  replyComposerPreview: string;
  replyToMessage: SupportMessage | null;
  replyToPreview: string | null;
  requestAttachmentRetry: (messageId: string, file: File) => void;
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
  selectedAttachment: File | null;
  selectReplyToMessage: (messageId: string | null) => void;
  setFullscreenImage: (image: FullscreenImage | null) => void;
  setIsDragging: (value: boolean) => void;
  setReply: (value: string) => void;
  setSelectedAttachment: (file: File | null) => void;
  startReplyToMessage: (message: SupportMessage) => void;
  statusMutationIsPending: boolean;
  submitReply: () => void;
  text: ReturnType<typeof getDictionary>;
  userDisplayName: string;
  userEmailDisplay: string;
};

export function SupportConversationChatPane({
  attachmentInputRef,
  attachmentPreviewUrl,
  canManageSupportWorkspace,
  canClaimConversation,
  canManageReplyTemplates,
  canRetryAttachment,
  composerPlaceholder,
  composerValue,
  conversation,
  conversationQueryIsFetching,
  conversationSla,
  copy,
  detailsAction,
  groupedConversationFeed,
  hasComposerAttachment,
  highlightedMessageId,
  isComposerBusy,
  isComposerDisabled,
  isOwnershipComposerNoticeVisible,
  isOwnershipRequired,
  isAttachmentRetrySubmitting,
  isLoadingOlderMessages,
  isConversationClosed,
  isConversationReadOnly,
  isDragging,
  jumpToMessage,
  onClaimConversation,
  onOwnershipRequired,
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
  requestAttachmentRetry,
  requestOlderMessagesLoad,
  requestReopenConversation,
  reopenStatusAction,
  renderAttachmentTile,
  renderReplyThumbnail,
  resetSelectedAttachment,
  selectedAttachment,
  selectReplyToMessage,
  setFullscreenImage,
  setIsDragging,
  setReply,
  setSelectedAttachment,
  startReplyToMessage,
  statusMutationIsPending,
  submitReply,
  text,
  userDisplayName,
  userEmailDisplay,
}: SupportConversationChatPaneProps) {
  const selectedAttachmentMediaType = selectedAttachment?.type.startsWith("video/")
    ? "video"
    : "image";
  const openSelectedAttachmentPreview = () => {
    if (!attachmentPreviewUrl || !selectedAttachment) {
      return;
    }

    setFullscreenImage({
      attachmentFileUrl: attachmentPreviewUrl,
      fileName: selectedAttachment.name,
      fileSizeBytes: selectedAttachment.size,
      mediaType: selectedAttachmentMediaType,
    });
  };

  return (
    <div className={styles.chatWorkspacePane} data-testid="support-chat-pane">
      <div
        className={styles.chatPane}
        onDragOver={(event) => {
          event.preventDefault();
          if (!isComposerDisabled && !isOwnershipRequired) setIsDragging(true);
        }}
        onDragEnter={(event) => {
          event.preventDefault();
          if (!isComposerDisabled && !isOwnershipRequired) setIsDragging(true);
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
          if (isOwnershipRequired) {
            onOwnershipRequired();
            return;
          }
          const droppedFile = event.dataTransfer.files[0];
          if (droppedFile) {
            setSelectedAttachment(droppedFile);
          }
        }}
      >
        <AdminCard className={`${styles.chatShell} ${isDragging ? styles.chatShellDragging : ""}`}>
          <SupportConversationChatHeader
            action={detailsAction}
            conversation={conversation}
            conversationSla={conversationSla}
            deletedUserEmail={copy.shared.deletedUserEmail}
            locale={locale}
            text={text}
            userDisplayName={userDisplayName}
            userEmailDisplay={userEmailDisplay}
          />

          {isDragging ? (
            <div className={styles.dropOverlay}>
              <div className={styles.dropOverlayContent}>
                <UploadIcon className={styles.dropOverlayIcon} />
                <span>{copy.page.dragAndDropAttachment}</span>
              </div>
            </div>
          ) : null}
          <SupportConversationMessages
            canManageSupportWorkspace={canManageSupportWorkspace}
            canRetryAttachment={canRetryAttachment}
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
            isAttachmentRetrySubmitting={isAttachmentRetrySubmitting}
            isLoadingOlderMessages={isLoadingOlderMessages}
            renderAttachmentTile={renderAttachmentTile}
            renderReplyThumbnail={renderReplyThumbnail}
            requestAttachmentRetry={requestAttachmentRetry}
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
                {isOwnershipComposerNoticeVisible ? (
                  <div
                    className={styles.ownershipComposerNotice}
                    data-testid="support-composer-ownership-gate"
                  >
                    <div className={styles.ownershipComposerCopy}>
                      <strong>{copy.controller.ownershipRequired}</strong>
                      <span>
                        {locale === "ru"
                          ? "Возьмите тикет в работу — после этого можно будет написать ответ или прикрепить файл."
                          : "Claim the ticket to reply to the customer or attach a file."}
                      </span>
                    </div>
                    {canClaimConversation ? (
                      <Button variant="primary" size="sm" onClick={onClaimConversation}>
                        {locale === "ru" ? "Взять в работу" : "Claim ticket"}
                      </Button>
                    ) : null}
                  </div>
                ) : null}
                <input
                  ref={attachmentInputRef}
                  type="file"
                  className={styles.hiddenFileInput}
                  accept={SUPPORT_ATTACHMENT_ACCEPT}
                  disabled={isComposerDisabled}
                  onChange={(event) => {
                    if (isComposerDisabled || isOwnershipRequired) {
                      event.currentTarget.value = "";
                      onOwnershipRequired();
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
                      selectedAttachmentMediaType === "video" ? (
                        <SupportSecureMedia
                          url={attachmentPreviewUrl}
                          kind="video"
                          className={styles.attachmentPreviewImage}
                          controls
                          preload="metadata"
                          playsInline
                          logContext={{ mimeType: selectedAttachment.type }}
                        />
                      ) : (
                        <button
                          type="button"
                          className={styles.attachmentPreviewImageButton}
                          onClick={openSelectedAttachmentPreview}
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
                      )
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
                          onClick={openSelectedAttachmentPreview}
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

                <SupportReplyTemplates
                  locale={locale}
                  disabled={isComposerDisabled}
                  canManageTemplates={canManageReplyTemplates}
                  setReply={setReply}
                />

                <div className={styles.composerInputBar} data-testid="support-composer">
                  <button
                    type="button"
                    className={styles.composerIconBtn}
                    data-testid="support-composer-attachment"
                    onClick={() => {
                      if (isOwnershipRequired) {
                        onOwnershipRequired();
                        return;
                      }

                      attachmentInputRef.current?.click();
                    }}
                    disabled={isComposerDisabled}
                    aria-label={messageLabels.attachFile}
                    title={messageLabels.attachFile}
                  >
                    <PaperclipIcon className={styles.composerIconSvg} />
                    <span className={styles.composerAttachLabel}>{messageLabels.attachFile}</span>
                  </button>
                  <textarea
                    className={styles.composerTextarea}
                    data-testid="support-composer-input"
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
    </div>
  );
}
