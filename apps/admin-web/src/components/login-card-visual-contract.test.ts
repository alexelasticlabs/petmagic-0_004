import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const loginCardPath = fileURLToPath(new URL("./login-card.tsx", import.meta.url));
const loginCardStylesPath = fileURLToPath(new URL("./login-card.module.css", import.meta.url));

describe("login card visual contract", () => {
  it("uses shared admin icons instead of local inline SVG art", () => {
    const source = readFileSync(loginCardPath, "utf8");
    const cssSource = readFileSync(loginCardStylesPath, "utf8");

    expect(source).toContain('from "@/components/admin/admin-icons"');
    expect(source).toContain("MailIcon");
    expect(source).toContain("LockIcon");
    expect(source).toContain("EyeIcon");
    expect(source).toContain("EyeOffIcon");
    expect(source).toContain("className={styles.inputIcon}");
    expect(source).not.toContain("<svg");
    expect(source).not.toContain("function IconEmail");
    expect(source).not.toContain("function IconLock");
    expect(source).not.toContain("function IconEye");
    expect(cssSource).toContain(".inputIcon {");
    expect(cssSource).toContain(".eyeButton svg {");
  });
});
