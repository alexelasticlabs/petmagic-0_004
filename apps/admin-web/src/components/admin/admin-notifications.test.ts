import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

import {
  buildAdminNotificationDedupeKey,
  sanitizeAdminNotificationDedupeKey,
  sanitizeAdminNotificationSource,
  sanitizeAdminNotificationText,
} from "@/components/admin/admin-notifications";

const adminTopbarPath = fileURLToPath(new URL("./admin-topbar.tsx", import.meta.url));
const adminShellStylesPath = fileURLToPath(new URL("./admin-shell.module.css", import.meta.url));

describe("admin notification sanitization", () => {
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
    expect(sanitized).toContain("https://storage.example.com/file.png?***");
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
    expect(key).toContain("https://cdn.example.com/a?***");
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
    expect(key).toContain("https://cdn.example.com/file.png?***");
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
    expect(source).toContain("https://cdn.example.com/source?***");
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

  it("sanitizes notification text again at the topbar render boundary", () => {
    const source = readFileSync(adminTopbarPath, "utf8");

    expect(source).toContain("sanitizeAdminNotificationText,");
    expect(source).toContain("const safeNotificationTitle = sanitizeAdminNotificationText(");
    expect(source).toContain("const safeNotificationMessage = sanitizeAdminNotificationText(");
    expect(source).toContain('{locale === "ru" ? "Закреплено" : "Pinned"}');
    expect(source).toContain("{safeNotificationTitle}");
    expect(source).toContain("{safeNotificationMessage}");
    expect(source).not.toContain(
      '<strong className={styles.notificationCardTitle}>{item.title}</strong>'
    );
    expect(source).not.toContain(
      '<p className={styles.notificationCardMessage}>{item.message}</p>'
    );
  });

  it("keeps the topbar notification dialog keyboard reachable", () => {
    const source = readFileSync(adminTopbarPath, "utf8");

    expect(source).toContain("useCallback, useEffect, useId, useMemo, useRef, useState");
    expect(source).toContain("const notificationTriggerRef = useRef<HTMLButtonElement | null>(null);");
    expect(source).toContain("const notificationPanelRef = useRef<HTMLDivElement | null>(null);");
    expect(source).toContain("const notificationPanelId = useId();");
    expect(source).toContain("const notificationPanelTitleId = useId();");
    expect(source).toContain("const closeNotificationPanel = useCallback(");
    expect(source).toContain("notificationPanelRef.current?.focus();");
    expect(source).toContain("closeNotificationPanel({ restoreFocus: true });");
    expect(source).toContain("ref={notificationTriggerRef}");
    expect(source).toContain("aria-controls={isNotificationsOpen ? notificationPanelId : undefined}");
    expect(source).toContain("id={notificationPanelId}");
    expect(source).toContain("ref={notificationPanelRef}");
    expect(source).toContain("aria-labelledby={notificationPanelTitleId}");
    expect(source).toContain("tabIndex={-1}");
    expect(source).toContain("id={notificationPanelTitleId}");
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
    expect(source).toContain("font-size: 1.05rem;");
    expect(source).toContain(".topbarTitle {\n    font-size: 0.98rem;");
    expect(source).not.toMatch(/font-size:\s*[^;]*vw/);
  });
});
