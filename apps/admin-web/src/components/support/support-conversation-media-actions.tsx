"use client";

import { FileIcon, PlayCircleIcon } from "@/components/admin/admin-icons";
import styles from "@/components/support/support-conversation-chat-content.module.css";
import {
  formatFileSize,
  formatSafeSupportDownloadName,
  formatSafeSupportDisplay,
  getMessageAttachments,
  shouldRenderMessageBody,
} from "@/components/support/support-conversation-helpers";
import type {
  FullscreenImage,
  SupportMessage,
  SupportMessageAttachment,
} from "@/components/support/support-conversation-page.types";
import { getSupportConversationCopy } from "@/components/support/support-conversation.content";
import sharedStyles from "@/components/support/support-page.module.css";
import {
  getBlockedUnsafeSupportMediaUrlDetails,
  isUnsafeSupportMediaUrl,
  SupportSecureMedia,
} from "@/components/support/support-secure-media";
import type { AdminSupportConversation } from "@/lib/api-client";
import { clientLogger } from "@/lib/client-logger";
import { fetchWithTimeout } from "@/lib/fetch-with-timeout";
import { getDictionary, type Locale } from "@/lib/i18n";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

import type { MutableRefObject, ReactNode } from "react";

type AttachmentTileOptions = {
  overlayCount?: number;
  single?: boolean;
};

type UseSupportConversationMediaActionsArgs = {
  attachmentActionAbortControllerRef: MutableRefObject<AbortController | null>;
  canManageSupportWorkspace: boolean;
  copy: ReturnType<typeof getSupportConversationCopy>;
  fullscreenActionAbortControllerRef: MutableRefObject<AbortController | null>;
  fullscreenImage: FullscreenImage | null;
  imageViewerLabels: ReturnType<typeof getSupportConversationCopy>["page"]["imageViewer"];
  locale: Locale;
  messageLabels: ReturnType<typeof getSupportConversationCopy>["page"]["message"];
  pendingAttachmentActionKey: string | null;
  pendingFullscreenAction: "download" | "share" | "open" | null;
  replyToMessage: SupportMessage | null;
  replyToPreview: string | null;
  selectReplyToMessage: (messageId: string | null, preview?: string) => void;
  setFullscreenImage: (image: FullscreenImage | null) => void;
  setPendingAttachmentActionKey: (key: string | null) => void;
  setPendingFullscreenAction: (action: "download" | "share" | "open" | null) => void;
  text: ReturnType<typeof getDictionary>;
};

export function downloadSupportBlobUrl(objectUrl: string, fileName: string): void {
  const link = document.createElement("a");
  link.href = objectUrl;
  link.download = fileName;
  document.body.append(link);
  link.click();
  link.remove();
}

function scheduleSupportBlobUrlRevoke(objectUrl: string, delayMs: number): void {
  window.setTimeout(() => URL.revokeObjectURL(objectUrl), delayMs);
}

function revokeSupportBlobUrlOnFailure(objectUrl: string, action: () => void): void {
  try {
    action();
  } catch (error) {
    URL.revokeObjectURL(objectUrl);
    throw error;
  }
}

export function getSupportActionErrorDetails(error: unknown) {
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

export function useSupportConversationMediaActions({
  attachmentActionAbortControllerRef,
  canManageSupportWorkspace,
  copy,
  fullscreenActionAbortControllerRef,
  fullscreenImage,
  imageViewerLabels,
  locale,
  messageLabels,
  pendingAttachmentActionKey,
  pendingFullscreenAction,
  replyToMessage,
  replyToPreview,
  selectReplyToMessage,
  setFullscreenImage,
  setPendingAttachmentActionKey,
  setPendingFullscreenAction,
  text,
}: UseSupportConversationMediaActionsArgs) {
  async function fetchFullscreenAttachmentBlob(
    image: FullscreenImage,
    action: "download" | "share" | "open",
    signal: AbortSignal
  ): Promise<Blob | null> {
    if (isUnsafeSupportMediaUrl(image.attachmentFileUrl)) {
      clientLogger.warn(`support.fullscreen_${action}_blocked`, {
        messageId: formatSupportLogText(image.messageId),
        mediaType: formatSupportLogText(image.mediaType),
        ...getBlockedUnsafeSupportMediaUrlDetails(image.attachmentFileUrl),
      });
      return null;
    }

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
      revokeSupportBlobUrlOnFailure(objectUrl, () => {
        downloadSupportBlobUrl(
          objectUrl,
          formatSafeSupportDownloadName(fullscreenImage.fileName, defaultFileName)
        );
        scheduleSupportBlobUrlRevoke(objectUrl, 1000);
      });
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
        revokeSupportBlobUrlOnFailure(objectUrl, () => {
          downloadSupportBlobUrl(objectUrl, safeFileName);
          scheduleSupportBlobUrlRevoke(objectUrl, 1000);
        });
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
      revokeSupportBlobUrlOnFailure(objectUrl, () => {
        const opened = window.open(objectUrl, "_blank", "noopener,noreferrer");
        if (!opened) {
          const defaultFileName =
            fullscreenImage.mediaType === "video" ? "support-video" : "support-image";
          downloadSupportBlobUrl(
            objectUrl,
            formatSafeSupportDownloadName(fullscreenImage.fileName, defaultFileName)
          );
          scheduleSupportBlobUrlRevoke(objectUrl, 1000);
          return;
        }

        scheduleSupportBlobUrlRevoke(objectUrl, 60_000);
      });
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
      if (isUnsafeSupportMediaUrl(attachment.fileUrl)) {
        clientLogger.warn("support.attachment_download_blocked", {
          messageId: formatSupportLogText(message.messageId),
          mimeType: formatSupportLogText(attachment.mimeType),
          ...getBlockedUnsafeSupportMediaUrlDetails(attachment.fileUrl),
        });
        return;
      }

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
      revokeSupportBlobUrlOnFailure(objectUrl, () => {
        downloadSupportBlobUrl(objectUrl, formatSafeSupportDownloadName(attachment.fileName));
        scheduleSupportBlobUrlRevoke(objectUrl, 1000);
      });
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

  const closeFullscreenImage = () => {
    fullscreenActionAbortControllerRef.current?.abort();
    fullscreenActionAbortControllerRef.current = null;
    setPendingFullscreenAction(null);
    setFullscreenImage(null);
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
    options?: AttachmentTileOptions
  ): ReactNode => {
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
        disabled={!canManageSupportWorkspace || pendingAttachmentActionKey !== null}
        className={`${styles.messageAttachmentCard} ${styles.messageMediaFileTile}`}
      >
        <div className={styles.messageAttachmentIcon}>
          <FileIcon className={sharedStyles.supportFileIcon} />
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

  return {
    closeFullscreenImage,
    openFullscreenImageInNewTab,
    renderAttachmentTile,
    renderReplyThumbnail,
    replyComposerAttachment,
    replyComposerPreview,
    saveFullscreenImage,
    shareFullscreenImage,
    startReplyToMessage,
  };
}
