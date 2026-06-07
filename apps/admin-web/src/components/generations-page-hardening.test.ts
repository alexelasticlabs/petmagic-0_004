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

  it("localizes generation statuses and keeps unsupported retry/cancel actions hidden", () => {
    const source = readFileSync(generationsPagePath, "utf8");

    expect(source).toContain('pending: isRu ? "Ожидает" : "Pending"');
    expect(source).toContain('running: isRu ? "В работе" : "Running"');
    expect(source).toContain('failed: isRu ? "Ошибка" : "Failed"');
    expect(source).toContain('cancelled: isRu ? "Отменена" : "Cancelled"');
    expect(source).toContain("formatStatus(item.status, text)");
    expect(source).toContain("formatTemplateType(item.templateType, text)");
    expect(source).toContain("Retry/cancel не показаны");
  });

  it("keeps generation search server-backed and disables repeated retry clicks", () => {
    const source = readFileSync(generationsPagePath, "utf8");

    expect(source).toContain("const debouncedProvider = useDebouncedValue(provider, 350)");
    expect(source).toContain("const debouncedUser = useDebouncedValue(user, 350)");
    expect(source).toContain("const debouncedSearch = useDebouncedValue(search, 350)");
    expect(source).toContain("normalizeAdminTemplateGenerationsQuery({");
    expect(source).toContain("fetchAdminTemplateGenerations(query, signal)");
    expect(source).toContain("placeholderData: keepPreviousData");
    expect(source).toContain("disabled={generationsQuery.isFetching}");
    expect(source).toContain("void generationsQuery.refetch().catch(() => undefined)");
    expect(source).not.toContain(".filter((item) => item.generationId");
    expect(source).not.toContain(".filter((item) => item.provider");
    expect(source).not.toContain(".filter((item) => item.userId");
  });

  it("does not present current-page status counts as global metrics", () => {
    const source = readFileSync(generationsPagePath, "utf8");

    expect(source).toContain('currentPageScope: isRu ? "Текущая страница" : "Current page"');
    expect(source).toContain("hint={text.currentPageScope}");
    expect(source).toContain('aria-busy={generationsQuery.isFetching ? "true" : undefined}');
  });
});
