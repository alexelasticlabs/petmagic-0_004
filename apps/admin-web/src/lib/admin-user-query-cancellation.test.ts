import { readFileSync } from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";

import { readSupportConversationControllerLibrarySource } from "@/components/support/support-conversation-controller.test-source";

function readSource(relativePath: string): string {
  return readFileSync(path.join(process.cwd(), "src", relativePath), "utf8");
}

describe("admin user query cancellation", () => {
  it("propagates AbortSignal through profile, analytics, and user-scoped support helpers", () => {
    const source = readSource("lib/api-client.admin-users.ts");
    const supportSource = readSource("lib/api-client.support.ts");

    expect(source).toContain(
      "export async function fetchAdminUser(\n  userId: string,\n  signal?: AbortSignal"
    );
    expect(source).toContain(
      "export async function fetchAdminUserAnalytics(\n  userId: string,\n  signal?: AbortSignal"
    );
    expect(source).toContain("const encodedUserId = encodePathSegment(userId);");
    expect(source).toContain("apiRequest<AdminUserDetail>(`/api/admin/users/${encodedUserId}`,");
    expect(source).toContain(
      "apiRequest<AdminUserAnalytics>(`/api/admin/users/${encodedUserId}/analytics`,"
    );
    expect(source).toContain("signal");
    expect(supportSource).toContain("export async function fetchAdminUserSupportTickets(");
    expect(supportSource).toContain("signal?: AbortSignal;");
    expect(supportSource).toContain("`/api/admin/users/${encodedUserId}/support/tickets${query}`");
    expect(supportSource).toContain("signal: options?.signal,");
  });

  it("uses React Query AbortSignal for registry metrics and lazy dossier data without list N+1", () => {
    const profileSource = readSource("components/users/use-admin-user-profile.ts");
    const usersPageSource = readSource("components/users-management-page.tsx");
    const userDetailSource = readSource("components/users/user-detail-page.tsx");
    const userSupportSource = readSource("components/users/user-support-tickets-panel.tsx");
    const promoCodesSource = readSource("components/promo-codes-view.tsx");
    const supportSource = readSupportConversationControllerLibrarySource();

    expect(profileSource).toContain("fetchAdminUser(userId!, signal)");
    expect(profileSource).toContain("fetchAdminUserAnalytics(userId!, signal)");
    expect(usersPageSource).toContain(
      "queryFn: ({ signal }) => fetchAdminUserDashboardMetrics(signal),"
    );
    expect(usersPageSource).not.toContain("fetchAdminUserAnalytics(");
    expect(usersPageSource).not.toContain("fetchAdminEconomyUserSubscriptionSummary(");
    expect(usersPageSource).not.toContain("fetchUserRowEnrichment");
    expect(userDetailSource).toContain(
      'enabled: canViewUserProfile && activeTab === "content" && Boolean(userId),'
    );
    expect(userDetailSource).toContain(
      "queryFn: ({ signal }) => fetchAdminUserPets(userId, signal),"
    );
    expect(userDetailSource).toContain('{activeTab === "support" ? (');
    expect(userSupportSource).toContain(
      "fetchAdminUserSupportTickets(userId, { page, pageSize: SUPPORT_PAGE_SIZE, signal })"
    );
    expect(promoCodesSource).toContain("fetchAdminUser(userId, signal)");
    expect(supportSource).toContain("fetchAdminUser(subjectUserId!, signal)");
    expect(supportSource).toContain("fetchAdminUserAnalytics(subjectUserId!, signal)");
    expect(supportSource).toContain("fetchAdminEconomyPurchases(");
    expect(supportSource).toContain(
      "fetchAdminEconomyUserSubscriptionSummary(subjectUserId!, signal)"
    );
  });
});
