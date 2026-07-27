import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const loginScreenPath = fileURLToPath(new URL("./admin-login-screen.tsx", import.meta.url));
const loginScreenStylesPath = fileURLToPath(
  new URL("./admin-login-screen.module.css", import.meta.url)
);
const adminIconsPath = fileURLToPath(new URL("./admin-icons.tsx", import.meta.url));
const adminChromeContentPath = fileURLToPath(new URL("./admin-chrome.content.ts", import.meta.url));

describe("admin login screen visual contract", () => {
  it("keeps dashboard preview colors on semantic theme tokens", () => {
    const source = readFileSync(loginScreenPath, "utf8");
    const iconsSource = readFileSync(adminIconsPath, "utf8");
    const styles = readFileSync(loginScreenStylesPath, "utf8");

    expect(source).toContain("AdminLoginPreviewChart");
    expect(source).not.toContain("<svg");
    expect(iconsSource).toContain('stopColor="var(--success)"');
    expect(iconsSource).toContain('stroke="var(--success)"');
    expect(source).not.toMatch(/#[0-9a-fA-F]{3,8}/);
    expect(styles).toContain(".previewDotRed {\n  background: var(--danger);");
    expect(styles).toContain(".previewDotYellow {\n  background: var(--warning);");
    expect(styles).toContain(".previewDotGreen {\n  background: var(--success);");
    expect(styles).toContain(".previewChartGraphic");
    expect(styles).not.toMatch(/#[0-9a-fA-F]{3,8}/);
  });

  it("keeps compact login shell typography from using decorative letter spacing", () => {
    const styles = readFileSync(loginScreenStylesPath, "utf8");
    const nonZeroLetterSpacingRules = [...styles.matchAll(/letter-spacing:\s*([^;]+);/g)]
      .map((match) => match[1].trim())
      .filter((value) => value !== "0");

    expect(nonZeroLetterSpacingRules).toEqual([]);
    expect(styles).toContain("letter-spacing: 0;");
    expect(styles).not.toMatch(/font-size:\s*[^;]*vw/);
    expect(styles).toContain("min-height: 100dvh;");
    expect(styles).toContain("@media (max-width: 820px)");
    expect(styles).toContain(".right {\n    min-height: auto;\n  }");
    expect(styles).not.toContain("100vh");
  });

  it("exposes the login screen title as the page heading", () => {
    const source = readFileSync(loginScreenPath, "utf8");

    expect(source).toContain("<h1 className={styles.welcome}>{copy.welcomeTitle}</h1>");
    expect(source).not.toContain("<h2 className={styles.welcome}>{copy.welcomeTitle}</h2>");
  });

  it("keeps preview window title localized through admin chrome copy", () => {
    const source = readFileSync(loginScreenPath, "utf8");
    const contentSource = readFileSync(adminChromeContentPath, "utf8");

    expect(source).toContain("<LoginDashboardPreview title={copy.previewWindowTitle} />");
    expect(source).toContain("<span className={styles.previewWindowTitle}>{title}</span>");
    expect(source).not.toContain("<span className={styles.previewWindowTitle}>Dashboard</span>");
    expect(contentSource).toContain('previewWindowTitle: "Дашборд"');
    expect(contentSource).toContain('previewWindowTitle: "Dashboard"');
  });
});
