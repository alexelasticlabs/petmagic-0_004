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

  it("uses the media-led card layout from the approved catalog direction", () => {
    const catalogSource = readTemplatesCatalogViewLibrarySource();
    const cssSource = readFileSync(catalogCssPath, "utf8");
    const letterSpacingRules = cssSource.match(/letter-spacing:\s*[^;]+;/g) ?? [];

    expect(letterSpacingRules.every((rule) => rule === "letter-spacing: 0;")).toBe(true);
    expect(cssSource).toContain("grid-template-columns: repeat(3, minmax(0, 1fr));");
    expect(cssSource).toContain("grid-template-columns: minmax(0, 43%) minmax(0, 57%);");
    expect(cssSource).toContain("grid-template-rows: minmax(17.25rem, auto) auto;");
    expect(cssSource).toContain("grid-column: 1 / -1;");
    expect(cssSource).toContain("grid-template-columns: repeat(2, minmax(0, 1fr));");
    expect(cssSource).toContain("border-right: 1px solid var(--border-soft);");
    expect(cssSource).toContain("@media (max-width: 560px)");
    expect(cssSource).toContain("aspect-ratio: 16 / 9;");
    expect(cssSource).toContain("grid-template-columns: repeat(3, minmax(0, 1fr)) auto;");
    expect(catalogSource).toContain("className={styles.cardSecondaryAction}");
    expect(catalogSource).toContain("copy.testAction");
    expect(catalogSource).toContain("copy.analyticsAction");
    expect(catalogSource).not.toContain("<AdminMetricStrip");
    expect(cssSource).not.toContain(".catalogMetricStrip {");
    expect(catalogSource).toContain("CaretDownIcon");
    expect(catalogSource).toContain("aria-label={copy.previousPageLabel}");
    expect(catalogSource).toContain("aria-label={copy.nextPageLabel}");
    expect(catalogSource).toContain("className={`${styles.pageIcon} ${styles.pageIconPrevious}`}");
    expect(catalogSource).toContain("className={`${styles.pageIcon} ${styles.pageIconNext}`}");
    expect(catalogSource).not.toContain('{"<"}');
    expect(catalogSource).not.toContain('{">"}');
  });

  it("keeps catalog controls accessible and locked during refreshes", () => {
    const catalogSource = readTemplatesCatalogViewLibrarySource();
    const cssSource = readFileSync(catalogCssPath, "utf8");

    expect(catalogSource).toContain("aria-pressed={showingArchived}");
    expect(catalogSource).toContain('showingArchived={archiveFilter === "archived"}');
    expect(catalogSource).toContain('role="group" aria-label={copy.viewToggleLabel}');
    expect(catalogSource).toContain('aria-pressed={viewMode === "cards"}');
    expect(catalogSource).toContain('aria-pressed={viewMode === "list"}');
    expect(catalogSource).toContain("disabled={isCatalogInteractionLocked}");
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
    expect(cssSource).toContain("width: 0.72rem;");
    expect(cssSource).toContain("height: 0.72rem;");
    expect(cssSource).toContain("opacity: 0.62;");
    expect(cssSource).toContain("flex-shrink: 0;");
  });

  it("shows an operator-facing fallback instead of a blank card when preview media fails", () => {
    const catalogSource = readTemplatesCatalogViewLibrarySource();
    const cssSource = readFileSync(catalogCssPath, "utf8");

    expect(catalogSource).toContain("fallback={mediaFallback}");
    expect(catalogSource).toContain("copy.previewUnavailable");
    expect(catalogSource).toContain("copy.previewUnavailableDescription");
    expect(cssSource).toContain(".cardMediaFallback {");
    expect(cssSource).toContain(".cardMediaFallback strong {");
    expect(cssSource).toContain(".cardMediaFallback span {");
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
    expect(cssSource).toContain("@media (max-width: 760px)");
    expect(cssSource).toContain(".listTable {\n    min-width: 0;\n    display: block;");
    expect(cssSource).toContain(
      ".listTable thead {\n    position: absolute;\n    width: 1px;\n    height: 1px;"
    );
    expect(cssSource).toContain(".listTable td::before {\n    content: attr(data-label);");
    expect(cssSource).toContain(
      ".tableActions {\n    justify-content: flex-start;\n    flex-wrap: wrap;"
    );
    expect(cssSource).toContain(".tableActions .cardActionIconButton {\n    flex: 1 1 2.75rem;");
    expect(cssSource).toContain(".tableActionsCell {\n    min-width: 14rem;");
    expect(catalogSource).toContain("<td data-label={copy.tableTemplate}>");
    expect(catalogSource).toContain(
      "<td data-label={text.actionsLabel} className={styles.tableActionsCell}>"
    );
  });
});
