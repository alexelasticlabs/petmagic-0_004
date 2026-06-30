import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import { readTemplatesCategoriesViewLibrarySource } from "./templates-categories-view.test-source";

const categoriesViewContentPath = fileURLToPath(
  new URL("./templates-categories-view.content.ts", import.meta.url)
);
const catalogStylesPath = fileURLToPath(new URL("./templates-catalog.module.css", import.meta.url));

describe("template categories view actions", () => {
  it("confirms archive changes and guards category mutations against double submit", () => {
    const source = readTemplatesCategoriesViewLibrarySource();

    expect(source).toContain("function assertCanManageCategories(): boolean");
    expect(source).toContain("setActionError(categoryActionsAdminOnly)");
    expect(source).toContain('setToast({ type: "error", message: categoryActionsAdminOnly })');
    expect(source).toContain("if (!assertCanManageCategories()) {\n      return;");
    expect(source).toContain("if (!assertCanManageCategories()) {\n      return false;");
    expect(source).toContain(
      "const isCategoryActionLocked = isSubmitting || busyCategoryId !== null || isFetching;"
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
    expect(source).toContain("function requestArchiveToggle(category: AdminTemplateCategory)");
    expect(source).toContain("function requestDeleteCategory(category: AdminTemplateCategory)");
    expect(source).toContain("onClick={() => onArchiveToggle(category)}");
    expect(source).toContain("onClick={() => onDeleteCategory(category)}");
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
    expect(source).toContain("aria-busy={isCategoryActionLocked}");
    expect(source).toContain("disabled={isCategoryActionLocked}");
    expect(source).toContain("disabled={isCategoryActionLocked}");
    expect(source).toContain("isCategoryActionLocked || !editingName.trim()");
    expect(source).toContain("disabled={isCategoryActionLocked || category.totalTemplates > 0}");
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

  it("bounds category names while typing and trims only before mutations", () => {
    const source = readTemplatesCategoriesViewLibrarySource();

    expect(source).toContain("const CATEGORY_NAME_MAX_LENGTH = 64;");
    expect(source).toContain("const name = normalizeCategoryName(newCategoryName);");
    expect(source).toContain("const name = normalizeCategoryName(editingName);");
    expect(source).toContain("setNewCategoryName(limitCategoryNameInput(event.target.value))");
    expect(source).toContain(
      "onEditingNameChange={(value) => setEditingName(limitCategoryNameInput(value))}"
    );
    expect(source).toContain("onChange={(event) => onEditingNameChange(event.target.value)}");
    expect(source).toContain("setEditingName(normalizeCategoryName(category.name))");
    expect(source).toContain("maxLength={CATEGORY_NAME_MAX_LENGTH}");
    expect(source).toContain("maxLength={categoryNameMaxLength}");
    expect(source).toContain("categoryNameMaxLength={CATEGORY_NAME_MAX_LENGTH}");
    expect(source).toContain("function normalizeCategoryName(value: string): string");
    expect(source).toContain("return value.trim().slice(0, CATEGORY_NAME_MAX_LENGTH);");
    expect(source).toContain("function limitCategoryNameInput(value: string): string");
    expect(source).toContain("return value.slice(0, CATEGORY_NAME_MAX_LENGTH);");
    expect(source).not.toContain("setNewCategoryName(normalizeCategoryName(event.target.value))");
    expect(source).not.toContain("setEditingName(normalizeCategoryName(event.target.value))");
    expect(source).not.toContain("setNewCategoryName(event.target.value)");
    expect(source).not.toContain("setEditingName(event.target.value)");
    expect(source).not.toContain("const name = newCategoryName.trim();");
    expect(source).not.toContain("const name = editingName.trim();");
    expect(source).not.toContain("maxLength={64}");
  });

  it("keeps category load/action errors retryable", () => {
    const source = readTemplatesCategoriesViewLibrarySource();
    const contentSource = readFileSync(categoriesViewContentPath, "utf8");

    expect(source).toContain("const { categories, hasError, isFetching, isLoading, refresh }");
    expect(source).toContain(
      'const canViewCategories = sessionRoles.includes("Admin") || sessionRoles.includes("Moderator");'
    );
    expect(source).toContain("enabled: canViewCategories");
    expect(source).toContain("ensureAdminSession(locale, router);");
    expect(source).toContain("if (!canViewCategories || isLoading)");
    expect(source).toContain("title={error}");
    expect(source).toContain("disabled={!canViewCategories || isFetching}");
    expect(source).toContain("function requestCategoriesRetry()");
    expect(source).toContain("if (!canViewCategories || isFetching) {\n      return;\n    }");
    expect(source).toContain("onClick={requestCategoriesRetry}");
    expect(contentSource).toContain('retry: "Повторить"');
    expect(source).toContain("{categoryText.retry}");
    expect(source).not.toContain("onClick={() => {\n                if (!canViewCategories)");
  });

  it("logs category CRUD failures with sanitized diagnostics", () => {
    const source = readTemplatesCategoriesViewLibrarySource();

    expect(source).toContain('import { clientLogger } from "@/lib/client-logger";');
    expect(source).toContain("function getCategoryActionErrorDetails(error: unknown)");
    expect(source).toContain('errorName: error instanceof Error ? error.name : "UnknownError"');
    expect(source).toContain(
      "function getCategoryActionContext(category?: AdminTemplateCategory | null)"
    );
    expect(source).toContain(
      "categoryId: category?.categoryId ? sanitizeSensitiveText(category.categoryId, 80) : undefined"
    );
    expect(source).toContain(
      "categoryName: category?.name ? sanitizeSensitiveText(category.name, 96) : undefined"
    );
    expect(source).toContain('clientLogger.warn("templates.categories_create_failed", {');
    expect(source).toContain('clientLogger.warn("templates.categories_update_failed", {');
    expect(source).toContain('clientLogger.warn("templates.categories_archive_toggle_failed", {');
    expect(source).toContain('clientLogger.warn("templates.categories_delete_failed", {');
    expect(source).toContain("categoryName: sanitizeSensitiveText(name, 96)");
    expect(source).toContain("categoryId: sanitizeSensitiveText(categoryId, 80)");
    expect(source).toContain("...getCategoryActionErrorDetails(actionError)");
    expect(source).not.toContain('clientLogger.warn("templates.categories_create_failed", { error');
    expect(source).not.toContain('clientLogger.warn("templates.categories_update_failed", { error');
    expect(source).not.toContain(
      'clientLogger.warn("templates.categories_archive_toggle_failed", { error'
    );
    expect(source).not.toContain('clientLogger.warn("templates.categories_delete_failed", { error');
  });

  it("keeps category page copy centralized while preserving sanitized confirmation names", () => {
    const source = readTemplatesCategoriesViewLibrarySource();
    const contentSource = readFileSync(categoriesViewContentPath, "utf8");

    expect(source).toContain(
      'import { getTemplatesCategoriesViewText } from "@/components/templates/templates-categories-view.content";'
    );
    expect(source).toContain(
      "const categoryText = useMemo(() => getTemplatesCategoriesViewText(locale), [locale]);"
    );
    expect(source).toContain("const categoryActionsAdminOnly = categoryText.actionsAdminOnly;");
    expect(source).toContain("title: categoryText.notificationTitle,");
    expect(source).toContain("message: categoryText.createSuccess");
    expect(source).toContain("getActionErrorMessage(actionError, categoryText.createError)");
    expect(source).toContain(
      "message: category.isArchived ? categoryText.restoreSuccess : categoryText.archiveSuccess"
    );
    expect(source).toContain("getActionErrorMessage(actionError, categoryText.archiveError)");
    expect(source).toContain("message: categoryText.deleteSuccess");
    expect(source).toContain("getActionErrorMessage(actionError, categoryText.deleteError)");
    expect(source).toContain("eyebrow={categoryText.heroEyebrow}");
    expect(source).toContain("title={categoryText.heroTitle}");
    expect(source).toContain("description={categoryText.heroDescription}");
    expect(source).toContain(
      "badge={canManageCategories ? categoryText.crudEnabled : categoryText.readOnly}"
    );
    expect(source).toContain("title={categoryText.empty}");
    expect(source).toContain("title={categoryText.deleteDialogTitle}");
    expect(source).toContain("cancelLabel={categoryText.cancel}");
    expect(contentSource).toContain("restoreDialogDescription: (name: string) =>");
    expect(contentSource).toContain("archiveDialogDescription: (name: string) =>");
    expect(contentSource).toContain("deleteDialogDescription: (name: string) =>");
    expect(contentSource).toContain("videoCategoryLabel: (name: string) =>");
    expect(contentSource).toContain("imageCategoryLabel: (name: string) =>");
    expect(contentSource).toContain("editCategoryLabel: (name: string) =>");
    expect(contentSource).toContain("archiveCategoryLabel: (name: string) =>");
    expect(contentSource).toContain("restoreCategoryLabel: (name: string) =>");
    expect(contentSource).toContain("deleteCategoryLabel: (name: string) =>");
    expect(source).toContain(
      "categoryText.restoreDialogDescription(\n                  formatCategoryActionName(categoryPendingArchive)"
    );
    expect(source).toContain(
      "categoryText.archiveDialogDescription(\n                  formatCategoryActionName(categoryPendingArchive)"
    );
    expect(source).toContain(
      "categoryText.deleteDialogDescription(formatCategoryActionName(categoryPendingDelete))"
    );
    expect(source).not.toContain('const isRu = locale === "ru";');
    expect(source).not.toContain('title={isRu ? "Удалить категорию?" : "Delete category?"}');
    expect(source).not.toContain('{isRu ? "Повторить" : "Retry"}');
    expect(source).not.toContain('{isRu ? "Сохранить" : "Save"}');
    expect(source).not.toContain('{isRu ? "Отмена" : "Cancel"}');
  });

  it("keeps the existing category table visible but locks actions during background refetches", () => {
    const source = readTemplatesCategoriesViewLibrarySource();
    const hookSource = readFileSync(
      fileURLToPath(new URL("./use-admin-template-categories.ts", import.meta.url)),
      "utf8"
    );

    expect(hookSource).toContain("isFetching: categoriesQuery.isFetching,");
    expect(hookSource).toContain("isLoading: categoriesQuery.isLoading,");
    expect(hookSource).not.toContain(
      "isLoading: categoriesQuery.isLoading || categoriesQuery.isFetching"
    );
    expect(source).toContain("disabled={!canViewCategories || isFetching}");
    expect(source).toContain(
      "const isCategoryActionLocked = isSubmitting || busyCategoryId !== null || isFetching;"
    );
    expect(source).not.toContain("if (!canViewCategories || isLoading || isFetching)");
  });

  it("sanitizes category names before dangerous confirmation copy", () => {
    const source = readTemplatesCategoriesViewLibrarySource();

    expect(source).toContain("import { sanitizeSensitiveText }");
    expect(source).toContain("function formatCategoryActionName(");
    expect(source).toContain("sanitizeSensitiveText(category?.name, 96)");
    expect(source).toContain("formatCategoryActionName(categoryPendingArchive)");
    expect(source).toContain("formatCategoryActionName(categoryPendingDelete)");
    expect(source).not.toContain('categoryPendingArchive.name}"');
    expect(source).not.toContain('categoryPendingDelete.name}"');
  });

  it("sanitizes category names and tags before table display", () => {
    const source = readTemplatesCategoriesViewLibrarySource();

    expect(source).toContain("<strong>{sanitizeSensitiveText(category.name, 96)}</strong>");
    expect(source).toContain(".map((tag) => `#${sanitizeSensitiveText(tag, 40)}`)");
    expect(source).not.toContain("<strong>{category.name}</strong>");
    expect(source).not.toContain(".map((tag) => `#${tag}`)");
  });

  it("disables category drilldown links while category actions are locked", () => {
    const source = readTemplatesCategoriesViewLibrarySource();
    const stylesSource = readFileSync(catalogStylesPath, "utf8");

    expect(source).toContain("className={`${styles.tableActions} ${styles.categoryTableActions}`}");
    expect(source).toContain('isCategoryActionLocked ? ` ${styles.compactLinkDisabled}` : ""');
    expect(source).toContain("aria-disabled={isCategoryActionLocked}");
    expect(source).toContain("aria-label={categoryText.videoCategoryLabel");
    expect(source).toContain("aria-label={categoryText.imageCategoryLabel");
    expect(source).toContain("aria-label={categoryText.editCategoryLabel");
    expect(source).toContain("aria-label={categoryText.deleteCategoryLabel");
    expect(source).toContain("title={categoryText.videoCategoryLabel");
    expect(source).toContain("title={categoryText.imageCategoryLabel");
    expect(source).toContain("tabIndex={isCategoryActionLocked ? -1 : undefined}");
    expect(source).toContain(
      "if (isCategoryActionLocked) {\n                                event.preventDefault();"
    );
    expect(stylesSource).toContain(".compactLinkDisabled,");
    expect(stylesSource).toContain('.compactLink[aria-disabled="true"]');
    expect(stylesSource).toContain("pointer-events: none;");
    expect(stylesSource).toContain(".categoryInput:focus-visible");
    expect(stylesSource).toContain("box-shadow: var(--focus-ring);");
    expect(stylesSource).toContain(".categoryInput:disabled");
    expect(stylesSource).toContain("cursor: not-allowed;");
    expect(stylesSource).toContain(".categoryTableActions {");
    expect(stylesSource).toContain("grid-template-columns: repeat(auto-fit, minmax(8.5rem, 1fr));");
    expect(stylesSource).toContain(".categoryTableActions > * {");
    expect(stylesSource).toContain("justify-content: center;");
    expect(stylesSource).toContain("min-width: 0;");
    expect(stylesSource).not.toMatch(/\.categoryInput:focus(?!-visible)/);
  });

  it("clears stale category dialogs and editors after list refreshes", () => {
    const source = readTemplatesCategoriesViewLibrarySource();

    expect(source).toContain(
      "const categoryIds = useMemo(\n    () => new Set(categories.map((category) => category.categoryId)),"
    );
    expect(source).toContain("if (isCategoryActionLocked) {\n      return;\n    }");
    expect(source).toContain(
      "categoryPendingArchive !== null && !categoryIds.has(categoryPendingArchive.categoryId)"
    );
    expect(source).toContain(
      "categoryPendingDelete !== null && !categoryIds.has(categoryPendingDelete.categoryId)"
    );
    expect(source).toContain("editingCategoryId !== null && !categoryIds.has(editingCategoryId)");
    expect(source).toContain("queueMicrotask(() => {");
    expect(source).toContain("setCategoryPendingArchive(null);");
    expect(source).toContain("setCategoryPendingDelete(null);");
    expect(source).toContain("setEditingCategoryId(null);");
    expect(source).toContain('setEditingName("");');
    expect(source).not.toContain("useEffect(() => {\n    setCategoryPendingArchive(null);");
  });

  it("clears category edit and confirmation state when switching archive tabs", () => {
    const source = readTemplatesCategoriesViewLibrarySource();

    expect(source).toContain("function switchArchiveFilter(nextFilter: ArchiveFilter)");
    expect(source).toContain("if (isCategoryActionLocked) {\n      return;\n    }");
    expect(source).toContain("setArchiveFilter(nextFilter);");
    expect(source).toContain("setEditingCategoryId(null);");
    expect(source).toContain('setEditingName("");');
    expect(source).toContain("setCategoryPendingArchive(null);");
    expect(source).toContain("setCategoryPendingDelete(null);");
    expect(source).toContain("disabled={isCategoryActionLocked}");
    expect(source).toContain('onClick={() => switchArchiveFilter("active")}');
    expect(source).toContain('onClick={() => switchArchiveFilter("archived")}');
    expect(source).not.toContain('onClick={() => setArchiveFilter("active")}');
    expect(source).not.toContain('onClick={() => setArchiveFilter("archived")}');
  });
});
