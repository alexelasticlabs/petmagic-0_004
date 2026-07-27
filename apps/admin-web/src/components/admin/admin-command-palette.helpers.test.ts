import { describe, expect, it } from "vitest";

import {
  ADMIN_COMMAND_USER_RESULT_LIMIT,
  ADMIN_COMMAND_USER_SEARCH_DEBOUNCE_MS,
  buildAdminCommandPaletteResults,
  canSearchAdminCommandUsers,
  getAdminCommandPaletteOptionId,
  getNextAdminCommandPaletteIndex,
  normalizeAdminCommandUserSearch,
} from "@/components/admin/admin-command-palette.helpers";
import type { AdminCommandItem } from "@/lib/admin-navigation";
import type { UserListItem } from "@/lib/api-client";

const navigationItems: AdminCommandItem[] = [
  {
    type: "link",
    key: "users",
    href: "/ru/users",
    label: "Пользователи",
  },
  {
    type: "link",
    key: "template-analytics",
    href: "/ru/templates/analytics",
    label: "Аналитика",
    groupLabel: "Шаблоны",
  },
];

function makeUser(userId: string, overrides: Partial<UserListItem> = {}): UserListItem {
  return {
    userId,
    email: `${userId}@example.com`,
    displayName: `User ${userId}`,
    isPremium: false,
    isActive: true,
    emailConfirmed: true,
    roles: ["User"],
    createdAtUtc: "2026-07-26T00:00:00Z",
    ...overrides,
  };
}

describe("admin-command-palette helpers", () => {
  it("enables trimmed user search only for admins after two characters", () => {
    expect(ADMIN_COMMAND_USER_SEARCH_DEBOUNCE_MS).toBeGreaterThanOrEqual(250);
    expect(ADMIN_COMMAND_USER_SEARCH_DEBOUNCE_MS).toBeLessThanOrEqual(300);
    expect(normalizeAdminCommandUserSearch("  alice  ")).toBe("alice");
    expect(canSearchAdminCommandUsers(["Admin"], " a ")).toBe(false);
    expect(canSearchAdminCommandUsers(["Admin"], " al ")).toBe(true);
    expect(canSearchAdminCommandUsers(["Moderator"], "alice")).toBe(false);
    expect(canSearchAdminCommandUsers([], "alice")).toBe(false);
  });

  it("keeps navigation first and caps deduplicated user results at six", () => {
    const users = [
      makeUser("user-1"),
      makeUser("user-1"),
      makeUser("user-2"),
      makeUser("user-3"),
      makeUser("user-4"),
      makeUser("user-5"),
      makeUser("user-6"),
      makeUser("user-7"),
    ];

    const results = buildAdminCommandPaletteResults(navigationItems, users, "ru");

    expect(results.slice(0, navigationItems.length).map((result) => result.kind)).toEqual([
      "navigation",
      "navigation",
    ]);
    expect(results.filter((result) => result.kind === "user")).toHaveLength(
      ADMIN_COMMAND_USER_RESULT_LIMIT
    );
    expect(results.map((result) => result.key)).toEqual([
      "navigation:users",
      "navigation:template-analytics",
      "user:user-1",
      "user:user-2",
      "user:user-3",
      "user:user-4",
      "user:user-5",
      "user:user-6",
    ]);
  });

  it("sanitizes display labels, masks email, shortens IDs, and builds locale routes", () => {
    const [result] = buildAdminCommandPaletteResults(
      [],
      [
        makeUser("user/id-123456", {
          email: "alice@example.com",
          displayName: "Alice token=raw-secret alice@example.com",
        }),
      ],
      "en"
    );

    expect(result).toEqual({
      kind: "user",
      key: "user:user/id-123456",
      href: "/en/users/user%2Fid-123456",
      label: "Alice token=[redacted] al***@e***.com",
      secondaryLabel: "al***@e***.com · ID user/id-",
    });
    expect(JSON.stringify(result)).not.toContain("alice@example.com");
    expect(JSON.stringify(result)).not.toContain("raw-secret");
  });

  it("avoids repeating the masked email when it is the display fallback", () => {
    const [result] = buildAdminCommandPaletteResults(
      [],
      [makeUser("user-123456", { email: "nora@example.com", displayName: "" })],
      "ru"
    );

    expect(result.label).toBe("no***@e***.com");
    expect(result.secondaryLabel).toBe("ID user-123");
  });

  it("moves through the merged result order with deterministic wrapping", () => {
    expect(getNextAdminCommandPaletteIndex(0, 1, 4)).toBe(1);
    expect(getNextAdminCommandPaletteIndex(3, 1, 4)).toBe(0);
    expect(getNextAdminCommandPaletteIndex(0, -1, 4)).toBe(3);
    expect(getNextAdminCommandPaletteIndex(9, 1, 4)).toBe(0);
    expect(getNextAdminCommandPaletteIndex(9, -1, 4)).toBe(3);
    expect(getNextAdminCommandPaletteIndex(0, 1, 0)).toBe(0);
  });

  it("gives replacements at the same index distinct stable option IDs", () => {
    expect(getAdminCommandPaletteOptionId(":palette:", "navigation:users")).toBe(
      ":palette:-option-navigation%3Ausers"
    );
    expect(getAdminCommandPaletteOptionId(":palette:", "user:user-123")).toBe(
      ":palette:-option-user%3Auser-123"
    );
    expect(getAdminCommandPaletteOptionId(":palette:", "navigation:users")).not.toBe(
      getAdminCommandPaletteOptionId(":palette:", "user:user-123")
    );
  });
});
