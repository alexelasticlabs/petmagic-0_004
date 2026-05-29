"use client";

import Image from "next/image";
import Link from "next/link";
import { useEffect, useRef, useState } from "react";

import {
  AdminBadge,
  AdminCard,
  AdminPage,
  AdminStateCard,
} from "@/components/admin/admin-primitives";
import {
  formatClockTime,
  formatDateTime,
  formatFileSize,
  formatRelativeTime,
  getConversationSla,
  getMessageAttachments,
  groupSupportConversationFeed,
  initialsFor,
  shortId,
  shouldRenderMessageBody,
} from "@/components/support/support-conversation-helpers";
import { SupportInfoPanel } from "@/components/support/support-info-panel";
import styles from "@/components/support/support-page.module.css";
import {
  sourceLabel,
  statusHint,
  statusLabel,
  toneForStatus,
} from "@/components/support/support-status-helpers";
import { useSupportConversationController } from "@/components/support/use-support-conversation-controller";
import { Button } from "@/components/ui/button";
import { Select } from "@/components/ui/select";
import { Toast } from "@/components/ui/toast";
import type {
  AdminSupportConversation,
  SupportConversationPriority,
  SupportConversationStatus,
} from "@/lib/api-client";
import { type Locale } from "@/lib/i18n";

type SupportConversationPageProps = {
  locale: Locale;
  conversationId: string;
  navigationMode?: "route" | "local";
  onConversationSelect?: (conversationId: string) => void;
};

type FullscreenImage = {
  mediaType?: "image" | "video";
  url: string;
  fileName?: string | null;
  messageId?: string;
  senderDisplayName?: string | null;
  createdAtUtc?: string | null;
  fileSizeBytes?: number | null;
  durationSeconds?: number | null;
};

type SupportMessage = AdminSupportConversation["messages"][number];
type SupportMessageAttachment = ReturnType<typeof getMessageAttachments>[number];

export function SupportConversationPage({
  locale,
  conversationId,
  navigationMode = "route",
  onConversationSelect,
}: SupportConversationPageProps) {
  const [fullscreenImage, setFullscreenImage] = useState<FullscreenImage | null>(null);
  const [isDragging, setIsDragging] = useState(false);
  const [highlightedMessageId, setHighlightedMessageId] = useState<string | null>(null);
  const [subFilter, setSubFilter] = useState<"all" | "waiting" | "unassigned" | "archive">("all");
  const [queueStatusFilter, setQueueStatusFilter] = useState<"all" | SupportConversationStatus>(
    "all"
  );
  const [queuePriorityFilter, setQueuePriorityFilter] = useState<
    "all" | SupportConversationPriority
  >("all");
  const [queueSortBy, setQueueSortBy] = useState<"recent" | "status" | "priority">("recent");
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const searchInputRef = useRef<HTMLInputElement>(null);
  const messageHighlightTimerRef = useRef<number | null>(null);
  const controller = useSupportConversationController({ locale, conversationId });
  const {
    attachmentInputRef,
    attachmentPreviewUrl,
    composerPlaceholder,
    composerValue,
    conversation,
    conversationQuery,
    conversationSla,
    filteredInboxItems,
    hasComposerAttachment,
    inboxQuery,
    isSidePanelOpen,
    primaryStatusAction,
    reply,
    replyToMessage,
    replyToPreview,
    resetSelectedAttachment,
    searchQuery,
    secondaryStatusActions,
    selectedAttachment,
    selectReplyToMessage,
    sendMutation,
    setIsSidePanelOpen,
    setMessagesViewportVisible,
    setReply,
    setSearchQuery,
    setSelectedAttachment,
    statusMutation,
    text,
    toast,
    userDisplayName,
  } = controller;

  const isConversationReadOnly = conversation?.isReadOnly ?? false;
  const isConversationClosed = conversation?.status === "Closed";

  const waitingCount = filteredInboxItems.filter(
    (item) => item.status === "New" || item.status === "WaitingForUser"
  ).length;
  const archiveCount = filteredInboxItems.filter((item) => item.status === "Closed").length;
  const activeCount = filteredInboxItems.length - archiveCount;
  const incomingMessagesCount = filteredInboxItems.filter((item) => item.unreadForAdmin).length;
  const unassignedCount = filteredInboxItems.filter((item) => !item.assignedAdminId).length;
  const displayedInboxItems = filteredInboxItems
    .filter((item) => {
      const isArchived = item.status === "Closed";

      if (subFilter === "archive") {
        return isArchived;
      }

      if (isArchived) {
        return false;
      }

      if (subFilter === "waiting") {
        return item.status === "New" || item.status === "WaitingForUser";
      }
      if (subFilter === "unassigned") {
        return !item.assignedAdminId;
      }
      return true;
    })
    .filter((item) => (queueStatusFilter === "all" ? true : item.status === queueStatusFilter))
    .filter((item) =>
      queuePriorityFilter === "all" ? true : item.priority === queuePriorityFilter
    )
    .slice()
    .sort((left, right) => {
      if (queueSortBy === "status") {
        const statusOrder: Record<SupportConversationStatus, number> = {
          New: 0,
          InProgress: 1,
          WaitingForUser: 2,
          Closed: 3,
        };
        const byStatus = statusOrder[left.status] - statusOrder[right.status];
        if (byStatus !== 0) {
          return byStatus;
        }
      }

      if (queueSortBy === "priority") {
        const priorityOrder: Record<SupportConversationPriority, number> = {
          High: 0,
          Normal: 1,
          Low: 2,
        };
        const byPriority = priorityOrder[left.priority] - priorityOrder[right.priority];
        if (byPriority !== 0) {
          return byPriority;
        }
      }

      const leftTs = left.lastMessageAtUtc ?? left.updatedAtUtc ?? left.createdAtUtc;
      const rightTs = right.lastMessageAtUtc ?? right.updatedAtUtc ?? right.createdAtUtc;
      return rightTs.localeCompare(leftTs);
    });
  const reopenStatusAction =
    primaryStatusAction?.status === "InProgress"
      ? primaryStatusAction
      : (secondaryStatusActions.find((action) => action.status === "InProgress") ?? null);
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
  const supportWorkspaceSubtitle =
    locale === "ru"
      ? "Единое рабочее пространство для очереди, переписки и действий оператора"
      : "Unified workspace for queue, conversation, and operator actions";

  // Auto-scroll to bottom when new messages arrive
  useEffect(() => {
    if (messagesEndRef.current) {
      messagesEndRef.current.scrollIntoView({ behavior: "smooth" });
    }
  }, [conversation?.messages.length]);

  // Track whether the latest messages are actually inside the viewport so the
  // controller only marks the conversation read when the operator can see them.
  useEffect(() => {
    const node = messagesEndRef.current;
    if (!node || typeof IntersectionObserver === "undefined") {
      setMessagesViewportVisible(true);
      return;
    }

    const observer = new IntersectionObserver(
      (entries) => {
        setMessagesViewportVisible(entries.some((entry) => entry.isIntersecting));
      },
      { threshold: 0.1 }
    );

    observer.observe(node);
    return () => {
      observer.disconnect();
      setMessagesViewportVisible(false);
    };
  }, [conversationId, conversation?.messages.length, setMessagesViewportVisible]);

  useEffect(() => {
    selectReplyToMessage(null);
  }, [conversationId, selectReplyToMessage]);

  const submitReply = () => {
    sendMutation.mutate();
  };

  const avatarColorFor = (name: string): string => {
    let hash = 0;
    for (let i = 0; i < name.length; i++) {
      hash = (hash + name.charCodeAt(i)) % 8;
    }
    return styles[`avatarColor${hash}` as keyof typeof styles] ?? styles.avatarColor6;
  };

  const queueStatusIcon = (status: SupportConversationStatus) => {
    if (status === "New") return "✦";
    if (status === "InProgress") return "▶";
    if (status === "WaitingForUser") return "⏳";
    return "✓";
  };

  const closeFullscreenImage = () => {
    setFullscreenImage(null);
  };

  // Keyboard shortcut: "/" focuses the inbox search input
  useEffect(() => {
    const handleGlobalKeyDown = (event: KeyboardEvent) => {
      const tag = (event.target as HTMLElement).tagName;
      if (
        event.key === "/" &&
        tag !== "INPUT" &&
        tag !== "TEXTAREA" &&
        !event.metaKey &&
        !event.ctrlKey
      ) {
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

  useEffect(
    () => () => {
      if (messageHighlightTimerRef.current !== null) {
        window.clearTimeout(messageHighlightTimerRef.current);
      }
    },
    []
  );

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
      const defaultFileName =
        fullscreenImage.mediaType === "video" ? "support-video" : "support-image";
      link.download = fullscreenImage.fileName?.trim() || defaultFileName;
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

  const highlightMessage = (messageId: string) => {
    setHighlightedMessageId(messageId);
    if (messageHighlightTimerRef.current !== null) {
      window.clearTimeout(messageHighlightTimerRef.current);
    }

    messageHighlightTimerRef.current = window.setTimeout(() => {
      setHighlightedMessageId((current) => (current === messageId ? null : current));
      messageHighlightTimerRef.current = null;
    }, 1500);
  };

  const jumpToMessage = (messageId: string) => {
    const target = document.getElementById(`message-${messageId}`);
    if (!target) {
      return;
    }

    target.scrollIntoView({ behavior: "smooth", block: "center" });
    highlightMessage(messageId);
  };

  const formatAttachmentDuration = (value?: number | null) => {
    if (!value || value <= 0) {
      return "0:00";
    }

    const totalSeconds = Math.max(0, Math.round(value));
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    return `${minutes}:${seconds.toString().padStart(2, "0")}`;
  };

  const resolveReplyPreview = (
    message: Pick<
      AdminSupportConversation["messages"][number],
      | "body"
      | "attachments"
      | "replyToPreview"
      | "attachmentFileName"
      | "attachmentUrl"
      | "attachmentContentType"
      | "attachmentFileSizeBytes"
    >
  ) => {
    const body = message.body.trim();
    if (body && shouldRenderMessageBody(message)) {
      return body;
    }

    const attachments = getMessageAttachments(message);
    if (attachments.length > 1) {
      return locale === "ru"
        ? `Вложения (${attachments.length})`
        : `Attachments (${attachments.length})`;
    }

    const primaryAttachment = attachments[0];
    if (!primaryAttachment) {
      return text.supportReplyOriginalUnavailable;
    }

    if (primaryAttachment.mimeType.startsWith("image/")) {
      return locale === "ru" ? "Фото" : "Photo";
    }

    if (primaryAttachment.mimeType.startsWith("video/")) {
      return locale === "ru" ? "Видео" : "Video";
    }

    return primaryAttachment.fileName || (locale === "ru" ? "Файл" : "File");
  };

  const startReplyToMessage = (message: AdminSupportConversation["messages"][number]) => {
    const preview = resolveReplyPreview(message);
    selectReplyToMessage(message.messageId, preview);
  };

  const replyComposerPreview =
    replyToPreview?.trim() ||
    (replyToMessage ? resolveReplyPreview(replyToMessage) : text.supportReplyOriginalUnavailable);
  const replyComposerAttachment = replyToMessage
    ? getMessageAttachments(replyToMessage).find((attachment) => !attachment.isDeleted)
    : null;

  const mediaGridLayoutClass = (count: number) => {
    const key = count >= 7 ? "messageMediaGridCount7Plus" : `messageMediaGridCount${count}`;
    return styles[key as keyof typeof styles] ?? "";
  };

  const renderReplyThumbnail = (attachment: SupportMessageAttachment | null | undefined) => {
    if (!attachment || attachment.isDeleted) {
      return null;
    }

    if (attachment.mimeType.startsWith("image/")) {
      return (
        <Image
          src={attachment.fileUrl}
          alt=""
          width={34}
          height={34}
          sizes="34px"
          className={styles.replyThumbImage}
          loading="lazy"
          unoptimized
        />
      );
    }

    return (
      <span className={styles.replyThumbIcon} aria-hidden="true">
        {attachment.mimeType.startsWith("video/") ? "▶" : "FILE"}
      </span>
    );
  };

  const renderAttachmentTile = (
    message: SupportMessage,
    attachment: SupportMessageAttachment,
    attachmentIndex: number,
    options?: { overlayCount?: number; single?: boolean }
  ) => {
    const key = `${message.messageId}:${attachmentIndex}`;
    const overlayCount = options?.overlayCount ?? 0;
    const tileClassName = `${styles.messageMediaTile} ${options?.single ? styles.messageMediaTileSingle : ""}`;

    if (attachment.isDeleted) {
      return (
        <div key={key} className={`${styles.deletedAttachmentPlaceholder} ${tileClassName}`}>
          {text.supportAttachmentExpiredLabel}
        </div>
      );
    }

    const isImage = attachment.mimeType.startsWith("image/");
    const isVideo = attachment.mimeType.startsWith("video/");

    if (isImage) {
      return (
        <button
          key={key}
          type="button"
          onClick={() =>
            setFullscreenImage({
              mediaType: "image",
              url: attachment.fileUrl,
              fileName: attachment.fileName,
              messageId: message.messageId,
              senderDisplayName: message.senderDisplayName,
              createdAtUtc: message.createdAtUtc,
              fileSizeBytes: attachment.sizeBytes,
            })
          }
          className={`${styles.messageImageButton} ${tileClassName}`}
          aria-label={locale === "ru" ? "Открыть фото" : "Open photo"}
        >
          <Image
            src={attachment.fileUrl}
            alt={attachment.fileName || message.body || "Support attachment"}
            width={options?.single ? 360 : 180}
            height={options?.single ? 260 : 140}
            sizes="(max-width: 860px) 100vw, 360px"
            className={styles.messageImage}
            loading="lazy"
            unoptimized
          />
          {overlayCount > 0 ? (
            <span className={styles.messageMediaMoreOverlay}>+{overlayCount}</span>
          ) : null}
        </button>
      );
    }

    if (isVideo) {
      return (
        <button
          key={key}
          type="button"
          onClick={() =>
            setFullscreenImage({
              mediaType: "video",
              url: attachment.fileUrl,
              fileName: attachment.fileName,
              messageId: message.messageId,
              senderDisplayName: message.senderDisplayName,
              createdAtUtc: message.createdAtUtc,
              fileSizeBytes: attachment.sizeBytes,
              durationSeconds: attachment.durationSeconds,
            })
          }
          className={`${styles.messageVideoButton} ${tileClassName}`}
          aria-label={locale === "ru" ? "Открыть видео" : "Open video"}
        >
          <video preload="metadata" src={attachment.fileUrl} className={styles.messageVideo} />
          <span className={styles.messageVideoDurationBadge}>
            ▶ {formatAttachmentDuration(attachment.durationSeconds)}
          </span>
          {overlayCount > 0 ? (
            <span className={styles.messageMediaMoreOverlay}>+{overlayCount}</span>
          ) : null}
        </button>
      );
    }

    return (
      <a
        key={key}
        href={attachment.fileUrl}
        target="_blank"
        rel="noopener noreferrer"
        download={attachment.fileName || "attachment"}
        className={`${styles.messageAttachmentCard} ${styles.messageMediaFileTile}`}
      >
        <div className={styles.messageAttachmentIcon}>FILE</div>
        <div className={styles.messageAttachmentMeta}>
          <strong>{attachment.fileName || (locale === "ru" ? "Файл" : "File")}</strong>
          <span>{formatFileSize(attachment.sizeBytes, locale)}</span>
        </div>
        {overlayCount > 0 ? (
          <span className={styles.messageMediaMoreOverlay}>+{overlayCount}</span>
        ) : null}
      </a>
    );
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
                  <svg viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="1.8">
                    <circle cx="8.5" cy="8.5" r="5.5" />
                    <path d="M12.5 12.5 17 17" strokeLinecap="round" />
                  </svg>
                </span>
                <span className={styles.searchLabelHidden}>{text.supportSearchPlaceholder}</span>
                <input
                  ref={searchInputRef}
                  className={`${styles.searchInput} ${styles.supportPageSearchInput}`}
                  value={searchQuery}
                  onChange={(event) => setSearchQuery(event.target.value)}
                  placeholder={text.supportSearchPlaceholder}
                  aria-label={text.supportSearchPlaceholder}
                  title={text.supportSearchKeyboardHint}
                />
                <span className={styles.supportSearchShortcut} aria-hidden="true">
                  /
                </span>
              </label>
            </div>
          </div>

          <div
            className={`${styles.workspace} ${isSidePanelOpen ? styles.workspaceFullView : styles.workspaceCompact}`}
          >
            <div className={styles.inboxPaneFlat}>
              <div className={styles.queuePaneHeader}>
                <div className={styles.queuePaneTitleRow}>
                  <h2 className={styles.queuePaneTitle}>{locale === "ru" ? "Очередь" : "Queue"}</h2>
                  <span className={styles.paneCountBadge}>
                    {subFilter === "archive" ? archiveCount : activeCount}
                  </span>
                  {incomingMessagesCount > 0 ? (
                    <span
                      className={`${styles.queueCountBadge} ${styles.queueCountBadgeIncoming}`}
                      title={
                        locale === "ru"
                          ? `Новых сообщений от пользователей: ${incomingMessagesCount}`
                          : `New messages from users: ${incomingMessagesCount}`
                      }
                    >
                      💬 {incomingMessagesCount}
                    </span>
                  ) : null}
                </div>
              </div>

              <div className={styles.queueSubFilters}>
                <button
                  type="button"
                  className={
                    subFilter === "all" ? styles.queueSubFilterActive : styles.queueSubFilter
                  }
                  onClick={() => setSubFilter("all")}
                >
                  {locale === "ru" ? "Активные" : "Active"} {activeCount}
                </button>
                <button
                  type="button"
                  className={
                    subFilter === "waiting" ? styles.queueSubFilterActive : styles.queueSubFilter
                  }
                  onClick={() => setSubFilter("waiting")}
                >
                  {locale === "ru" ? "Ожидают" : "Waiting"} {waitingCount}
                </button>
                <button
                  type="button"
                  className={
                    subFilter === "unassigned" ? styles.queueSubFilterActive : styles.queueSubFilter
                  }
                  onClick={() => setSubFilter("unassigned")}
                >
                  {locale === "ru" ? "Без ответств." : "Unassigned"} {unassignedCount}
                </button>
                <button
                  type="button"
                  className={
                    subFilter === "archive" ? styles.queueSubFilterActive : styles.queueSubFilter
                  }
                  onClick={() => setSubFilter("archive")}
                >
                  {locale === "ru" ? "Архив" : "Archive"} {archiveCount}
                </button>
              </div>

              <div className={styles.queueFiltersGrid}>
                <label className={styles.queueToolField}>
                  <span>{locale === "ru" ? "Статус" : "Status"}</span>
                  <Select
                    value={queueStatusFilter}
                    onChange={(value) =>
                      setQueueStatusFilter(value as "all" | SupportConversationStatus)
                    }
                    showSelectedDescription={false}
                    options={[
                      { value: "all", label: locale === "ru" ? "Все" : "All" },
                      { value: "New", label: statusLabel("New", text) },
                      { value: "InProgress", label: statusLabel("InProgress", text) },
                      { value: "WaitingForUser", label: statusLabel("WaitingForUser", text) },
                      { value: "Closed", label: statusLabel("Closed", text) },
                    ]}
                  />
                </label>

                <label className={styles.queueToolField}>
                  <span>{locale === "ru" ? "Приоритет" : "Priority"}</span>
                  <Select
                    value={queuePriorityFilter}
                    onChange={(value) =>
                      setQueuePriorityFilter(value as "all" | SupportConversationPriority)
                    }
                    showSelectedDescription={false}
                    options={[
                      { value: "all", label: locale === "ru" ? "Все" : "All" },
                      { value: "High", label: text.supportPriorityHigh },
                      { value: "Normal", label: text.supportPriorityNormal },
                      { value: "Low", label: text.supportPriorityLow },
                    ]}
                  />
                </label>

                <label className={styles.queueToolField}>
                  <span>{locale === "ru" ? "Сортировка" : "Sort"}</span>
                  <Select
                    value={queueSortBy}
                    onChange={(value) => setQueueSortBy(value as "recent" | "status" | "priority")}
                    showSelectedDescription={false}
                    options={[
                      { value: "recent", label: locale === "ru" ? "Сначала новые" : "Newest" },
                      { value: "status", label: locale === "ru" ? "По статусу" : "By status" },
                      {
                        value: "priority",
                        label: locale === "ru" ? "По приоритету" : "By priority",
                      },
                    ]}
                  />
                </label>
              </div>

              {inboxQuery.isLoading ? (
                <AdminStateCard tone="info" title={text.loading} />
              ) : inboxQuery.isError ? (
                <AdminStateCard tone="danger" title={text.supportLoadError} />
              ) : displayedInboxItems.length === 0 ? (
                <AdminStateCard tone="info" title={text.supportEmpty} />
              ) : (
                <div className={styles.list} role="list">
                  {displayedInboxItems.map((item) => {
                    const itemSla = getConversationSla(
                      item.waitingSinceUtc ?? item.lastMessageAtUtc ?? item.createdAtUtc,
                      locale,
                      item.adminUnreadCount
                    );
                    const hasUnread = item.adminUnreadCount > 0;

                    const queueItemClassName = `${styles.conversationRow} ${item.isReadOnly ? styles.conversationRowClosed : ""} ${item.conversationId === conversationId ? styles.conversationRowActive : ""} ${hasUnread ? styles.conversationRowUnread : ""}`;
                    const queueItemContent = (
                      <>
                        <div className={styles.queueRowHeader}>
                          <div className={styles.queueRowIdentity}>
                            <span
                              className={`${styles.avatar} ${avatarColorFor(item.userDisplayName?.trim() || item.userEmail || "")}`}
                              aria-hidden="true"
                            >
                              {initialsFor(item.userDisplayName?.trim() || item.userEmail)}
                            </span>
                            <div className={styles.queueRowTextStack}>
                              <div className={styles.queueRowTitleLine}>
                                <div
                                  className={`${styles.rowTitle} ${hasUnread ? styles.rowTitleUnread : ""}`}
                                >
                                  {item.userDisplayName?.trim() || item.userEmail}
                                </div>
                                {hasUnread ? (
                                  <span className={styles.unreadDotInline} aria-hidden="true" />
                                ) : null}
                              </div>
                              <div className={styles.rowPreview}>
                                <span>{item.lastMessagePreview || text.supportNoMessages}</span>
                              </div>
                            </div>
                          </div>
                          <div className={styles.queueRowMeta}>
                            <span className={styles.rowTime}>
                              {item.lastMessageAtUtc
                                ? formatClockTime(item.lastMessageAtUtc, locale)
                                : formatRelativeTime(item.updatedAtUtc, locale)}
                            </span>
                            <div className={styles.queueRowCounters}>
                              {item.userUnreadCount > 0 ? (
                                <span
                                  className={`${styles.queueCountBadge} ${styles.queueCountBadgeIncoming}`}
                                  title={
                                    locale === "ru"
                                      ? `Сообщений от пользователя: ${item.userUnreadCount}`
                                      : `Messages from user: ${item.userUnreadCount}`
                                  }
                                >
                                  💬 {item.userUnreadCount}
                                </span>
                              ) : null}
                              {item.adminUnreadCount > 0 ? (
                                <span
                                  className={`${styles.queueCountBadge} ${styles.queueCountBadgeUnread}`}
                                  title={
                                    locale === "ru"
                                      ? `Непрочитанных для админа: ${item.adminUnreadCount}`
                                      : `Unread for admin: ${item.adminUnreadCount}`
                                  }
                                >
                                  🔔 {item.adminUnreadCount}
                                </span>
                              ) : null}
                            </div>
                          </div>
                        </div>
                        <div className={styles.queueRowFooter}>
                          <span
                            className={`${styles.queueStatusPill} ${styles[`queueStatusPill_${item.status}` as keyof typeof styles]}`}
                          >
                            <span aria-hidden="true">{queueStatusIcon(item.status)}</span>
                            {statusLabel(item.status, text)}
                          </span>
                          {itemSla.waitLabel ? (
                            <span
                              className={`${styles.slaPill} ${styles[`slaPill_${itemSla.level}`]}`}
                            >
                              {itemSla.waitLabel}
                            </span>
                          ) : null}
                        </div>
                        <div className={styles.queueRowDetailLine}>
                          <span className={styles.queueMetaChip}>
                            {sourceLabel(item.source, text)}
                          </span>
                          <span className={styles.queueMetaChipMuted}>
                            #{shortId(item.initiatorUserId)}
                          </span>
                          <span className={styles.queueMetaChipMuted}>
                            {item.assignedAdminDisplayName?.trim()
                              ? `${locale === "ru" ? "Оператор" : "Operator"}: ${item.assignedAdminDisplayName}`
                              : locale === "ru"
                                ? "Без оператора"
                                : "Unassigned"}
                          </span>
                        </div>
                      </>
                    );

                    if (navigationMode === "local") {
                      return (
                        <button
                          key={item.conversationId}
                          type="button"
                          role="listitem"
                          aria-current={item.conversationId === conversationId ? "page" : undefined}
                          className={`${queueItemClassName} ${styles.conversationRowButton}`}
                          onClick={() => onConversationSelect?.(item.conversationId)}
                        >
                          {queueItemContent}
                        </button>
                      );
                    }

                    return (
                      <Link
                        key={item.conversationId}
                        href={`/${locale}/support/${item.conversationId}`}
                        role="listitem"
                        aria-current={item.conversationId === conversationId ? "page" : undefined}
                        className={queueItemClassName}
                      >
                        {queueItemContent}
                      </Link>
                    );
                  })}
                </div>
              )}
              {!inboxQuery.isLoading && !inboxQuery.isError && displayedInboxItems.length > 0 ? (
                <div className={styles.queueFooter}>
                  <span className={styles.queueFooterCount}>
                    {locale === "ru"
                      ? `Показано ${displayedInboxItems.length} из ${filteredInboxItems.length}`
                      : `Showing ${displayedInboxItems.length} of ${filteredInboxItems.length}`}
                  </span>
                </div>
              ) : null}
            </div>

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
                                  conversationSla.level === "critical" ||
                                  conversationSla.level === "risk"
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
                          {conversation.userEmail} · #{shortId(conversation.initiatorUserId)}
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
                        ticketClosedByUser: text.supportSystemTicketClosedByUser,
                        ticketClosedByOperator: text.supportSystemTicketClosedByOperator,
                      }).map((group) => {
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
                                normalizedAttachmentStatus === "failed" ||
                                normalizedAttachmentStatus === "retry";
                              const hasMediaMessage = attachments.some(
                                (attachment) =>
                                  attachment.mimeType.startsWith("image/") ||
                                  attachment.mimeType.startsWith("video/")
                              );
                              const isMediaOnlyBubble = hasMediaMessage && !shouldShowBody;
                              const repliedMessage = message.replyToMessageId
                                ? (conversation.messages.find(
                                    (candidate) => candidate.messageId === message.replyToMessageId
                                  ) ?? null)
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
                                  id={`message-${message.messageId}`}
                                  className={`${styles.messageItem} ${message.isFromAdmin ? styles.messageAdmin : styles.messageUser} ${isBotMessage ? styles.messageBot : ""} ${highlightedMessageId === message.messageId ? styles.messageHighlighted : ""} ${hasMediaMessage ? styles.messageWithMedia : ""} ${isMediaOnlyBubble ? styles.messageMediaOnly : ""}`}
                                  onDoubleClick={() => startReplyToMessage(message)}
                                >
                                  <button
                                    type="button"
                                    className={styles.messageReplyAction}
                                    onClick={() => startReplyToMessage(message)}
                                    title={locale === "ru" ? "Ответить" : "Reply"}
                                    aria-label={locale === "ru" ? "Ответить" : "Reply"}
                                  >
                                    ↩
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
                                          {locale === "ru" ? "Ответ на" : "Reply to"}
                                        </span>
                                        <span className={styles.messageReplyBlockPreview}>
                                          {(
                                            message.replyToPreview?.trim() ||
                                            text.supportReplyOriginalUnavailable
                                          ).trim()}
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
                                          .slice(
                                            0,
                                            attachments.length >= 7 ? 6 : attachments.length
                                          )
                                          .map((attachment, attachmentIndex, visibleAttachments) =>
                                            renderAttachmentTile(
                                              message,
                                              attachment,
                                              attachmentIndex,
                                              {
                                                overlayCount:
                                                  attachments.length >= 7 &&
                                                  attachmentIndex === visibleAttachments.length - 1
                                                    ? attachments.length - visibleAttachments.length
                                                    : 0,
                                              }
                                            )
                                          )}
                                      </div>
                                    ) : primaryAttachment ? (
                                      renderAttachmentTile(message, primaryAttachment, 0, {
                                        single: true,
                                      })
                                    ) : null
                                  ) : null}
                                  {shouldShowBody ? (
                                    <div className={styles.messageBody}>{message.body}</div>
                                  ) : null}
                                  {shouldShowAttachmentFailure ? (
                                    <div className={styles.messageAttachmentStatusRow}>
                                      <span
                                        className={`${styles.messageAttachmentStatusPill} ${styles[`messageAttachmentStatus_${normalizedAttachmentStatus}`] ?? ""}`}
                                      >
                                        {normalizedAttachmentStatus === "retry"
                                          ? locale === "ru"
                                            ? "Повторить"
                                            : "Retry"
                                          : text.supportAttachmentFailedLabel}
                                      </span>
                                    </div>
                                  ) : null}
                                  <div className={styles.messageMeta}>
                                    <span>{formatClockTime(message.createdAtUtc, locale)}</span>
                                    {message.isFromAdmin && !isSystemMessage ? (
                                      <span
                                        className={`${styles.messageTick} ${message.isRead ? styles.messageTickRead : ""}`}
                                        aria-label={message.isRead ? "Read" : "Sent"}
                                        title={
                                          message.isRead
                                            ? locale === "ru"
                                              ? "Прочитано"
                                              : "Read"
                                            : locale === "ru"
                                              ? "Отправлено"
                                              : "Sent"
                                        }
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
                      {replyToMessage || replyToPreview ? (
                        <div className={styles.composerReplyPreview}>
                          <span className={styles.composerReplyAccent} aria-hidden="true" />
                          <span className={styles.composerReplyIcon} aria-hidden="true">
                            ↩
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
                                {locale === "ru" ? "К сообщению" : "Jump"}
                              </button>
                            ) : null}
                            <button
                              type="button"
                              className={styles.composerReplyClose}
                              onClick={() => selectReplyToMessage(null)}
                              aria-label={locale === "ru" ? "Отменить ответ" : "Cancel reply"}
                              title={locale === "ru" ? "Отменить ответ" : "Cancel reply"}
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

                      <div className={styles.composerInputBar}>
                        <button
                          type="button"
                          className={styles.composerIconBtn}
                          onClick={() => attachmentInputRef.current?.click()}
                          disabled={isConversationReadOnly || sendMutation.isPending}
                          aria-label={locale === "ru" ? "Прикрепить файл" : "Attach file"}
                          title={locale === "ru" ? "Прикрепить файл" : "Attach file"}
                        >
                          📎
                        </button>
                        <textarea
                          className={`${styles.textarea} ${styles.composerTextarea}`}
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
                          placeholder={composerPlaceholder}
                          disabled={isConversationReadOnly || sendMutation.isPending}
                          rows={1}
                        />
                        <div className={styles.composerSendGroup}>
                          <Button
                            variant="primary"
                            size="sm"
                            onClick={submitReply}
                            className={styles.composerSendPrimary}
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

            {isSidePanelOpen ? (
              <>
                <SupportInfoPanel locale={locale} controller={controller} />
              </>
            ) : null}
          </div>
          {fullscreenImage ? (
            <div
              className={styles.imageViewerOverlay}
              role="dialog"
              aria-modal="true"
              aria-label={
                fullscreenImage.fileName?.trim() ||
                (fullscreenImage.mediaType === "video" ? "Video preview" : "Image preview")
              }
              onClick={closeFullscreenImage}
            >
              <div className={styles.imageViewerPanel} onClick={(event) => event.stopPropagation()}>
                <div className={styles.imageViewerHeader}>
                  <strong>
                    {fullscreenImage.fileName?.trim() ||
                      (fullscreenImage.mediaType === "video" ? "Video" : "Image")}
                  </strong>
                  <Button variant="ghost" size="sm" onClick={closeFullscreenImage}>
                    {imageViewerLabels.close}
                  </Button>
                </div>
                <div className={styles.imageViewerBody}>
                  {fullscreenImage.mediaType === "video" ? (
                    <video
                      src={fullscreenImage.url}
                      className={styles.imageViewerVideo}
                      controls
                      preload="metadata"
                      playsInline
                    />
                  ) : (
                    <Image
                      src={fullscreenImage.url}
                      alt={fullscreenImage.fileName ?? "Support image"}
                      width={1720}
                      height={980}
                      sizes="100vw"
                      className={styles.imageViewerImage}
                      unoptimized
                    />
                  )}
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
                  {fullscreenImage.mediaType === "video" ? (
                    <div>
                      <span>{locale === "ru" ? "Длительность" : "Duration"}</span>
                      <strong>{formatAttachmentDuration(fullscreenImage.durationSeconds)}</strong>
                    </div>
                  ) : null}
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
