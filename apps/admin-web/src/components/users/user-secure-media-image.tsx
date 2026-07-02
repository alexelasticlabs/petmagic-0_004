"use client";

import { type ReactNode, useCallback, useEffect, useMemo, useRef, useState } from "react";

import { clientLogger } from "@/lib/client-logger";
import { fetchWithTimeout } from "@/lib/fetch-with-timeout";

import {
  getUserMediaFetchErrorDetails,
  isLocalObjectUrl,
  resolveUserMediaUrl,
} from "./user-secure-media";

type UserSecureMediaImageProps = {
  alt: string;
  className?: string;
  fallback: ReactNode;
  logEvent: string;
  src?: string | null;
};

export function UserSecureMediaImage({
  alt,
  className,
  fallback,
  logEvent,
  src,
}: UserSecureMediaImageProps) {
  const imageUrl = useMemo(() => resolveUserMediaUrl(src), [src]);
  const localObjectUrl = imageUrl && isLocalObjectUrl(imageUrl) ? imageUrl : null;
  const [mediaState, setMediaState] = useState<{
    sourceUrl: string;
    objectUrl: string | null;
    failed: boolean;
  }>({ sourceUrl: "", objectUrl: null, failed: false });
  const activeObjectUrlRef = useRef<string | null>(null);
  const failedToLoad = Boolean(imageUrl && mediaState.sourceUrl === imageUrl && mediaState.failed);
  const objectUrl = !failedToLoad
    ? (localObjectUrl ??
      (imageUrl && mediaState.sourceUrl === imageUrl ? mediaState.objectUrl : null))
    : null;
  const revokeActiveObjectUrl = useCallback(() => {
    if (!activeObjectUrlRef.current) {
      return;
    }

    URL.revokeObjectURL(activeObjectUrlRef.current);
    activeObjectUrlRef.current = null;
  }, []);

  useEffect(() => {
    if (!imageUrl || localObjectUrl) {
      return;
    }

    const controller = new AbortController();
    let createdObjectUrl: string | null = null;
    let isActive = true;

    void fetchWithTimeout(imageUrl, { credentials: "include", signal: controller.signal })
      .then(async (response) => {
        if (!isActive) {
          return;
        }

        if (!response.ok) {
          clientLogger.warn(logEvent, { status: response.status });
          setMediaState({ sourceUrl: imageUrl, objectUrl: null, failed: true });
          return;
        }

        const blob = await response.blob();
        if (!isActive) {
          return;
        }

        createdObjectUrl = URL.createObjectURL(blob);
        revokeActiveObjectUrl();
        activeObjectUrlRef.current = createdObjectUrl;
        setMediaState({ sourceUrl: imageUrl, objectUrl: createdObjectUrl, failed: false });
      })
      .catch((error) => {
        if (controller.signal.aborted || !isActive) {
          return;
        }

        clientLogger.warn(logEvent, getUserMediaFetchErrorDetails(error));
        setMediaState({ sourceUrl: imageUrl, objectUrl: null, failed: true });
      });

    return () => {
      isActive = false;
      controller.abort();
      if (createdObjectUrl && activeObjectUrlRef.current === createdObjectUrl) {
        revokeActiveObjectUrl();
      }
    };
  }, [imageUrl, localObjectUrl, logEvent, revokeActiveObjectUrl]);

  if (!objectUrl || failedToLoad) {
    return <>{fallback}</>;
  }

  return (
    // eslint-disable-next-line @next/next/no-img-element -- Media URLs may be signed; render only fetched blob URLs in the DOM.
    <img
      src={objectUrl}
      alt={alt}
      className={className}
      onError={() => {
        if (imageUrl) {
          revokeActiveObjectUrl();
          setMediaState({ sourceUrl: imageUrl, objectUrl: null, failed: true });
        }
      }}
    />
  );
}
