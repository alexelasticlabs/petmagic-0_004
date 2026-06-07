"use client";

import { useEffect, useRef, useState } from "react";

import { clientLogger } from "@/lib/client-logger";
import { fetchWithTimeout } from "@/lib/fetch-with-timeout";

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
  const [remoteMedia, setRemoteMedia] = useState<{
    sourceUrl: string;
    objectUrl: string | null;
    failed: boolean;
  }>({ sourceUrl: "", objectUrl: null, failed: false });
  const objectUrl =
    localObjectUrl ?? (remoteMedia.sourceUrl === url ? remoteMedia.objectUrl : null);
  const loadFailed = !localObjectUrl && remoteMedia.sourceUrl === url && remoteMedia.failed;
  const onLoadFailedRef = useRef(onLoadFailed);

  useEffect(() => {
    onLoadFailedRef.current = onLoadFailed;
  }, [onLoadFailed]);

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
          clientLogger.warn("templates.secure_media_fetch_failed", {
            templateId: logContext?.templateId,
            contentType: logContext?.contentType,
            surface: logContext?.surface,
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
          templateId: logContext?.templateId,
          contentType: logContext?.contentType,
          surface: logContext?.surface,
          kind,
          error,
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
    kind,
    localObjectUrl,
    logContext?.contentType,
    logContext?.surface,
    logContext?.templateId,
    url,
  ]);

  if (!objectUrl) {
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
        src={objectUrl}
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
    // eslint-disable-next-line @next/next/no-img-element -- Template media URLs may be signed; render only fetched blob URLs in the DOM.
    <img
      src={objectUrl}
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
