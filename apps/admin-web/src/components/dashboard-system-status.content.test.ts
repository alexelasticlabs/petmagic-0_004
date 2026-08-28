import { describe, expect, it } from "vitest";

import { getDashboardSystemStatusGuidance } from "@/components/dashboard-system-status.content";

describe("dashboard system-status guidance", () => {
  it("explains the intentional store-account compatibility mode and its safe exit", () => {
    expect(getDashboardSystemStatusGuidance("ru", "storeAccountBinding", "degraded")).toEqual({
      description:
        "Новые покупки не заблокированы, но пока принимаются и старые покупки без привязки к аккаунту магазина.",
      nextStep:
        "Подтвердите покупку и восстановление покупки в Apple и Google sandbox, затем включите строгую проверку привязки.",
    });
  });

  it("keeps a useful, non-sensitive fallback for an unknown path", () => {
    expect(getDashboardSystemStatusGuidance("en", "new-check", "unhealthy")).toEqual({
      description: "The path is unavailable or misconfigured; some features may not work.",
      nextStep: "Review service configuration and logs, then run the check again.",
    });
  });
});
