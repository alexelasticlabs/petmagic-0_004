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

  it("refreshes user detail and analytics independently before surfacing failures", () => {
    const source = readFileSync(profileHookPath, "utf8");

    expect(source).toContain("await Promise.allSettled([");
    expect(source).toContain("userQuery.refetch()");
    expect(source).toContain("analyticsQuery.refetch()");
    expect(source).toContain('if (userResult.status === "rejected")');
    expect(source).toContain('if (analyticsResult.status === "rejected")');
    expect(source).toContain("if (userResult.value.isError)");
    expect(source).toContain("if (analyticsResult.value.isError)");
    expect(source).not.toContain("await Promise.all([\n      userQuery.refetch()");
  });

  it("keeps user detail error state retryable and disabled while refetching", () => {
    const source = readFileSync(detailPagePath, "utf8");

    expect(source).toContain("title={text.userAnalyticsLoadError}");
    expect(source).toContain("function requestUserProfileRetry()");
    expect(source).toContain("if (!canViewUserProfile || isFetching) {\n      return;\n    }");
    expect(source).toContain("void refresh().catch(() => undefined)");
    expect(source).toContain("onClick={requestUserProfileRetry}");
    expect(source).toContain("disabled={!canViewUserProfile || isFetching}");
    expect(source).toContain("{text.supportRetryAction}");
    expect(source).toContain("href={`/${locale}/users`}");
  });

  it("keeps inline user analytics error state retryable and disabled while refetching", () => {
    const source = readFileSync(inlineAnalyticsPath, "utf8");

    expect(source).toContain("title={text.userAnalyticsLoadError}");
    expect(source).toContain("function requestUserProfileRetry()");
    expect(source).toContain("if (!canViewUserProfile || isFetching) {\n      return;\n    }");
    expect(source).toContain("void refresh().catch(() => undefined)");
    expect(source).toContain("onClick={requestUserProfileRetry}");
    expect(source).toContain("disabled={!canViewUserProfile || isFetching}");
    expect(source).toContain("{text.supportRetryAction}");
  });
});
