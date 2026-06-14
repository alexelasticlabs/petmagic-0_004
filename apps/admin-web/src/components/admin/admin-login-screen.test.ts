import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const loginScreenPath = fileURLToPath(new URL("./admin-login-screen.tsx", import.meta.url));
const loginScreenStylesPath = fileURLToPath(
  new URL("./admin-login-screen.module.css", import.meta.url)
);
const adminIconsPath = fileURLToPath(new URL("./admin-icons.tsx", import.meta.url));

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

  it("keeps compact login headings from using negative letter spacing", () => {
    const styles = readFileSync(loginScreenStylesPath, "utf8");

    expect(styles).toContain("letter-spacing: 0;");
    expect(styles).not.toContain("letter-spacing: -");
  });
});
