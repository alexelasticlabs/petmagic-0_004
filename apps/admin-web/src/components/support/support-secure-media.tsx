"use client";

import { useCallback, useEffect, useRef, useState } from "react";

import { isUnsafeAdminMediaHost } from "@/lib/admin-unsafe-remote-host";
import { clientLogger } from "@/lib/client-logger";
import { fetchWithTimeout } from "@/lib/fetch-with-timeout";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

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

function formatSupportMediaLogText(value: string | null | undefined, maxLength = 80) {
  return value ? sanitizeSensitiveText(value, maxLength) : undefined;
}

function getSupportMediaErrorDetails(error: unknown) {
  return {
    errorName: error instanceof Error ? error.name : "UnknownError",
    errorDigest:
      error && typeof error === "object" && "digest" in error
        ? sanitizeSensitiveText(String((error as { digest?: unknown }).digest ?? ""), 80)
        : undefined,
  };
}

export function getBlockedUnsafeSupportMediaUrlDetails(url: string) {
  return {
    rawLength: url.length,
    startsWithSlash: url.startsWith("/"),
    isBlobOrData: isLocalObjectUrl(url),
  };
}

export function isUnsafeSupportMediaUrl(url: string): boolean {
  try {
    const parsed = new URL(url);
    return isUnsafeMediaHost(parsed.hostname);
  } catch {
    return false;
  }
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
  const unsafeRemoteUrl = !localObjectUrl && isUnsafeSupportMediaUrl(url);
  const [remoteMedia, setRemoteMedia] = useState<{
    sourceUrl: string;
    objectUrl: string | null;
    failed: boolean;
  }>({ sourceUrl: "", objectUrl: null, failed: false });
  const activeObjectUrlRef = useRef<string | null>(null);
  const objectUrl =
    localObjectUrl ?? (remoteMedia.sourceUrl === url ? remoteMedia.objectUrl : null);
  const loadFailed =
    unsafeRemoteUrl || (!localObjectUrl && remoteMedia.sourceUrl === url && remoteMedia.failed);
  const revokeActiveObjectUrl = useCallback(() => {
    if (!activeObjectUrlRef.current) {
      return;
    }

    URL.revokeObjectURL(activeObjectUrlRef.current);
    activeObjectUrlRef.current = null;
  }, []);
  const markRemoteMediaFailed = useCallback(() => {
    if (localObjectUrl) {
      return;
    }

    revokeActiveObjectUrl();
    setRemoteMedia({ sourceUrl: url, objectUrl: null, failed: true });
  }, [localObjectUrl, revokeActiveObjectUrl, url]);

  useEffect(() => {
    if (localObjectUrl) {
      return;
    }

    if (unsafeRemoteUrl) {
      clientLogger.warn("support.secure_media_unsafe_host_blocked", {
        messageId: formatSupportMediaLogText(logContext?.messageId),
        mimeType: formatSupportMediaLogText(logContext?.mimeType),
        kind,
        ...getBlockedUnsafeSupportMediaUrlDetails(url),
      });
      revokeActiveObjectUrl();
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
            messageId: formatSupportMediaLogText(logContext?.messageId),
            mimeType: formatSupportMediaLogText(logContext?.mimeType),
            kind,
            status: response.status,
          });
          markRemoteMediaFailed();
          return;
        }

        const blob = await response.blob();
        if (!isActive) {
          return;
        }

        createdObjectUrl = URL.createObjectURL(blob);
        revokeActiveObjectUrl();
        activeObjectUrlRef.current = createdObjectUrl;
        setRemoteMedia({ sourceUrl: url, objectUrl: createdObjectUrl, failed: false });
      })
      .catch((error) => {
        if (controller.signal.aborted || !isActive) {
          return;
        }

        clientLogger.warn("support.secure_media_fetch_failed", {
          messageId: formatSupportMediaLogText(logContext?.messageId),
          mimeType: formatSupportMediaLogText(logContext?.mimeType),
          kind,
          ...getSupportMediaErrorDetails(error),
        });
        markRemoteMediaFailed();
      });

    return () => {
      isActive = false;
      controller.abort();
      if (createdObjectUrl && activeObjectUrlRef.current === createdObjectUrl) {
        revokeActiveObjectUrl();
      }
    };
  }, [
    kind,
    localObjectUrl,
    logContext?.messageId,
    logContext?.mimeType,
    markRemoteMediaFailed,
    revokeActiveObjectUrl,
    unsafeRemoteUrl,
    url,
  ]);

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
        onError={markRemoteMediaFailed}
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
      onError={markRemoteMediaFailed}
    />
  );
}

function isUnsafeMediaHost(hostname: string): boolean {
  return isUnsafeAdminMediaHost(hostname);
}
