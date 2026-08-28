"use client";

import { useCallback, useEffect, useRef, useState, type ReactNode } from "react";

import { isUnsafeAdminMediaHost } from "@/lib/admin-unsafe-remote-host";
import { clientLogger } from "@/lib/client-logger";
import { fetchWithTimeout } from "@/lib/fetch-with-timeout";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

type TemplateSecureMediaProps = {
  url: string;
  kind: "image" | "video";
  alt?: string;
  className?: string;
  width?: number;
  height?: number;
  loading?: "eager" | "lazy";
  preload?: "none" | "metadata" | "auto";
  controls?: boolean;
  muted?: boolean;
  autoPlay?: boolean;
  loop?: boolean;
  playsInline?: boolean;
  ariaHidden?: boolean;
  ariaLabel?: string;
  fallback?: ReactNode;
  onLoadFailed?: () => void;
  logContext?: {
    templateId?: string;
    contentType?: string | null;
    surface?: string;
  };
};

function isLocalObjectUrl(url: string) {
  return url.startsWith("blob:") || url.startsWith("data:");
}

export function isUnsafeTemplateMediaUrl(url: string) {
  try {
    const parsed = new URL(url, globalThis.location?.href ?? "https://admin.petgpt.app");
    return isUnsafeMediaHost(parsed.hostname);
  } catch {
    return false;
  }
}

function getMediaFetchErrorName(error: unknown) {
  return error instanceof Error ? error.name : "UnknownError";
}

function formatTemplateMediaLogText(value: string | null | undefined, maxLength = 80) {
  return value ? sanitizeSensitiveText(value, maxLength) : undefined;
}

export function getBlockedUnsafeTemplateMediaUrlDetails(url: string) {
  return {
    rawLength: url.length,
    startsWithSlash: url.startsWith("/"),
    isBlobOrData: isLocalObjectUrl(url),
  };
}

export function TemplateSecureMedia({
  url,
  kind,
  alt = "",
  className,
  width,
  height,
  loading = "lazy",
  preload = "metadata",
  controls = false,
  muted = false,
  autoPlay = false,
  loop = false,
  playsInline = false,
  ariaHidden = false,
  ariaLabel,
  fallback,
  onLoadFailed,
  logContext,
}: TemplateSecureMediaProps) {
  const localObjectUrl = isLocalObjectUrl(url) ? url : null;
  const unsafeRemoteUrl = !localObjectUrl && isUnsafeTemplateMediaUrl(url);
  const [remoteMedia, setRemoteMedia] = useState<{
    sourceUrl: string;
    objectUrl: string | null;
    useDirectUrl: boolean;
    failed: boolean;
  }>({ sourceUrl: "", objectUrl: null, useDirectUrl: false, failed: false });
  const activeObjectUrlRef = useRef<string | null>(null);
  const resolvedUrl =
    localObjectUrl ??
    (remoteMedia.sourceUrl === url
      ? (remoteMedia.objectUrl ?? (remoteMedia.useDirectUrl ? url : null))
      : null);
  const loadFailed =
    unsafeRemoteUrl || (!localObjectUrl && remoteMedia.sourceUrl === url && remoteMedia.failed);
  const onLoadFailedRef = useRef(onLoadFailed);
  const revokeActiveObjectUrl = useCallback(() => {
    if (!activeObjectUrlRef.current) {
      return;
    }

    URL.revokeObjectURL(activeObjectUrlRef.current);
    activeObjectUrlRef.current = null;
  }, []);
  const markRemoteMediaFailed = useCallback(() => {
    if (localObjectUrl) {
      onLoadFailedRef.current?.();
      return;
    }

    revokeActiveObjectUrl();
    setRemoteMedia({ sourceUrl: url, objectUrl: null, useDirectUrl: false, failed: true });
    onLoadFailedRef.current?.();
  }, [localObjectUrl, revokeActiveObjectUrl, url]);
  const fallBackToDirectRemoteUrl = useCallback(() => {
    revokeActiveObjectUrl();
    setRemoteMedia({ sourceUrl: url, objectUrl: null, useDirectUrl: true, failed: false });
  }, [revokeActiveObjectUrl, url]);

  useEffect(() => {
    onLoadFailedRef.current = onLoadFailed;
  }, [onLoadFailed]);

  useEffect(() => {
    if (localObjectUrl) {
      return;
    }

    if (unsafeRemoteUrl) {
      clientLogger.warn("templates.secure_media_unsafe_host_blocked", {
        templateId: formatTemplateMediaLogText(logContext?.templateId),
        contentType: formatTemplateMediaLogText(logContext?.contentType),
        surface: formatTemplateMediaLogText(logContext?.surface, 48),
        kind,
        ...getBlockedUnsafeTemplateMediaUrlDetails(url),
      });
      revokeActiveObjectUrl();
      onLoadFailedRef.current?.();
      return;
    }

    const controller = new AbortController();
    let createdObjectUrl: string | null = null;
    let isActive = true;

    // Template previews are public CDN assets. Sending admin cookies cross-origin
    // makes a valid CORS response require Access-Control-Allow-Credentials and
    // prevents Cloudflare R2 from serving the preview to this isolated renderer.
    // A regular media element can still display the configured public asset when its
    // storage origin does not expose CORS headers to JavaScript.
    void fetchWithTimeout(url, { credentials: "omit", signal: controller.signal })
      .then(async (response) => {
        if (!isActive) {
          return;
        }

        if (!response.ok) {
          clientLogger.warn("templates.secure_media_fetch_failed", {
            templateId: formatTemplateMediaLogText(logContext?.templateId),
            contentType: formatTemplateMediaLogText(logContext?.contentType),
            surface: formatTemplateMediaLogText(logContext?.surface, 48),
            kind,
            status: response.status,
          });
          fallBackToDirectRemoteUrl();
          return;
        }

        const blob = await response.blob();
        if (!isActive) {
          return;
        }

        createdObjectUrl = URL.createObjectURL(blob);
        revokeActiveObjectUrl();
        activeObjectUrlRef.current = createdObjectUrl;
        setRemoteMedia({
          sourceUrl: url,
          objectUrl: createdObjectUrl,
          useDirectUrl: false,
          failed: false,
        });
      })
      .catch((error) => {
        if (controller.signal.aborted || !isActive) {
          return;
        }

        clientLogger.warn("templates.secure_media_fetch_failed", {
          templateId: formatTemplateMediaLogText(logContext?.templateId),
          contentType: formatTemplateMediaLogText(logContext?.contentType),
          surface: formatTemplateMediaLogText(logContext?.surface, 48),
          kind,
          errorName: getMediaFetchErrorName(error),
        });
        fallBackToDirectRemoteUrl();
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
    logContext?.contentType,
    logContext?.surface,
    logContext?.templateId,
    fallBackToDirectRemoteUrl,
    revokeActiveObjectUrl,
    unsafeRemoteUrl,
    url,
  ]);

  if (!resolvedUrl) {
    if (loadFailed && fallback) {
      return fallback;
    }

    return (
      <span
        className={className}
        aria-hidden={ariaHidden || undefined}
        aria-label={!ariaHidden ? (ariaLabel ?? alt) || undefined : undefined}
        role={!ariaHidden && (ariaLabel || alt) ? "img" : undefined}
        data-media-state={loadFailed ? "error" : "loading"}
      />
    );
  }

  if (kind === "video") {
    return (
      <video
        src={resolvedUrl}
        className={className}
        controls={controls}
        muted={muted}
        autoPlay={autoPlay}
        loop={loop}
        playsInline={playsInline}
        preload={preload}
        aria-hidden={ariaHidden || undefined}
        aria-label={!ariaHidden ? (ariaLabel ?? alt) || undefined : undefined}
        onError={markRemoteMediaFailed}
      />
    );
  }

  return (
    // eslint-disable-next-line @next/next/no-img-element -- Signed/local template media stays behind blob URLs.
    <img
      src={resolvedUrl}
      alt={alt}
      className={className}
      width={width}
      height={height}
      loading={loading}
      aria-hidden={ariaHidden || undefined}
      referrerPolicy="no-referrer"
      onError={markRemoteMediaFailed}
    />
  );
}

function isUnsafeMediaHost(hostname: string): boolean {
  return isUnsafeAdminMediaHost(hostname);
}
