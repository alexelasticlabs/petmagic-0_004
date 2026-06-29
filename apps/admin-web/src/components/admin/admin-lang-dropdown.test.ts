import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const langDropdownPath = fileURLToPath(new URL("./admin-lang-dropdown.tsx", import.meta.url));
const adminChromeContentPath = fileURLToPath(
  new URL("./admin-chrome.content.ts", import.meta.url)
);
const adminIconsPath = fileURLToPath(new URL("./admin-icons.tsx", import.meta.url));
const adminShellStylesPath = fileURLToPath(new URL("./admin-shell.module.css", import.meta.url));

describe("admin language dropdown", () => {
  it("keeps the locale menu labelled, controlled, and icon-based", () => {
    const source = readFileSync(langDropdownPath, "utf8");
    const contentSource = readFileSync(adminChromeContentPath, "utf8");
    const iconsSource = readFileSync(adminIconsPath, "utf8");
    const stylesSource = readFileSync(adminShellStylesPath, "utf8");

    expect(source).toContain("useEffect, useId, useRef, useState");
    expect(source).toContain("const menuId = useId();");
    expect(source).toContain('import { getAdminChromeCopy }');
    expect(source).toContain("const copy = getAdminChromeCopy(locale).langDropdown;");
    expect(source).toContain("const languageOptions = [");
    expect(contentSource).toContain('languageLabel: "Язык интерфейса"');
    expect(contentSource).toContain('languageLabel: "Interface language"');
    expect(contentSource).toContain('triggerLabel: "Выбрать язык интерфейса"');
    expect(contentSource).toContain('triggerLabel: "Choose interface language"');
    expect(contentSource).toContain('currentLabel: "Текущий язык"');
    expect(contentSource).toContain('currentLabel: "Current language"');
    expect(source).toContain("aria-controls={open ? menuId : undefined}");
    expect(source).toContain("aria-label={triggerLabel}");
    expect(source).toContain("title={triggerLabel}");
    expect(source).toContain(
      '<ul id={menuId} className={styles.localeMenu} role="listbox" aria-label={languageLabel}>'
    );
    expect(source).toContain('import { CaretDownIcon, CheckIcon, GlobeIcon }');
    expect(source).toContain('<span className={styles.localeCheck} aria-label={currentLabel}>');
    expect(source).toContain("<CheckIcon />");
    expect(source).toContain("document.addEventListener(\"mousedown\", handlePointerDown);");
    expect(source).toContain("window.addEventListener(\"keydown\", handleKeyDown);");
    expect(source).not.toContain('locale === "ru" ? "Язык интерфейса" : "Interface language"');
    expect(source).not.toContain(
      'locale === "ru" ? "Выбрать язык интерфейса" : "Choose interface language"'
    );
    expect(source).not.toContain('locale === "ru" ? "Текущий язык" : "Current language"');
    expect(source).not.toContain('className={styles.localeCheck}>✓</span>');
    expect(iconsSource).toContain("export function CheckIcon");
    expect(stylesSource).toContain(".localeCheck {");
    expect(stylesSource).toContain("display: inline-flex;");
    expect(stylesSource).toContain("color: var(--admin-accent);");
    expect(stylesSource).toContain(".localeCheck svg {");
    expect(stylesSource).toContain("max-width: min(14rem, calc(100vw - 1rem));");
    expect(stylesSource).toContain("max-height: calc(100dvh - 5rem);");
    expect(stylesSource).toContain("overflow-y: auto;");
    expect(stylesSource).toContain(".localeOption {\n  display: flex;");
    expect(stylesSource).toContain("min-width: 0;");
    expect(stylesSource).toContain("overflow-wrap: anywhere;");
  });
});
