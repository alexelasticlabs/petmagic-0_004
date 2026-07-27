import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import {
  normalizeAdminTemplateGenerationsQuery,
  retryAdminTemplateGenerationRefund,
} from "@/lib/api-client.templates";

describe("admin generation refund recovery API", () => {
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

  it("sends the reason and stable idempotency key to the refund-only endpoint", async () => {
    const payload = {
      generationId: "11111111-1111-1111-1111-111111111111",
      reason: "  Provider refund attempts exhausted  ",
      idempotencyKey: "refund-intent-1",
    };
    const fetchMock = vi.fn<typeof fetch>(async () =>
      Response.json({
        generationId: payload.generationId,
        userId: "22222222-2222-2222-2222-222222222222",
        templateId: "33333333-3333-3333-3333-333333333333",
        status: "Failed",
        tokenCost: 4,
        canCancel: false,
      })
    );
    vi.stubGlobal("fetch", fetchMock);

    await retryAdminTemplateGenerationRefund(payload);

    const [input, init] = fetchMock.mock.calls[0];
    expect(String(input)).toBe(
      "https://api.example.com/api/admin/templates/generations/11111111-1111-1111-1111-111111111111/retry-refund"
    );
    expect(init?.method).toBe("POST");
    expect(new Headers(init?.headers).get("Idempotency-Key")).toBe("refund-intent-1");
    expect(JSON.parse(String(init?.body))).toEqual({
      reason: "Provider refund attempts exhausted",
    });
  });

  it("normalizes the refund state filter without changing existing filters", () => {
    expect(
      normalizeAdminTemplateGenerationsQuery({
        status: "Failed",
        refundState: "exhausted",
        search: "  generation-id  ",
      })
    ).toMatchObject({
      status: "Failed",
      refundState: "exhausted",
      search: "generation-id",
    });
    expect(
      normalizeAdminTemplateGenerationsQuery({ refundState: "all" }).refundState
    ).toBeUndefined();
  });
});
