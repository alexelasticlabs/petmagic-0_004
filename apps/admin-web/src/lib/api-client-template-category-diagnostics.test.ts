import { describe, expect, it, vi } from "vitest";

const { apiRequestMock } = vi.hoisted(() => ({
  apiRequestMock: vi.fn(),
}));

vi.mock("@/lib/api-client.core", () => ({
  apiRequest: apiRequestMock,
}));

import { fetchAdminTemplateCategoryDiagnostics } from "@/lib/api-client.template-category-diagnostics";

describe("template category diagnostics API client", () => {
  it("uses the Admin-only diagnostics route and forwards cancellation", async () => {
    const controller = new AbortController();
    apiRequestMock.mockResolvedValueOnce({
      totalActiveTemplates: 0,
      noncanonicalTemplates: 0,
      noncanonicalPercent: 0,
      items: [],
      generatedAtUtc: "2026-07-27T00:00:00.000Z",
    });

    await fetchAdminTemplateCategoryDiagnostics(controller.signal);

    expect(apiRequestMock).toHaveBeenCalledWith("/api/admin/templates/categories/diagnostics", {
      method: "GET",
      signal: controller.signal,
    });
  });
});
