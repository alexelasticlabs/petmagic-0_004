import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import { readTemplatesCatalogViewLibrarySource } from "./templates-catalog-view.test-source";
import { readTemplatesCategoriesViewLibrarySource } from "./templates-categories-view.test-source";

const catalogCssPath = fileURLToPath(new URL("./templates-catalog.module.css", import.meta.url));

describe("templates catalog visual contract", () => {
  it("keeps template status colors on semantic theme tokens", () => {
    const catalogSource = readTemplatesCatalogViewLibrarySource();
    const categoriesSource = readTemplatesCategoriesViewLibrarySource();

    expect(catalogSource).toContain('Draft: "var(--warning)"');
    expect(catalogSource).toContain('Active: "var(--success)"');
    expect(catalogSource).toContain('Archived: "var(--text-muted)"');
    expect(categoriesSource).toContain('Video: "var(--success)"');
    expect(categoriesSource).toContain('Image: "var(--info)"');
    expect(categoriesSource).toContain('Archived: "var(--text-muted)"');
    expect(catalogSource).not.toMatch(/#[0-9a-fA-F]{3,8}/);
    expect(categoriesSource).not.toMatch(/#[0-9a-fA-F]{3,8}/);
  });

  it("does not depend on generated CSS module names for composed table styling", () => {
    const catalogSource = readTemplatesCatalogViewLibrarySource();
    const cssSource = readFileSync(catalogCssPath, "utf8");

    expect(catalogSource).toContain("className={`${adminTableStyles.table} ${styles.listTable}`}");
    expect(catalogSource).toContain("className={styles.listStatusBadge}");
    expect(catalogSource).toContain("className={styles.cardStatusBadge}");
    expect(cssSource).toContain(".listTable {");
    expect(cssSource).toContain(".listStatusBadge {");
    expect(cssSource).toContain(".cardStatusBadge {");
    expect(cssSource).not.toContain("admin-primitives-module__");
    expect(cssSource).not.toContain("__gNhzuG__");
  });

  it("keeps compact catalog text stable and pagers icon-based", () => {
    const catalogSource = readTemplatesCatalogViewLibrarySource();
    const cssSource = readFileSync(catalogCssPath, "utf8");
    const letterSpacingRules = cssSource.match(/letter-spacing:\s*[^;]+;/g) ?? [];

    expect(letterSpacingRules.every((rule) => rule === "letter-spacing: 0;")).toBe(true);
    expect(cssSource).toContain(".bigMetric {");
    expect(cssSource).toContain("font-size: 1.78rem;");
    expect(cssSource).toContain(".heroCopy h1 {\n    font-size: 1.65rem;");
    expect(cssSource).toContain(".bigMetric {\n    font-size: 1.56rem;");
    expect(cssSource).not.toMatch(/font-size:\s*[^;]*vw/);
    expect(catalogSource).toContain("CaretDownIcon");
    expect(catalogSource).toContain("aria-label={copy.previousPageLabel}");
    expect(catalogSource).toContain("aria-label={copy.nextPageLabel}");
    expect(catalogSource).toContain("className={`${styles.pageIcon} ${styles.pageIconPrevious}`}");
    expect(catalogSource).toContain("className={`${styles.pageIcon} ${styles.pageIconNext}`}");
    expect(catalogSource).not.toContain('{"<"}');
    expect(catalogSource).not.toContain('{">"}');
  });

  it("keeps active catalog tabs and view toggles non-interactive", () => {
    const catalogSource = readTemplatesCatalogViewLibrarySource();
    const cssSource = readFileSync(catalogCssPath, "utf8");

    expect(catalogSource).toContain(
      'disabled={archiveFilter === "active" || isCatalogInteractionLocked}'
    );
    expect(catalogSource).toContain(
      'disabled={archiveFilter === "archived" || isCatalogInteractionLocked}'
    );
    expect(catalogSource).toContain(
      'disabled={viewMode === "cards" || isCatalogInteractionLocked}'
    );
    expect(catalogSource).toContain('disabled={viewMode === "list" || isCatalogInteractionLocked}');
    expect(cssSource).toContain(".tab:not(:disabled):hover");
    expect(cssSource).toContain(".viewButton:not(:disabled):hover,");
    expect(cssSource).toContain(".viewButtonActive:not(:disabled):hover");
    expect(cssSource).toContain(".tab:disabled,");
    expect(cssSource).toContain(".viewButtonActive:disabled");
    expect(cssSource).toContain("cursor: not-allowed;");
    expect(cssSource).toContain("opacity: 0.68;");
    expect(cssSource).toContain("transform: none;");
  });

  it("keeps card metric icon layout in the catalog stylesheet", () => {
    const catalogSource = readTemplatesCatalogViewLibrarySource();
    const cssSource = readFileSync(catalogCssPath, "utf8");

    expect(catalogSource).toContain("DollarIcon");
    expect(catalogSource).toContain("ImageIcon");
    expect(catalogSource).toContain("PlayCircleIcon");
    expect(catalogSource).toContain("CancelCircleIcon");
    expect(catalogSource).toContain("className={styles.cardMetricIcon}");
    expect(catalogSource).not.toContain("<svg");
    expect(catalogSource).not.toContain('strokeWidth="1.7"');
    expect(catalogSource).not.toContain("M12 2l2.4 7.4H22");
    expect(catalogSource).not.toContain(
      'style={{ width: "0.85rem", height: "0.85rem", opacity: 0.7, flexShrink: 0 }}'
    );
    expect(cssSource).toContain(".cardMetricIcon {");
    expect(cssSource).toContain("width: 0.85rem;");
    expect(cssSource).toContain("height: 0.85rem;");
    expect(cssSource).toContain("opacity: 0.7;");
    expect(cssSource).toContain("flex-shrink: 0;");
  });

  it("keeps list action controls stable in the sticky catalog table column", () => {
    const catalogSource = readTemplatesCatalogViewLibrarySource();
    const cssSource = readFileSync(catalogCssPath, "utf8");

    expect(catalogSource).toContain("className={styles.tableActionsCell}");
    expect(catalogSource).toContain("className={styles.tableActions}");
    expect(cssSource).toContain(".tableActionsCell {\n  min-width: 13.25rem;");
    expect(cssSource).toContain(
      ".tableActions {\n  justify-content: flex-end;\n  flex-wrap: nowrap;"
    );
    expect(cssSource).toContain(".tableActions .cardActionIconButton {\n  flex: 0 0 1.9rem;");
    expect(cssSource).toContain(
      "@media (max-width: 760px) {\n  .catalogHero {\n    grid-template-columns: 1fr;"
    );
    expect(cssSource).toContain(
      ".tableActions {\n    justify-content: flex-start;\n    flex-wrap: wrap;"
    );
    expect(cssSource).toContain(".tableActions .cardActionIconButton {\n    flex: 1 1 2.1rem;");
    expect(cssSource).toContain(".tableActionsCell {\n    min-width: 14rem;");
  });
});
