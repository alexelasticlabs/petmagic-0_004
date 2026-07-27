import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { fetchAdminOperationsStatus, fetchAdminSystemStatus } from "@/lib/api-client.system-status";

describe("api-client.system-status", () => {
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

  it("uses the exact admin GET endpoint and propagates AbortSignal", async () => {
    const payload = {
      overallStatus: "healthy",
      generatedAtUtc: "2026-07-27T10:00:00Z",
      staleAfterSeconds: 60,
      checks: [
        {
          key: "api",
          status: "healthy",
          summary: "API is operational.",
          checkedAtUtc: "2026-07-27T10:00:00Z",
        },
      ],
    } as const;
    const fetchMock = vi.fn<typeof fetch>(async () => Response.json(payload));
    vi.stubGlobal("fetch", fetchMock);
    const controller = new AbortController();

    await expect(fetchAdminSystemStatus(controller.signal)).resolves.toEqual(payload);

    expect(fetchMock).toHaveBeenCalledTimes(1);
    const [input, init] = fetchMock.mock.calls[0];
    expect(String(input)).toBe("https://api.example.com/api/admin/system/status");
    expect(init?.method).toBe("GET");
    expect(init?.signal).toBeInstanceOf(AbortSignal);
    expect(init?.signal?.aborted).toBe(false);
    expect(init?.body).toBeUndefined();
  });

  it("rejects a successful HTTP response that does not match the status contract", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn<typeof fetch>(async () =>
        Response.json({ items: [], totalCount: 0, page: 1, pageSize: 25, hasMore: false })
      )
    );

    await expect(fetchAdminSystemStatus()).rejects.toThrow(
      "Admin system status response contract is invalid."
    );
  });

  it("loads bounded operations aggregates from the exact private endpoint", async () => {
    const payload = {
      overallStatus: "degraded",
      generatedAtUtc: "2026-07-27T10:00:00Z",
      cacheDurationSeconds: 15,
      staleAfterSeconds: 45,
      email: {
        status: "healthy",
        backlogCount: 2,
        deadLetterCount: 0,
        oldestItemAgeSeconds: 30,
        lastSuccessfulRunAtUtc: "2026-07-27T09:59:00Z",
      },
      auditOutbox: {
        status: "healthy",
        backlogCount: 0,
        deadLetterCount: 0,
        oldestItemAgeSeconds: null,
        lastSuccessfulRunAtUtc: null,
      },
      pushOutbox: {
        status: "healthy",
        backlogCount: 0,
        deadLetterCount: 0,
        oldestItemAgeSeconds: null,
        lastSuccessfulRunAtUtc: null,
      },
      generations: { status: "degraded", queueDepth: 8, oldestQueuedItemAgeSeconds: 360 },
      economy: { status: "healthy", openIncidentCount: 0, criticalIncidentCount: 0 },
      workers: {
        status: "healthy",
        lastSuccessfulRunAtUtc: "2026-07-27T09:59:00Z",
        generationWorkerHeartbeatAtUtc: "2026-07-27T09:59:50Z",
        generationWorkerHeartbeatAgeSeconds: 10,
      },
      unavailableSources: [],
    } as const;
    const fetchMock = vi.fn<typeof fetch>(async () => Response.json(payload));
    vi.stubGlobal("fetch", fetchMock);
    const controller = new AbortController();

    await expect(fetchAdminOperationsStatus(controller.signal)).resolves.toEqual(payload);

    expect(fetchMock).toHaveBeenCalledTimes(1);
    expect(String(fetchMock.mock.calls[0][0])).toBe(
      "https://api.example.com/api/admin/system/operations"
    );
    expect(fetchMock.mock.calls[0][1]?.method).toBe("GET");
    expect(fetchMock.mock.calls[0][1]?.signal).toBeInstanceOf(AbortSignal);
    expect(fetchMock.mock.calls[0][1]?.signal?.aborted).toBe(false);
  });

  it("rejects unbounded operations payloads", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn<typeof fetch>(async () =>
        Response.json({
          overallStatus: "healthy",
          generatedAtUtc: "2026-07-27T10:00:00Z",
          cacheDurationSeconds: 15,
          staleAfterSeconds: 45,
          email: { status: "healthy", backlogCount: 0, deadLetterCount: 0 },
          auditOutbox: { status: "healthy", backlogCount: 0, deadLetterCount: 0 },
          pushOutbox: { status: "healthy", backlogCount: 0, deadLetterCount: 0 },
          generations: { status: "healthy", queueDepth: 0 },
          economy: { status: "healthy", openIncidentCount: 0, criticalIncidentCount: 0 },
          workers: { status: "healthy" },
          unavailableSources: Array.from({ length: 20 }, (_, index) => `source-${index}`),
        })
      )
    );

    await expect(fetchAdminOperationsStatus()).rejects.toThrow(
      "Admin operations status response contract is invalid."
    );
  });
});
