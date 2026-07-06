"use client";

import { useEffect, useRef, useState } from "react";

import { DownloadIcon, ImageIcon, PlayCircleIcon } from "@/components/admin/admin-icons";
import {
  getBlockedUnsafeTemplateMediaUrlDetails,
  isUnsafeTemplateMediaUrl,
} from "@/components/templates/template-secure-media";
import { getTemplateTestErrorDetails } from "@/components/templates/template-test-page.helpers";
import styles from "@/components/templates/template-test-page.module.css";
import { clientLogger } from "@/lib/client-logger";
import { fetchWithTimeout } from "@/lib/fetch-with-timeout";

type TemplateTestMediaActionsProps = {
  canManageTemplates: boolean;
  downloadLabel: string;
  downloadName?: string;
  openLabel: string;
  previewUrl?: string;
  videoUrl?: string;
};

export function TemplateTestMediaActions({
  canManageTemplates,
  downloadLabel,
  downloadName,
  openLabel,
  previewUrl,
  videoUrl,
}: TemplateTestMediaActionsProps) {
  const mediaType = videoUrl ? "video" : "image";
  const [pendingMediaAction, setPendingMediaAction] = useState<"download" | "open" | null>(null);
  const mediaActionAbortControllerRef = useRef<AbortController | null>(null);

  useEffect(
    () => () => {
      mediaActionAbortControllerRef.current?.abort();
    },
    []
  );

  async function fetchPreviewBlob(
    action: "download" | "open",
    signal: AbortSignal
  ): Promise<Blob | null> {
    if (!previewUrl) {
      return null;
    }

    if (isUnsafeTemplateMediaUrl(previewUrl)) {
      clientLogger.warn("templates.media_preview_fetch_blocked", {
        action,
        mediaType,
        ...getBlockedUnsafeTemplateMediaUrlDetails(previewUrl),
      });
      return null;
    }

    try {
      const response = await fetchWithTimeout(previewUrl, { credentials: "include", signal });
      if (!response.ok) {
        clientLogger.warn("templates.media_preview_fetch_failed", {
          action,
          mediaType,
          status: response.status,
        });
        return null;
      }

      return response.blob();
    } catch (error) {
      if (signal.aborted) {
        return null;
      }

      clientLogger.warn("templates.media_preview_fetch_failed", {
        action,
        mediaType,
        ...getTemplateTestErrorDetails(error),
      });
      return null;
    }
  }

  function downloadPreviewBlobUrl(objectUrl: string): void {
    const anchor = document.createElement("a");
    anchor.href = objectUrl;
    anchor.download = downloadName ?? (videoUrl ? "template-test.mp4" : "template-test.png");
    anchor.rel = "noreferrer";
    document.body.appendChild(anchor);
    anchor.click();
    anchor.remove();
  }

  function schedulePreviewBlobUrlRevoke(objectUrl: string, delayMs: number): void {
    window.setTimeout(() => URL.revokeObjectURL(objectUrl), delayMs);
  }

  function revokePreviewBlobUrlOnFailure(objectUrl: string, action: () => void): void {
    try {
      action();
    } catch (error) {
      URL.revokeObjectURL(objectUrl);
      throw error;
    }
  }

  async function handleDownload() {
    if (!canManageTemplates || !previewUrl || pendingMediaAction) {
      return;
    }

    mediaActionAbortControllerRef.current?.abort();
    const controller = new AbortController();
    mediaActionAbortControllerRef.current = controller;
    setPendingMediaAction("download");
    try {
      const blob = await fetchPreviewBlob("download", controller.signal);
      if (!blob || controller.signal.aborted) {
        return;
      }

      const objectUrl = URL.createObjectURL(blob);
      revokePreviewBlobUrlOnFailure(objectUrl, () => {
        downloadPreviewBlobUrl(objectUrl);
        schedulePreviewBlobUrlRevoke(objectUrl, 1000);
      });
    } finally {
      if (mediaActionAbortControllerRef.current === controller) {
        mediaActionAbortControllerRef.current = null;
        setPendingMediaAction(null);
      }
    }
  }

  async function handleOpen() {
    if (!canManageTemplates || !previewUrl || pendingMediaAction) {
      return;
    }

    mediaActionAbortControllerRef.current?.abort();
    const controller = new AbortController();
    mediaActionAbortControllerRef.current = controller;
    setPendingMediaAction("open");
    try {
      const blob = await fetchPreviewBlob("open", controller.signal);
      if (!blob || controller.signal.aborted) {
        return;
      }

      const objectUrl = URL.createObjectURL(blob);
      revokePreviewBlobUrlOnFailure(objectUrl, () => {
        const opened = window.open(objectUrl, "_blank", "noopener,noreferrer");
        if (!opened) {
          downloadPreviewBlobUrl(objectUrl);
          schedulePreviewBlobUrlRevoke(objectUrl, 1000);
          return;
        }

        schedulePreviewBlobUrlRevoke(objectUrl, 60_000);
      });
    } finally {
      if (mediaActionAbortControllerRef.current === controller) {
        mediaActionAbortControllerRef.current = null;
        setPendingMediaAction(null);
      }
    }
  }

  return (
    <div className={styles.mediaActions}>
      <button
        type="button"
        onClick={() => void handleOpen()}
        disabled={!canManageTemplates || pendingMediaAction !== null}
        className={styles.mediaActionLink}
      >
        {videoUrl ? (
          <PlayCircleIcon className={styles.inlineIcon} />
        ) : (
          <ImageIcon className={styles.inlineIcon} />
        )}
        <span>{openLabel}</span>
      </button>
      <button
        type="button"
        onClick={() => void handleDownload()}
        disabled={!canManageTemplates || pendingMediaAction !== null}
        className={`${styles.mediaActionLink} ${styles.mediaActionLinkPrimary}`}
      >
        <DownloadIcon className={styles.inlineIcon} />
        <span>{downloadLabel}</span>
      </button>
    </div>
  );
}
