import { readFileSync } from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";

function readSource(relativePath: string): string {
  return readFileSync(path.join(process.cwd(), "src", relativePath), "utf8");
}

describe("admin user query cancellation", () => {
  it("propagates AbortSignal through user detail and analytics helpers", () => {
    const source = readSource("lib/api-client.admin-users.ts");

    expect(source).toContain("export async function fetchAdminUser(\n  userId: string,\n  signal?: AbortSignal");
    expect(source).toContain("export async function fetchAdminUserAnalytics(\n  userId: string,\n  signal?: AbortSignal");
    expect(source).toContain("const encodedUserId = encodePathSegment(userId);");
    expect(source).toContain("apiRequest<AdminUserDetail>(`/api/admin/users/${encodedUserId}`,");
    expect(source).toContain(
      "apiRequest<AdminUserAnalytics>(`/api/admin/users/${encodedUserId}/analytics`,"
    );
    expect(source).toContain("signal");
  });

  it("uses React Query AbortSignal in user profile, users table, promo, and support panels", () => {
    const profileSource = readSource("components/users/use-admin-user-profile.ts");
    const usersPageSource = readSource("components/users-management-page.tsx");
    const promoCodesSource = readSource("components/promo-codes-view.tsx");
    const supportSource = readSource("components/support/use-support-conversation-controller.ts");

    expect(profileSource).toContain("fetchAdminUser(userId!, signal)");
    expect(profileSource).toContain("fetchAdminUserAnalytics(userId!, signal)");
    expect(usersPageSource).toContain(
      "fetchAdminEconomyUserSubscriptionSummary(selectedUserId!, signal)"
    );
    expect(usersPageSource).toContain(
      "fetchUserRowEnrichment<AdminUserAnalytics>(pageUserIds, signal, fetchAdminUserAnalytics)"
    );
    expect(usersPageSource).toContain(
      "fetchUserRowEnrichment<AdminEconomyUserSubscriptionSummary>(\n        premiumPageUserIds,\n        signal,\n        fetchAdminEconomyUserSubscriptionSummary"
    );
    expect(promoCodesSource).toContain("fetchAdminUser(userId, signal)");
    expect(supportSource).toContain("fetchAdminUser(subjectUserId!, signal)");
    expect(supportSource).toContain("fetchAdminUserAnalytics(subjectUserId!, signal)");
    expect(supportSource).toContain("fetchAdminEconomyPurchases(");
    expect(supportSource).toContain("fetchAdminEconomyUserSubscriptionSummary(subjectUserId!, signal)");
  });
});
