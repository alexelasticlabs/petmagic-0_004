import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const profileHookPath = fileURLToPath(new URL("./use-admin-user-profile.ts", import.meta.url));
const detailPagePath = fileURLToPath(new URL("./user-detail-page.tsx", import.meta.url));
const inlineAnalyticsPath = fileURLToPath(new URL("./user-inline-analytics.tsx", import.meta.url));

describe("admin user profile retry states", () => {
  it("exposes fetching state from the shared profile hook", () => {
    const source = readFileSync(profileHookPath, "utf8");

    expect(source).toContain("isFetching: userQuery.isFetching || analyticsQuery.isFetching");
  });

  it("keeps user detail error state retryable and disabled while refetching", () => {
    const source = readFileSync(detailPagePath, "utf8");

    expect(source).toContain("title={text.userAnalyticsLoadError}");
    expect(source).toContain("void refresh().catch(() => undefined);");
    expect(source).toContain("disabled={isFetching}");
    expect(source).toContain("{text.supportRetryAction}");
    expect(source).toContain("href={`/${locale}/users`}");
  });

  it("keeps inline user analytics error state retryable and disabled while refetching", () => {
    const source = readFileSync(inlineAnalyticsPath, "utf8");

    expect(source).toContain("title={text.userAnalyticsLoadError}");
    expect(source).toContain("void refresh().catch(() => undefined);");
    expect(source).toContain("disabled={isFetching}");
    expect(source).toContain("{text.supportRetryAction}");
  });
});
