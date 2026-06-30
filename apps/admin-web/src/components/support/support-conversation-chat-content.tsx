"use client";

import type { ReactNode, RefObject } from "react";

import { ReplyIcon, SearchIcon, UploadIcon } from "@/components/admin/admin-icons";
import { AdminBadge, AdminStateCard } from "@/components/admin/admin-primitives";
import {
  formatClockTime,
  formatDateTime,
  formatSafeSupportDisplay,
  getMessageAttachments,
  initialsFor,
  shortId,
  shouldRenderMessageBody,
  type SupportConversationFeedGroup,
} from "@/components/support/support-conversation-helpers";
import { getSupportConversationCopy } from "@/components/support/support-conversation.content";
import type {
  SupportMessage,
  SupportMessageAttachment,
} from "@/components/support/support-conversation-page.types";
import {
  sourceLabel,
  statusLabel,
  toneForStatus,
} from "@/components/support/support-status-helpers";
import { SUPPORT_SEARCH_MAX_LENGTH } from "@/components/support/use-support-conversation-controller";
import { Button } from "@/components/ui/button";
import type { AdminSupportConversation } from "@/lib/api-client";
import { type Dictionary, type Locale } from "@/lib/i18n";
import styles from "@/components/support/support-page.module.css";

type AttachmentTileOptions = {
  overlayCount?: number;
  single?: boolean;
};

type SupportConversationChatHeaderProps = {
  conversation: AdminSupportConversation;
  conversationSla: {
    level: "good" | "warning" | "risk" | "critical";
    waitLabel: string | null;
  };
  deletedUserEmail: string;
  locale: Locale;
  searchInputRef: RefObject<HTMLInputElement | null>;
  searchQuery: string;
  setSearchQuery: (value: string) => void;
  supportWorkspaceSubtitle: string;
  text: Dictionary;
  userDisplayName: string;
  userEmailDisplay: string;
};

type SupportConversationMessagesProps = {
  canManageSupportWorkspace: boolean;
  conversation: AdminSupportConversation;
  conversationQueryIsFetching: boolean;
  copy: ReturnType<typeof getSupportConversationCopy>;
  groupedConversationFeed: SupportConversationFeedGroup[];
  highlightedMessageId: string | null;
  jumpToMessage: (messageId: string) => void;
  locale: Locale;
  messageLabels: ReturnType<typeof getSupportConversationCopy>["page"]["message"];
  messagesById: Map<string, SupportMessage>;
  messagesEndRef: RefObject<HTMLDivElement | null>;
  renderAttachmentTile: (
    message: SupportMessage,
    attachment: SupportMessageAttachment,
    attachmentIndex: number,
    options?: AttachmentTileOptions
  ) => ReactNode;
  renderReplyThumbnail: (attachment: SupportMessageAttachment | null | undefined) => ReactNode;
  requestOlderMessagesLoad: () => void;
  startReplyToMessage: (message: SupportMessage) => void;
  text: Dictionary;
};

function avatarColorFor(name: string): string {
  let hash = 0;
  for (let i = 0; i < name.length; i++) {
    hash = (hash + name.charCodeAt(i)) % 8;
  }
  return styles[`avatarColor${hash}` as keyof typeof styles] ?? styles.avatarColor6;
}

function mediaGridLayoutClass(count: number) {
  const key = count >= 7 ? "messageMediaGridCount7Plus" : `messageMediaGridCount${count}`;
  return styles[key as keyof typeof styles] ?? "";
}

function getSupportMessageElementId(messageId: string) {
  return `message-${encodeURIComponent(messageId)}`;
}

export function SupportConversationChatHeader({
  conversation,
  conversationSla,
  deletedUserEmail,
  locale,
  searchInputRef,
  searchQuery,
  setSearchQuery,
  supportWorkspaceSubtitle,
  text,
  userDisplayName,
  userEmailDisplay,
}: SupportConversationChatHeaderProps) {
  return (
    <div className={styles.supportPageHeader}>
      <div className={styles.supportPageTitleWrap}>
        <div className={styles.supportPageTitleRow}>
          <h1 className={styles.supportPageTitle}>{text.supportTitle}</h1>
        </div>
        <span className={styles.supportPageSubtitle}>{supportWorkspaceSubtitle}</span>
      </div>
      <div className={styles.supportPageToolbar}>
        <label className={`${styles.searchField} ${styles.supportPageHeroSearch}`}>
          <span className={styles.supportSearchIcon} aria-hidden="true">
            <SearchIcon />
          </span>
          <span className={styles.searchLabelHidden}>{text.supportSearchPlaceholder}</span>
          <input
            ref={searchInputRef}
            className={`${styles.searchInput} ${styles.supportPageSearchInput}`}
            value={searchQuery}
            onChange={(event) =>
              setSearchQuery(event.target.value.slice(0, SUPPORT_SEARCH_MAX_LENGTH))
            }
            maxLength={SUPPORT_SEARCH_MAX_LENGTH}
            placeholder={text.supportSearchPlaceholder}
            aria-label={text.supportSearchPlaceholder}
            title={text.supportSearchKeyboardHint}
          />
          <span className={styles.supportSearchShortcut} aria-hidden="true">
            /
          </span>
        </label>
      </div>

      <div className={styles.chatTopbar}>
        <div className={styles.chatHeaderTop}>
          <div className={styles.chatHeaderIdentity}>
            <span
              className={`${styles.avatarSm} ${avatarColorFor(userDisplayName)}`}
              aria-hidden="true"
            >
              {initialsFor(userDisplayName)}
            </span>
            <div>
              <div className={styles.chatHeaderNameRow}>
                <strong>{userDisplayName}</strong>
                <div className={styles.chatHeaderBadges}>
                  <AdminBadge tone={toneForStatus(conversation.status)}>
                    {statusLabel(conversation.status, text)}
                  </AdminBadge>
                  {conversationSla.waitLabel ? (
                    <span
                      className={`${styles.chatHeaderSlaBadge} ${
                        conversationSla.level === "critical" || conversationSla.level === "risk"
                          ? styles.chatHeaderSlaBadgeUrgent
                          : ""
                      }`}
                    >
                      {conversationSla.waitLabel}
                    </span>
                  ) : null}
                </div>
              </div>
              <span className={styles.chatHeaderSubtext}>
                {userEmailDisplay || deletedUserEmail} · #{shortId(conversation.initiatorUserId)}
              </span>
            </div>
          </div>
        </div>
        <div className={styles.chatMetaRow}>
          <span>{sourceLabel(conversation.source, text)}</span>
          <span className={styles.chatMetaDivider}>·</span>
          <span>
            {conversation.priority === "High"
              ? text.supportPriorityHigh
              : conversation.priority === "Low"
                ? text.supportPriorityLow
                : text.supportPriorityNormal}
          </span>
          <span className={styles.chatMetaDivider}>·</span>
          <span>{formatDateTime(conversation.createdAtUtc, locale)}</span>
        </div>
      </div>
    </div>
  );
}

export function SupportConversationMessages({
  canManageSupportWorkspace,
  conversation,
  conversationQueryIsFetching,
  copy,
  groupedConversationFeed,
  highlightedMessageId,
  jumpToMessage,
  locale,
  messageLabels,
  messagesById,
  messagesEndRef,
  renderAttachmentTile,
  renderReplyThumbnail,
  requestOlderMessagesLoad,
  startReplyToMessage,
  text,
}: SupportConversationMessagesProps) {
  if (conversation.messages.length === 0) {
    return <AdminStateCard tone="info" title={text.supportNoMessages} />;
  }

  return (
    <div className={styles.messagesWrap}>
      <div className={styles.messages}>
        {conversation.hasOlderMessages ? (
          <div className={styles.messagesLoadOlderRow}>
            <Button
              variant="ghost"
              onClick={requestOlderMessagesLoad}
              disabled={!canManageSupportWorkspace || conversationQueryIsFetching}
            >
              {copy.page.loadPreviousMessages}
            </Button>
          </div>
        ) : null}
        {groupedConversationFeed.map((group) => {
          const hasVisibleItems = group.items.some(
            (item) =>
              item.kind === "system" ||
              (item.kind === "message" &&
                (item.message.senderType?.trim().toLowerCase() ?? "") !== "system")
          );
          if (!hasVisibleItems) {
            return null;
          }

          return (
            <div key={group.key} className={styles.dayGroup}>
              <div className={styles.dayDivider}>{group.label}</div>
              {group.items.map((item) => {
                if (item.kind === "system") {
                  return (
                    <div
                      key={item.id}
                      className={`${styles.systemEventCard} ${styles[`systemEventCard_${item.tone}`] ?? ""}`}
                    >
                      <span className={styles.systemEventDot} />
                      <span>{item.label}</span>
                      <span className={styles.systemEventTime}>
                        {formatClockTime(item.occurredAtUtc, locale)}
                      </span>
                    </div>
                  );
                }

                const message = item.message;
                const attachments = getMessageAttachments(message);
                const primaryAttachment = attachments[0];
                const hasAttachmentGroup = attachments.length > 1;
                const senderType = message.senderType?.toLowerCase() ?? "";
                const isSystemMessage = senderType === "system";
                const isBotMessage = senderType === "bot";
                const shouldShowBody = shouldRenderMessageBody(message);
                const normalizedAttachmentStatus =
                  message.attachmentUploadStatus?.trim().toLowerCase() ?? "";
                const shouldShowAttachmentFailure =
                  normalizedAttachmentStatus === "failed" || normalizedAttachmentStatus === "retry";
                const hasMediaMessage = attachments.some(
                  (attachment) =>
                    attachment.mimeType.startsWith("image/") ||
                    attachment.mimeType.startsWith("video/")
                );
                const isMediaOnlyBubble = hasMediaMessage && !shouldShowBody;
                const repliedMessage = message.replyToMessageId
                  ? (messagesById.get(message.replyToMessageId) ?? null)
                  : null;
                const repliedAttachment = repliedMessage
                  ? getMessageAttachments(repliedMessage).find(
                      (attachment) => !attachment.isDeleted
                    )
                  : null;

                if (isSystemMessage) {
                  return null;
                }

                return (
                  <article
                    key={message.messageId}
                    id={getSupportMessageElementId(message.messageId)}
                    className={`${styles.messageItem} ${message.isFromAdmin ? styles.messageAdmin : styles.messageUser} ${isBotMessage ? styles.messageBot : ""} ${highlightedMessageId === message.messageId ? styles.messageHighlighted : ""} ${hasMediaMessage ? styles.messageWithMedia : ""} ${isMediaOnlyBubble ? styles.messageMediaOnly : ""}`}
                    onDoubleClick={() => startReplyToMessage(message)}
                  >
                    <button
                      type="button"
                      className={styles.messageReplyAction}
                      onClick={() => startReplyToMessage(message)}
                      title={messageLabels.reply}
                      aria-label={messageLabels.reply}
                    >
                      <ReplyIcon className={styles.messageReplyActionIcon} />
                    </button>
                    {message.replyToMessageId || message.replyToPreview?.trim() ? (
                      <button
                        type="button"
                        className={styles.messageReplyBlock}
                        onClick={() => {
                          if (message.replyToMessageId) {
                            jumpToMessage(message.replyToMessageId);
                          }
                        }}
                        disabled={!message.replyToMessageId}
                      >
                        {renderReplyThumbnail(repliedAttachment)}
                        <span className={styles.messageReplyBlockContent}>
                          <span className={styles.messageReplyBlockLabel}>
                            {messageLabels.replyTo}
                          </span>
                          <span className={styles.messageReplyBlockPreview}>
                            {formatSafeSupportDisplay(
                              message.replyToPreview,
                              text.supportReplyOriginalUnavailable,
                              160
                            )}
                          </span>
                        </span>
                      </button>
                    ) : null}
                    {attachments.length > 0 ? (
                      hasAttachmentGroup ? (
                        <div
                          className={`${styles.messageMediaGrid} ${mediaGridLayoutClass(attachments.length)}`}
                        >
                          {attachments
                            .slice(0, attachments.length >= 7 ? 6 : attachments.length)
                            .map((attachment, attachmentIndex, visibleAttachments) =>
                              renderAttachmentTile(message, attachment, attachmentIndex, {
                                overlayCount:
                                  attachments.length >= 7 &&
                                  attachmentIndex === visibleAttachments.length - 1
                                    ? attachments.length - visibleAttachments.length
                                    : 0,
                              })
                            )}
                        </div>
                      ) : primaryAttachment ? (
                        renderAttachmentTile(message, primaryAttachment, 0, {
                          single: true,
                        })
                      ) : null
                    ) : null}
                    {shouldShowBody ? (
                      <div className={styles.messageBody}>
                        {formatSafeSupportDisplay(message.body, "", 2000)}
                      </div>
                    ) : null}
                    {shouldShowAttachmentFailure ? (
                      <div className={styles.messageAttachmentStatusRow}>
                        <span
                          className={`${styles.messageAttachmentStatusPill} ${styles[`messageAttachmentStatus_${normalizedAttachmentStatus}`] ?? ""}`}
                        >
                          {normalizedAttachmentStatus === "retry"
                            ? copy.page.retryAttachmentUpload
                            : text.supportAttachmentFailedLabel}
                        </span>
                      </div>
                    ) : null}
                    <div className={styles.messageMeta}>
                      <span>{formatClockTime(message.createdAtUtc, locale)}</span>
                      {message.isFromAdmin && !isSystemMessage ? (
                        <span
                          className={`${styles.messageTick} ${message.isRead ? styles.messageTickRead : ""}`}
                          aria-label={message.isRead ? messageLabels.read : messageLabels.sent}
                          title={message.isRead ? messageLabels.read : messageLabels.sent}
                        >
                          {message.isRead ? "✓✓" : "✓"}
                        </span>
                      ) : null}
                    </div>
                  </article>
                );
              })}
            </div>
          );
        })}
        <div ref={messagesEndRef} />
      </div>
    </div>
  );
}
