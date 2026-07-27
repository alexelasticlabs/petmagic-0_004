import type { AdminCommandItem } from "@/lib/admin-navigation";
import type { UserListItem } from "@/lib/api-client";
import type { Locale } from "@/lib/i18n";
import { getAdminUserDisplayName, maskEmail, shortIdentifier } from "@/lib/sensitive-display";

export const ADMIN_COMMAND_USER_SEARCH_DEBOUNCE_MS = 275;
export const ADMIN_COMMAND_USER_SEARCH_MIN_LENGTH = 2;
export const ADMIN_COMMAND_USER_RESULT_LIMIT = 6;

export type AdminCommandPaletteResult = {
  kind: "navigation" | "user";
  key: string;
  href: string;
  label: string;
  secondaryLabel?: string;
};

export function normalizeAdminCommandUserSearch(query: string): string {
  return query.trim();
}

export function canSearchAdminCommandUsers(roles: readonly string[], query: string): boolean {
  return (
    roles.includes("Admin") &&
    normalizeAdminCommandUserSearch(query).length >= ADMIN_COMMAND_USER_SEARCH_MIN_LENGTH
  );
}

export function buildAdminCommandPaletteResults(
  navigationItems: readonly AdminCommandItem[],
  users: readonly UserListItem[],
  locale: Locale
): AdminCommandPaletteResult[] {
  const navigationResults = navigationItems.map<AdminCommandPaletteResult>((item) => ({
    kind: "navigation",
    key: `navigation:${item.key}`,
    href: item.href,
    label: item.label,
    secondaryLabel: item.groupLabel,
  }));
  const seenUserIds = new Set<string>();
  const userResults: AdminCommandPaletteResult[] = [];

  for (const user of users) {
    const userId = user.userId.trim();
    if (!userId || seenUserIds.has(userId)) {
      continue;
    }

    const label = getAdminUserDisplayName(user);
    const maskedEmail = maskEmail(user.email);
    const shortUserId = shortIdentifier(userId);
    const secondaryLabel =
      label === maskedEmail ? `ID ${shortUserId}` : `${maskedEmail} · ID ${shortUserId}`;

    seenUserIds.add(userId);
    userResults.push({
      kind: "user",
      key: `user:${userId}`,
      href: `/${locale}/users/${encodeURIComponent(userId)}`,
      label,
      secondaryLabel,
    });

    if (userResults.length === ADMIN_COMMAND_USER_RESULT_LIMIT) {
      break;
    }
  }

  return [...navigationResults, ...userResults];
}

export function getNextAdminCommandPaletteIndex(
  currentIndex: number,
  direction: 1 | -1,
  resultCount: number
): number {
  if (resultCount <= 0) {
    return 0;
  }

  const normalizedIndex =
    currentIndex >= 0 && currentIndex < resultCount
      ? currentIndex
      : direction === 1
        ? resultCount - 1
        : 0;

  return (normalizedIndex + direction + resultCount) % resultCount;
}

export function getAdminCommandPaletteOptionId(resultsId: string, resultKey: string): string {
  return `${resultsId}-option-${encodeURIComponent(resultKey)}`;
}
