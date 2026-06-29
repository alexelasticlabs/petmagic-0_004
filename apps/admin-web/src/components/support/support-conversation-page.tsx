"use client";

import Link from "next/link";
import { useEffect, useMemo, useRef, useState } from "react";

import {
  BellIcon,
  CancelCircleIcon,
  CaretDownIcon,
  ClockIcon,
  FileIcon,
  PaperclipIcon,
  PlayCircleIcon,
  ReplyIcon,
  SearchIcon,
  SupportIcon,
  UploadIcon,
} from "@/components/admin/admin-icons";
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
  formatSafeSupportDownloadName,
  formatSafeSupportDisplay,
  formatRelativeTime,
  getConversationSla,
  getMessageAttachments,
  groupSupportConversationFeed,
  initialsFor,
  shortId,
  shouldRenderMessageBody,
} from "@/components/support/support-conversation-helpers";
import { getSupportConversationCopy } from "@/components/support/support-conversation.content";
import { SupportInfoPanel } from "@/components/support/support-info-panel";
import { formatSupportMessagePreview } from "@/components/support/support-message-preview";
import styles from "@/components/support/support-page.module.css";
import { SupportSecureMedia } from "@/components/support/support-secure-media";
import { sourceLabel, statusHint, statusLabel, toneForStatus } from "@/components/support/support-status-helpers";
import {
  SUPPORT_REPLY_MAX_LENGTH,
  SUPPORT_SEARCH_MAX_LENGTH,
  useSupportConversationController,
} from "@/components/support/use-support-conversation-controller";
import { Button } from "@/components/ui/button";
import { Select } from "@/components/ui/select";
import { Toast } from "@/components/ui/toast";
import type { AdminSupportConversation, SupportConversationStatus } from "@/lib/api-client";
import { clientLogger } from "@/lib/client-logger";
import { fetchWithTimeout } from "@/lib/fetch-with-timeout";
import { type Locale } from "@/lib/i18n";
import { maskEmail, sanitizeSensitiveText } from "@/lib/sensitive-display";

type SupportConversationPageProps = {
  locale: Locale;
  conversationId: string;
  navigationMode?: "route" | "local";
  onConversationSelect?: (conversationId: string) => void;
};

type FullscreenImage = {
  mediaType?: "image" | "video";
  attachmentFileUrl: string;
  fileName?: string | null;
  messageId?: string;
  senderDisplayName?: string | null;
  createdAtUtc?: string | null;
  fileSizeBytes?: number | null;
  durationSeconds?: number | null;
};

type SupportMessage = AdminSupportConversation["messages"][number];
type SupportMessageAttachment = ReturnType<typeof getMessageAttachments>[number];

function downloadSupportBlobUrl(objectUrl: string, fileName: string): void {
  const link = document.createElement("a");
  link.href = objectUrl;
  link.download = fileName;
  document.body.append(link);
  link.click();
  link.remove();
}

function getSupportActionErrorDetails(error: unknown) {
  return {
    errorName: error instanceof Error ? error.name : "UnknownError",
    errorDigest:
      error && typeof error === "object" && "digest" in error
        ? sanitizeSensitiveText(String((error as { digest?: unknown }).digest ?? ""), 80)
        : undefined,
  };
}

function formatSupportLogText(value: string | null | undefined, maxLength = 80) {
  return value ? sanitizeSensitiveText(value, maxLength) : undefined;
}

export function SupportConversationPage({
  locale,
  conversationId,
  navigationMode = "route",
  onConversationSelect,
}: SupportConversationPageProps) {
  const copy = useMemo(() => getSupportConversationCopy(locale), [locale]);
  const [fullscreenImage, setFullscreenImage] = useState<FullscreenImage | null>(null);
  const [isDragging, setIsDragging] = useState(false);
  const [highlightedMessageId, setHighlightedMessageId] = useState<string | null>(null);
  const [subFilter, setSubFilter] = useState<"all" | "unassigned" | "archive">("all");
  const [queueStatusFilter, setQueueStatusFilter] = useState<"all" | SupportConversationStatus>(
    "all"
  );
  const [pendingAttachmentActionKey, setPendingAttachmentActionKey] = useState<string | null>(null);
  const [pendingFullscreenAction, setPendingFullscreenAction] = useState<
    "download" | "share" | "open" | null
  >(null);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const searchInputRef = useRef<HTMLInputElement>(null);
  const messageHighlightTimerRef = useRef<number | null>(null);
  const fullscreenActionAbortControllerRef = useRef<AbortController | null>(null);
  const attachmentActionAbortControllerRef = useRef<AbortController | null>(null);
  const controller = useSupportConversationController({
    locale,
    conversationId,
    queueStatusFilter,
  });
  const {
    attachmentInputRef,
    attachmentPreviewUrl,
    composerPlaceholder,
    composerValue,
    conversation,
    conversationQuery,
    conversationSla,
    filteredInboxItems,
    canManageSupportWorkspace,
    canGoToNextQueuePage,
    canGoToPreviousQueuePage,
    hasComposerAttachment,
    inboxMetrics,
    inboxQuery,
    isSidePanelOpen,
    isSendReplySubmitting,
    loadOlderMessages,
    primaryStatusAction,
    reply,
    replyToMessage,
    replyToPreview,
    queuePage,
    requestSendReply,
    resetSelectedAttachment,
    searchQuery,
    secondaryStatusActions,
    selectedAttachment,
    selectReplyToMessage,
    setMessagesViewportVisible,
    setReply,
    setQueueFilter,
    setQueuePage,
    setSearchQuery,
    setSelectedAttachment,
    statusMutation,
    text,
    toast,
    userEmailDisplay,
    userDisplayName,
  } = controller;

  const isConversationReadOnly = conversation?.isReadOnly ?? false;
  const isComposerBusy = isSendReplySubmitting;
  const isComposerDisabled = isConversationReadOnly || !canManageSupportWorkspace || isComposerBusy;
  const isConversationClosed = conversation?.status === "Closed";
  const isQueueControlsLocked = !canManageSupportWorkspace || inboxQuery.isFetching;
  const setQueueSubFilter = (value: "all" | "unassigned" | "archive") => {
    if (isQueueControlsLocked) {
      return;
    }

    setSubFilter(value);
    setQueueStatusFilter("all");
    if (value === "archive") {
      setQueueFilter("Closed");
      return;
    }
    if (value === "unassigned") {
      setQueueFilter("unassigned");
      return;
    }
    setQueueFilter("all");
  };
  const setExactQueueStatusFilter = (value: "all" | SupportConversationStatus) => {
    if (isQueueControlsLocked) {
      return;
    }

    setSubFilter("all");
    setQueueFilter("all");
    setQueueStatusFilter(value);
    setQueuePage(1);
  };
  const requestPreviousQueuePage = () => {
    if (isQueueControlsLocked || !canGoToPreviousQueuePage) {
      return;
    }

    setQueuePage((currentPage) => Math.max(1, currentPage - 1));
  };
  const requestNextQueuePage = () => {
    if (isQueueControlsLocked || !canGoToNextQueuePage) {
      return;
    }

    setQueuePage((currentPage) => currentPage + 1);
  };
  const requestConversationRetry = () => {
    if (!canManageSupportWorkspace || conversationQuery.isFetching) {
      return;
    }

    void conversationQuery.refetch().catch(() => undefined);
  };
  const requestInboxRetry = () => {
    if (isQueueControlsLocked) {
      return;
    }

    void inboxQuery.refetch().catch(() => undefined);
  };
  const requestOlderMessagesLoad = () => {
    if (!canManageSupportWorkspace || conversationQuery.isFetching) {
      return;
    }

    void loadOlderMessages();
  };

  const archiveCount = inboxMetrics?.closedConversations ?? 0;
  const queueCount = inboxMetrics?.openConversations ?? 0;
  const incomingMessagesCount = inboxMetrics?.unreadForAdminConversations ?? 0;
  const unassignedCount = inboxMetrics?.unassignedConversations ?? 0;
  const displayedInboxItems = filteredInboxItems;
  const inboxTotalCount = inboxQuery.data?.totalCount ?? filteredInboxItems.length;
  const inboxPageSize = inboxQuery.data?.pageSize ?? displayedInboxItems.length;
  const inboxCurrentPage = inboxQuery.data?.page ?? queuePage;
  const queueShownStart = inboxTotalCount > 0 ? (inboxCurrentPage - 1) * inboxPageSize + 1 : 0;
  const queueShownEnd =
    inboxTotalCount > 0
      ? Math.min(inboxTotalCount, queueShownStart + displayedInboxItems.length - 1)
      : 0;
  const reopenStatusAction =
    primaryStatusAction?.status === "InProgress"
      ? primaryStatusAction
      : (secondaryStatusActions.find((action) => action.status === "InProgress") ?? null);
  const readOnlyComposerTitle = isConversationClosed
    ? copy.page.closedConversationReadonly
    : statusHint(conversation?.status ?? "Closed", text);
  const imageViewerLabels = copy.page.imageViewer;
  const queueLabels = copy.page.queue;
  const messageLabels = copy.page.message;
  const supportWorkspaceSubtitle = copy.page.workspaceSubtitle;

  const groupedConversationFeed = useMemo(
    () =>
      conversation
        ? groupSupportConversationFeed(conversation, {
            today: text.supportTodayLabel,
            yesterday: text.supportYesterdayLabel,
            earlier: text.supportEarlierLabel,
            ticketCreated: text.supportSystemTicketCreated,
            ticketResolved: text.supportSystemTicketResolved,
            ticketReopened: text.supportSystemTicketReopened,
            ticketClosed: text.supportSystemTicketClosed,
            ticketClosedByUser: text.supportSystemTicketClosedByUser,
            ticketClosedByOperator: text.supportSystemTicketClosedByOperator,
          })
        : [],
    [
      conversation,
      text.supportEarlierLabel,
      text.supportSystemTicketClosed,
      text.supportSystemTicketClosedByOperator,
      text.supportSystemTicketClosedByUser,
      text.supportSystemTicketCreated,
      text.supportSystemTicketReopened,
      text.supportSystemTicketResolved,
      text.supportTodayLabel,
      text.supportYesterdayLabel,
    ]
  );

  const messagesById = useMemo(() => {
    if (!conversation) {
      return new Map<string, SupportMessage>();
    }

    return new Map(conversation.messages.map((message) => [message.messageId, message]));
  }, [conversation]);

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
    setReply("");
    resetSelectedAttachment();
  }, [conversationId, resetSelectedAttachment, selectReplyToMessage, setReply]);

  useEffect(() => {
    fullscreenActionAbortControllerRef.current?.abort();
    fullscreenActionAbortControllerRef.current = null;
    attachmentActionAbortControllerRef.current?.abort();
    attachmentActionAbortControllerRef.current = null;

    queueMicrotask(() => {
      setFullscreenImage(null);
      setPendingFullscreenAction(null);
      setPendingAttachmentActionKey(null);
      setHighlightedMessageId(null);
      setIsDragging(false);
    });
  }, [conversationId]);

  const submitReply = () => {
    if (isComposerDisabled || (!reply.trim() && !hasComposerAttachment)) {
      return;
    }

    requestSendReply();
  };

  const requestReopenConversation = () => {
    if (
      !canManageSupportWorkspace ||
      !reopenStatusAction ||
      statusMutation.isPending ||
      conversation?.status === reopenStatusAction.status
    ) {
      return;
    }

    statusMutation.mutate(reopenStatusAction.status);
  };

  const avatarColorFor = (name: string): string => {
    let hash = 0;
    for (let i = 0; i < name.length; i++) {
      hash = (hash + name.charCodeAt(i)) % 8;
    }
    return styles[`avatarColor${hash}` as keyof typeof styles] ?? styles.avatarColor6;
  };

  const QueueStatusIcon = ({ status }: { status: SupportConversationStatus }) => {
    if (status === "New") {
      return <BellIcon className={styles.queueStatusIcon} />;
    }
    if (status === "InProgress") {
      return <PlayCircleIcon className={styles.queueStatusIcon} />;
    }
    if (status === "WaitingForUser") {
      return <ClockIcon className={styles.queueStatusIcon} />;
    }
    return <CancelCircleIcon className={styles.queueStatusIcon} />;
  };

  const closeFullscreenImage = () => {
    fullscreenActionAbortControllerRef.current?.abort();
    fullscreenActionAbortControllerRef.current = null;
    setPendingFullscreenAction(null);
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
        closeFullscreenImage();
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
      fullscreenActionAbortControllerRef.current?.abort();
      attachmentActionAbortControllerRef.current?.abort();
    },
    []
  );

  async function fetchFullscreenAttachmentBlob(
    image: FullscreenImage,
    action: "download" | "share" | "open",
    signal: AbortSignal
  ): Promise<Blob | null> {
    try {
      const response = await fetchWithTimeout(image.attachmentFileUrl, {
        credentials: "include",
        signal,
      });
      if (!response.ok) {
        clientLogger.warn(`support.fullscreen_${action}_failed`, {
          messageId: formatSupportLogText(image.messageId),
          status: response.status,
          mediaType: formatSupportLogText(image.mediaType),
        });
        return null;
      }

      return response.blob();
    } catch (error) {
      if (signal.aborted) {
        return null;
      }

      clientLogger.warn(`support.fullscreen_${action}_failed`, {
        messageId: formatSupportLogText(image.messageId),
        mediaType: formatSupportLogText(image.mediaType),
        ...getSupportActionErrorDetails(error),
      });
      return null;
    }
  }

  const saveFullscreenImage = async () => {
    if (!canManageSupportWorkspace || !fullscreenImage || pendingFullscreenAction !== null) {
      return;
    }

    fullscreenActionAbortControllerRef.current?.abort();
    const controller = new AbortController();
    fullscreenActionAbortControllerRef.current = controller;
    setPendingFullscreenAction("download");

    try {
      const blob = await fetchFullscreenAttachmentBlob(
        fullscreenImage,
        "download",
        controller.signal
      );
      if (!blob || controller.signal.aborted) {
        return;
      }

      const objectUrl = URL.createObjectURL(blob);
      const defaultFileName =
        fullscreenImage.mediaType === "video" ? "support-video" : "support-image";
      downloadSupportBlobUrl(
        objectUrl,
        formatSafeSupportDownloadName(fullscreenImage.fileName, defaultFileName)
      );
      URL.revokeObjectURL(objectUrl);
    } finally {
      if (fullscreenActionAbortControllerRef.current === controller) {
        fullscreenActionAbortControllerRef.current = null;
        setPendingFullscreenAction(null);
      }
    }
  };

  const shareFullscreenImage = async () => {
    if (!canManageSupportWorkspace || !fullscreenImage || pendingFullscreenAction !== null) {
      return;
    }

    const currentFullscreenImage = fullscreenImage;
    fullscreenActionAbortControllerRef.current?.abort();
    const controller = new AbortController();
    fullscreenActionAbortControllerRef.current = controller;
    setPendingFullscreenAction("share");

    try {
      if (typeof window === "undefined") {
        return;
      }

      const browserNavigator = window.navigator as Navigator & {
        share?: (data: ShareData) => Promise<void>;
        canShare?: (data: ShareData) => boolean;
      };

      const blob = await fetchFullscreenAttachmentBlob(
        currentFullscreenImage,
        "share",
        controller.signal
      );
      if (!blob || controller.signal.aborted) {
        return;
      }

      const defaultFileName =
        currentFullscreenImage.mediaType === "video" ? "support-video" : "support-image";
      const safeFileName = formatSafeSupportDownloadName(
        currentFullscreenImage.fileName,
        defaultFileName
      );
      const shareBlob = blob;

      function fallbackToDownload(reason: string) {
        clientLogger.warn("support.fullscreen_share_unsupported", {
          messageId: formatSupportLogText(currentFullscreenImage.messageId),
          reason: formatSupportLogText(reason),
        });

        const objectUrl = URL.createObjectURL(shareBlob);
        downloadSupportBlobUrl(objectUrl, safeFileName);
        window.setTimeout(() => URL.revokeObjectURL(objectUrl), 1000);
      }

      if (!browserNavigator.share) {
        fallbackToDownload("navigator_share_missing");
        return;
      }

      const file = new File([blob], safeFileName, {
        type:
          blob.type || (currentFullscreenImage.mediaType === "video" ? "video/mp4" : "image/jpeg"),
      });
      const shareData: ShareData = {
        title: formatSafeSupportDisplay(
          currentFullscreenImage.fileName,
          imageViewerLabels.supportAttachmentFallback,
          120
        ),
        files: [file],
      };

      if (!browserNavigator.canShare || browserNavigator.canShare(shareData)) {
        await browserNavigator.share({
          title: shareData.title,
          files: shareData.files,
        });
        return;
      }

      fallbackToDownload("file_share_unsupported");
    } catch (error) {
      if (controller.signal.aborted) {
        return;
      }

      clientLogger.warn("support.fullscreen_share_failed", {
        messageId: formatSupportLogText(currentFullscreenImage.messageId),
        ...getSupportActionErrorDetails(error),
      });
    } finally {
      if (fullscreenActionAbortControllerRef.current === controller) {
        fullscreenActionAbortControllerRef.current = null;
        setPendingFullscreenAction(null);
      }
    }
  };

  const openFullscreenImageInNewTab = async () => {
    if (!canManageSupportWorkspace || !fullscreenImage || pendingFullscreenAction !== null) {
      return;
    }

    fullscreenActionAbortControllerRef.current?.abort();
    const controller = new AbortController();
    fullscreenActionAbortControllerRef.current = controller;
    setPendingFullscreenAction("open");

    try {
      const blob = await fetchFullscreenAttachmentBlob(fullscreenImage, "open", controller.signal);
      if (!blob || controller.signal.aborted) {
        return;
      }

      const objectUrl = URL.createObjectURL(blob);
      const opened = window.open(objectUrl, "_blank", "noopener,noreferrer");
      if (!opened) {
        const defaultFileName =
          fullscreenImage.mediaType === "video" ? "support-video" : "support-image";
        downloadSupportBlobUrl(
          objectUrl,
          formatSafeSupportDownloadName(fullscreenImage.fileName, defaultFileName)
        );
        window.setTimeout(() => URL.revokeObjectURL(objectUrl), 1000);
        return;
      }

      window.setTimeout(() => URL.revokeObjectURL(objectUrl), 60_000);
    } finally {
      if (fullscreenActionAbortControllerRef.current === controller) {
        fullscreenActionAbortControllerRef.current = null;
        setPendingFullscreenAction(null);
      }
    }
  };

  const getAttachmentActionKey = (
    message: SupportMessage,
    attachment: SupportMessageAttachment,
    attachmentIndex: number
  ) => `${message.messageId}:${attachment.fileName}:${attachment.sizeBytes}:${attachmentIndex}`;

  const downloadAttachmentFile = async (
    message: SupportMessage,
    attachment: SupportMessageAttachment,
    attachmentIndex: number
  ) => {
    const actionKey = getAttachmentActionKey(message, attachment, attachmentIndex);
    if (!canManageSupportWorkspace || pendingAttachmentActionKey !== null) {
      return;
    }

    setPendingAttachmentActionKey(actionKey);
    attachmentActionAbortControllerRef.current?.abort();
    const controller = new AbortController();
    attachmentActionAbortControllerRef.current = controller;
    try {
      const response = await fetchWithTimeout(attachment.fileUrl, {
        credentials: "include",
        signal: controller.signal,
      });
      if (!response.ok) {
        clientLogger.warn("support.attachment_download_failed", {
          messageId: formatSupportLogText(message.messageId),
          status: response.status,
          mimeType: formatSupportLogText(attachment.mimeType),
        });
        return;
      }

      const blob = await response.blob();
      const objectUrl = URL.createObjectURL(blob);
      downloadSupportBlobUrl(objectUrl, formatSafeSupportDownloadName(attachment.fileName));
      window.setTimeout(() => URL.revokeObjectURL(objectUrl), 1000);
    } catch (error) {
      if (controller.signal.aborted) {
        return;
      }

      clientLogger.warn("support.attachment_download_failed", {
        messageId: formatSupportLogText(message.messageId),
        mimeType: formatSupportLogText(attachment.mimeType),
        ...getSupportActionErrorDetails(error),
      });
    } finally {
      if (attachmentActionAbortControllerRef.current === controller) {
        attachmentActionAbortControllerRef.current = null;
        setPendingAttachmentActionKey(null);
      }
    }
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
    const target = document.getElementById(getSupportMessageElementId(messageId));
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
      return formatSafeSupportDisplay(body, text.supportReplyOriginalUnavailable, 160);
    }

    const attachments = getMessageAttachments(message);
    if (attachments.length > 1) {
      return messageLabels.attachmentGroup(attachments.length);
    }

    const primaryAttachment = attachments[0];
    if (!primaryAttachment) {
      return text.supportReplyOriginalUnavailable;
    }

    if (primaryAttachment.mimeType.startsWith("image/")) {
      return copy.shared.photo;
    }

    if (primaryAttachment.mimeType.startsWith("video/")) {
      return copy.shared.video;
    }

    return formatSafeSupportDisplay(primaryAttachment.fileName, copy.shared.file, 120);
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
        <SupportSecureMedia
          url={attachment.fileUrl}
          kind="image"
          alt=""
          width={34}
          height={34}
          className={styles.replyThumbImage}
          loading="lazy"
          ariaHidden
        />
      );
    }

    return (
      <span className={styles.replyThumbIcon} aria-hidden="true">
        {attachment.mimeType.startsWith("video/") ? (
          <PlayCircleIcon className={styles.replyThumbSvg} />
        ) : (
          <FileIcon className={styles.replyThumbSvg} />
        )}
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
    const safeAttachmentName = formatSafeSupportDisplay(
      attachment.fileName,
      messageLabels.fileFallback,
      120
    );

    if (isImage) {
      return (
        <button
          key={key}
          type="button"
          onClick={() =>
            setFullscreenImage({
              mediaType: "image",
              attachmentFileUrl: attachment.fileUrl,
              fileName: attachment.fileName,
              messageId: message.messageId,
              senderDisplayName: message.senderDisplayName,
              createdAtUtc: message.createdAtUtc,
              fileSizeBytes: attachment.sizeBytes,
            })
          }
          className={`${styles.messageImageButton} ${tileClassName}`}
          aria-label={messageLabels.openPhoto}
        >
          <SupportSecureMedia
            url={attachment.fileUrl}
            kind="image"
            alt={formatSafeSupportDisplay(
              attachment.fileName || message.body,
              imageViewerLabels.supportAttachmentFallback,
              120
            )}
            width={options?.single ? 360 : 180}
            height={options?.single ? 260 : 140}
            className={styles.messageImage}
            loading="lazy"
            logContext={{ messageId: message.messageId, mimeType: attachment.mimeType }}
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
              attachmentFileUrl: attachment.fileUrl,
              fileName: attachment.fileName,
              messageId: message.messageId,
              senderDisplayName: message.senderDisplayName,
              createdAtUtc: message.createdAtUtc,
              fileSizeBytes: attachment.sizeBytes,
              durationSeconds: attachment.durationSeconds,
            })
          }
          className={`${styles.messageVideoButton} ${tileClassName}`}
          aria-label={messageLabels.openVideo}
        >
          <SupportSecureMedia
            url={attachment.fileUrl}
            kind="video"
            preload="metadata"
            className={styles.messageVideo}
            ariaHidden
            logContext={{ messageId: message.messageId, mimeType: attachment.mimeType }}
          />
          <span className={styles.messageVideoDurationBadge}>
            <PlayCircleIcon className={styles.messageVideoDurationIcon} />
            {formatAttachmentDuration(attachment.durationSeconds)}
          </span>
          {overlayCount > 0 ? (
            <span className={styles.messageMediaMoreOverlay}>+{overlayCount}</span>
          ) : null}
        </button>
      );
    }

    return (
      <button
        key={key}
        type="button"
        onClick={() => void downloadAttachmentFile(message, attachment, attachmentIndex)}
        disabled={
          !canManageSupportWorkspace ||
          pendingAttachmentActionKey !== null
        }
        className={`${styles.messageAttachmentCard} ${styles.messageMediaFileTile}`}
      >
        <div className={styles.messageAttachmentIcon}>
          <FileIcon className={styles.supportFileIcon} />
        </div>
        <div className={styles.messageAttachmentMeta}>
          <strong>{safeAttachmentName}</strong>
          <span>{formatFileSize(attachment.sizeBytes, locale)}</span>
        </div>
        {overlayCount > 0 ? (
          <span className={styles.messageMediaMoreOverlay}>+{overlayCount}</span>
        ) : null}
      </button>
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
            <div className={styles.errorActions}>
              <Button
                variant="secondary"
                onClick={requestConversationRetry}
                disabled={!canManageSupportWorkspace || conversationQuery.isFetching}
              >
                {text.supportRetryAction}
              </Button>
              <Link
                href={`/${locale}/support`}
                className="ui-button ui-button--secondary ui-button--md"
              >
                {text.supportBackToInbox}
              </Link>
            </div>
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
          </div>

          <div
            className={`${styles.workspace} ${isSidePanelOpen ? styles.workspaceFullView : styles.workspaceCompact}`}
          >
            <div className={styles.inboxPaneFlat}>
              <div className={styles.queuePaneHeader}>
                <div className={styles.queuePaneTitleRow}>
                  <h2 className={styles.queuePaneTitle}>{queueLabels.title}</h2>
                  <span className={styles.paneCountBadge}>
                    {subFilter === "archive" ? archiveCount : queueCount}
                  </span>
                  {incomingMessagesCount > 0 ? (
                    <span
                      className={`${styles.queueCountBadge} ${styles.queueCountBadgeIncoming}`}
                      title={queueLabels.newMessagesTitle(incomingMessagesCount)}
                    >
                      <SupportIcon className={styles.queueBadgeIcon} />
                      {incomingMessagesCount}
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
                  disabled={isQueueControlsLocked}
                  onClick={() => setQueueSubFilter("all")}
                >
                  {queueLabels.all} {queueCount}
                </button>
                <button
                  type="button"
                  className={
                    subFilter === "unassigned" ? styles.queueSubFilterActive : styles.queueSubFilter
                  }
                  disabled={isQueueControlsLocked}
                  onClick={() => setQueueSubFilter("unassigned")}
                >
                  {queueLabels.unassigned} {unassignedCount}
                </button>
                <button
                  type="button"
                  className={
                    subFilter === "archive" ? styles.queueSubFilterActive : styles.queueSubFilter
                  }
                  disabled={isQueueControlsLocked}
                  onClick={() => setQueueSubFilter("archive")}
                >
                  {queueLabels.archive} {archiveCount}
                </button>
              </div>

              <div className={styles.queueFiltersGrid}>
                <label className={styles.queueToolField}>
                  <span>{queueLabels.status}</span>
                  <Select
                    value={queueStatusFilter}
                    disabled={isQueueControlsLocked}
                    onChange={(value) => {
                      setExactQueueStatusFilter(value as "all" | SupportConversationStatus);
                    }}
                    showSelectedDescription={false}
                    options={[
                      { value: "all", label: queueLabels.all },
                      { value: "New", label: statusLabel("New", text) },
                      { value: "InProgress", label: statusLabel("InProgress", text) },
                      { value: "WaitingForUser", label: statusLabel("WaitingForUser", text) },
                      { value: "Closed", label: statusLabel("Closed", text) },
                    ]}
                  />
                </label>
              </div>

              {inboxQuery.isLoading ? (
                <AdminStateCard tone="info" title={text.loading} />
              ) : inboxQuery.isError ? (
                <AdminStateCard
                  tone="danger"
                  title={text.supportLoadError}
                  action={
                    <Button
                      variant="secondary"
                      size="sm"
                      onClick={requestInboxRetry}
                      disabled={!canManageSupportWorkspace || inboxQuery.isFetching}
                    >
                      {text.supportRetryAction}
                    </Button>
                  }
                />
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
                    const queueUserLabel = item.userDisplayName?.trim()
                      ? formatSafeSupportDisplay(item.userDisplayName, "", 72)
                      : (item.userEmail?.trim() ? maskEmail(item.userEmail) : "") ||
                        copy.shared.deletedUserName;

                    const queueItemClassName = `${styles.conversationRow} ${item.isReadOnly ? styles.conversationRowClosed : ""} ${item.conversationId === conversationId ? styles.conversationRowActive : ""} ${hasUnread ? styles.conversationRowUnread : ""}`;
                    const queueItemContent = (
                      <>
                        <div className={styles.queueRowHeader}>
                          <div className={styles.queueRowIdentity}>
                            <span
                              className={`${styles.avatar} ${avatarColorFor(queueUserLabel)}`}
                              aria-hidden="true"
                            >
                              {initialsFor(queueUserLabel)}
                            </span>
                            <div className={styles.queueRowTextStack}>
                              <div className={styles.queueRowTitleLine}>
                                <div
                                  className={`${styles.rowTitle} ${hasUnread ? styles.rowTitleUnread : ""}`}
                                >
                                  {queueUserLabel}
                                </div>
                                {hasUnread ? (
                                  <span className={styles.unreadDotInline} aria-hidden="true" />
                                ) : null}
                              </div>
                              <div className={styles.rowPreview}>
                                <span>
                                  {formatSupportMessagePreview(
                                    item.lastMessagePreview,
                                    text.supportNoMessages
                                  )}
                                </span>
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
                                  title={queueLabels.userUnreadTitle(item.userUnreadCount)}
                                >
                                  <SupportIcon className={styles.queueBadgeIcon} />
                                  {item.userUnreadCount}
                                </span>
                              ) : null}
                              {item.adminUnreadCount > 0 ? (
                                <span
                                  className={`${styles.queueCountBadge} ${styles.queueCountBadgeUnread}`}
                                  title={queueLabels.adminUnreadTitle(item.adminUnreadCount)}
                                >
                                  <BellIcon className={styles.queueBadgeIcon} />
                                  {item.adminUnreadCount}
                                </span>
                              ) : null}
                            </div>
                          </div>
                        </div>
                        <div className={styles.queueRowFooter}>
                          <span
                            className={`${styles.queueStatusPill} ${styles[`queueStatusPill_${item.status}` as keyof typeof styles]}`}
                          >
                            <QueueStatusIcon status={item.status} />
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
                              ? queueLabels.assignedOperator(
                                  formatSafeSupportDisplay(item.assignedAdminDisplayName, "", 72)
                                )
                              : queueLabels.unassignedOperator}
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
                          disabled={isQueueControlsLocked}
                          onClick={() => {
                            if (isQueueControlsLocked) {
                              return;
                            }

                            onConversationSelect?.(item.conversationId);
                          }}
                        >
                          {queueItemContent}
                        </button>
                      );
                    }

                    const supportConversationPathId = encodeURIComponent(item.conversationId);
                    return (
                      <Link
                        key={item.conversationId}
                        href={`/${locale}/support/${supportConversationPathId}`}
                        role="listitem"
                        aria-current={item.conversationId === conversationId ? "page" : undefined}
                        className={queueItemClassName}
                        data-disabled={isQueueControlsLocked ? "true" : undefined}
                        tabIndex={isQueueControlsLocked ? -1 : undefined}
                        onClick={(event) => {
                          if (isQueueControlsLocked) {
                            event.preventDefault();
                          }
                        }}
                      >
                        {queueItemContent}
                      </Link>
                    );
                  })}
                </div>
              )}
              {!inboxQuery.isLoading &&
              !inboxQuery.isError &&
              (filteredInboxItems.length > 0 || queuePage > 1) ? (
                <div className={styles.queueFooter}>
                  <span className={styles.queueFooterCount}>
                    {queueLabels.pageCount(
                      inboxCurrentPage,
                      queueShownStart,
                      queueShownEnd,
                      inboxTotalCount
                    )}
                  </span>
                  <div className={styles.queuePagerActions}>
                    <button
                      type="button"
                      className={styles.queuePagerButton}
                      disabled={!canGoToPreviousQueuePage || isQueueControlsLocked}
                      aria-label={queueLabels.previousPage}
                      title={queueLabels.previousPage}
                      onClick={requestPreviousQueuePage}
                    >
                      <CaretDownIcon
                        className={`${styles.queuePagerIcon} ${styles.queuePagerIconPrevious}`}
                      />
                    </button>
                    <button
                      type="button"
                      className={styles.queuePagerButton}
                      disabled={!canGoToNextQueuePage || isQueueControlsLocked}
                      aria-label={queueLabels.nextPage}
                      title={queueLabels.nextPage}
                      onClick={requestNextQueuePage}
                    >
                      <CaretDownIcon
                        className={`${styles.queuePagerIcon} ${styles.queuePagerIconNext}`}
                      />
                    </button>
                  </div>
                </div>
              ) : null}
            </div>

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
              <AdminCard
                className={`${styles.chatShell} ${isDragging ? styles.chatShellDragging : ""}`}
              >
                {isDragging ? (
                  <div className={styles.dropOverlay}>
                    <div className={styles.dropOverlayContent}>
                      <UploadIcon className={styles.dropOverlayIcon} />
                      <span>{copy.page.dragAndDropImage}</span>
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
                          {userEmailDisplay || copy.shared.deletedUserEmail}{" "}
                          · #{shortId(conversation.initiatorUserId)}
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
                      {conversation.hasOlderMessages ? (
                        <div className={styles.messagesLoadOlderRow}>
                          <Button
                            variant="ghost"
                            onClick={requestOlderMessagesLoad}
                            disabled={!canManageSupportWorkspace || conversationQuery.isFetching}
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
                                normalizedAttachmentStatus === "failed" ||
                                normalizedAttachmentStatus === "retry";
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
                            onClick={requestReopenConversation}
                            disabled={!canManageSupportWorkspace || statusMutation.isPending}
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
                              <FileIcon className={styles.supportFileIcon} />
                            </div>
                          )}
                          <div className={styles.attachmentPreviewMeta}>
                            <span className={styles.subtle}>{text.selectedFileLabel}</span>
                            <strong>
                              {formatSafeSupportDisplay(
                                selectedAttachment.name,
                                messageLabels.fileFallback,
                                120
                              )}
                            </strong>
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
                          className={`${styles.textarea} ${styles.composerTextarea}`}
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
                            disabled={
                              isComposerDisabled ||
                              (!reply.trim() && !hasComposerAttachment)
                            }
                          >
                            {isComposerBusy
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
              aria-label={formatSafeSupportDisplay(
                fullscreenImage.fileName,
                fullscreenImage.mediaType === "video"
                  ? imageViewerLabels.videoPreview
                  : imageViewerLabels.imagePreview,
                120
              )}
              onClick={closeFullscreenImage}
            >
              <div className={styles.imageViewerPanel} onClick={(event) => event.stopPropagation()}>
                <div className={styles.imageViewerHeader}>
                  <strong>
                    {formatSafeSupportDisplay(
                      fullscreenImage.fileName,
                      fullscreenImage.mediaType === "video" ? copy.shared.video : copy.shared.photo,
                      120
                    )}
                  </strong>
                  <Button variant="ghost" size="sm" onClick={closeFullscreenImage}>
                    {imageViewerLabels.close}
                  </Button>
                </div>
                <div className={styles.imageViewerBody}>
                  {fullscreenImage.mediaType === "video" ? (
                    <SupportSecureMedia
                      url={fullscreenImage.attachmentFileUrl}
                      kind="video"
                      className={styles.imageViewerVideo}
                      controls
                      preload="metadata"
                      playsInline
                      logContext={{ messageId: fullscreenImage.messageId, mimeType: "video" }}
                    />
                  ) : (
                    <SupportSecureMedia
                      url={fullscreenImage.attachmentFileUrl}
                      kind="image"
                      alt={formatSafeSupportDisplay(
                        fullscreenImage.fileName,
                        imageViewerLabels.supportImageAlt,
                        120
                      )}
                      width={1720}
                      height={980}
                      className={styles.imageViewerImage}
                      logContext={{ messageId: fullscreenImage.messageId, mimeType: "image" }}
                    />
                  )}
                </div>
                <div className={styles.imageViewerMeta}>
                  {fullscreenImage.senderDisplayName ? (
                    <div>
                      <span>{imageViewerLabels.author}</span>
                      <strong>
                        {formatSafeSupportDisplay(fullscreenImage.senderDisplayName, "", 72)}
                      </strong>
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
                      <span>{copy.shared.duration}</span>
                      <strong>{formatAttachmentDuration(fullscreenImage.durationSeconds)}</strong>
                    </div>
                  ) : null}
                </div>
                <div className={styles.imageViewerActions}>
                  <Button
                    variant="secondary"
                    size="sm"
                    onClick={() => void saveFullscreenImage()}
                    disabled={!canManageSupportWorkspace || pendingFullscreenAction !== null}
                  >
                    {imageViewerLabels.download}
                  </Button>
                  <Button
                    variant="secondary"
                    size="sm"
                    onClick={() => void shareFullscreenImage()}
                    disabled={!canManageSupportWorkspace || pendingFullscreenAction !== null}
                  >
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
                  <Button
                    variant="secondary"
                    size="sm"
                    onClick={() => void openFullscreenImageInNewTab()}
                    disabled={!canManageSupportWorkspace || pendingFullscreenAction !== null}
                  >
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

function getSupportMessageElementId(messageId: string) {
  return `message-${encodeURIComponent(messageId)}`;
}
