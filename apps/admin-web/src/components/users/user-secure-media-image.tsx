"use client";

import { type ReactNode, useEffect, useMemo, useState } from "react";

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
  const failedToLoad = Boolean(imageUrl && mediaState.sourceUrl === imageUrl && mediaState.failed);
  const objectUrl = !failedToLoad
    ? (localObjectUrl ?? (imageUrl && mediaState.sourceUrl === imageUrl ? mediaState.objectUrl : null))
    : null;

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
      if (createdObjectUrl) {
        URL.revokeObjectURL(createdObjectUrl);
      }
    };
  }, [imageUrl, localObjectUrl, logEvent]);

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
          setMediaState({ sourceUrl: imageUrl, objectUrl: null, failed: true });
        }
      }}
    />
  );
}
