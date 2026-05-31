"use client";

import Image from "next/image";
import { useMemo, useState } from "react";

import styles from "@/components/users/user-avatar.module.css";
import type { UserAvatar } from "@/lib/api-client";

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

function getApiBaseUrl(): string {
  return process.env.NEXT_PUBLIC_API_BASE_URL ?? "http://localhost:5000";
}

function resolveAvatarUrl(rawUrl?: string | null): string | null {
  const normalizedRaw = rawUrl?.trim();
  if (!normalizedRaw) {
    return null;
  }

  const apiBase = getApiBaseUrl();
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

export function UserAvatarView({ avatar, label, fallbackLabel, size = "sm" }: UserAvatarProps) {
  const initials = getInitials(fallbackLabel);
  const [failedToLoad, setFailedToLoad] = useState(false);
  const imageUrl = useMemo(() => resolveAvatarUrl(avatar?.url), [avatar?.url]);

  return (
    <span
      className={`${styles.avatar} ${size === "lg" ? styles.avatarLg : styles.avatarSm}`}
      aria-label={label}
    >
      {imageUrl && !failedToLoad ? (
        <Image
          src={imageUrl}
          alt={label}
          className={styles.image}
          fill
          sizes={size === "lg" ? "88px" : "40px"}
          unoptimized
          onError={() => setFailedToLoad(true)}
        />
      ) : (
        <span className={styles.initials}>{initials}</span>
      )}
    </span>
  );
}
