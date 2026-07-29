import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

import {
  buildAdminNotificationDedupeKey,
  getAdminNotificationStorageKey,
  localizeAdminNotification,
  sanitizeAdminNotificationText,
} from "@/components/admin/admin-notifications";
import type { AdminNotificationEvent } from "@/lib/api-client";

const read = (path: string) => readFileSync(fileURLToPath(new URL(path, import.meta.url)), "utf8");
const providerSource = read("./admin-notifications.tsx");
const topbarSource = read("./admin-topbar.tsx");
const shellSource = read("../admin-shell.tsx");
const shellStyles = read("./admin-shell.module.css");
const globalStyles = read("../../app/globals.css");

function event(overrides: Partial<AdminNotificationEvent> = {}): AdminNotificationEvent {
  return {
    notificationId: "notification-1",
    type: "support.message.received",
    schemaVersion: 1,
    payload: { conversationId: "12345678-1234-1234-1234-123456789012" },
    category: "support",
    priority: "normal",
    source: "support-chat",
    createdAtUtc: "2026-07-29T10:00:00Z",
    version: 1,
    ...overrides,
  };
}

describe("server-backed admin notifications", () => {
  it("localizes neutral server events without rendering payload HTML", () => {
    const ru = localizeAdminNotification(event(), "ru");
    const en = localizeAdminNotification(event(), "en");
    const unknown = localizeAdminNotification(
      event({ type: "future.event", category: "economy", priority: "critical" }),
      "ru"
    );

    expect(ru.title).toBe("Новое сообщение в поддержке");
    expect(ru.message).toContain("1234…9012");
    expect(en.title).toBe("New support message");
    expect(unknown).toMatchObject({ category: "economy", tone: "error" });
  });

  it("keeps operator copy first and technical detail secondary", () => {
    const failed = localizeAdminNotification(
      event({
        type: "generation.failed",
        category: "generation",
        priority: "warning",
        payload: { generationId: "generation-123456", failureCode: "provider_timeout" },
      }),
      "ru"
    );
    const refund = localizeAdminNotification(
      event({ type: "generation.refund_exhausted", payload: { generationId: "generation-1" } }),
      "en"
    );

    expect(failed.title).toBe("Генерация завершилась ошибкой");
    expect(failed.message).toContain("Код: provider_timeout");
    expect(refund.message).toContain("Manual review is required");
  });

  it("sanitizes compatibility helpers and never keeps sensitive values", () => {
    const sanitized = sanitizeAdminNotificationText(
      "alice@example.com token=raw-secret https://cdn.example.com/a?sig=secret",
      200
    );
    const dedupe = buildAdminNotificationDedupeKey(
      "support",
      "error",
      "alice@example.com token=raw-secret",
      "/support?token=secret"
    );

    expect(sanitized).not.toContain("alice@example.com");
    expect(sanitized).not.toContain("raw-secret");
    expect(dedupe).not.toContain("raw-secret");
    expect(dedupe).not.toContain("token=secret");
  });

  it("hydrates from the server before deleting untrusted legacy storage", () => {
    expect(getAdminNotificationStorageKey("admin/one")).toBe(
      "petmagic.admin.notifications.v2:admin%2Fone"
    );
    expect(providerSource).toContain('if (!query.data || typeof window === "undefined") return;');
    expect(providerSource).toContain(
      "window.localStorage.removeItem(LEGACY_ADMIN_NOTIFICATIONS_STORAGE_KEY)"
    );
    expect(providerSource).not.toContain("window.localStorage.setItem");
    expect(providerSource).toContain("refetchInterval: 30_000");
    expect(providerSource).toContain("refetchOnWindowFocus: true");
    expect(providerSource).toContain("useAdminNotificationsRealtime");
  });

  it("keeps action toasts transient and performs server mutations for inbox state", () => {
    expect(providerSource).toContain("setTransientFeedback");
    expect(providerSource).toContain("ui-toast ui-toast--");
    expect(providerSource).toContain("window.setTimeout(() => setTransientFeedback(null), 3_200)");
    expect(providerSource).toContain(
      "persistent inbox events originate from trusted server transitions"
    );
    expect(providerSource).toContain("markAdminNotificationRead(notificationId)");
    expect(providerSource).toContain("markAllAdminNotificationsRead(cutoffUtc)");
    expect(providerSource).toContain("archiveAdminNotification(notificationId)");
  });

  it("persists the desktop rail using a versioned key while preserving mobile drawer semantics", () => {
    expect(shellSource).toContain('const ADMIN_SIDEBAR_STORAGE_KEY = "petmagic.admin.sidebar.v1"');
    expect(shellSource).toContain("window.localStorage.getItem(ADMIN_SIDEBAR_STORAGE_KEY)");
    expect(shellSource).toContain("if (!isSidebarDrawerMode)");
    expect(shellSource).toContain("setSidebarOpen(true)");
    expect(shellStyles).toContain("grid-template-columns: 4.5rem minmax(0, 1fr);");
    expect(shellStyles).toContain("grid-template-columns: 15rem minmax(0, 1fr);");
  });

  it("keeps the topbar inbox keyboard trapped and mobile sheet viewport-safe", () => {
    expect(topbarSource).toContain('event.key === "Tab"');
    expect(topbarSource).toContain("notificationTriggerRef.current?.focus()");
    expect(topbarSource).toContain("href={`/${locale}/notifications`}");
    expect(shellStyles).toContain("height: 100dvh;");
    expect(shellStyles).toContain("overflow-wrap: anywhere;");
  });

  it("defines compact motion tokens and honors reduced motion", () => {
    expect(globalStyles).toContain("--motion-fast: 120ms;");
    expect(globalStyles).toContain("--motion-standard: 160ms;");
    expect(globalStyles).toContain("--motion-emphasis: 220ms;");
    expect(globalStyles).toContain("@media (prefers-reduced-motion: reduce)");
  });
});
