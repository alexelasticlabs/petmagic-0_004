import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const adminShellPath = fileURLToPath(new URL("./admin-shell.tsx", import.meta.url));
const adminSidebarPath = fileURLToPath(new URL("./admin/admin-sidebar.tsx", import.meta.url));
const adminTopbarPath = fileURLToPath(new URL("./admin/admin-topbar.tsx", import.meta.url));
const adminChromeContentPath = fileURLToPath(
  new URL("./admin/admin-chrome.content.ts", import.meta.url)
);
const adminShellStylesPath = fileURLToPath(
  new URL("./admin/admin-shell.module.css", import.meta.url)
);

describe("admin shell localization", () => {
  it("keeps the document language synchronized with the active locale route", () => {
    const source = readFileSync(adminShellPath, "utf8");

    expect(source).toContain("document.documentElement.lang = locale;");
    expect(source).toContain("}, [locale]);");
  });

  it("keeps the theme control named, stateful, and discoverable", () => {
    const source = readFileSync(adminTopbarPath, "utf8");

    expect(source).toContain("aria-label={nextThemeAriaLabel}");
    expect(source).toContain('aria-pressed={theme === "dark"}');
    expect(source).toContain("title={nextThemeAriaLabel}");

    const styles = readFileSync(adminShellStylesPath, "utf8");
    expect(styles).toContain(".localeTrigger:focus-visible {");
    expect(styles).toContain("box-shadow: var(--focus-ring);");
  });

  it("keeps compact shell identity metadata on the readable semantic token", () => {
    const styles = readFileSync(adminShellStylesPath, "utf8");

    expect(styles).toMatch(/\.brandCaption\s*\{[\s\S]*?color:\s*var\(--text-muted\);/);
    expect(styles).toMatch(/\.userRole\s*\{[\s\S]*?color:\s*var\(--text-muted\);/);
  });

  it("provides a keyboard bypass and a modal mobile navigation focus boundary", () => {
    const shellSource = readFileSync(adminShellPath, "utf8");
    const sidebarSource = readFileSync(adminSidebarPath, "utf8");
    const topbarSource = readFileSync(adminTopbarPath, "utf8");
    const contentSource = readFileSync(adminChromeContentPath, "utf8");
    const stylesSource = readFileSync(adminShellStylesPath, "utf8");

    expect(shellSource).toContain('href="#admin-main"');
    expect(shellSource).toContain('<main id="admin-main"');
    expect(shellSource).toContain("ADMIN_SIDEBAR_FOCUSABLE_SELECTOR");
    expect(shellSource).toContain("initialFocusTarget.focus();");
    expect(shellSource).toContain('event.key === "Escape"');
    expect(shellSource).toContain('event.key !== "Tab"');
    expect(shellSource).toContain("restoreTarget?.focus();");
    expect(shellSource).toContain("inert={isSidebarDrawerMode && sidebarOpen}");

    expect(sidebarSource).toContain('role={isDrawerDialog ? "dialog" : undefined}');
    expect(sidebarSource).toContain('aria-modal={isDrawerDialog ? "true" : undefined}');
    expect(sidebarSource).toContain("data-admin-sidebar-close");
    expect(topbarSource).toContain("ref={sidebarTriggerRef}");

    expect(contentSource).toContain('skipToContent: "Перейти к основному содержимому"');
    expect(contentSource).toContain('skipToContent: "Skip to main content"');
    expect(contentSource).toContain('closeNavigationLabel: "Закрыть навигацию"');
    expect(contentSource).toContain('closeNavigationLabel: "Close navigation"');
    expect(stylesSource).toContain(".skipLink:focus,");
    expect(stylesSource).toContain(".sidebarClose:focus-visible {");
    expect(stylesSource).toContain("visibility: hidden;");
    expect(stylesSource).toContain("visibility: visible;");
  });
});
