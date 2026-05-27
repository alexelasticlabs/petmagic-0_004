"use client";

import Image from "next/image";
import Link from "next/link";
import { useEffect, useRef, useState } from "react";

import { AdminCard, AdminPage, AdminStateCard } from "@/components/admin/admin-primitives";
import {
  formatClockTime,
  formatDateTime,
  formatFileSize,
  formatRelativeTime,
  getConversationSla,
  groupSupportConversationFeed,
  hasAttachment,
  hasImageAttachment,
  hasVideoAttachment,
  initialsFor,
  shortId,
  shouldRenderMessageBody,
} from "@/components/support/support-conversation-helpers";
import { SupportConversationSidePanel } from "@/components/support/support-conversation-side-panel";
import { SupportOptionGroup } from "@/components/support/support-option-group";
import styles from "@/components/support/support-page.module.css";
import {
  priorityLabel,
  statusHint,
  statusLabel,
} from "@/components/support/support-status-helpers";
import {
  statusOptions,
  type SupportQueueFilter,
  useSupportConversationController,
} from "@/components/support/use-support-conversation-controller";
import { Button } from "@/components/ui/button";
import { Toast } from "@/components/ui/toast";
import { type Locale } from "@/lib/i18n";

type SupportConversationPageProps = {
  locale: Locale;
  conversationId: string;
};

type FullscreenImage = {
  url: string;
  fileName?: string | null;
  messageId?: string;
  senderDisplayName?: string | null;
  createdAtUtc?: string | null;
  fileSizeBytes?: number | null;
};

export function SupportConversationPage({ locale, conversationId }: SupportConversationPageProps) {
  const [fullscreenImage, setFullscreenImage] = useState<FullscreenImage | null>(null);
  const [showTemplates, setShowTemplates] = useState(false);
  const [isDragging, setIsDragging] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const searchInputRef = useRef<HTMLInputElement>(null);
  const {
    activeSidePanelTab,
    accountCreatedAt,
    activityTimeline,
    analyticsQuery,
    applyTemplate,
    assignmentMutation,
    attachmentInputRef,
    attachmentPreviewUrl,
    chatFacts,
    composerPlaceholder,
    composerValue,
    conversation,
    conversationQuery,
    conversationSla,
    conversationTimeline,
    destructiveStatusAction,
    failedGenerations,
    filteredInboxItems,
    filteredTemplates,
    hasComposerAttachment,
    inboxQuery,
    isAssignedToCurrentAdmin,
    isSidePanelOpen,
    isTemplateEditorOpen,
    openTemplateEditor,
    purchasesQuery,
    primaryStatusAction,
    recentFailures,
    recentUserPurchases,
    lastActivityAtUtc,
    lastUserPurchaseAtUtc,
    reply,
    resetSelectedAttachment,
    searchQuery,
    selectedAttachment,
    selectedTemplate,
    secondaryStatusActions,
    sendMutation,
    sessionUserId,
    setUserActiveMutation,
    setUserPremiumMutation,
    setActiveSidePanelTab,
    setIsSidePanelOpen,
    setIsTemplateEditorOpen,
    setQueueFilter,
    setReply,
    setSearchQuery,
    setSelectedAttachment,
    setSelectedTemplateId,
    setTemplateDraft,
    setTemplateSearchQuery,
    sidePanelDescription,
    sidePanelTabs,
    sidePanelTitle,
    queueFilter,
    subscriptionQuery,
    statusMutation,
    templateDeleteMutation,
    templateDraft,
    templateSaveMutation,
    templateSearchQuery,
    templatesQuery,
    text,
    toast,
    totalPurchases,
    userDisplayName,
    userQuery,
    visibleTemplates,
  } = useSupportConversationController({ locale, conversationId });

  const isConversationReadOnly = conversation?.isReadOnly ?? false;
  const isConversationClosed = conversation?.status === "Closed";
  const reopenStatusAction =
    primaryStatusAction?.status === "Open"
      ? primaryStatusAction
      : (secondaryStatusActions.find((action) => action.status === "Open") ?? null);
  const readOnlyComposerTitle = isConversationClosed
    ? locale === "ru"
      ? "Диалог закрыт. Чтобы продолжить, переоткройте обращение."
      : "Conversation is closed. Reopen it to continue."
    : statusHint(conversation?.status ?? "Closed", text);
  const imageViewerLabels = {
    close: locale === "ru" ? "Закрыть" : "Close",
    download: locale === "ru" ? "Скачать" : "Download",
    jump: locale === "ru" ? "К сообщению" : "Jump to message",
    openOriginal: locale === "ru" ? "Открыть оригинал" : "Open original",
    share: locale === "ru" ? "Поделиться" : "Share",
    author: locale === "ru" ? "Автор" : "Author",
    date: locale === "ru" ? "Дата" : "Date",
    size: locale === "ru" ? "Размер" : "Size",
  };

  // Auto-scroll to bottom when new messages arrive
  useEffect(() => {
    if (messagesEndRef.current) {
      messagesEndRef.current.scrollIntoView({ behavior: "smooth" });
    }
  }, [conversation?.messages.length]);

  const submitReply = () => {
    setShowTemplates(false);
    sendMutation.mutate();
  };

  const closeFullscreenImage = () => {
    setFullscreenImage(null);
  };

  // Keyboard shortcut: "/" focuses the inbox search input
  useEffect(() => {
    const handleGlobalKeyDown = (event: KeyboardEvent) => {
      const tag = (event.target as HTMLElement).tagName;
      if (event.key === "/" && tag !== "INPUT" && tag !== "TEXTAREA" && !event.metaKey && !event.ctrlKey) {
        event.preventDefault();
        searchInputRef.current?.focus();
      }
    };
    window.addEventListener("keydown", handleGlobalKeyDown);
    return () => window.removeEventListener("keydown", handleGlobalKeyDown);
  }, []);

  useEffect(() => {
    if (!fullscreenImage || typeof document === "undefined") {
      return;
    }

    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        setFullscreenImage(null);
      }
    };

    window.addEventListener("keydown", handleKeyDown);
    return () => {
      window.removeEventListener("keydown", handleKeyDown);
      document.body.style.overflow = previousOverflow;
    };
  }, [fullscreenImage]);

  const saveFullscreenImage = async () => {
    if (!fullscreenImage) {
      return;
    }

    try {
      const response = await fetch(fullscreenImage.url, { credentials: "include" });
      if (!response.ok) {
        return;
      }

      const blob = await response.blob();
      const objectUrl = URL.createObjectURL(blob);
      const link = document.createElement("a");
      link.href = objectUrl;
      link.download = fullscreenImage.fileName?.trim() || "support-image";
      document.body.append(link);
      link.click();
      link.remove();
      URL.revokeObjectURL(objectUrl);
    } catch {
      // Keep the dialog actionable even if browser download API is blocked.
    }
  };

  const shareFullscreenImage = async () => {
    if (!fullscreenImage) {
      return;
    }

    try {
      if (typeof window === "undefined") {
        return;
      }

      const browserNavigator = window.navigator as Navigator & {
        share?: (data: ShareData) => Promise<void>;
        clipboard?: Clipboard;
      };

      if (browserNavigator.share) {
        await browserNavigator.share({
          title: fullscreenImage.fileName ?? "Support attachment",
          url: fullscreenImage.url,
        });
        return;
      }

      if (browserNavigator.clipboard) {
        await browserNavigator.clipboard.writeText(fullscreenImage.url);
      }
    } catch {
      // Ignore action errors to avoid breaking message rendering.
    }
  };

  const openFullscreenImageInNewTab = () => {
    if (!fullscreenImage) {
      return;
    }

    window.open(fullscreenImage.url, "_blank", "noopener,noreferrer");
  };

  const jumpToMessage = (messageId: string) => {
    const target = document.getElementById(`message-${messageId}`);
    if (!target) {
      return;
    }

    target.scrollIntoView({ behavior: "smooth", block: "center" });
  };

  return (
    <AdminPage className={styles.page}>
      {toast ? <Toast type={toast.type} message={toast.message} /> : null}

      {conversationQuery.isLoading ? (
        <AdminStateCard
          tone="info"
          title={text.loading}
          description={text.supportConversationDescription}
        />
      ) : conversationQuery.isError || !conversation ? (
        <AdminStateCard
          tone="danger"
          title={text.supportLoadError}
          action={
            <Link
              href={`/${locale}/support`}
              className="ui-button ui-button--secondary ui-button--md"
            >
              {text.supportBackToInbox}
            </Link>
          }
        />
      ) : (
        <>
          <div className={styles.compactHeader}>
            <div className={styles.compactHeaderTrail}>
              <Link href={`/${locale}/support`} className={styles.compactHeaderLink}>
                {text.supportTitle}
              </Link>
              <span className={styles.compactHeaderSeparator}>/</span>
              <strong>{shortId(conversation.conversationId)}</strong>
              <span className={styles.subtle}>{userDisplayName}</span>
            </div>
            <div className={styles.compactHeaderMeta}>
              {conversation.adminUnreadCount > 0 ? (
                <span
                  className={styles.unreadDot}
                  aria-live="polite"
                  aria-label={`${conversation.adminUnreadCount} ${locale === "ru" ? "непрочитанных" : "unread"}`}
                >
                  {conversation.adminUnreadCount}
                </span>
              ) : null}
              <Button
                variant="secondary"
                size="sm"
                onClick={() => setIsSidePanelOpen((current) => !current)}
              >
                {isSidePanelOpen ? text.supportClosePanelAction : text.supportOpenPanelAction}
              </Button>
            </div>
          </div>

          <div
            className={`${styles.workspace} ${isSidePanelOpen ? styles.workspaceWithSidebar : styles.workspaceCompact}`}
          >
            <AdminCard className={styles.inboxPane}>
              <div className={styles.paneTopbar}>
                <div className={styles.paneTitleGroup}>
                  <span className={styles.paneEyebrow}>{text.supportTitle}</span>
                  <h2 className={styles.paneTitle}>{text.supportInboxTitle}</h2>
                  <p className={styles.paneDescription}>{text.supportInboxDescription}</p>
                </div>
                <div className={styles.paneCountBadge}>{filteredInboxItems.length}</div>
              </div>
              <div className={styles.inboxToolbar}>
                <SupportOptionGroup
                  label={text.supportQueueFilterLabel}
                  value={queueFilter}
                  options={[
                    { value: "all", label: text.supportStatusAll },
                    ...statusOptions.map((status) => ({
                      value: status,
                      label: statusLabel(status, text),
                    })),
                    { value: "mine", label: text.supportAssignmentMine },
                    { value: "unassigned", label: text.supportAssignmentUnassigned },
                  ]}
                  onChange={(value) => setQueueFilter(value as SupportQueueFilter)}
                  compact
                />
                <label className={styles.searchField}>
                  <span className={styles.searchLabelHidden}>{text.supportSearchPlaceholder}</span>
                  <input
                    ref={searchInputRef}
                    className={styles.searchInput}
                    value={searchQuery}
                    onChange={(event) => setSearchQuery(event.target.value)}
                    placeholder={text.supportSearchPlaceholder}
                    aria-label={text.supportSearchPlaceholder}
                    title={text.supportSearchKeyboardHint}
                  />
                </label>
              </div>

              {inboxQuery.isLoading ? (
                <AdminStateCard tone="info" title={text.loading} />
              ) : inboxQuery.isError ? (
                <AdminStateCard tone="danger" title={text.supportLoadError} />
              ) : filteredInboxItems.length === 0 ? (
                <AdminStateCard tone="info" title={text.supportEmpty} />
              ) : (
                <div className={styles.list} role="list">
                  {filteredInboxItems.map((item) => {
                    const itemSla = getConversationSla(
                      item.lastMessageAtUtc ?? item.createdAtUtc,
                      locale,
                      item.adminUnreadCount
                    );
                    const hasUnread = item.adminUnreadCount > 0;
                    const assignedName =
                      item.assignedAdminDisplayName?.trim() || text.supportUnassigned;

                    return (
                      <Link
                        key={item.conversationId}
                        href={`/${locale}/support/${item.conversationId}`}
                        role="listitem"
                        aria-current={item.conversationId === conversationId ? "page" : undefined}
                        className={`${styles.conversationRow} ${item.isReadOnly ? styles.conversationRowClosed : ""} ${item.conversationId === conversationId ? styles.conversationRowActive : ""} ${hasUnread ? styles.conversationRowUnread : ""}`}
                      >
                        <div className={styles.rowHeader}>
                          <div className={styles.rowIdentity}>
                            <span
                              className={styles.avatar}
                              aria-hidden="true"
                            >
                              {initialsFor(item.userDisplayName?.trim() || item.userEmail)}
                            </span>
                            <div className={styles.rowTextStack}>
                              <div
                                className={`${styles.rowTitle} ${hasUnread ? styles.rowTitleUnread : ""}`}
                              >
                                {item.userDisplayName?.trim() || item.userEmail}
                              </div>
                              <div className={styles.rowPreview}>
                                <span>{item.lastMessagePreview || text.supportNoMessages}</span>
                              </div>
                            </div>
                          </div>
                          <span className={styles.timePill}>
                            {formatRelativeTime(item.lastMessageAtUtc ?? item.updatedAtUtc, locale)}
                          </span>
                        </div>
                        <div className={styles.rowSlaLine}>
                          <span
                            className={`${styles.slaPill} ${styles[`slaPill_${itemSla.level}`]}`}
                          >
                            {itemSla.primaryLabel}
                          </span>
                          <div className={styles.rowMetaGroup}>
                            {hasUnread ? (
                              <span className={styles.unreadDot}>{item.adminUnreadCount}</span>
                            ) : null}
                            <span className={styles.rowSecondaryMeta}>
                              {statusLabel(item.status, text)}
                            </span>
                            <span className={styles.rowSecondaryMeta}>
                              {priorityLabel(item.priority, text)}
                            </span>
                            <span
                              className={styles.rowSecondaryMeta}
                              title={assignedName}
                            >
                              {assignedName}
                            </span>
                          </div>
                        </div>
                      </Link>
                    );
                  })}
                </div>
              )}
            </AdminCard>

            <div
              className={styles.chatPane}
              onDragOver={(event) => {
                event.preventDefault();
                if (!isConversationReadOnly) setIsDragging(true);
              }}
              onDragEnter={(event) => {
                event.preventDefault();
                if (!isConversationReadOnly) setIsDragging(true);
              }}
              onDragLeave={(event) => {
                if (!event.currentTarget.contains(event.relatedTarget as Node)) {
                  setIsDragging(false);
                }
              }}
              onDrop={(event) => {
                event.preventDefault();
                setIsDragging(false);
                if (isConversationReadOnly) return;
                const droppedFile = event.dataTransfer.files[0];
                if (droppedFile) {
                  setSelectedAttachment(droppedFile);
                }
              }}
            >
              <AdminCard
                className={`${styles.chatShell} ${isDragging ? styles.chatShellDragging : ""}`}
              >
                {isDragging ? (
                  <div className={styles.dropOverlay}>
                    <div className={styles.dropOverlayContent}>
                      <svg
                        width="40"
                        height="40"
                        viewBox="0 0 24 24"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth="1.5"
                        aria-hidden="true"
                      >
                        <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
                        <polyline points="17 8 12 3 7 8" />
                        <line x1="12" y1="3" x2="12" y2="15" />
                      </svg>
                      <span>{locale === "ru" ? "Перетащите фото сюда" : "Drop image here"}</span>
                    </div>
                  </div>
                ) : null}
                <div className={styles.chatTopbar}>
                  <div className={styles.chatIdentityCompact}>
                    <div className={styles.chatTitleRow}>
                      <strong className={styles.chatUserName}>{userDisplayName}</strong>
                    </div>
                    <div className={styles.chatMetaLine}>
                      <span>{conversation.userEmail}</span>
                      <span>•</span>
                      <span>{shortId(conversation.initiatorUserId)}</span>
                    </div>
                    <div className={styles.chatStatusLine}>
                      <span>{statusLabel(conversation.status, text)}</span>
                      <span>•</span>
                      <span>{priorityLabel(conversation.priority, text)}</span>
                      <span>•</span>
                      <span>
                        {locale === "ru" ? "Назначен:" : "Assigned:"}{" "}
                        {conversation.assignedAdminDisplayName?.trim() ||
                          (locale === "ru" ? "Не назначен" : "Unassigned")}
                      </span>
                    </div>
                  </div>

                  <div className={styles.chatHeaderAside}>
                    <span
                      className={`${styles.slaPill} ${styles[`slaPill_${conversationSla.level}`]}`}
                    >
                      {conversationSla.waitLabel}
                    </span>
                  </div>
                </div>

                {conversation.messages.length > 0 ? (
                  <div className={styles.messagesWrap}>
                    <div className={styles.messages}>
                      {groupSupportConversationFeed(conversation, {
                        today: text.supportTodayLabel,
                        yesterday: text.supportYesterdayLabel,
                        earlier: text.supportEarlierLabel,
                        ticketCreated: text.supportSystemTicketCreated,
                        ticketResolved: text.supportSystemTicketResolved,
                        ticketReopened: text.supportSystemTicketReopened,
                        ticketClosed: text.supportSystemTicketClosed,
                      }).map((group) => (
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
                            const senderType = message.senderType?.toLowerCase() ?? "";
                            const isSystemMessage = senderType === "system";
                            const isBotMessage = senderType === "bot";

                            if (isSystemMessage) {
                              return (
                                <div
                                  key={message.messageId}
                                  id={`message-${message.messageId}`}
                                  className={styles.inlineSystemLabel}
                                >
                                  <span>{message.body}</span>
                                  <span className={styles.systemEventTime}>
                                    {formatClockTime(message.createdAtUtc, locale)}
                                  </span>
                                </div>
                              );
                            }

                            return (
                              <article
                                key={message.messageId}
                                id={`message-${message.messageId}`}
                                className={`${styles.messageItem} ${message.isFromAdmin ? styles.messageAdmin : styles.messageUser} ${isBotMessage ? styles.messageBot : ""}`}
                              >
                                <div className={styles.messageHeader}>
                                  <div className={styles.messageSenderWrap}>
                                    {message.isFromAdmin ? (
                                      <span
                                        className={`${styles.avatarTiny} ${styles.avatarTinyAdmin}`}
                                        aria-hidden="true"
                                      >
                                        PM
                                      </span>
                                    ) : isBotMessage ? (
                                      <span
                                        className={`${styles.avatarTiny} ${styles.avatarTinyBot}`}
                                        aria-hidden="true"
                                      >
                                        AI
                                      </span>
                                    ) : (
                                      <span className={styles.avatarTiny} aria-hidden="true">
                                        {initialsFor(message.senderDisplayName)}
                                      </span>
                                    )}
                                    <strong>
                                      {isBotMessage
                                        ? text.supportAssistantMobileLabel
                                        : message.senderDisplayName}
                                    </strong>
                                  </div>
                                  <span>{formatClockTime(message.createdAtUtc, locale)}</span>
                                </div>
                                {hasImageAttachment(message) ? (
                                  <button
                                    type="button"
                                    onClick={() =>
                                      setFullscreenImage({
                                        url: message.attachmentUrl!,
                                        fileName: message.attachmentFileName,
                                        messageId: message.messageId,
                                        senderDisplayName: message.senderDisplayName,
                                        createdAtUtc: message.createdAtUtc,
                                        fileSizeBytes: message.attachmentFileSizeBytes,
                                      })
                                    }
                                    className={styles.messageImageButton}
                                  >
                                    <Image
                                      src={message.attachmentUrl!}
                                      alt={message.attachmentFileName ?? message.body}
                                      width={152}
                                      height={120}
                                      sizes="(max-width: 860px) 100vw, 152px"
                                      className={styles.messageImage}
                                      loading="lazy"
                                      unoptimized
                                    />
                                  </button>
                                ) : hasVideoAttachment(message) ? (
                                  <div className={styles.messageVideoButton}>
                                    <video
                                      controls
                                      preload="metadata"
                                      src={message.attachmentUrl!}
                                      className={styles.messageVideo}
                                    />
                                  </div>
                                ) : hasAttachment(message) ? (
                                  <a
                                    href={message.attachmentUrl!}
                                    target="_blank"
                                    rel="noopener noreferrer"
                                    download={message.attachmentFileName ?? "attachment"}
                                    className={styles.messageAttachmentCard}
                                  >
                                    <div className={styles.messageAttachmentIcon}>FILE</div>
                                    <div className={styles.messageAttachmentMeta}>
                                      <strong>
                                        {message.attachmentFileName ?? message.body}
                                      </strong>
                                      <span>
                                        {formatFileSize(message.attachmentFileSizeBytes, locale)}
                                      </span>
                                    </div>
                                  </a>
                                ) : null}
                                {shouldRenderMessageBody(message) ? (
                                  <div className={styles.messageBody}>{message.body}</div>
                                ) : null}
                                {message.attachmentUploadStatus &&
                                  message.attachmentUploadStatus.toLowerCase() !== "uploaded" ? (
                                  <div className={styles.messageAttachmentStatusRow}>
                                    <span
                                      className={`${styles.messageAttachmentStatusPill} ${styles[`messageAttachmentStatus_${message.attachmentUploadStatus.toLowerCase()}`] ?? ""}`}
                                    >
                                      {message.attachmentUploadStatus.toLowerCase() === "pending"
                                        ? text.supportAttachmentUploadingLabel
                                        : message.attachmentUploadStatus.toLowerCase() === "failed"
                                          ? text.supportAttachmentFailedLabel
                                          : message.attachmentUploadStatus}
                                    </span>
                                    {message.attachmentUploadErrorCode ? (
                                      <span className={styles.messageAttachmentStatusErrorCode}>
                                        {message.attachmentUploadErrorCode}
                                      </span>
                                    ) : null}
                                  </div>
                                ) : null}
                              </article>
                            );
                          })}
                        </div>
                      ))}
                      <div ref={messagesEndRef} />
                    </div>
                  </div>
                ) : (
                  <AdminStateCard tone="info" title={text.supportNoMessages} />
                )}

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
                            onClick={() => statusMutation.mutate(reopenStatusAction.status)}
                            disabled={statusMutation.isPending}
                          >
                            {text.supportReopenConversationAction}
                          </Button>
                        </div>
                      ) : null}
                    </div>
                  ) : (
                    <>
                      {showTemplates && visibleTemplates.length > 0 ? (
                        <div className={styles.composerTemplateRail}>
                          <span className={styles.subtle}>{text.supportQuickRepliesLabel}</span>
                          <div className={`${styles.templateList} ${styles.templateListCompact}`}>
                            {visibleTemplates.map((template) => (
                              <Button
                                key={template.templateId}
                                size="sm"
                                variant="ghost"
                                className={styles.quickTemplateButton}
                                disabled={isConversationReadOnly}
                                onClick={() => applyTemplate(template)}
                              >
                                {`✓ ${template.title}`}
                              </Button>
                            ))}
                          </div>
                        </div>
                      ) : null}

                      <input
                        ref={attachmentInputRef}
                        type="file"
                        className={styles.hiddenFileInput}
                        accept="image/jpeg,image/png,image/webp"
                        onChange={(event) => {
                          const nextFile = event.target.files?.[0] ?? null;
                          setSelectedAttachment(nextFile);
                        }}
                      />
                      <div className={styles.composerAttachmentBar}>
                        <Button
                          variant="secondary"
                          size="sm"
                          onClick={() => attachmentInputRef.current?.click()}
                          disabled={sendMutation.isPending || isConversationReadOnly}
                        >
                          {text.chooseFile}
                        </Button>
                        {visibleTemplates.length > 0 ? (
                          <Button
                            variant="ghost"
                            size="sm"
                            onClick={() => setShowTemplates((v) => !v)}
                            disabled={isConversationReadOnly}
                          >
                            {showTemplates
                              ? locale === "ru"
                                ? "⚡ Скрыть"
                                : "⚡ Hide"
                              : locale === "ru"
                                ? "⚡ Шаблоны"
                                : "⚡ Templates"}
                          </Button>
                        ) : null}
                        <span className={styles.subtle}>{text.supportAttachmentHint}</span>
                      </div>
                      {selectedAttachment ? (
                        <div className={styles.attachmentPreviewCard}>
                          {attachmentPreviewUrl ? (
                            <button
                              type="button"
                              className={styles.attachmentPreviewImageButton}
                              onClick={() =>
                                setFullscreenImage({
                                  url: attachmentPreviewUrl,
                                  fileName: selectedAttachment.name,
                                  fileSizeBytes: selectedAttachment.size,
                                })
                              }
                            >
                              <Image
                                src={attachmentPreviewUrl}
                                alt={selectedAttachment.name}
                                width={72}
                                height={72}
                                sizes="72px"
                                className={styles.attachmentPreviewImage}
                                unoptimized
                              />
                            </button>
                          ) : (
                            <div className={styles.attachmentPreviewFileIcon}>FILE</div>
                          )}
                          <div className={styles.attachmentPreviewMeta}>
                            <span className={styles.subtle}>{text.selectedFileLabel}</span>
                            <strong>{selectedAttachment.name}</strong>
                            <span className={styles.subtle}>
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
                                    url: attachmentPreviewUrl,
                                    fileName: selectedAttachment.name,
                                    fileSizeBytes: selectedAttachment.size,
                                  })
                                }
                              >
                                {text.supportAttachmentOpenAction}
                              </button>
                            ) : null}
                            <Button variant="ghost" size="sm" onClick={resetSelectedAttachment}>
                              {text.supportAttachmentRemoveAction}
                            </Button>
                          </div>
                        </div>
                      ) : null}

                      <textarea
                        className={styles.textarea}
                        value={composerValue}
                        onChange={(event) => setReply(event.target.value)}
                        onKeyDown={(event) => {
                          if (
                            event.key === "Enter" &&
                            !event.shiftKey &&
                            !isConversationReadOnly &&
                            !sendMutation.isPending &&
                            (reply.trim() || hasComposerAttachment)
                          ) {
                            event.preventDefault();
                            submitReply();
                          }
                        }}
                        placeholder={
                          isConversationReadOnly
                            ? statusHint(conversation.status, text)
                            : composerPlaceholder
                        }
                        disabled={isConversationReadOnly}
                      />

                      <div className={styles.composerActions}>
                        <div className={styles.rowMetaGroup}>
                          <Button
                            variant="primary"
                            onClick={submitReply}
                            disabled={
                              isConversationReadOnly ||
                              sendMutation.isPending ||
                              (!reply.trim() && !hasComposerAttachment)
                            }
                          >
                            {sendMutation.isPending
                              ? text.supportReplySending
                              : text.supportReplyAction}
                          </Button>
                        </div>
                      </div>
                    </>
                  )}
                </div>
              </AdminCard>
            </div>

            <SupportConversationSidePanel
              locale={locale}
              onJumpToMessage={jumpToMessage}
              onOpenAttachmentPreview={(message) =>
                setFullscreenImage({
                  url: message.attachmentUrl!,
                  fileName: message.attachmentFileName,
                  messageId: message.messageId,
                  senderDisplayName: message.senderDisplayName,
                  createdAtUtc: message.createdAtUtc,
                  fileSizeBytes: message.attachmentFileSizeBytes,
                })
              }
              controller={{
                activeSidePanelTab,
                accountCreatedAt,
                activityTimeline,
                analyticsQuery,
                applyTemplate,
                assignmentMutation,
                attachmentInputRef,
                attachmentPreviewUrl,
                chatFacts,
                composerPlaceholder,
                composerValue,
                conversation,
                conversationQuery,
                conversationSla,
                conversationTimeline,
                destructiveStatusAction,
                failedGenerations,
                filteredInboxItems,
                filteredTemplates,
                hasComposerAttachment,
                inboxQuery,
                isAssignedToCurrentAdmin,
                isSidePanelOpen,
                isTemplateEditorOpen,
                openTemplateEditor,
                primaryStatusAction,
                purchasesQuery,
                recentUserPurchases,
                lastActivityAtUtc,
                lastUserPurchaseAtUtc,
                recentFailures,
                reply,
                resetSelectedAttachment,
                searchQuery,
                selectedAttachment,
                selectedTemplate,
                secondaryStatusActions,
                sendMutation,
                sessionUserId,
                setUserActiveMutation,
                setUserPremiumMutation,
                setActiveSidePanelTab,
                setIsSidePanelOpen,
                setIsTemplateEditorOpen,
                setQueueFilter,
                setReply,
                setSearchQuery,
                setSelectedAttachment,
                setSelectedTemplateId,
                setTemplateDraft,
                setTemplateSearchQuery,
                sidePanelDescription,
                sidePanelTabs,
                sidePanelTitle,
                queueFilter,
                subscriptionQuery,
                statusMutation,
                templateDeleteMutation,
                templateDraft,
                templateSaveMutation,
                templateSearchQuery,
                templatesQuery,
                text,
                toast,
                totalPurchases,
                userDisplayName,
                userQuery,
                visibleTemplates,
              }}
            />
          </div>
          {fullscreenImage ? (
            <div
              className={styles.imageViewerOverlay}
              role="dialog"
              aria-modal="true"
              aria-label={fullscreenImage.fileName?.trim() || "Image preview"}
              onClick={closeFullscreenImage}
            >
              <div className={styles.imageViewerPanel} onClick={(event) => event.stopPropagation()}>
                <div className={styles.imageViewerHeader}>
                  <strong>{fullscreenImage.fileName?.trim() || "Image"}</strong>
                  <Button variant="ghost" size="sm" onClick={closeFullscreenImage}>
                    {imageViewerLabels.close}
                  </Button>
                </div>
                <div className={styles.imageViewerBody}>
                  <Image
                    src={fullscreenImage.url}
                    alt={fullscreenImage.fileName ?? "Support image"}
                    width={1720}
                    height={980}
                    sizes="100vw"
                    className={styles.imageViewerImage}
                    unoptimized
                  />
                </div>
                <div className={styles.imageViewerMeta}>
                  {fullscreenImage.senderDisplayName ? (
                    <div>
                      <span>{imageViewerLabels.author}</span>
                      <strong>{fullscreenImage.senderDisplayName}</strong>
                    </div>
                  ) : null}
                  {fullscreenImage.createdAtUtc ? (
                    <div>
                      <span>{imageViewerLabels.date}</span>
                      <strong>{formatDateTime(fullscreenImage.createdAtUtc, locale)}</strong>
                    </div>
                  ) : null}
                  <div>
                    <span>{imageViewerLabels.size}</span>
                    <strong>{formatFileSize(fullscreenImage.fileSizeBytes, locale)}</strong>
                  </div>
                </div>
                <div className={styles.imageViewerActions}>
                  <Button variant="secondary" size="sm" onClick={saveFullscreenImage}>
                    {imageViewerLabels.download}
                  </Button>
                  <Button variant="secondary" size="sm" onClick={shareFullscreenImage}>
                    {imageViewerLabels.share}
                  </Button>
                  {fullscreenImage.messageId ? (
                    <Button
                      variant="secondary"
                      size="sm"
                      onClick={() => {
                        const messageId = fullscreenImage.messageId!;
                        closeFullscreenImage();
                        window.setTimeout(() => jumpToMessage(messageId), 0);
                      }}
                    >
                      {imageViewerLabels.jump}
                    </Button>
                  ) : null}
                  <Button variant="secondary" size="sm" onClick={openFullscreenImageInNewTab}>
                    {imageViewerLabels.openOriginal}
                  </Button>
                  <Button variant="primary" size="sm" onClick={closeFullscreenImage}>
                    {imageViewerLabels.close}
                  </Button>
                </div>
              </div>
            </div>
          ) : null}
        </>
      )}
    </AdminPage>
  );
}
