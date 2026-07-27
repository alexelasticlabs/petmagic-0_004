import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const componentPath = fileURLToPath(
  new URL("./templates-category-diagnostics.tsx", import.meta.url)
);
const contentPath = fileURLToPath(
  new URL("./templates-category-diagnostics.content.ts", import.meta.url)
);
const hookPath = fileURLToPath(
  new URL("./use-admin-template-category-diagnostics.ts", import.meta.url)
);
const viewPath = fileURLToPath(new URL("./templates-categories-view.tsx", import.meta.url));
const stylesPath = fileURLToPath(
  new URL("./templates-category-diagnostics.module.css", import.meta.url)
);

describe("template category diagnostics workflow", () => {
  it("stays manual, Admin-only, and independent from category CRUD", () => {
    const hookSource = readFileSync(hookPath, "utf8");
    const viewSource = readFileSync(viewPath, "utf8");

    expect(hookSource).toContain("enabled: false");
    expect(hookSource).toContain("retry: false");
    expect(hookSource).toContain("if (!enabled || isFetching)");
    expect(viewSource).toContain("enabled: canManageCategories");
    expect(viewSource).toContain("{canManageCategories ? (");
    expect(viewSource).toContain("<TemplatesCategoryDiagnostics");
    expect(viewSource.match(/categoryDiagnostics\.markStale\(\);/g)).toHaveLength(4);
    expect(viewSource).not.toContain("await categoryDiagnostics.markStale()");
    expect(viewSource).not.toContain("await categoryDiagnostics.run()");
  });

  it("covers not-run, loading, healthy, issues, error, retry, and stale states", () => {
    const componentSource = readFileSync(componentPath, "utf8");
    const contentSource = readFileSync(contentPath, "utf8");
    const hookSource = readFileSync(hookPath, "utf8");

    expect(componentSource).toContain("!hasRun ? (");
    expect(componentSource).toContain("hasRun && isFetching && !diagnostics");
    expect(componentSource).toContain("{hasError ? (");
    expect(componentSource).toContain("{isStale ? (");
    expect(componentSource).toContain("diagnostics.items.length === 0");
    expect(componentSource).toContain("<DiagnosticsResults");
    expect(componentSource).toContain("hasRun ? text.retry : text.run");
    expect(contentSource).toContain('notRunTitle: "Проверка ещё не запускалась"');
    expect(contentSource).toContain('healthyTitle: "Каталог согласован"');
    expect(contentSource).toContain('staleTitle: "Результат мог устареть"');
    expect(hookSource).toContain("hadCachedDiagnosticsAtMount");
    expect(hookSource).toContain("getQueryData<AdminTemplateCategoryDiagnostics>");
    expect(hookSource).toContain("useState(hadCachedDiagnosticsAtMount)");
  });

  it("sanitizes server values and exposes responsive table and definition-list cards", () => {
    const componentSource = readFileSync(componentPath, "utf8");
    const stylesSource = readFileSync(stylesPath, "utf8");

    expect(componentSource).toContain("sanitizeSensitiveText(item.title, 120)");
    expect(componentSource).toContain("sanitizeSensitiveText(item.category, 96)");
    expect(componentSource).toContain("sanitizeSensitiveText(item.templateType, 32)");
    expect(componentSource).toContain("buildTemplateCategoryEditorPath(locale, item)");
    expect(componentSource).toContain("<table className={styles.desktopTable}>");
    expect(componentSource).toContain("<ul className={styles.mobileCards}>");
    expect(componentSource).toContain("<dl>");
    expect(stylesSource).toContain("@media (max-width: 760px)");
    expect(stylesSource).toContain(".desktopTableWrap {\n    display: none;");
    expect(stylesSource).toContain(".mobileCards {\n    min-width: 0;\n    display: grid;");
    expect(stylesSource).toContain("@media (prefers-reduced-motion: reduce)");
  });
});
