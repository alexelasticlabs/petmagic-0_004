import { describe, expect, it } from "vitest";

import {
  formatAuditIdentity,
  formatAuditTarget,
  getAuditEventDeepLink,
  getAuditEventPresentation,
  getAuditPeriodRange,
} from "@/components/audit-events-page.helpers";
import type { AdminAuditEventListItem } from "@/lib/api-client";

const event: AdminAuditEventListItem = {
  auditEventId: "4d5a78b4-62d8-45e4-9197-489975ba17e2",
  action: "user.blocked",
  category: "identity",
  actorUserId: "123e4567-e89b-12d3-a456-426614174000",
  targetType: "User",
  targetId: "42f53a11-0583-4119-95d7-b6c11c7a04d1",
  occurredAtUtc: "2026-07-26T10:00:00Z",
};

describe("audit-events-page helpers", () => {
  it("creates deterministic UTC period bounds", () => {
    const now = new Date("2026-07-26T12:30:00.000Z");

    expect(getAuditPeriodRange("24h", now)).toEqual({
      fromUtc: "2026-07-25T12:30:00.000Z",
      toUtc: "2026-07-26T12:30:00.000Z",
    });
    expect(getAuditPeriodRange("30d", now).fromUtc).toBe("2026-06-26T12:30:00.000Z");
  });

  it("masks actor email and sanitizes persisted labels", () => {
    expect(formatAuditIdentity({ email: "alex@example.com" }, "System")).toBe("al***@e***.com");
    expect(
      formatAuditIdentity({ displayName: "authorization=secret-token Product Admin" }, "System")
    ).toBe("authorization=[redacted] Product Admin");
    expect(formatAuditTarget({ ...event, targetType: "User" }, "No target")).toBe(
      "User · #42f53a11"
    );
  });

  it("maps known action codes to localized operator language", () => {
    expect(getAuditEventPresentation(event, "ru")).toMatchObject({
      title: "Доступ пользователя заблокирован",
      actionCode: "user.blocked",
    });
    expect(getAuditEventPresentation({ ...event, action: "custom.system.event" }, "en").title).toBe(
      "System event"
    );
    expect(
      getAuditEventPresentation({ ...event, action: "admin.economy.currency_pack.updated" }, "ru")
        .title
    ).toBe("Пакет PawSpark обновлён");
    expect(
      getAuditEventPresentation(
        { ...event, action: "admin.economy.subscription_plan.updated" },
        "en"
      ).title
    ).toBe("Subscription plan updated");
    expect(
      getAuditEventPresentation({ ...event, action: "admin.economy.redeem_code.created" }, "ru")
        .title
    ).toBe("Промокод создан");
    expect(
      getAuditEventPresentation({ ...event, action: "admin.economy.redeem_code.updated" }, "en")
        .title
    ).toBe("Promo code updated");
  });

  it("prefers the operational support target and safely encodes user deep links", () => {
    expect(getAuditEventDeepLink({ ...event, subjectUserId: "user/one" }, "ru")).toEqual({
      href: "/ru/users/user%2Fone",
      kind: "user",
    });
    expect(
      getAuditEventDeepLink(
        {
          ...event,
          subjectUserId: "33333333-3333-4333-8333-333333333333",
          targetType: "SupportConversation",
          targetId: "123e4567-e89b-12d3-a456-426614174000",
        },
        "en"
      )
    ).toEqual({
      href: "/en/support/123e4567-e89b-12d3-a456-426614174000",
      kind: "support",
    });
    expect(
      getAuditEventDeepLink(
        { ...event, subjectUserId: null, targetType: "SupportConversation", targetId: "../x" },
        "en"
      )
    ).toBeNull();
  });

  it("links economy catalog events to their operational workspaces", () => {
    expect(
      getAuditEventDeepLink({ ...event, subjectUserId: null, targetType: "currency_pack" }, "ru")
    ).toEqual({ href: "/ru/economy", kind: "economy" });
    expect(
      getAuditEventDeepLink(
        { ...event, subjectUserId: null, targetType: "Subscription_Plan" },
        "en"
      )
    ).toEqual({ href: "/en/economy", kind: "economy" });
    expect(
      getAuditEventDeepLink({ ...event, subjectUserId: null, targetType: "redeem_code" }, "ru")
    ).toEqual({ href: "/ru/promo-codes", kind: "promo" });
  });
});
