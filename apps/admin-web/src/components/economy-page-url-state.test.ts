import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

describe("economy page URL state contract", () => {
  it("restores and shares payment and incident workspace context", () => {
    const pageSource = readFileSync(new URL("./economy-page.tsx", import.meta.url), "utf8");
    const controllerSource = readFileSync(
      new URL("./use-economy-page-controller.ts", import.meta.url),
      "utf8"
    );

    expect(pageSource).toContain('readEconomyWorkspace(searchParams.get("workspace"))');
    expect(pageSource).toContain('setOptional("purchaseStatus", purchaseStatus)');
    expect(pageSource).toContain('setOptional("incidentStatus", incidentStatus, "open")');
    expect(pageSource).toContain('setOptional("incident", selectedIncidentId ?? "")');
    expect(pageSource).toContain("useAdminUrlStateSyncGuard({");
    expect(pageSource).toContain(
      'setWorkspace(readEconomyWorkspace(nextSearchParams.get("workspace")))'
    );
    expect(pageSource).toContain("applyControllerUrlState(nextSearchParams)");
    expect(controllerSource).toContain("const applyUrlState = useCallback");
    expect(controllerSource).toContain(
      'setPurchasePage(readEconomyPageIndex(nextSearchParams.get("purchasePage")))'
    );
    expect(pageSource).toContain(
      "router.replace(nextSearch ? `${pathname}?${nextSearch}` : pathname"
    );
    expect(controllerSource).toContain('searchParams.get("purchaseSearch")');
    expect(controllerSource).toContain('searchParams.get("incidentType")');
    expect(controllerSource).toContain('readEconomyPageIndex(searchParams.get("incidentPage"))');
  });
});
