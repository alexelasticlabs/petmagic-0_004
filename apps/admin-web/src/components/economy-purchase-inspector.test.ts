import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const inspectorPath = fileURLToPath(new URL("./economy-purchase-inspector.tsx", import.meta.url));
const economyPagePath = fileURLToPath(new URL("./economy-page.tsx", import.meta.url));
const purchaseSectionPath = fileURLToPath(
  new URL("./economy-page-ledger-purchases-section.tsx", import.meta.url)
);
const operationsPath = fileURLToPath(new URL("./dashboard-operations-health.tsx", import.meta.url));

describe("economy purchase inspector and operations health", () => {
  it("uses URL-selected purchase detail with retry, safe actions, and entity links", () => {
    const inspector = readFileSync(inspectorPath, "utf8");
    const page = readFileSync(economyPagePath, "utf8");
    const section = readFileSync(purchaseSectionPath, "utf8");

    expect(page).toContain('searchParams.get("purchase")');
    expect(page).toContain('setOptional("purchase", selectedPurchaseId ?? "")');
    expect(page).toContain("fetchAdminEconomyPurchase(selectedPurchaseId");
    expect(page).toContain("<EconomyPurchaseInspector");
    expect(section).toContain("onInspectPurchase(item)");
    expect(inspector).toContain("<AdminDetailsDrawer");
    expect(inspector).toContain("<AdminEntityLink");
    expect(inspector).toContain("detail.capabilities.canRefund");
    expect(inspector).toContain("detail.capabilities.canRetryRefund");
    expect(inspector).toContain("onRetry");
  });

  it("renders bounded operations aggregates without raw provider fields", () => {
    const source = readFileSync(operationsPath, "utf8");

    expect(source).toContain("fetchAdminOperationsStatus(signal)");
    expect(source).toContain("data.email.backlogCount");
    expect(source).toContain("data.auditOutbox.deadLetterCount");
    expect(source).toContain("data.workers.generationWorkerHeartbeatAgeSeconds");
    expect(source).not.toContain("payloadJson");
    expect(source).not.toContain("exception");
  });
});
