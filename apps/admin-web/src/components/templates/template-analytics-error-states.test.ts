import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const templateAnalyticsPagePath = fileURLToPath(
  new URL("./template-analytics-page.tsx", import.meta.url)
);
const templatesAnalyticsHubPagePath = fileURLToPath(
  new URL("./templates-analytics-hub-page.tsx", import.meta.url)
);
const overviewHookPath = fileURLToPath(
  new URL("./use-admin-template-analytics-overview.ts", import.meta.url)
);

describe("template analytics error states", () => {
  it("keeps template analytics detail and hub failures retryable", () => {
    const detailSource = readFileSync(templateAnalyticsPagePath, "utf8");
    const hubSource = readFileSync(templatesAnalyticsHubPagePath, "utf8");
    const overviewHookSource = readFileSync(overviewHookPath, "utf8");

    expect(overviewHookSource).toContain("isFetching: primaryQuery.isFetching || secondaryQuery.isFetching");

    expect(detailSource).toContain("title={error ?? text.loadError}");
    expect(detailSource).toContain("disabled={isFetching}");
    expect(detailSource).toContain("onClick={() => void refresh().catch(() => undefined)}");
    expect(detailSource).toContain("{text.retryAction}");

    expect(hubSource).toContain("title={error ?? text.loadError}");
    expect(hubSource).toContain("disabled={overviewQuery.isFetching}");
    expect(hubSource).toContain("onClick={() => void overviewQuery.refetch().catch(() => undefined)}");
    expect(hubSource).toContain("{text.retryAction}");
  });
});
