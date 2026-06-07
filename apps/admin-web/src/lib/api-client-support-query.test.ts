import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { fetchSupportConversation, fetchSupportInbox } from "@/lib/api-client.support";

describe("api-client.support query normalization", () => {
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

  it("normalizes support inbox page parameters before building request URLs", async () => {
    const fetchMock = vi.fn(async () => Response.json([]));
    vi.stubGlobal("fetch", fetchMock);

    await fetchSupportInbox("New", "unassigned", {
      search: " alice@example.com ",
      page: 2.9,
      pageSize: 500.4,
    });

    expect(String(fetchMock.mock.calls[0]?.[0])).toBe(
      "https://api.example.com/api/admin/support/tickets?status=New&assignment=unassigned&search=alice%40example.com&page=2&pageSize=100"
    );
  });

  it("normalizes support conversation message take before building request URLs", async () => {
    const fetchMock = vi.fn(async () =>
      Response.json({
        conversationId: "conversation-1",
        subjectUserId: "user-1",
        status: "New",
        priority: "Normal",
        messages: [],
      })
    );
    vi.stubGlobal("fetch", fetchMock);

    await fetchSupportConversation("conversation-1", {
      take: 25.8,
      beforeMessageCreatedAtUtc: "2026-06-06T12:00:00Z",
    });

    expect(String(fetchMock.mock.calls[0]?.[0])).toBe(
      "https://api.example.com/api/admin/support/tickets/conversation-1?take=25&beforeMessageCreatedAtUtc=2026-06-06T12%3A00%3A00Z"
    );
  });
});
