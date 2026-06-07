import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const generationsPagePath = fileURLToPath(new URL("./generations-page.tsx", import.meta.url));

describe("generations page hardening", () => {
  it("sanitizes generation display strings instead of rendering provider or failure values raw", () => {
    const source = readFileSync(generationsPagePath, "utf8");

    expect(source).toContain("import { sanitizeSensitiveText }");
    expect(source).toContain("function formatSafeText");
    expect(source).toContain("const failureText = formatSafeText(item.failureCode, text.noFailure)");
    expect(source).toContain("const providerText = formatSafeText(item.provider)");
    expect(source).toContain('const modelText = formatSafeText(item.model, "")');
    expect(source).toContain("const templateTitle = formatSafeText(item.templateTitle)");
    expect(source).toContain("const generationIdText = formatShortId(item.generationId)");
    expect(source).toContain("const userIdText = formatShortId(item.userId)");
    expect(source).not.toContain("{item.provider}</AdminBadge>");
    expect(source).not.toContain("{item.model}</div>");
    expect(source).not.toContain("{item.failureCode}");
    expect(source).not.toContain("title={item.generationId}");
    expect(source).not.toContain("title={item.userId}");
  });

  it("localizes generation statuses and keeps unsupported retry/cancel actions out of the UI", () => {
    const source = readFileSync(generationsPagePath, "utf8");

    expect(source).toContain('pending: isRu ? "Ожидает" : "Pending"');
    expect(source).toContain('running: isRu ? "В работе" : "Running"');
    expect(source).toContain('failed: isRu ? "Ошибка" : "Failed"');
    expect(source).toContain('cancelled: isRu ? "Отменена" : "Cancelled"');
    expect(source).toContain("formatStatus(item.status, text)");
    expect(source).toContain("formatTemplateType(item.templateType, text)");
    expect(source).not.toContain("unsupportedActions");
    expect(source).not.toContain("Retry/cancel не показаны");
    expect(source).not.toContain("Retry/cancel are hidden");
    expect(source).not.toContain("backend does not expose");
    expect(source).not.toContain("metaItems={[");
  });

  it("keeps generation search server-backed and disables repeated retry clicks", () => {
    const source = readFileSync(generationsPagePath, "utf8");

    expect(source).toContain("const debouncedProvider = useDebouncedValue(provider, 350)");
    expect(source).toContain("const debouncedUser = useDebouncedValue(user, 350)");
    expect(source).toContain("const debouncedSearch = useDebouncedValue(search, 350)");
    expect(source).toContain("GENERATION_PROVIDER_FILTER_MAX_LENGTH,");
    expect(source).toContain("GENERATION_SEARCH_FILTER_MAX_LENGTH,");
    expect(source).toContain("GENERATION_USER_FILTER_MAX_LENGTH,");
    expect(source).toContain("useAuthSession,");
    expect(source).toContain("const session = useAuthSession();");
    expect(source).toContain(
      'const canViewGenerations = session?.user.roles.includes("Admin") ?? false;'
    );
    expect(source).toContain(
      'ensureAdminSession(locale, router, { requiredRole: "Admin" });'
    );
    expect(source).toContain("setSearch(event.target.value.slice(0, GENERATION_SEARCH_FILTER_MAX_LENGTH));");
    expect(source).toContain("setProvider(event.target.value.slice(0, GENERATION_PROVIDER_FILTER_MAX_LENGTH));");
    expect(source).toContain("setUser(event.target.value.slice(0, GENERATION_USER_FILTER_MAX_LENGTH));");
    expect(source).toContain("maxLength={GENERATION_SEARCH_FILTER_MAX_LENGTH}");
    expect(source).toContain("maxLength={GENERATION_PROVIDER_FILTER_MAX_LENGTH}");
    expect(source).toContain("maxLength={GENERATION_USER_FILTER_MAX_LENGTH}");
    expect(source).toContain("normalizeAdminTemplateGenerationsQuery({");
    expect(source).toContain("fetchAdminTemplateGenerations(query, signal)");
    expect(source).toContain("enabled: canViewGenerations");
    expect(source).toContain("placeholderData: keepPreviousData");
    expect(source).toContain("disabled={!canViewGenerations || generationsQuery.isFetching}");
    expect(source).toContain(
      "if (!canViewGenerations) {\n                  return;\n                }\n\n                void generationsQuery.refetch().catch(() => undefined);",
    );
    expect(source).not.toContain(".filter((item) => item.generationId");
    expect(source).not.toContain(".filter((item) => item.provider");
    expect(source).not.toContain(".filter((item) => item.userId");
    expect(source).not.toContain("setSearch(event.target.value);");
    expect(source).not.toContain("setProvider(event.target.value);");
    expect(source).not.toContain("setUser(event.target.value);");
  });

  it("sources status KPI cards from backend aggregate metrics", () => {
    const source = readFileSync(generationsPagePath, "utf8");

    expect(source).toContain("fetchAdminTemplateGenerationMetrics(signal)");
    expect(source).toContain("adminQueryKeys.templateGenerationMetrics");
    expect(source).toContain("generationMetrics?.totalJobs");
    expect(source).toContain("generationMetrics?.pendingJobs");
    expect(source).toContain("generationMetrics?.runningJobs");
    expect(source).toContain("generationMetrics?.failedJobs");
    expect(source).toContain("generationMetrics?.retryingJobs");
    expect(source).toContain("generationMetrics?.cancelledJobs");
    expect(source).toContain("hint={text.allJobsScope}");
    expect(source).toContain('aria-busy={generationsQuery.isFetching ? "true" : undefined}');
    expect(source).not.toContain('currentPageScope: isRu ? "Текущая страница" : "Current page"');
    expect(source).not.toContain("items.filter((item) => item.status");
  });
});
