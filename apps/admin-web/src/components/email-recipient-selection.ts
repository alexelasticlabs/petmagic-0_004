import type { UserListItem } from "@/lib/api-client";
import { maskEmail, sanitizeSensitiveText } from "@/lib/sensitive-display";

export type SelectedUserEntity = {
  id: string;
  label: string;
  eligible: boolean;
};

export const selectionStoragePrefix = "petmagic.admin.users.email-selection:v1";
export const maximumPersistedSelectionCount = 500;

export function toSelectedUserEntity(user: UserListItem): SelectedUserEntity {
  return {
    id: user.userId,
    label: sanitizeSensitiveText(user.displayName?.trim() || maskEmail(user.email), 96),
    eligible: user.isActive && user.emailConfirmed,
  };
}

export function readPersistedSelection(storageKey: string): Map<string, SelectedUserEntity> {
  try {
    const parsed = JSON.parse(window.localStorage.getItem(storageKey) ?? "[]") as unknown;
    if (!Array.isArray(parsed)) return new Map();
    const selected = new Map<string, SelectedUserEntity>();
    for (const value of parsed.slice(0, maximumPersistedSelectionCount)) {
      if (!value || typeof value !== "object") continue;
      const item = value as Partial<SelectedUserEntity>;
      const id = typeof item.id === "string" ? item.id.trim().slice(0, 100) : "";
      if (!id) continue;
      selected.set(id, {
        id,
        label: sanitizeSensitiveText(typeof item.label === "string" ? item.label : "—", 96),
        eligible: item.eligible === true,
      });
    }
    return selected;
  } catch {
    return new Map();
  }
}
