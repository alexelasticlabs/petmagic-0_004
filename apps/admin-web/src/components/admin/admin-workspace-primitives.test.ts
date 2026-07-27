import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const read = (path: string) => readFileSync(fileURLToPath(new URL(path, import.meta.url)), "utf8");

const queueSource = read("./admin-queue-layout.tsx");
const queueStyles = read("./admin-queue-layout.module.css");
const drawerSource = read("./admin-details-drawer.tsx");
const drawerStyles = read("./admin-details-drawer.module.css");
const actionMenuSource = read("./admin-action-menu.tsx");
const selectionSource = read("./admin-selection-tray.tsx");
const paginationSource = read("./admin-pagination.tsx");
const entityLinkSource = read("./admin-entity-link.tsx");
const globalStyles = read("../../app/globals.css");

describe("admin workspace primitives", () => {
  it("provides a flat queue, workspace and inspector composition", () => {
    expect(queueSource).toContain("export function AdminQueueLayout");
    expect(queueSource).toContain("export function AdminInspector");
    expect(queueSource).toContain("aria-label={queueLabel}");
    expect(queueSource).toContain("aria-label={workspaceLabel}");
    expect(queueStyles).toContain("grid-template-columns: minmax(16rem, 20rem) minmax(0, 1fr)");
    expect(queueStyles).not.toContain(".card");
  });

  it("traps drawer focus, closes with Escape and restores focus", () => {
    expect(drawerSource).toContain('role="dialog"');
    expect(drawerSource).toContain('aria-modal="true"');
    expect(drawerSource).toContain('event.key === "Escape"');
    expect(drawerSource).toContain("focusableSelector");
    expect(drawerSource).toContain("previouslyFocusedElement.focus();");
    expect(drawerSource).toContain('document.body.style.overflow = "hidden";');
    expect(drawerStyles).toContain("@media (prefers-reduced-motion: reduce)");
  });

  it("provides keyboard-operable menus and pagination semantics", () => {
    expect(actionMenuSource).toContain('aria-haspopup="menu"');
    expect(actionMenuSource).toContain('role="menuitem"');
    expect(actionMenuSource).toContain('event.key === "ArrowDown"');
    expect(paginationSource).toContain('aria-current={item.page === normalizedPage ? "page"');
    expect(paginationSource).toContain("export function getAdminPaginationItems");
  });

  it("provides shared selection and entity-link contracts", () => {
    expect(selectionSource).toContain("export function AdminSelectionTray");
    expect(selectionSource).toContain('aria-live="polite"');
    expect(entityLinkSource).toContain("export function AdminEntityLink");
    expect(entityLinkSource).toContain('aria-hidden="true"');
  });

  it("keeps new foundations scoped to CSS Modules and semantic runtime tokens", () => {
    const styles = [
      queueStyles,
      drawerStyles,
      read("./admin-action-menu.module.css"),
      read("./admin-selection-tray.module.css"),
      read("./admin-pagination.module.css"),
      read("./admin-entity-link.module.css"),
    ].join("\n");

    expect(styles).not.toMatch(/#[0-9a-fA-F]{3,8}/);
    expect(styles).not.toContain("rgba(");
    expect(styles).toContain("var(--primary-bg)");
    expect(styles).toContain("var(--border-accent)");
    expect(globalStyles).toContain(
      'Inter, "Segoe UI", "Helvetica Neue", Arial, system-ui, -apple-system, BlinkMacSystemFont'
    );
    expect(globalStyles).toContain('Manrope, Inter, "Segoe UI Variable Display"');
    expect(globalStyles).toContain(
      '--font-mono: ui-monospace, SFMono-Regular, Consolas, "Liberation Mono", Menlo, monospace;'
    );
    expect(globalStyles).toContain("--primary-bg: #1a73e8;");
    expect(globalStyles).toContain("--success: #81c995;");
  });
});
