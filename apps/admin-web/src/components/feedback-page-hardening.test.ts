import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const feedbackPagePath = fileURLToPath(new URL("./feedback-page.tsx", import.meta.url));

describe("feedback page hardening", () => {
  it("uses the shared admin session guard for Admin and Moderator feedback access", () => {
    const source = readFileSync(feedbackPagePath, "utf8");

    expect(source).toContain('import { useRouter } from "next/navigation";');
    expect(source).toContain(
      'import { ensureAdminSession } from "@/components/admin/admin-session";'
    );
    expect(source).toContain("const router = useRouter();");
    expect(source).toContain("ensureAdminSession(locale, router);");
    expect(source).toContain(
      'session?.user.roles.some((role) => role === "Admin" || role === "Moderator") ?? false'
    );
    expect(source).not.toContain('ensureAdminSession(locale, router, { requiredRole: "Admin" });');
  });

  it("debounces free-text filters before changing the backend query", () => {
    const source = readFileSync(feedbackPagePath, "utf8");

    expect(source).toContain("function useDebouncedValue(value: string, delayMs: number)");
    expect(source).toContain("const debouncedCategory = useDebouncedValue(category, 350);");
    expect(source).toContain("const debouncedPlatform = useDebouncedValue(platform, 350);");
    expect(source).toContain("const debouncedTemplateId = useDebouncedValue(templateId, 350);");
    expect(source).toContain("const debouncedUserId = useDebouncedValue(userId, 350);");
    expect(source).toContain("category: debouncedCategory");
    expect(source).toContain("platform: debouncedPlatform");
    expect(source).toContain("templateId: debouncedTemplateId");
    expect(source).toContain("userId: debouncedUserId");
  });

  it("treats the To date filter as the end of the selected day", () => {
    const source = readFileSync(feedbackPagePath, "utf8");

    expect(source).toContain("function dateInputToUtcStart(value: string)");
    expect(source).toContain("function dateInputToUtcEnd(value: string)");
    expect(source).toContain("new Date(`${value}T23:59:59.999Z`).toISOString()");
    expect(source).toContain("fromUtc: dateInputToUtcStart(fromUtc)");
    expect(source).toContain("toUtc: dateInputToUtcEnd(toUtc)");
    expect(source).not.toContain("toUtc: toUtc ? new Date(toUtc).toISOString() : undefined");
  });

  it("guards manual retry and pagination while feedback data is fetching", () => {
    const source = readFileSync(feedbackPagePath, "utf8");

    expect(source).toContain("const isFeedbackFetching = feedbackQuery.isFetching;");
    expect(source).toContain("const isDetailsFetching = detailsQuery.isFetching;");
    expect(source).toContain("disabled={isFeedbackFetching}");
    expect(source).toContain("void feedbackQuery.refetch().catch(() => undefined);");
    expect(source).toContain("disabled={page === 0 || isFeedbackFetching}");
    expect(source).toContain("disabled={!pageData?.hasMore || isFeedbackFetching}");
    expect(source).toContain("aria-label={text.previousPageLabel}");
    expect(source).toContain("aria-label={text.nextPageLabel}");
  });

  it("shows loading and retry states for selected feedback details", () => {
    const source = readFileSync(feedbackPagePath, "utf8");

    expect(source).toContain("detailsLoading:");
    expect(source).toContain("detailsError:");
    expect(source).toContain("selectedId && detailsQuery.isLoading");
    expect(source).toContain("selectedId && detailsQuery.isError");
    expect(source).toContain(
      "description={getAdminErrorMessage(detailsQuery.error, text.detailsError)}"
    );
    expect(source).toContain("disabled={isDetailsFetching}");
    expect(source).toContain("void detailsQuery.refetch().catch(() => undefined);");
  });

  it("shows mutation errors and prevents overlapping feedback detail actions", () => {
    const source = readFileSync(feedbackPagePath, "utf8");

    expect(source).toContain("saveError:");
    expect(source).toContain("refundError:");
    expect(source).toContain("updateMutation.isError");
    expect(source).toContain("refundMutation.isError");
    expect(source).toContain("getAdminErrorMessage(updateMutation.error, text.saveError)");
    expect(source).toContain("getAdminErrorMessage(refundMutation.error, text.refundError)");
    expect(source).toContain("disabled={updateMutation.isPending || refundMutation.isPending}");
    expect(source).toContain(
      "disabled={!details.canRefund || updateMutation.isPending || refundMutation.isPending}"
    );
  });

  it("does not show a free user plan before user context finishes loading", () => {
    const source = readFileSync(feedbackPagePath, "utf8");

    expect(source).toContain("userQuery.isLoading");
    expect(source).toContain("userAnalyticsQuery.isLoading");
    expect(source).toContain("text.userContextLoading");
    expect(source).not.toContain('`${userQuery.data?.isPremium ? "premium" : "free"}');
  });
});
