import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const categoriesViewPath = fileURLToPath(new URL("./templates-categories-view.tsx", import.meta.url));

describe("template categories view actions", () => {
  it("confirms archive changes and guards category mutations against double submit", () => {
    const source = readFileSync(categoriesViewPath, "utf8");

    expect(source).toContain("function assertCanManageCategories(): boolean");
    expect(source).toContain("setActionError(categoryActionsAdminOnly)");
    expect(source).toContain('setToast({ type: "error", message: categoryActionsAdminOnly })');
    expect(source).toContain("if (!assertCanManageCategories()) {\n      return;");
    expect(source).toContain("if (!assertCanManageCategories()) {\n      return false;");
    expect(source).toContain("if (isSubmitting) {\n      return;");
    expect(source).toContain("if (busyCategoryId === categoryId) {\n      return;");
    expect(source).toContain("if (busyCategoryId === category.categoryId) {\n      return false;");
    expect(source).toContain("async function handleArchiveToggle(category: AdminTemplateCategory): Promise<boolean>");
    expect(source).toContain("async function handleDeleteCategory(category: AdminTemplateCategory): Promise<boolean>");
    expect(source).toContain("const [categoryPendingArchive, setCategoryPendingArchive]");
    expect(source).toContain("function requestArchiveToggle(category: AdminTemplateCategory)");
    expect(source).toContain("function requestDeleteCategory(category: AdminTemplateCategory)");
    expect(source).toContain("onClick={() => requestArchiveToggle(category)}");
    expect(source).toContain("onClick={() => requestDeleteCategory(category)}");
    expect(source).not.toContain("onClick={() => setCategoryPendingArchive(category)}");
    expect(source).not.toContain("onClick={() => setCategoryPendingDelete(category)}");
    expect(source).not.toContain("onClick={() => void handleArchiveToggle(category)}");
    expect(source).toContain("open={categoryPendingArchive !== null}");
    expect(source).toContain("void handleArchiveToggle(categoryPendingArchive).then((succeeded) => {");
    expect(source).toContain("if (succeeded) {\n              setCategoryPendingArchive(null);");
    expect(source).toContain("void handleDeleteCategory(categoryPendingDelete).then((succeeded) => {");
    expect(source).toContain("if (succeeded) {\n              setCategoryPendingDelete(null);");
    expect(source).toContain("isSubmitting={categoryPendingArchive?.categoryId === busyCategoryId}");
  });

  it("keeps category load/action errors retryable", () => {
    const source = readFileSync(categoriesViewPath, "utf8");

    expect(source).toContain("const { categories, hasError, isFetching, isLoading, refresh }");
    expect(source).toContain("title={error}");
    expect(source).toContain("disabled={isFetching}");
    expect(source).toContain("void refresh().catch(() => undefined);");
  });

  it("sanitizes category names before dangerous confirmation copy", () => {
    const source = readFileSync(categoriesViewPath, "utf8");

    expect(source).toContain("import { sanitizeSensitiveText }");
    expect(source).toContain("function formatCategoryActionName(");
    expect(source).toContain("sanitizeSensitiveText(category?.name, 96)");
    expect(source).toContain("formatCategoryActionName(categoryPendingArchive)");
    expect(source).toContain("formatCategoryActionName(categoryPendingDelete)");
    expect(source).not.toContain('categoryPendingArchive.name}"');
    expect(source).not.toContain('categoryPendingDelete.name}"');
  });
});
