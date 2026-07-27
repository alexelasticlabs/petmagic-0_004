import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

describe("generations page URL state contract", () => {
  it("restores and shares generation filters and pagination", () => {
    const source = readFileSync(new URL("./generations-page.tsx", import.meta.url), "utf8");

    expect(source).toContain('readGenerationStatus(searchParams.get("status"))');
    expect(source).toContain('readGenerationPageIndex(searchParams.get("page"))');
    expect(source).toContain('setOptional("provider", debouncedProvider)');
    expect(source).toContain('setOptional("selected", expandedGenerationId ?? "")');
    expect(source).toContain('setExpandedGenerationId(nextSearchParams.get("selected"))');
    expect(source).toContain('setOptional("user", debouncedUser)');
    expect(source).toContain('setOptional("search", debouncedSearch)');
    expect(source).toContain("useAdminUrlStateSyncGuard({");
    expect(source).toContain('setPageIndex(readGenerationPageIndex(nextSearchParams.get("page")))');
    expect(source).toContain("consumeUrlStateApplication(isGenerationUrlStatePending)");
    expect(source).toContain("markUrlStateWritten(nextSearch)");
    expect(source).toContain("router.replace(nextSearch ? `${pathname}?${nextSearch}` : pathname");
  });
});
