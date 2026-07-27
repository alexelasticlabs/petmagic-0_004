import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import {
  ADMIN_FEEDBACK_ADMIN_NOTE_MAX_LENGTH,
  ADMIN_FEEDBACK_CATEGORY_FILTER_MAX_LENGTH,
  ADMIN_FEEDBACK_LOOKUP_ID_MAX_LENGTH,
  ADMIN_FEEDBACK_PLATFORM_FILTER_MAX_LENGTH,
  ADMIN_FEEDBACK_REFUND_REASON_MAX_LENGTH,
  isAdminFeedbackLookupId,
  normalizeAdminFeedbackQuery,
  refundAdminFeedbackCredits,
  updateAdminFeedback,
} from "@/lib/api-client.feedback";

describe("api-client.feedback query normalization", () => {
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

  it("uses backend-aligned limits and drops invalid lookup IDs before requests", () => {
    const overlongCategory = "c".repeat(ADMIN_FEEDBACK_CATEGORY_FILTER_MAX_LENGTH + 20);
    const overlongPlatform = "p".repeat(ADMIN_FEEDBACK_PLATFORM_FILTER_MAX_LENGTH + 20);
    const invalidTemplateId = "t".repeat(ADMIN_FEEDBACK_LOOKUP_ID_MAX_LENGTH + 20);
    const invalidUserId = "u".repeat(ADMIN_FEEDBACK_LOOKUP_ID_MAX_LENGTH + 20);

    expect(
      normalizeAdminFeedbackQuery({
        status: "All",
        priority: "All",
        type: "All",
        category: ` ${overlongCategory} `,
        platform: ` ${overlongPlatform} `,
        templateId: ` ${invalidTemplateId} `,
        userId: ` ${invalidUserId} `,
        skip: -10.8,
        take: 500.2,
      })
    ).toEqual({
      status: undefined,
      priority: undefined,
      type: undefined,
      category: "c".repeat(ADMIN_FEEDBACK_CATEGORY_FILTER_MAX_LENGTH),
      platform: "p".repeat(ADMIN_FEEDBACK_PLATFORM_FILTER_MAX_LENGTH),
      templateId: undefined,
      userId: undefined,
      fromUtc: undefined,
      toUtc: undefined,
      generationId: undefined,
      skip: 0,
      take: 100,
    });
  });

  it("accepts canonical UUID lookup values", () => {
    const lookupId = "0ec0f186-01a1-4a67-8c63-3b4ee5fcb498";

    expect(lookupId).toHaveLength(ADMIN_FEEDBACK_LOOKUP_ID_MAX_LENGTH);
    expect(isAdminFeedbackLookupId(lookupId)).toBe(true);
    expect(isAdminFeedbackLookupId("not-an-id")).toBe(false);
    expect(
      normalizeAdminFeedbackQuery({
        generationId: lookupId,
        templateId: lookupId,
        userId: lookupId,
      })
    ).toMatchObject({
      generationId: lookupId,
      templateId: lookupId,
      userId: lookupId,
    });
  });

  it("drops unsupported enum filters before backend requests", () => {
    expect(
      normalizeAdminFeedbackQuery({
        status: "Deleted" as never,
        priority: "Urgent" as never,
        type: "Other" as never,
        category: " billing ",
        skip: 0,
        take: 25,
      })
    ).toEqual({
      status: undefined,
      priority: undefined,
      type: undefined,
      category: "billing",
      platform: undefined,
      templateId: undefined,
      userId: undefined,
      fromUtc: undefined,
      toUtc: undefined,
      generationId: undefined,
      skip: 0,
      take: 25,
    });
  });

  it("bounds admin feedback notes before sending update payloads", async () => {
    const fetchMock = vi.fn<typeof fetch>(async () =>
      Response.json({
        id: "feedback-1",
        type: "General",
        category: "general",
        sourceScreen: "admin",
        status: "InReview",
        priority: "High",
        createdAtUtc: "2026-06-15T00:00:00.000Z",
        canRefund: false,
      })
    );
    const overlongNote = "n".repeat(ADMIN_FEEDBACK_ADMIN_NOTE_MAX_LENGTH + 50);
    vi.stubGlobal("fetch", fetchMock);

    await updateAdminFeedback("feedback/one", {
      status: "InReview",
      priority: "High",
      adminNote: overlongNote,
    });

    const [url, init] = fetchMock.mock.calls[0] ?? [];
    expect(String(url)).toBe("https://api.example.com/api/admin/feedback/feedback%2Fone");
    expect(init?.method).toBe("PUT");
    expect(JSON.parse(String(init?.body))).toEqual({
      status: "InReview",
      priority: "High",
      adminNote: "n".repeat(ADMIN_FEEDBACK_ADMIN_NOTE_MAX_LENGTH),
    });
  });

  it("bounds feedback refund reasons before sending audit payloads", async () => {
    const fetchMock = vi.fn<typeof fetch>(async () =>
      Response.json({
        id: "refund-1",
        userId: "user-1",
        feedbackId: "feedback-1",
        amount: 5,
        reason: "refund",
        adminId: "admin-1",
        createdAtUtc: "2026-06-15T00:00:00.000Z",
      })
    );
    const overlongReason = "r".repeat(ADMIN_FEEDBACK_REFUND_REASON_MAX_LENGTH + 50);
    vi.stubGlobal("fetch", fetchMock);

    await refundAdminFeedbackCredits("feedback/one", {
      amount: 5,
      reason: ` ${overlongReason} `,
    });

    const [url, init] = fetchMock.mock.calls[0] ?? [];
    expect(String(url)).toBe("https://api.example.com/api/admin/feedback/feedback%2Fone/refund");
    expect(init?.method).toBe("POST");
    expect(JSON.parse(String(init?.body))).toEqual({
      amount: 5,
      reason: "r".repeat(ADMIN_FEEDBACK_REFUND_REASON_MAX_LENGTH),
    });
  });

  it("matches the backend's 500-character refund reason contract", () => {
    expect(ADMIN_FEEDBACK_REFUND_REASON_MAX_LENGTH).toBe(500);
  });
});
