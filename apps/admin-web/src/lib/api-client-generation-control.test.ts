import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import {
  fetchAdminTemplateGenerationControl,
  refreshAdminTemplateGenerationProvider,
  resolveAdminTemplateProviderAttempt,
  updateAdminTemplateGenerationControlPolicy,
} from "@/lib/api-client.templates";

describe("admin generation control API", () => {
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

  it("loads generation control independently with request cancellation", async () => {
    const fetchMock = vi.fn<typeof fetch>(async () => Response.json({ revision: 4 }));
    vi.stubGlobal("fetch", fetchMock);
    const controller = new AbortController();

    await fetchAdminTemplateGenerationControl(controller.signal);

    const [input, init] = fetchMock.mock.calls[0];
    expect(String(input)).toBe("https://api.example.com/api/admin/templates/generation-control");
    expect(init?.method).toBe("GET");
    expect(init?.signal).toBeInstanceOf(AbortSignal);
  });

  it("sends optimistic revision, reason, and idempotency key without leaking it into JSON", async () => {
    const fetchMock = vi.fn<typeof fetch>(async () => Response.json({ revision: 5 }));
    vi.stubGlobal("fetch", fetchMock);

    await updateAdminTemplateGenerationControlPolicy({
      expectedRevision: 4,
      reason: "  Verified fal.ai Dashboard concurrency  ",
      admissionEnabled: true,
      confirmedFalConcurrencyLimit: 40,
      reservedHeadroom: 2,
      applicationHardCeiling: 38,
      idempotencyKey: "generation-policy-4",
    });

    const [input, init] = fetchMock.mock.calls[0];
    expect(String(input)).toBe(
      "https://api.example.com/api/admin/templates/generation-control/policy"
    );
    expect(init?.method).toBe("PUT");
    expect(new Headers(init?.headers).get("Idempotency-Key")).toBe("generation-policy-4");
    expect(JSON.parse(String(init?.body))).toEqual({
      expectedRevision: 4,
      reason: "Verified fal.ai Dashboard concurrency",
      admissionEnabled: true,
      confirmedFalConcurrencyLimit: 40,
      reservedHeadroom: 2,
      applicationHardCeiling: 38,
    });
  });

  it("refreshes provider state through the dedicated endpoint", async () => {
    const fetchMock = vi.fn<typeof fetch>(async () => Response.json({ revision: 4 }));
    vi.stubGlobal("fetch", fetchMock);

    await refreshAdminTemplateGenerationProvider();

    const [input, init] = fetchMock.mock.calls[0];
    expect(String(input)).toBe(
      "https://api.example.com/api/admin/templates/generation-control/provider/refresh"
    );
    expect(init?.method).toBe("POST");
  });

  it("sends evidence-backed provider attempt resolution with idempotency outside JSON", async () => {
    const fetchMock = vi.fn<typeof fetch>(async () =>
      Response.json({ providerAttemptId: "attempt-1", resolution: "correlated_accepted" })
    );
    vi.stubGlobal("fetch", fetchMock);

    await resolveAdminTemplateProviderAttempt({
      attemptId: "9c97c35e-4da1-4de1-8d87-8b02f9fce2ad",
      expectedAttemptVersion: 4,
      resolution: "correlated_accepted",
      reason: "  Correlated with the fal.ai Dashboard request.  ",
      evidenceReference: "  fal-dashboard:case-accepted-1  ",
      providerRequestId: "request_accepted_1",
      providerStatusUrl:
        "https://queue.fal.run/fal-ai/nano-banana-pro/edit/requests/request_accepted_1/status",
      providerResponseUrl:
        "https://queue.fal.run/fal-ai/nano-banana-pro/edit/requests/request_accepted_1/response",
      providerCancelUrl:
        "https://queue.fal.run/fal-ai/nano-banana-pro/edit/requests/request_accepted_1/cancel",
      idempotencyKey: "resolve-provider-attempt-1",
    });

    const [input, init] = fetchMock.mock.calls[0];
    expect(String(input)).toBe(
      "https://api.example.com/api/admin/templates/generation-control/provider-attempts/9c97c35e-4da1-4de1-8d87-8b02f9fce2ad/resolve"
    );
    expect(init?.method).toBe("POST");
    expect(new Headers(init?.headers).get("Idempotency-Key")).toBe("resolve-provider-attempt-1");
    expect(JSON.parse(String(init?.body))).toMatchObject({
      expectedAttemptVersion: 4,
      resolution: "correlated_accepted",
      reason: "Correlated with the fal.ai Dashboard request.",
      evidenceReference: "fal-dashboard:case-accepted-1",
      providerRequestId: "request_accepted_1",
    });
    expect(JSON.parse(String(init?.body))).not.toHaveProperty("idempotencyKey");
  });
});
