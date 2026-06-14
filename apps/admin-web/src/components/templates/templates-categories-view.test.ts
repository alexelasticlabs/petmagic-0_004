import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const categoriesViewPath = fileURLToPath(
  new URL("./templates-categories-view.tsx", import.meta.url)
);

describe("template categories view actions", () => {
  it("confirms archive changes and guards category mutations against double submit", () => {
    const source = readFileSync(categoriesViewPath, "utf8");

    expect(source).toContain("function assertCanManageCategories(): boolean");
    expect(source).toContain("setActionError(categoryActionsAdminOnly)");
    expect(source).toContain('setToast({ type: "error", message: categoryActionsAdminOnly })');
    expect(source).toContain("if (!assertCanManageCategories()) {\n      return;");
    expect(source).toContain("if (!assertCanManageCategories()) {\n      return false;");
    expect(source).toContain(
      "const isCategoryActionLocked = isSubmitting || busyCategoryId !== null;"
    );
    expect(source).toContain("if (isCategoryActionLocked) {\n      return;");
    expect(source).toContain("if (isCategoryActionLocked) {\n      return false;");
    expect(source).toContain("if (isCategoryActionLocked || category.totalTemplates > 0) {");
    expect(source).toContain(
      "async function handleArchiveToggle(category: AdminTemplateCategory): Promise<boolean>"
    );
    expect(source).toContain(
      "async function handleDeleteCategory(category: AdminTemplateCategory): Promise<boolean>"
    );
    expect(source).toContain("const [categoryPendingArchive, setCategoryPendingArchive]");
    expect(source).toContain("function requestArchiveToggle(category: AdminTemplateCategory)");
    expect(source).toContain("function requestDeleteCategory(category: AdminTemplateCategory)");
    expect(source).toContain("onClick={() => requestArchiveToggle(category)}");
    expect(source).toContain("onClick={() => requestDeleteCategory(category)}");
    expect(source).not.toContain("onClick={() => setCategoryPendingArchive(category)}");
    expect(source).not.toContain("onClick={() => setCategoryPendingDelete(category)}");
    expect(source).not.toContain("onClick={() => void handleArchiveToggle(category)}");
    expect(source).toContain("open={categoryPendingArchive !== null}");
    expect(source).toContain(
      "void handleArchiveToggle(categoryPendingArchive).then((succeeded) => {"
    );
    expect(source).toContain("if (succeeded) {\n              setCategoryPendingArchive(null);");
    expect(source).toContain(
      "void handleDeleteCategory(categoryPendingDelete).then((succeeded) => {"
    );
    expect(source).toContain("if (succeeded) {\n              setCategoryPendingDelete(null);");
    expect(source).toContain("disabled={isCategoryActionLocked || !newCategoryName.trim()}");
    expect(source).toContain("disabled={isCategoryActionLocked}");
    expect(source).toContain("isCategoryActionLocked || !editingName.trim()");
    expect(source).toContain(
      "isCategoryActionLocked ||\n                                    category.totalTemplates > 0"
    );
    expect(source).toContain(
      "isSubmitting={Boolean(categoryPendingArchive && isCategoryActionLocked)}"
    );
    expect(source).toContain(
      "isSubmitting={Boolean(categoryPendingDelete && isCategoryActionLocked)}"
    );
    expect(source).toContain(
      "if (!isCategoryActionLocked) {\n            setCategoryPendingArchive(null);"
    );
    expect(source).toContain(
      "if (!isCategoryActionLocked) {\n            setCategoryPendingDelete(null);"
    );
    expect(source).not.toContain("if (busyCategoryId === categoryId) {\n      return;");
    expect(source).not.toContain(
      "if (busyCategoryId === category.categoryId) {\n      return false;"
    );
    expect(source).not.toContain("disabled={busyCategoryId === category.categoryId}");
    expect(source).not.toContain(
      "isSubmitting={categoryPendingArchive?.categoryId === busyCategoryId}"
    );
  });

  it("trims and bounds category names before state updates and mutations", () => {
    const source = readFileSync(categoriesViewPath, "utf8");

    expect(source).toContain("const CATEGORY_NAME_MAX_LENGTH = 64;");
    expect(source).toContain("const name = normalizeCategoryName(newCategoryName);");
    expect(source).toContain("const name = normalizeCategoryName(editingName);");
    expect(source).toContain("setNewCategoryName(normalizeCategoryName(event.target.value))");
    expect(source).toContain("setEditingName(normalizeCategoryName(event.target.value))");
    expect(source).toContain("setEditingName(normalizeCategoryName(category.name))");
    expect(source).toContain("maxLength={CATEGORY_NAME_MAX_LENGTH}");
    expect(source).toContain("function normalizeCategoryName(value: string): string");
    expect(source).toContain("return value.trim().slice(0, CATEGORY_NAME_MAX_LENGTH);");
    expect(source).not.toContain("setNewCategoryName(event.target.value)");
    expect(source).not.toContain("setEditingName(event.target.value)");
    expect(source).not.toContain("const name = newCategoryName.trim();");
    expect(source).not.toContain("const name = editingName.trim();");
    expect(source).not.toContain("maxLength={64}");
  });

  it("keeps category load/action errors retryable", () => {
    const source = readFileSync(categoriesViewPath, "utf8");

    expect(source).toContain("const { categories, hasError, isFetching, isLoading, refresh }");
    expect(source).toContain("if (!session || isLoading)");
    expect(source).toContain("title={error}");
    expect(source).toContain("disabled={!session || isFetching}");
    expect(source).toContain(
      "if (!session) {\n                  return;\n                }\n\n                void refresh().catch(() => undefined);"
    );
  });

  it("keeps the existing category table visible during background refetches", () => {
    const source = readFileSync(categoriesViewPath, "utf8");
    const hookSource = readFileSync(
      fileURLToPath(new URL("./use-admin-template-categories.ts", import.meta.url)),
      "utf8"
    );

    expect(hookSource).toContain("isFetching: categoriesQuery.isFetching,");
    expect(hookSource).toContain("isLoading: categoriesQuery.isLoading,");
    expect(hookSource).not.toContain(
      "isLoading: categoriesQuery.isLoading || categoriesQuery.isFetching"
    );
    expect(source).toContain("disabled={!session || isFetching}");
    expect(source).not.toContain("if (!session || isLoading || isFetching)");
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

  it("sanitizes category names and tags before table display", () => {
    const source = readFileSync(categoriesViewPath, "utf8");

    expect(source).toContain("<strong>{sanitizeSensitiveText(category.name, 96)}</strong>");
    expect(source).toContain(".map((tag) => `#${sanitizeSensitiveText(tag, 40)}`)");
    expect(source).not.toContain("<strong>{category.name}</strong>");
    expect(source).not.toContain(".map((tag) => `#${tag}`)");
  });
});
