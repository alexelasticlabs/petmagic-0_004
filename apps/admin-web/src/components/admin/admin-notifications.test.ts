import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

import {
  buildAdminNotificationDedupeKey,
  createAdminNotificationId,
  getAdminNotificationStorageKey,
  sanitizeAdminNotificationDedupeKey,
  sanitizeAdminNotificationSource,
  sanitizeAdminNotificationText,
} from "@/components/admin/admin-notifications";

const adminTopbarPath = fileURLToPath(new URL("./admin-topbar.tsx", import.meta.url));
const adminChromeContentPath = fileURLToPath(new URL("./admin-chrome.content.ts", import.meta.url));
const adminShellStylesPath = fileURLToPath(new URL("./admin-shell.module.css", import.meta.url));
const adminNotificationsPath = fileURLToPath(new URL("./admin-notifications.tsx", import.meta.url));

describe("admin notification sanitization", () => {
  it("uses an isolated persisted storage key for every admin user", () => {
    const firstAdminKey = getAdminNotificationStorageKey("admin/one");
    const secondAdminKey = getAdminNotificationStorageKey("admin-two");

    expect(firstAdminKey).toBe("petmagic.admin.notifications.v2:admin%2Fone");
    expect(secondAdminKey).toBe("petmagic.admin.notifications.v2:admin-two");
    expect(firstAdminKey).not.toBe(secondAdminKey);
    expect(getAdminNotificationStorageKey("   ")).toBeNull();
  });

  it("masks sensitive values before notifications are persisted", () => {
    const sanitized = sanitizeAdminNotificationText(
      [
        "Failed for alice@example.com",
        "https://storage.example.com/file.png?X-Amz-Signature=secret",
        "Authorization: Bearer eyJhbGciOi.fake.payload",
        "receipt=ios-receipt-data",
        "sk_live_1234567890",
        "+1 (555) 111-2233",
      ].join(" "),
      500
    );

    expect(sanitized).toContain("al***@e***.com");
    expect(sanitized).toContain("https://storage.example.com/***");
    expect(sanitized).toContain("Authorization=[redacted]");
    expect(sanitized).toContain("receipt=[redacted]");
    expect(sanitized).toContain("[redacted-secret]");
    expect(sanitized).toContain("15***33");
    expect(sanitized).not.toContain("alice@example.com");
    expect(sanitized).not.toContain("X-Amz-Signature=secret");
    expect(sanitized).not.toContain("ios-receipt-data");
    expect(sanitized).not.toContain("sk_live_1234567890");
  });

  it("collapses and limits notification text length", () => {
    const sanitized = sanitizeAdminNotificationText(`A\n\n${"x".repeat(80)}`, 24);

    expect(sanitized).toHaveLength(24);
    expect(sanitized).toBe(`A ${"x".repeat(19)}...`);
  });

  it("does not keep sensitive toast content in notification dedupe keys", () => {
    const key = buildAdminNotificationDedupeKey(
      "templates token=source-secret receipt=source-receipt https://cdn.example.com/source?sig=source",
      "error",
      "Failed for alice@example.com https://cdn.example.com/a?sig=secret receipt=ios-secret token=raw-secret",
      "/en/templates?debug=1"
    );

    expect(key).toContain("al***@e***.com");
    expect(key).toContain("https://cdn.example.com/***");
    expect(key).toContain("receipt=[redacted]");
    expect(key).toContain("token=[redacted]");
    expect(key).not.toContain("alice@example.com");
    expect(key).not.toContain("source-secret");
    expect(key).not.toContain("source-receipt");
    expect(key).not.toContain("sig=source");
    expect(key).not.toContain("sig=secret");
    expect(key).not.toContain("ios-secret");
    expect(key).not.toContain("raw-secret");
    expect(key).not.toContain("debug=1");
  });

  it("sanitizes caller-provided notification dedupe keys before retaining them", () => {
    const key = sanitizeAdminNotificationDedupeKey(
      [
        "support:conversation-1",
        "https://cdn.example.com/file.png?X-Amz-Signature=secret",
        "receipt=ios-secret",
        "token=raw-secret",
        "x".repeat(500),
      ].join(" ")
    );

    expect(key.length).toBeLessThanOrEqual(360);
    expect(key).toContain("https://cdn.example.com/***");
    expect(key).toContain("receipt=[redacted]");
    expect(key).toContain("token=[redacted]");
    expect(key).not.toContain("X-Amz-Signature=secret");
    expect(key).not.toContain("ios-secret");
    expect(key).not.toContain("raw-secret");
  });

  it("sanitizes persisted notification source labels without accepting blank sources", () => {
    const source = sanitizeAdminNotificationSource(
      " support token=raw-source receipt=raw-receipt https://cdn.example.com/source?sig=raw "
    );

    expect(source).toContain("token=[redacted]");
    expect(source).toContain("receipt=[redacted]");
    expect(source).toContain("https://cdn.example.com/***");
    expect(source).not.toContain("raw-source");
    expect(source).not.toContain("raw-receipt");
    expect(source).not.toContain("sig=raw");
    expect(sanitizeAdminNotificationSource("   ")).toBe("");
  });

  it("drops oversized notification hrefs before persistence and dedupe", () => {
    const longPath = `/en/support/${"x".repeat(320)}`;
    const key = buildAdminNotificationDedupeKey("support", "info", "New support item", longPath);

    expect(key).not.toContain(longPath);
    expect(key).not.toContain("x".repeat(240));
  });

  it("creates local notification ids without Math.random", () => {
    const source = readFileSync(adminNotificationsPath, "utf8");
    const id = createAdminNotificationId(123456);

    expect(id).toMatch(/^123456-/);
    expect(source).toContain("function createAdminNotificationId");
    expect(source).toContain("crypto.randomUUID");
    expect(source).toContain("crypto.getRandomValues");
    expect(source).toContain("id: createAdminNotificationId(now)");
    expect(source).not.toContain("Math.random");
  });

  it("avoids notification state updates when read actions do not change data", () => {
    const source = readFileSync(adminNotificationsPath, "utf8");

    expect(source).toContain("let didChange = false;");
    expect(source).toContain("return didChange ? { ...current, items: next } : current;");
    expect(source).toContain("if (item.id !== notificationId || item.read)");
    expect(source).toContain("if (item.category !== category || item.read)");
    expect(source).toContain("if (current.items.every((item) => !item.read))");
    expect(source).toContain(
      "return { ...current, items: current.items.filter((item) => !item.read) };"
    );
    expect(source).not.toContain(
      "current.map((item) => (item.id === notificationId ? { ...item, read: true } : item))"
    );
  });

  it("logs notification storage failures without retaining raw Error objects", () => {
    const source = readFileSync(adminNotificationsPath, "utf8");

    expect(source).toContain("function getAdminNotificationStorageErrorDetails(error: unknown)");
    expect(source).toContain(
      "function removeStoredAdminNotifications(\n  storageKey: string | null,\n  storageFailureEvent: string\n)"
    );
    expect(source).toContain(
      "const storageKey = getAdminNotificationStorageKey(session?.user.userId);"
    );
    expect(source).toContain("notificationState, setNotificationState");
    expect(source).toContain("useLayoutEffect(() => {");
    expect(source).toContain("previousStorageKeyRef.current === storageKey");
    expect(source).toContain("dedupeMapRef.current.clear();");
    expect(source).toContain("notificationState.storageKey !== storageKey");
    expect(source.indexOf("notificationState.storageKey !== storageKey")).toBeLessThan(
      source.indexOf("window.localStorage.setItem(storageKey")
    );
    expect(source).toContain("LEGACY_ADMIN_NOTIFICATIONS_STORAGE_KEY");
    expect(source).toContain('errorName: error instanceof Error ? error.name : "UnknownError"');
    expect(source).toContain("clientLogger.warn(storageFailureEvent,");
    expect(source).toContain("getAdminNotificationStorageErrorDetails(error)");
    expect(source).toContain(
      'clientLogger.warn(\n      "admin.notifications_hydrate_failed",\n      getAdminNotificationStorageErrorDetails(error)\n    );'
    );
    expect(source).toContain(
      'clientLogger.warn(\n        "admin.notifications_persist_failed",\n        getAdminNotificationStorageErrorDetails(error)\n      );'
    );
    expect(source).not.toContain(
      'clientLogger.warn("admin.notifications_hydrate_failed", { error });'
    );
    expect(source).not.toContain(
      'clientLogger.warn("admin.notifications_persist_failed", { error });'
    );
    expect(source).not.toContain(
      'catch (error) {\n    clientLogger.warn(\n      "admin.notifications_hydrate_failed",\n      getAdminNotificationStorageErrorDetails(error)\n    );\n    window.localStorage.removeItem(storageKey);'
    );
  });

  it("removes empty persisted notification state instead of storing an empty list", () => {
    const source = readFileSync(adminNotificationsPath, "utf8");

    expect(source).toContain("if (items.length === 0)");
    expect(source.indexOf('"admin.notifications_empty_persist_cleanup_failed"')).toBeLessThan(
      source.indexOf("window.localStorage.setItem(storageKey")
    );
  });

  it("cleans malformed or fully stale notification storage through safe cleanup", () => {
    const source = readFileSync(adminNotificationsPath, "utf8");

    expect(source).toContain('"admin.notifications_invalid_storage_cleanup_failed"');
    expect(source).toContain('"admin.notifications_empty_hydration_cleanup_failed"');
    expect(source).toContain(
      'removeStoredAdminNotifications(storageKey, "admin.notifications_hydrate_cleanup_failed");'
    );
    expect(source).not.toContain("if (!Array.isArray(parsed)) {\n      return [];\n    }");
  });

  it("sanitizes notification text again at the topbar render boundary", () => {
    const source = readFileSync(adminTopbarPath, "utf8");
    const contentSource = readFileSync(adminChromeContentPath, "utf8");

    expect(source).toContain("sanitizeAdminNotificationText,");
    expect(source).toContain("const safeNotificationTitle = sanitizeAdminNotificationText(");
    expect(source).toContain("const safeNotificationMessage = sanitizeAdminNotificationText(");
    expect(source).toContain("const copy = useMemo(() => getAdminChromeCopy(locale), [locale]);");
    expect(source).toContain("{copy.topbar.pinned}");
    expect(contentSource).toContain('pinned: "Закреплено"');
    expect(contentSource).toContain('pinned: "Pinned"');
    expect(source).toContain("{safeNotificationTitle}");
    expect(source).toContain("{safeNotificationMessage}");
    expect(source).not.toContain('{locale === "ru" ? "Закреплено" : "Pinned"}');
    expect(source).not.toContain(
      "<strong className={styles.notificationCardTitle}>{item.title}</strong>"
    );
    expect(source).not.toContain(
      "<p className={styles.notificationCardMessage}>{item.message}</p>"
    );
  });

  it("keeps the topbar notification dialog keyboard reachable", () => {
    const source = readFileSync(adminTopbarPath, "utf8");
    const contentSource = readFileSync(adminChromeContentPath, "utf8");

    expect(source).toContain("useCallback, useEffect, useId, useMemo, useRef, useState");
    expect(source).toContain(
      "const notificationTriggerRef = useRef<HTMLButtonElement | null>(null);"
    );
    expect(source).toContain("const notificationPanelRef = useRef<HTMLDivElement | null>(null);");
    expect(source).toContain("const previousNotificationPathnameRef = useRef(pathname);");
    expect(source).toContain("const notificationPanelId = useId();");
    expect(source).toContain("const notificationPanelTitleId = useId();");
    expect(source).toContain("const closeNotificationPanel = useCallback(");
    expect(source).toContain("if (previousNotificationPathnameRef.current === pathname)");
    expect(source).toContain("previousNotificationPathnameRef.current = pathname;");
    expect(source).toContain("setNotificationPanelPathname(null);");
    expect(source).toContain("}, [pathname]);");
    expect(source).toContain("notificationPanelRef.current?.focus();");
    expect(source).toContain("closeNotificationPanel({ restoreFocus: true });");
    expect(source).toContain("ref={notificationTriggerRef}");
    expect(source).toContain(
      "aria-controls={isNotificationsOpen ? notificationPanelId : undefined}"
    );
    expect(source).toContain("const notificationTriggerLabel =");
    expect(source).toContain("copy.topbar.notificationTriggerLabel(isNotificationsOpen)");
    expect(contentSource).toContain(
      'notificationTriggerLabel: (open) => (open ? "Закрыть уведомления" : "Открыть уведомления")'
    );
    expect(contentSource).toContain(
      'notificationTriggerLabel: (open) => (open ? "Close notifications" : "Open notifications")'
    );
    expect(source).toContain("aria-label={notificationTriggerLabel}");
    expect(source).toContain("title={notificationTriggerLabel}");
    expect(source).toContain("id={notificationPanelId}");
    expect(source).toContain("ref={notificationPanelRef}");
    expect(source).toContain("aria-labelledby={notificationPanelTitleId}");
    expect(source).toContain("tabIndex={-1}");
    expect(source).toContain("id={notificationPanelTitleId}");
    expect(source).toContain("const notificationFiltersLabel =");
    expect(source).toContain("copy.topbar.notificationFiltersLabel");
    expect(contentSource).toContain('notificationFiltersLabel: "Фильтры уведомлений"');
    expect(contentSource).toContain('notificationFiltersLabel: "Notification filters"');
    expect(source).toContain('role="toolbar"');
    expect(source).toContain("aria-label={notificationFiltersLabel}");
    expect(source).toContain("aria-pressed={notificationFilter === filterOption.value}");
  });

  it("counts topbar attention without dropping non-support unread notifications", () => {
    const source = readFileSync(adminTopbarPath, "utf8");

    expect(source).toContain(
      'const unreadSupportNotificationCount = items.filter(\n    (item) => item.category === "support" && !item.read\n  ).length;'
    );
    expect(source).toContain(
      "const unreadNonSupportNotificationCount = unreadCount - unreadSupportNotificationCount;"
    );
    expect(source).toContain(
      "unreadNonSupportNotificationCount +\n    Math.max(unreadSupportNotificationCount, supportUnreadCount)"
    );
    expect(source).not.toContain(
      "const totalAttentionCount = Math.max(unreadCount, supportUnreadCount);"
    );
  });

  it("keeps the topbar notification dialog inside narrow viewports", () => {
    const source = readFileSync(adminShellStylesPath, "utf8");

    expect(source).toContain("max-height: min(36rem, calc(100dvh - 5.6rem));");
    expect(source).toContain("overflow: hidden;");
    expect(source).toContain(".notificationPanel:focus-visible");
    expect(source).toContain("@media (max-width: 640px)");
    expect(source).toContain("position: fixed;");
    expect(source).toContain("right: 0.75rem;");
    expect(source).toContain("left: 0.75rem;");
    expect(source).toContain("max-height: calc(100dvh - 5.5rem);");
    expect(source).toContain(".notificationPanelHeader {\n    display: grid;");
    expect(source).toContain(".notificationFilters {\n    display: grid;");
    expect(source).toContain("grid-template-columns: repeat(2, minmax(0, 1fr));");
    expect(source).toContain("@media (max-width: 420px)");
    expect(source).toContain("grid-template-columns: minmax(0, 1fr);");
    expect(source).toContain(".notificationCardMeta {\n  display: flex;");
    expect(source).toContain("flex-wrap: wrap;");
    expect(source).toContain(".notificationCardTitle {\n  font-size: 0.86rem;");
    expect(source).toContain(".notificationCardMessage {\n  font-size: 0.79rem;");
    expect(source).toContain("overflow-wrap: anywhere;");
  });

  it("keeps sidebar notification badges theme-token based", () => {
    const source = readFileSync(adminShellStylesPath, "utf8");

    expect(source).toContain(".navBadge {");
    expect(source).toContain("background: var(--danger);");
    expect(source).toContain("color: var(--text-inverse);");
    expect(source).not.toContain("background: rgba(239, 68, 68, 0.88);");
    expect(source).not.toContain("color: #fff;");
  });

  it("keeps admin shell typography and chrome on theme tokens", () => {
    const source = readFileSync(adminShellStylesPath, "utf8");
    const nonZeroLetterSpacingRules = [...source.matchAll(/letter-spacing:\s*([^;]+);/g)]
      .map((match) => match[1]?.trim())
      .filter((value) => value !== "0");

    expect(source).toContain("letter-spacing: 0;");
    expect(source).not.toMatch(/#[0-9a-fA-F]{3,8}/);
    expect(source).not.toContain("rgba(");
    expect(source).not.toContain("radial-gradient");
    expect(nonZeroLetterSpacingRules).toEqual([]);
    expect(source).toContain(".topbarTitle {");
    expect(source).toContain(".topbarHeading {\n  min-width: 0;\n  flex: 1 1 0;");
    expect(source).toContain("text-overflow: ellipsis;");
    expect(source).toContain("white-space: nowrap;");
    expect(source).toContain("font-size: 1.16rem;");
    expect(source).toContain(".topbarTitle {\n    font-size: 0.98rem;");
    expect(source).not.toMatch(/font-size:\s*[^;]*vw/);
    expect(source).toContain("min-height: 100dvh;");
    expect(source).toContain("height: 100dvh;");
    expect(source).not.toContain("100vh");
  });
});
