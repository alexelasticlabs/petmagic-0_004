import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

import { hasActiveModerationLease } from "@/components/moderation-lease-control";

function readSource(relativePath: string) {
  return readFileSync(fileURLToPath(new URL(relativePath, import.meta.url)), "utf8");
}

describe("admin operations UI contract", () => {
  it("renders broadcast history as a safe aggregate queue and inspector", () => {
    const source = readSource("./users-email-broadcasts-workspace.tsx");

    expect(source).toContain("<AdminQueueLayout");
    expect(source).toContain("<AdminInspector");
    expect(source).toContain("fetchAdminEmailBroadcasts(query, signal)");
    expect(source).toContain("fetchAdminEmailBroadcast(selectedBroadcastId!, signal)");
    expect(source).toContain("retryFailedAdminEmailBroadcast(selectedBroadcastId!)");
    expect(source).toContain("retryableFailedCount");
    expect(source).toContain("refetchInterval");
    expect(source).toContain('selected: item.broadcastId, tab: "broadcasts"');
    expect(source).not.toContain("detail.body");
    expect(source).not.toContain("recipientEmail");
    expect(source).not.toContain("providerPayload");
  });

  it("keeps user selection persistent, actor scoped, removable, and eligibility aware", () => {
    const usersSource = readSource("./users-management-users-card.tsx");
    const traySource = readSource("./admin/admin-selection-tray.tsx");

    expect(usersSource).toContain(
      'const selectionStoragePrefix = "petmagic.admin.users.email-selection:v1"'
    );
    expect(usersSource).toContain("`${selectionStoragePrefix}:${session.user.userId}`");
    expect(usersSource).toContain("window.localStorage.setItem(");
    expect(usersSource).toContain("eligible: user.isActive && user.emailConfirmed");
    expect(usersSource).toContain("<AdminSelectionTray");
    expect(usersSource).toContain("onRemove={(userId)");
    expect(usersSource).toContain("onClear={() => setSelectedUsers(new Map())}");
    expect(traySource).toContain("items?: readonly AdminSelectionTrayItem[]");
    expect(traySource).toContain("data-eligible={item.eligible}");
  });

  it("treats moderation leases as expiring ownership, not a permanent client flag", () => {
    const now = Date.parse("2026-07-27T12:00:00Z");
    const baseItem = {
      eventId: "event-1",
      templateId: "template-1",
      templateTitle: "Portrait",
      templateType: "Image" as const,
      eventType: "complaint",
      status: "pending" as const,
      source: "mobile",
      deviceClass: "phone",
      countryCode: "BY",
      createdAtUtc: "2026-07-27T11:00:00Z",
      leaseOwnerUserId: "moderator-1",
      version: 3,
    };

    expect(
      hasActiveModerationLease({ ...baseItem, leaseExpiresAtUtc: "2026-07-27T12:15:00Z" }, now)
    ).toBe(true);
    expect(
      hasActiveModerationLease({ ...baseItem, leaseExpiresAtUtc: "2026-07-27T11:59:59Z" }, now)
    ).toBe(false);
  });

  it("uses URL selection, versioned lease actions, and explicit decisions", () => {
    const pageSource = readSource("./moderation-page.tsx");
    const leaseSource = readSource("./moderation-lease-control.tsx");
    const contentSource = readSource("./moderation-page.content.ts");

    expect(pageSource).toContain("<AdminDetailsDrawer");
    expect(pageSource).toContain("updateAdminUrlState(");
    expect(pageSource).toContain("expectedVersion: decision.item.version ?? 0");
    expect(pageSource).toContain("<ModerationLeaseControl");
    expect(leaseSource).toContain("claimAdminModerationItem");
    expect(leaseSource).toContain("releaseAdminModerationItem");
    expect(leaseSource).toContain("handoffAdminModerationItem");
    expect(leaseSource).toContain("expectedVersion");
    expect(contentSource).toContain('approve: "Оставить без изменений"');
    expect(contentSource).toContain('reject: "Подтвердить нарушение"');
  });
});
