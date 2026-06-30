"use client";

import { useEffect, useMemo, useRef, useState } from "react";

import {
  formatSafeSupportDownloadName,
  getMessageAttachments,
} from "@/components/support/support-conversation-helpers";
import type {
  SupportInfoAttachment,
  SupportInfoAttachmentEntry,
} from "@/components/support/support-info-panel-attachments";
import type { AdminSupportMessage } from "@/lib/api-client";
import { clientLogger } from "@/lib/client-logger";
import { fetchWithTimeout } from "@/lib/fetch-with-timeout";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

function downloadSupportInfoBlobUrl(objectUrl: string, fileName: string): void {
  const link = document.createElement("a");
  link.href = objectUrl;
  link.download = fileName;
  document.body.append(link);
  link.click();
  link.remove();
}

function formatSupportInfoLogText(value: string | null | undefined, maxLength = 80) {
  return value ? sanitizeSensitiveText(value, maxLength) : undefined;
}

function getSupportInfoErrorDetails(error: unknown) {
  return {
    errorName: error instanceof Error ? error.name : "UnknownError",
    errorDigest:
      error && typeof error === "object" && "digest" in error
        ? sanitizeSensitiveText(String((error as { digest?: unknown }).digest ?? ""), 80)
        : undefined,
  };
}

type UseSupportInfoPanelAttachmentActionsArgs = {
  canManageSupportWorkspace: boolean;
  conversationMessages: AdminSupportMessage[] | undefined;
};

export function useSupportInfoPanelAttachmentActions({
  canManageSupportWorkspace,
  conversationMessages,
}: UseSupportInfoPanelAttachmentActionsArgs) {
  const [pendingAttachmentOpenKey, setPendingAttachmentOpenKey] = useState<string | null>(null);
  const attachmentOpenAbortControllerRef = useRef<AbortController | null>(null);

  useEffect(
    () => () => {
      attachmentOpenAbortControllerRef.current?.abort();
    },
    []
  );

  const recentAttachments = useMemo(() => {
    const entries: SupportInfoAttachmentEntry[] = (conversationMessages ?? [])
      .flatMap((message) =>
        getMessageAttachments(message)
          .filter((attachment) => !attachment.isDeleted && Boolean(attachment.fileUrl?.trim()))
          .map((attachment) => ({
            messageId: message.messageId,
            createdAtUtc: message.createdAtUtc,
            attachment,
          }))
      )
      .sort((left, right) => right.createdAtUtc.localeCompare(left.createdAtUtc));

    const seen = new Set<string>();
    return entries.filter((entry) => {
      const key = `${entry.messageId}|${entry.attachment.fileName}|${entry.attachment.sizeBytes}|${entry.createdAtUtc}`;
      if (seen.has(key)) {
        return false;
      }

      seen.add(key);
      return true;
    });
  }, [conversationMessages]);

  const attachmentPreviewEntries = recentAttachments.slice(0, 4);
  const remainingAttachmentCount = Math.max(
    recentAttachments.length - attachmentPreviewEntries.length,
    0
  );

  const getAttachmentOpenKey = (
    messageId: string,
    createdAtUtc: string,
    attachment: SupportInfoAttachment,
    index: number
  ) => `${messageId}:${createdAtUtc}:${attachment.fileName}:${attachment.sizeBytes}:${index}`;

  const openAttachmentBlob = async (
    messageId: string,
    createdAtUtc: string,
    attachment: SupportInfoAttachment,
    index: number
  ) => {
    const openKey = getAttachmentOpenKey(messageId, createdAtUtc, attachment, index);
    if (!canManageSupportWorkspace || pendingAttachmentOpenKey !== null) {
      return;
    }

    setPendingAttachmentOpenKey(openKey);
    attachmentOpenAbortControllerRef.current?.abort();
    const controller = new AbortController();
    attachmentOpenAbortControllerRef.current = controller;
    try {
      const response = await fetchWithTimeout(attachment.fileUrl, {
        credentials: "include",
        signal: controller.signal,
      });
      if (!response.ok) {
        clientLogger.warn("support.attachment_open_failed", {
          messageId: formatSupportInfoLogText(messageId),
          status: response.status,
          mimeType: formatSupportInfoLogText(attachment.mimeType),
        });
        return;
      }

      const blob = await response.blob();
      const objectUrl = URL.createObjectURL(blob);
      const opened = window.open(objectUrl, "_blank", "noopener,noreferrer");
      if (!opened) {
        downloadSupportInfoBlobUrl(objectUrl, formatSafeSupportDownloadName(attachment.fileName));
        window.setTimeout(() => URL.revokeObjectURL(objectUrl), 1000);
        return;
      }

      window.setTimeout(() => URL.revokeObjectURL(objectUrl), 60_000);
    } catch (error) {
      if (controller.signal.aborted) {
        return;
      }

      clientLogger.warn("support.attachment_open_failed", {
        messageId: formatSupportInfoLogText(messageId),
        mimeType: formatSupportInfoLogText(attachment.mimeType),
        ...getSupportInfoErrorDetails(error),
      });
    } finally {
      if (attachmentOpenAbortControllerRef.current === controller) {
        attachmentOpenAbortControllerRef.current = null;
        setPendingAttachmentOpenKey(null);
      }
    }
  };

  return {
    attachmentPreviewEntries,
    openAttachmentBlob,
    pendingAttachmentOpenKey,
    recentAttachments,
    remainingAttachmentCount,
  };
}
