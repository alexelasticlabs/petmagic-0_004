import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import {
  SUPPORT_CONVERSATION_MESSAGES_MAX_TAKE,
  fetchAdminUserSupportTickets,
  fetchSupportConversation,
  fetchSupportInbox,
  fetchSupportInboxMetrics,
  sendSupportMessage,
  SUPPORT_IDEMPOTENCY_KEY_MAX_LENGTH,
  SUPPORT_INBOX_SEARCH_MAX_LENGTH,
  SUPPORT_MESSAGE_BODY_MAX_LENGTH,
} from "@/lib/api-client.support";

const supportClientPath = fileURLToPath(new URL("./api-client.support.ts", import.meta.url));
const coreClientPath = fileURLToPath(new URL("./api-client.core.ts", import.meta.url));

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
    const fetchMock = vi.fn<typeof fetch>(async () =>
      Response.json({ items: [], page: 2, pageSize: 100, totalCount: 0, hasMore: false })
    );
    const overlongSearch = "s".repeat(SUPPORT_INBOX_SEARCH_MAX_LENGTH + 20);
    vi.stubGlobal("fetch", fetchMock);

    const response = await fetchSupportInbox("New", "unassigned", {
      search: ` ${overlongSearch} `,
      page: 2.9,
      pageSize: 500.4,
    });

    expect(String(fetchMock.mock.calls[0]?.[0])).toBe(
      `https://api.example.com/api/admin/support/tickets?status=New&assignment=unassigned&search=${"s".repeat(SUPPORT_INBOX_SEARCH_MAX_LENGTH)}&page=2&pageSize=100`
    );
    expect(response).toEqual({
      items: [],
      page: 2,
      pageSize: 100,
      totalCount: 0,
      hasMore: false,
    });
  });

  it("serializes multi-status support inbox filters with backend priority and sort", async () => {
    const fetchMock = vi.fn<typeof fetch>(async () =>
      Response.json({ items: [], page: 1, pageSize: 50, totalCount: 0, hasMore: false })
    );
    vi.stubGlobal("fetch", fetchMock);

    await fetchSupportInbox(["New", "WaitingForUser"], "all", {
      priority: "High",
      sort: "priority",
      page: 1,
      pageSize: 50,
    });

    expect(String(fetchMock.mock.calls[0]?.[0])).toBe(
      "https://api.example.com/api/admin/support/tickets?status=New&status=WaitingForUser&priority=High&sort=priority&page=1&pageSize=50"
    );
  });

  it("serializes support waiting-for-support queue through backend params", async () => {
    const fetchMock = vi.fn<typeof fetch>(async () =>
      Response.json({ items: [], page: 1, pageSize: 50, totalCount: 0, hasMore: false })
    );
    vi.stubGlobal("fetch", fetchMock);

    await fetchSupportInbox(undefined, "all", {
      queue: "waiting_for_support",
      sort: "waiting",
      page: 1,
      pageSize: 50,
    });

    expect(String(fetchMock.mock.calls[0]?.[0])).toBe(
      "https://api.example.com/api/admin/support/tickets?sort=waiting&queue=waiting_for_support&page=1&pageSize=50"
    );
  });

  it("serializes the unread support queue through the backend contract", async () => {
    const fetchMock = vi.fn<typeof fetch>(async () =>
      Response.json({ items: [], page: 1, pageSize: 50, totalCount: 0, hasMore: false })
    );
    vi.stubGlobal("fetch", fetchMock);

    await fetchSupportInbox(undefined, "all", {
      queue: "unread",
      page: 1,
      pageSize: 50,
    });

    expect(String(fetchMock.mock.calls[0]?.[0])).toBe(
      "https://api.example.com/api/admin/support/tickets?queue=unread&page=1&pageSize=50"
    );
  });

  it("normalizes user-scoped support history pagination and encodes the user id", async () => {
    const fetchMock = vi.fn<typeof fetch>(async () =>
      Response.json({ items: [], page: 2, pageSize: 100, totalCount: 0, hasMore: false })
    );
    vi.stubGlobal("fetch", fetchMock);

    await fetchAdminUserSupportTickets("user/one two", { page: 2.8, pageSize: 500.4 });

    expect(String(fetchMock.mock.calls[0]?.[0])).toBe(
      "https://api.example.com/api/admin/users/user%2Fone%20two/support/tickets?page=2&pageSize=100"
    );
  });

  it("drops unsupported support inbox enum filters before backend requests", async () => {
    const fetchMock = vi.fn<typeof fetch>(async () =>
      Response.json({ items: [], page: 1, pageSize: 50, totalCount: 0, hasMore: false })
    );
    vi.stubGlobal("fetch", fetchMock);

    await fetchSupportInbox(["New", "Deleted" as never], "everyone" as never, {
      priority: "Urgent" as never,
      sort: "oldest" as never,
      queue: "stale" as never,
      search: " billing ",
      page: 1,
      pageSize: 50,
    });

    expect(String(fetchMock.mock.calls[0]?.[0])).toBe(
      "https://api.example.com/api/admin/support/tickets?status=New&search=billing&page=1&pageSize=50"
    );
  });

  it("canonicalizes support inbox enum filters before request URLs", async () => {
    const fetchMock = vi.fn<typeof fetch>(async () =>
      Response.json({ items: [], page: 1, pageSize: 50, totalCount: 0, hasMore: false })
    );
    vi.stubGlobal("fetch", fetchMock);

    await fetchSupportInbox("waitingforuser" as never, "UNASSIGNED" as never, {
      priority: "high" as never,
      sort: "UPDATED" as never,
      page: 1,
      pageSize: 50,
    });

    expect(String(fetchMock.mock.calls[0]?.[0])).toBe(
      "https://api.example.com/api/admin/support/tickets?status=WaitingForUser&assignment=unassigned&priority=High&sort=updated&page=1&pageSize=50"
    );
  });

  it("requests support inbox metrics with abort support", async () => {
    const fetchMock = vi.fn<typeof fetch>(async () =>
      Response.json({
        totalConversations: 6,
        openConversations: 4,
        closedConversations: 2,
        unassignedConversations: 3,
        unreadForAdminConversations: 5,
      })
    );
    const controller = new AbortController();
    vi.stubGlobal("fetch", fetchMock);

    const response = await fetchSupportInboxMetrics(controller.signal);

    const [url, init] = fetchMock.mock.calls[0] ?? [];
    expect(response.unreadForAdminConversations).toBe(5);
    expect(String(url)).toBe("https://api.example.com/api/admin/support/tickets/metrics");
    expect(init?.method).toBe("GET");
    expect(init?.signal).toBeInstanceOf(AbortSignal);
  });

  it("normalizes support conversation message take before building request URLs", async () => {
    const fetchMock = vi.fn<typeof fetch>(async () =>
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
      beforeMessageId: "message-1",
    });

    expect(String(fetchMock.mock.calls[0]?.[0])).toBe(
      "https://api.example.com/api/admin/support/tickets/conversation-1?take=25&beforeMessageCreatedAtUtc=2026-06-06T12%3A00%3A00Z&beforeMessageId=message-1"
    );
  });

  it("caps support conversation message take at the backend limit", async () => {
    const fetchMock = vi.fn<typeof fetch>(async () =>
      Response.json({
        conversationId: "conversation-1",
        subjectUserId: "user-1",
        status: "New",
        priority: "Normal",
        messages: [],
      })
    );
    vi.stubGlobal("fetch", fetchMock);

    await fetchSupportConversation("conversation-1", { take: 500.9 });

    expect(String(fetchMock.mock.calls[0]?.[0])).toBe(
      `https://api.example.com/api/admin/support/tickets/conversation-1?take=${SUPPORT_CONVERSATION_MESSAGES_MAX_TAKE}`
    );
  });

  it("encodes support ids before placing them in API path segments", async () => {
    const fetchMock = vi.fn<typeof fetch>(async () =>
      Response.json({
        conversationId: "ticket/one two?x",
        subjectUserId: "user-1",
        status: "New",
        priority: "Normal",
        messages: [],
      })
    );
    vi.stubGlobal("fetch", fetchMock);

    await fetchSupportConversation("ticket/one two?x", { take: 10 });
    await sendSupportMessage("ticket/one two?x", "Hello", undefined, "message-intent-1");

    expect(fetchMock.mock.calls.map((call) => String(call[0]))).toEqual([
      "https://api.example.com/api/admin/support/tickets/ticket%2Fone%20two%3Fx?take=10",
      "https://api.example.com/api/admin/support/tickets/ticket%2Fone%20two%3Fx/messages",
    ]);
  });

  it("bounds support message bodies before sending reply payloads", async () => {
    const fetchMock = vi.fn<typeof fetch>(async () =>
      Response.json({
        messageId: "message-1",
        conversationId: "ticket-1",
        senderType: "Admin",
        body: "ok",
        createdAtUtc: "2026-06-07T00:00:00Z",
      })
    );
    const overlongBody = "b".repeat(SUPPORT_MESSAGE_BODY_MAX_LENGTH + 20);
    vi.stubGlobal("fetch", fetchMock);

    await sendSupportMessage(
      "ticket-1",
      ` ${overlongBody} `,
      " message-parent ",
      " message-intent-2 "
    );

    const [, init] = fetchMock.mock.calls[0] ?? [];
    expect(String(fetchMock.mock.calls[0]?.[0])).toBe(
      "https://api.example.com/api/admin/support/tickets/ticket-1/messages"
    );
    expect(JSON.parse(String(init?.body))).toEqual({
      body: "b".repeat(SUPPORT_MESSAGE_BODY_MAX_LENGTH),
      replyToMessageId: "message-parent",
    });
    expect((init?.headers as Headers).get("Idempotency-Key")).toBe("message-intent-2");
  });

  it("rejects blank and oversized support message idempotency keys before a request", async () => {
    const fetchMock = vi.fn<typeof fetch>();
    vi.stubGlobal("fetch", fetchMock);

    await expect(sendSupportMessage("ticket-1", "Hello", undefined, " ")).rejects.toThrow(
      "support.idempotency_key_invalid"
    );
    await expect(
      sendSupportMessage(
        "ticket-1",
        "Hello",
        undefined,
        "x".repeat(SUPPORT_IDEMPOTENCY_KEY_MAX_LENGTH + 1)
      )
    ).rejects.toThrow("support.idempotency_key_invalid");
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it("does not clear unrelated in-flight GET dedupe when support conversations mutate", () => {
    const supportSource = readFileSync(supportClientPath, "utf8");
    const coreSource = readFileSync(coreClientPath, "utf8");

    expect(supportSource).not.toContain("inflightGetRequests.clear()");
    expect(supportSource).toContain('invalidateCachedGetNamespaces(["support-templates"]);');
    expect(coreSource).not.toContain("cachedSupportConversations");
    expect(coreSource).not.toContain("cachedSupportInbox");
  });
});
