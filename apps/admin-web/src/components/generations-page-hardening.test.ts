import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const generationsPagePath = fileURLToPath(new URL("./generations-page.tsx", import.meta.url));
const generationsStylesPath = fileURLToPath(
  new URL("./generations-page.module.css", import.meta.url)
);

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

    expect(source).toContain('eyebrow: isRu ? "Операции" : "Operations"');
    expect(source).toContain(
      'description: isRu\n      ? "Операционный список заданий генерации'
    );
    expect(source).toContain('adminOnly: isRu ? "Только Admin" : "Admin only"');
    expect(source).toContain('total: isRu ? "Всего заданий" : "Total jobs"');
    expect(source).toContain('allJobsScope: isRu ? "Все задания" : "All jobs"');
    expect(source).toContain(
      'emptyDescription: isRu\n      ? "Измените фильтры или дождитесь новых заданий генерации."'
    );
    expect(source).toContain('job: isRu ? "Задание" : "Job"');
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

  it("keeps generation pagination accessible and usable on narrow screens", () => {
    const source = readFileSync(generationsPagePath, "utf8");
    const stylesSource = readFileSync(generationsStylesPath, "utf8");

    expect(source).toContain(
      'previousPageLabel: isRu ? "Предыдущая страница генераций" : "Previous generations page"'
    );
    expect(source).toContain(
      'nextPageLabel: isRu ? "Следующая страница генераций" : "Next generations page"'
    );
    expect(source).toContain("aria-label={text.previousPageLabel}");
    expect(source).toContain("aria-label={text.nextPageLabel}");
    expect(source).toContain("disabled={pageIndex === 0 || generationsQuery.isFetching}");
    expect(source).toContain("disabled={!page?.hasMore || generationsQuery.isFetching}");
    expect(stylesSource).toContain(".pageInfo {\n    width: 100%;");
    expect(stylesSource).toContain(".pager .button {\n    width: 100%;");
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

  it("uses theme tokens for generation status badge colors", () => {
    const source = readFileSync(generationsPagePath, "utf8");

    expect(source).toContain('return "var(--success)";');
    expect(source).toContain('return "var(--danger)";');
    expect(source).toContain('return "var(--neutral)";');
    expect(source).toContain('return "var(--magenta)";');
    expect(source).toContain('return "var(--info)";');
    expect(source).toContain('return "var(--warning)";');
    expect(source).not.toContain('return "#22c55e";');
    expect(source).not.toContain('return "#ef4444";');
    expect(source).not.toContain('return "#64748b";');
    expect(source).not.toContain('return "#a855f7";');
    expect(source).not.toContain('return "#3b82f6";');
    expect(source).not.toContain('return "#f59e0b";');
  });

  it("shows watermark unlock actor together with method, credits, and timestamp", () => {
    const source = readFileSync(generationsPagePath, "utf8");

    expect(source).toContain("watermarkUnlockedBy: isRu ? \"кем\" : \"by\"");
    expect(source).toContain("const watermarkUnlockedByText = item.watermarkUnlockedByUserId");
    expect(source).toContain("formatShortId(item.watermarkUnlockedByUserId)");
    expect(source).toContain("{text.watermarkUnlockedBy} {watermarkUnlockedByText}");
    expect(source).toContain("item.watermarkCreditsSpent");
    expect(source).toContain("item.watermarkUnlockedAtUtc");
  });
});
