import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

describe("moderation page URL state contract", () => {
  it("restores and shares the operational queue context", () => {
    const source = readFileSync(new URL("./moderation-page.tsx", import.meta.url), "utf8");

    expect(source).toContain('readModerationStatus(searchParams.get("status"))');
    expect(source).toContain('readModerationPage(searchParams.get("page"))');
    expect(source).toContain('next.set("search", debouncedSearch)');
    expect(source).toContain("useAdminUrlStateSyncGuard({");
    expect(source).toContain('setStatus(readModerationStatus(nextSearchParams.get("status")))');
    expect(source).toContain("consumeUrlStateApplication(isModerationUrlStatePending)");
    expect(source).toContain('queryKey: ["admin", "dashboard"]');
    expect(source).toContain("router.replace(nextSearch ? `${pathname}?${nextSearch}` : pathname");
  });
});
