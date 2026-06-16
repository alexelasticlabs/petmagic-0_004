"use client";

import { useEffect, useRef, useState } from "react";

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

function shouldUseDirectMediaUrl(url: string) {
  if (typeof globalThis.location === "undefined") {
    return false;
  }

  try {
    const candidate = new URL(url, globalThis.location.href);
    return candidate.origin !== globalThis.location.origin;
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
  onLoadFailed,
  logContext,
}: TemplateSecureMediaProps) {
  const localObjectUrl = isLocalObjectUrl(url) ? url : null;
  const directMediaUrl = !localObjectUrl && shouldUseDirectMediaUrl(url) ? url : null;
  const [remoteMedia, setRemoteMedia] = useState<{
    sourceUrl: string;
    objectUrl: string | null;
    failed: boolean;
  }>({ sourceUrl: "", objectUrl: null, failed: false });
  const resolvedUrl =
    localObjectUrl ?? directMediaUrl ?? (remoteMedia.sourceUrl === url ? remoteMedia.objectUrl : null);
  const loadFailed =
    !localObjectUrl && !directMediaUrl && remoteMedia.sourceUrl === url && remoteMedia.failed;
  const onLoadFailedRef = useRef(onLoadFailed);

  useEffect(() => {
    onLoadFailedRef.current = onLoadFailed;
  }, [onLoadFailed]);

  useEffect(() => {
    if (localObjectUrl || directMediaUrl) {
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
          clientLogger.warn("templates.secure_media_fetch_failed", {
            templateId: formatTemplateMediaLogText(logContext?.templateId),
            contentType: formatTemplateMediaLogText(logContext?.contentType),
            surface: formatTemplateMediaLogText(logContext?.surface, 48),
            kind,
            status: response.status,
          });
          setRemoteMedia({ sourceUrl: url, objectUrl: null, failed: true });
          onLoadFailedRef.current?.();
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

        clientLogger.warn("templates.secure_media_fetch_failed", {
          templateId: formatTemplateMediaLogText(logContext?.templateId),
          contentType: formatTemplateMediaLogText(logContext?.contentType),
          surface: formatTemplateMediaLogText(logContext?.surface, 48),
          kind,
          errorName: getMediaFetchErrorName(error),
        });
        setRemoteMedia({ sourceUrl: url, objectUrl: null, failed: true });
        onLoadFailedRef.current?.();
      });

    return () => {
      isActive = false;
      controller.abort();
      if (createdObjectUrl) {
        URL.revokeObjectURL(createdObjectUrl);
      }
    };
  }, [
    directMediaUrl,
    kind,
    localObjectUrl,
    logContext?.contentType,
    logContext?.surface,
    logContext?.templateId,
    url,
  ]);

  if (!resolvedUrl) {
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
        aria-label={!ariaHidden ? ariaLabel : undefined}
        onError={onLoadFailed}
      />
    );
  }

  return (
    // eslint-disable-next-line @next/next/no-img-element -- Signed/local template media stays behind blob URLs; public cross-origin media can render directly.
    <img
      src={resolvedUrl}
      alt={alt}
      className={className}
      width={width}
      height={height}
      loading={loading}
      aria-hidden={ariaHidden || undefined}
      onError={onLoadFailed}
    />
  );
}
