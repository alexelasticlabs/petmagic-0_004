import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import {
  buildAdminAuditEventsPath,
  fetchAdminAuditEvent,
  fetchAdminAuditEvents,
  normalizeAdminAuditEventsQuery,
} from "@/lib/api-client.audit";

describe("api-client.audit", () => {
  const originalPublicApiBaseUrl = process.env.NEXT_PUBLIC_API_BASE_URL;
  const originalInternalApiBaseUrl = process.env.INTERNAL_API_BASE_URL;

  beforeEach(() => {
    process.env.NEXT_PUBLIC_API_BASE_URL = "https://api.example.com";
    process.env.INTERNAL_API_BASE_URL = "https://api.example.com";
  });

  afterEach(() => {
    vi.unstubAllGlobals();
    process.env.NEXT_PUBLIC_API_BASE_URL = originalPublicApiBaseUrl;
    process.env.INTERNAL_API_BASE_URL = originalInternalApiBaseUrl;
  });

  it("normalizes paging, server filters, and date bounds", () => {
    expect(
      normalizeAdminAuditEventsQuery({
        skip: -20.8,
        take: 500,
        search: `  ${"x".repeat(140)}  `,
        category: "support",
        actorUserId: "  123e4567-e89b-12d3-a456-426614174000  ",
        fromUtc: "2026-07-01T10:00:00+03:00",
        toUtc: "not-a-date",
      })
    ).toEqual({
      skip: 0,
      take: 100,
      search: "x".repeat(120),
      category: "support",
      actorUserId: "123e4567-e89b-12d3-a456-426614174000",
      subjectUserId: undefined,
      fromUtc: "2026-07-01T07:00:00.000Z",
      toUtc: undefined,
    });
  });

  it("builds an encoded deterministic list URL", () => {
    expect(
      buildAdminAuditEventsPath({
        skip: 25,
        take: 25,
        search: "refund / failed",
        category: "economy",
        actorUserId: "123e4567-e89b-12d3-a456-426614174000",
        fromUtc: "2026-07-01T00:00:00Z",
        toUtc: "2026-07-08T00:00:00Z",
      })
    ).toBe(
      "/api/admin/audit-events?skip=25&take=25&search=refund+%2F+failed&category=economy&actorUserId=123e4567-e89b-12d3-a456-426614174000&fromUtc=2026-07-01T00%3A00%3A00.000Z&toUtc=2026-07-08T00%3A00%3A00.000Z"
    );
  });

  it("uses GET for list and detail and propagates AbortSignal", async () => {
    const fetchMock = vi.fn<typeof fetch>(async (input) => {
      const url = String(input);
      if (url.includes("?")) {
        return Response.json({
          items: [],
          skip: 0,
          take: 25,
          totalCount: 0,
          hasMore: false,
          summary: { totalEvents: 0, uniqueActors: 0, accessEvents: 0, systemEvents: 0 },
        });
      }

      return Response.json({
        auditEventId: "event/one",
        action: "user.blocked",
        category: "identity",
        occurredAtUtc: "2026-07-26T10:00:00Z",
        details: "reason",
        createdAtUtc: "2026-07-26T10:00:01Z",
      });
    });
    vi.stubGlobal("fetch", fetchMock);
    const controller = new AbortController();

    await fetchAdminAuditEvents({}, controller.signal);
    await fetchAdminAuditEvent(" event/one?expand=true ", controller.signal);

    expect(fetchMock.mock.calls.map(([input]) => String(input))).toEqual([
      "https://api.example.com/api/admin/audit-events?skip=0&take=25",
      "https://api.example.com/api/admin/audit-events/event%2Fone%3Fexpand%3Dtrue",
    ]);
    for (const [, init] of fetchMock.mock.calls) {
      expect(init?.method).toBe("GET");
      expect(init?.signal).toBeInstanceOf(AbortSignal);
      expect(init?.signal?.aborted).toBe(false);
      expect(init?.body).toBeUndefined();
    }
  });
});
