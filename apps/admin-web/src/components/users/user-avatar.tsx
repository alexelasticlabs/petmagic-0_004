"use client";

import Image from "next/image";

import styles from "@/components/users/user-avatar.module.css";
import type { UserAvatar } from "@/lib/api-client";

type UserAvatarProps = {
  avatar?: UserAvatar | null;
  label: string;
  fallbackLabel: string;
  size?: "sm" | "lg";
};

function getInitials(label: string) {
  const parts = label
    .trim()
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2);

  if (!parts.length) {
    return "?";
  }

  return parts.map((part) => part[0]?.toUpperCase() ?? "").join("");
}

export function UserAvatarView({ avatar, label, fallbackLabel, size = "sm" }: UserAvatarProps) {
  const initials = getInitials(fallbackLabel);

  return (
    <span className={`${styles.avatar} ${size === "lg" ? styles.avatarLg : styles.avatarSm}`} aria-label={label}>
      {avatar?.url ? (
        <Image src={avatar.url} alt={label} className={styles.image} fill sizes={size === "lg" ? "88px" : "40px"} />
      ) : (
        <span className={styles.initials}>{initials}</span>
      )}
    </span>
  );
}
