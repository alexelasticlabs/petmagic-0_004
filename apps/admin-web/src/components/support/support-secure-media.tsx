"use client";

import { useEffect, useState } from "react";

import { clientLogger } from "@/lib/client-logger";
import { fetchWithTimeout } from "@/lib/fetch-with-timeout";

type SupportSecureMediaProps = {
  url: string;
  alt?: string;
  className?: string;
  kind: "image" | "video";
  width?: number;
  height?: number;
  loading?: "eager" | "lazy";
  preload?: "none" | "metadata" | "auto";
  controls?: boolean;
  playsInline?: boolean;
  muted?: boolean;
  ariaHidden?: boolean;
  logContext?: {
    messageId?: string;
    mimeType?: string;
  };
};

function isLocalObjectUrl(url: string) {
  return url.startsWith("blob:") || url.startsWith("data:");
}

export function SupportSecureMedia({
  url,
  alt = "",
  className,
  kind,
  width,
  height,
  loading = "lazy",
  preload = "metadata",
  controls = false,
  playsInline = false,
  muted = false,
  ariaHidden = false,
  logContext,
}: SupportSecureMediaProps) {
  const localObjectUrl = isLocalObjectUrl(url) ? url : null;
  const [remoteMedia, setRemoteMedia] = useState<{
    sourceUrl: string;
    objectUrl: string | null;
    failed: boolean;
  }>({ sourceUrl: "", objectUrl: null, failed: false });
  const objectUrl =
    localObjectUrl ?? (remoteMedia.sourceUrl === url ? remoteMedia.objectUrl : null);
  const loadFailed = !localObjectUrl && remoteMedia.sourceUrl === url && remoteMedia.failed;

  useEffect(() => {
    if (localObjectUrl) {
      return;
    }

    const controller = new AbortController();
    let createdObjectUrl: string | null = null;
    let isActive = true;

    void fetchWithTimeout(url, { credentials: "include", signal: controller.signal })
      .then(async (response) => {
        if (!isActive) {
          return;
        }

        if (!response.ok) {
          clientLogger.warn("support.secure_media_fetch_failed", {
            messageId: logContext?.messageId,
            mimeType: logContext?.mimeType,
            kind,
            status: response.status,
          });
          setRemoteMedia({ sourceUrl: url, objectUrl: null, failed: true });
          return;
        }

        const blob = await response.blob();
        if (!isActive) {
          return;
        }

        createdObjectUrl = URL.createObjectURL(blob);
        setRemoteMedia({ sourceUrl: url, objectUrl: createdObjectUrl, failed: false });
      })
      .catch((error) => {
        if (controller.signal.aborted || !isActive) {
          return;
        }

        clientLogger.warn("support.secure_media_fetch_failed", {
          messageId: logContext?.messageId,
          mimeType: logContext?.mimeType,
          kind,
          error,
        });
        setRemoteMedia({ sourceUrl: url, objectUrl: null, failed: true });
      });

    return () => {
      isActive = false;
      controller.abort();
      if (createdObjectUrl) {
        URL.revokeObjectURL(createdObjectUrl);
      }
    };
  }, [kind, localObjectUrl, logContext?.messageId, logContext?.mimeType, url]);

  if (!objectUrl) {
    return (
      <span
        className={className}
        aria-hidden={ariaHidden || undefined}
        aria-label={!ariaHidden && alt ? alt : undefined}
        role={!ariaHidden && alt ? "img" : undefined}
        data-media-state={loadFailed ? "error" : "loading"}
      />
    );
  }

  if (kind === "video") {
    return (
      <video
        src={objectUrl}
        className={className}
        controls={controls}
        preload={preload}
        playsInline={playsInline}
        muted={muted}
        aria-hidden={ariaHidden || undefined}
      />
    );
  }

  return (
    // eslint-disable-next-line @next/next/no-img-element -- Next/Image would put signed attachment URLs in the DOM instead of blob URLs.
    <img
      src={objectUrl}
      alt={alt}
      className={className}
      width={width}
      height={height}
      loading={loading}
      aria-hidden={ariaHidden || undefined}
    />
  );
}
