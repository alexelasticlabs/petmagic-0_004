"use client";

import {
  formatDateTime,
  formatFileSize,
  formatSafeSupportDisplay,
} from "@/components/support/support-conversation-helpers";
import type { FullscreenImage } from "@/components/support/support-conversation-page.types";
import { getSupportConversationCopy } from "@/components/support/support-conversation.content";
import styles from "@/components/support/support-page.module.css";
import { SupportSecureMedia } from "@/components/support/support-secure-media";
import { Button } from "@/components/ui/button";
import type { Locale } from "@/lib/i18n";

type SupportConversationFullscreenViewerProps = {
  canManageSupportWorkspace: boolean;
  closeFullscreenImage: () => void;
  copy: ReturnType<typeof getSupportConversationCopy>;
  fullscreenImage: FullscreenImage;
  imageViewerLabels: ReturnType<typeof getSupportConversationCopy>["page"]["imageViewer"];
  jumpToMessage: (messageId: string) => void;
  locale: Locale;
  openFullscreenImageInNewTab: () => Promise<void>;
  pendingFullscreenAction: "download" | "share" | "open" | null;
  saveFullscreenImage: () => Promise<void>;
  shareFullscreenImage: () => Promise<void>;
};

function formatAttachmentDuration(value?: number | null) {
  if (!value || value <= 0) {
    return "0:00";
  }

  const totalSeconds = Math.max(0, Math.round(value));
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  return `${minutes}:${seconds.toString().padStart(2, "0")}`;
}

export function SupportConversationFullscreenViewer({
  canManageSupportWorkspace,
  closeFullscreenImage,
  copy,
  fullscreenImage,
  imageViewerLabels,
  jumpToMessage,
  locale,
  openFullscreenImageInNewTab,
  pendingFullscreenAction,
  saveFullscreenImage,
  shareFullscreenImage,
}: SupportConversationFullscreenViewerProps) {
  return (
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
              <strong>{formatSafeSupportDisplay(fullscreenImage.senderDisplayName, "", 72)}</strong>
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
  );
}
