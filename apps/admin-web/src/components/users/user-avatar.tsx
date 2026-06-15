"use client";

import { useEffect, useMemo, useState } from "react";

import styles from "@/components/users/user-avatar.module.css";
import { getAdminPublicApiBaseUrl } from "@/lib/admin-api-base-url";
import type { UserAvatar } from "@/lib/api-client";
import { clientLogger } from "@/lib/client-logger";
import { fetchWithTimeout } from "@/lib/fetch-with-timeout";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

type UserAvatarProps = {
  avatar?: UserAvatar | null;
  label: string;
  fallbackLabel: string;
  size?: "sm" | "lg";
};

function getInitials(label: string) {
  const parts = label.trim().split(/\s+/).filter(Boolean).slice(0, 2);

  if (!parts.length) {
    return "?";
  }

  return parts.map((part) => part[0]?.toUpperCase() ?? "").join("");
}

function getAvatarFetchErrorDetails(error: unknown) {
  return {
    errorName: error instanceof Error ? error.name : "UnknownError",
    errorDigest:
      error && typeof error === "object" && "digest" in error
        ? sanitizeSensitiveText(String((error as { digest?: unknown }).digest ?? ""), 80)
        : undefined,
  };
}

function resolveAvatarUrl(rawUrl?: string | null): string | null {
  const normalizedRaw = rawUrl?.trim();
  if (!normalizedRaw) {
    return null;
  }

  const apiBase = getAdminPublicApiBaseUrl();
  const apiOrigin = new URL(apiBase).origin;

  if (normalizedRaw.startsWith("/")) {
    return `${apiOrigin}${normalizedRaw}`;
  }

  try {
    const parsed = new URL(normalizedRaw);
    if (parsed.hostname === "localhost" || parsed.hostname === "127.0.0.1") {
      return `${apiOrigin}${parsed.pathname}${parsed.search}${parsed.hash}`;
    }

    return parsed.toString();
  } catch {
    return null;
  }
}

function isLocalObjectUrl(url: string) {
  return url.startsWith("blob:") || url.startsWith("data:");
}

export function UserAvatarView({ avatar, label, fallbackLabel, size = "sm" }: UserAvatarProps) {
  const initials = getInitials(fallbackLabel);
  const imageUrl = useMemo(() => resolveAvatarUrl(avatar?.url), [avatar?.url]);
  const localObjectUrl = imageUrl && isLocalObjectUrl(imageUrl) ? imageUrl : null;
  const [avatarMedia, setAvatarMedia] = useState<{
    sourceUrl: string;
    objectUrl: string | null;
    failed: boolean;
  }>({ sourceUrl: "", objectUrl: null, failed: false });
  const failedToLoad = Boolean(
    imageUrl && avatarMedia.sourceUrl === imageUrl && avatarMedia.failed
  );
  const objectUrl = !failedToLoad
    ? (localObjectUrl ?? (imageUrl && avatarMedia.sourceUrl === imageUrl ? avatarMedia.objectUrl : null))
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
          clientLogger.warn("users.avatar_fetch_failed", {
            status: response.status,
          });
          setAvatarMedia({ sourceUrl: imageUrl, objectUrl: null, failed: true });
          return;
        }

        const blob = await response.blob();
        if (!isActive) {
          return;
        }

        createdObjectUrl = URL.createObjectURL(blob);
        setAvatarMedia({ sourceUrl: imageUrl, objectUrl: createdObjectUrl, failed: false });
      })
      .catch((error) => {
        if (controller.signal.aborted || !isActive) {
          return;
        }

        clientLogger.warn("users.avatar_fetch_failed", getAvatarFetchErrorDetails(error));
        setAvatarMedia({ sourceUrl: imageUrl, objectUrl: null, failed: true });
      });

    return () => {
      isActive = false;
      controller.abort();
      if (createdObjectUrl) {
        URL.revokeObjectURL(createdObjectUrl);
      }
    };
  }, [imageUrl, localObjectUrl]);

  return (
    <span
      className={`${styles.avatar} ${size === "lg" ? styles.avatarLg : styles.avatarSm}`}
      aria-label={label}
    >
      {objectUrl && !failedToLoad ? (
        // eslint-disable-next-line @next/next/no-img-element -- Avatar URLs may be signed; render only fetched blob URLs in the DOM.
        <img
          src={objectUrl}
          alt={label}
          className={styles.image}
          onError={() => {
            if (imageUrl) {
              setAvatarMedia({ sourceUrl: imageUrl, objectUrl: null, failed: true });
            }
          }}
        />
      ) : (
        <span className={styles.initials}>{initials}</span>
      )}
    </span>
  );
}
