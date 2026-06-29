"use client";

import { useEffect, useMemo, useState } from "react";

import styles from "@/components/users/user-avatar.module.css";
import type { UserAvatar } from "@/lib/api-client";
import { clientLogger } from "@/lib/client-logger";
import { fetchWithTimeout } from "@/lib/fetch-with-timeout";

import {
  getUserMediaFetchErrorDetails,
  isLocalObjectUrl,
  resolveUserMediaUrl,
} from "./user-secure-media";

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

export function UserAvatarView({ avatar, label, fallbackLabel, size = "sm" }: UserAvatarProps) {
  const initials = getInitials(fallbackLabel);
  const imageUrl = useMemo(() => resolveUserMediaUrl(avatar?.url), [avatar?.url]);
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

        clientLogger.warn("users.avatar_fetch_failed", getUserMediaFetchErrorDetails(error));
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
