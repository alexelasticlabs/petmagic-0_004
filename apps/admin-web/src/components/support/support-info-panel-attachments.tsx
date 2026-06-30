"use client";

import { FileIcon } from "@/components/admin/admin-icons";
import {
  formatDateTime,
  formatFileSize,
  formatRelativeTime,
  formatSafeSupportDisplay,
  getMessageAttachments,
} from "@/components/support/support-conversation-helpers";
import { getSupportConversationCopy } from "@/components/support/support-conversation.content";
import styles from "@/components/support/support-info-panel.module.css";
import { SupportSecureMedia } from "@/components/support/support-secure-media";
import type { Locale } from "@/lib/i18n";

export type SupportInfoAttachment = ReturnType<typeof getMessageAttachments>[number];

export type SupportInfoAttachmentEntry = {
  messageId: string;
  createdAtUtc: string;
  attachment: SupportInfoAttachment;
};

type SupportInfoPanelAttachmentPreviewSectionProps = {
  attachmentPreviewEntries: SupportInfoAttachmentEntry[];
  canManageSupportWorkspace: boolean;
  locale: Locale;
  openAttachmentBlob: (
    messageId: string,
    createdAtUtc: string,
    attachment: SupportInfoAttachment,
    index: number
  ) => Promise<void>;
  panelText: ReturnType<typeof getSupportConversationCopy>["infoPanel"];
  pendingAttachmentOpenKey: string | null;
  recentAttachments: SupportInfoAttachmentEntry[];
  remainingAttachmentCount: number;
  setActiveSidePanelTab: (tab: "attachments") => void;
};

type SupportInfoPanelAttachmentsTabProps = {
  canManageSupportWorkspace: boolean;
  locale: Locale;
  openAttachmentBlob: (
    messageId: string,
    createdAtUtc: string,
    attachment: SupportInfoAttachment,
    index: number
  ) => Promise<void>;
  panelText: ReturnType<typeof getSupportConversationCopy>["infoPanel"];
  pendingAttachmentOpenKey: string | null;
  recentAttachments: SupportInfoAttachmentEntry[];
};

export function SupportInfoPanelAttachmentPreviewSection({
  attachmentPreviewEntries,
  canManageSupportWorkspace,
  locale,
  openAttachmentBlob,
  panelText,
  pendingAttachmentOpenKey,
  recentAttachments,
  remainingAttachmentCount,
  setActiveSidePanelTab,
}: SupportInfoPanelAttachmentPreviewSectionProps) {
  return (
    <div className={styles.infoPanelSection}>
      <div className={styles.infoPanelSectionHeader}>
        <span className={styles.infoPanelSectionTitle}>
          {panelText.attachmentsTitle(recentAttachments.length)}
        </span>
        {remainingAttachmentCount > 0 ? (
          <button
            type="button"
            className={styles.infoPanelSectionLinkButton}
            onClick={() => setActiveSidePanelTab("attachments")}
          >
            {panelText.viewAll}
          </button>
        ) : null}
      </div>
      {recentAttachments.length === 0 ? (
        <span className={styles.subtle}>{panelText.noAttachments}</span>
      ) : (
        <div className={styles.infoPanelAttachmentPreviewStrip}>
          {attachmentPreviewEntries.map((entry, index) => {
            const { attachment } = entry;
            const isImage = attachment.mimeType.toLowerCase().startsWith("image/");
            const safeName = formatSafeSupportDisplay(
              attachment.fileName,
              panelText.fileFallback,
              120
            );

            return (
              <button
                key={`${entry.messageId}-${index}`}
                type="button"
                onClick={() =>
                  void openAttachmentBlob(entry.messageId, entry.createdAtUtc, attachment, index)
                }
                disabled={!canManageSupportWorkspace || pendingAttachmentOpenKey !== null}
                className={styles.infoPanelAttachmentPreviewTile}
                title={safeName}
              >
                {isImage ? (
                  <SupportSecureMedia
                    url={attachment.fileUrl}
                    kind="image"
                    alt={safeName}
                    width={64}
                    height={64}
                    className={styles.infoPanelAttachmentPreviewImage}
                    logContext={{
                      messageId: entry.messageId,
                      mimeType: attachment.mimeType,
                    }}
                  />
                ) : (
                  <span className={styles.infoPanelAttachmentPreviewIcon}>
                    <FileIcon className={styles.supportFileIcon} />
                  </span>
                )}
                <span className={styles.infoPanelAttachmentPreviewSize}>
                  {formatFileSize(attachment.sizeBytes, locale)}
                </span>
              </button>
            );
          })}
          {remainingAttachmentCount > 0 ? (
            <span className={styles.infoPanelAttachmentPreviewMore}>
              +{remainingAttachmentCount}
            </span>
          ) : null}
        </div>
      )}
    </div>
  );
}

export function SupportInfoPanelAttachmentsTab({
  canManageSupportWorkspace,
  locale,
  openAttachmentBlob,
  panelText,
  pendingAttachmentOpenKey,
  recentAttachments,
}: SupportInfoPanelAttachmentsTabProps) {
  return (
    <div className={styles.infoPanelSection}>
      <div className={styles.infoPanelSectionHeader}>
        <span className={styles.infoPanelSectionTitle}>{panelText.allAttachments}</span>
      </div>
      {recentAttachments.length === 0 ? (
        <span className={styles.subtle}>{panelText.noAttachments}</span>
      ) : (
        <div className={styles.attachmentList}>
          {recentAttachments.map((entry, index) => {
            const { attachment } = entry;
            const safeName = formatSafeSupportDisplay(
              attachment.fileName,
              panelText.fileFallback,
              120
            );
            const isImage = attachment.mimeType.toLowerCase().startsWith("image/");
            const attachmentKindLabel = getAttachmentKindLabel(
              attachment.mimeType,
              safeName,
              panelText
            );

            return (
              <div key={`${entry.messageId}-${index}`} className={styles.attachmentListItem}>
                {isImage ? (
                  <button
                    type="button"
                    onClick={() =>
                      void openAttachmentBlob(
                        entry.messageId,
                        entry.createdAtUtc,
                        attachment,
                        index
                      )
                    }
                    disabled={!canManageSupportWorkspace || pendingAttachmentOpenKey !== null}
                    className={styles.attachmentListThumbButton}
                  >
                    <SupportSecureMedia
                      url={attachment.fileUrl}
                      kind="image"
                      alt={safeName}
                      width={76}
                      height={76}
                      className={styles.attachmentListThumb}
                      logContext={{
                        messageId: entry.messageId,
                        mimeType: attachment.mimeType,
                      }}
                    />
                  </button>
                ) : (
                  <span className={styles.attachmentPreviewFileIcon}>
                    <FileIcon className={styles.supportFileIcon} />
                  </span>
                )}
                <div className={styles.attachmentListMeta}>
                  <div className={styles.attachmentListMetaTop}>
                    <strong title={safeName}>{safeName}</strong>
                    <span className={styles.attachmentListTypeBadge}>{attachmentKindLabel}</span>
                  </div>
                  <div className={styles.attachmentListMetaRow}>
                    <span>{formatRelativeTime(entry.createdAtUtc, locale)}</span>
                    <span aria-hidden="true">•</span>
                    <span>{formatFileSize(attachment.sizeBytes, locale)}</span>
                  </div>
                  <span className={styles.attachmentListMetaHint}>
                    {formatDateTime(entry.createdAtUtc, locale)}
                  </span>
                </div>
                <div className={styles.attachmentListActions}>
                  <button
                    type="button"
                    onClick={() =>
                      void openAttachmentBlob(
                        entry.messageId,
                        entry.createdAtUtc,
                        attachment,
                        index
                      )
                    }
                    disabled={!canManageSupportWorkspace || pendingAttachmentOpenKey !== null}
                    className="ui-button ui-button--secondary ui-button--sm"
                  >
                    {panelText.open}
                  </button>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}

function getAttachmentKindLabel(
  mimeType: string,
  fileName: string,
  panelText: ReturnType<typeof getSupportConversationCopy>["infoPanel"]
) {
  const normalizedMime = mimeType.trim().toLowerCase();
  const extensionFromName = fileName.includes(".")
    ? (fileName.split(".").pop()?.trim().toUpperCase() ?? "")
    : "";

  if (extensionFromName.length >= 2 && extensionFromName.length <= 6) {
    return extensionFromName;
  }

  if (normalizedMime.startsWith("image/")) {
    return panelText.attachmentKinds.photo;
  }

  if (normalizedMime.startsWith("video/")) {
    return panelText.attachmentKinds.video;
  }

  if (normalizedMime.startsWith("audio/")) {
    return panelText.attachmentKinds.audio;
  }

  if (normalizedMime === "application/pdf") {
    return "PDF";
  }

  return panelText.attachmentKinds.file;
}
