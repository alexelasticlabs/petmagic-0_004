import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const loginCardPath = fileURLToPath(new URL("./login-card.tsx", import.meta.url));

describe("login card logging", () => {
  it("does not send raw login email to client telemetry", () => {
    const source = readFileSync(loginCardPath, "utf8");

    expect(source).not.toContain("email: normalizedEmail");
    expect(source).toContain("maskedEmail: maskEmail(normalizedEmail)");
  });

  it("keeps credential failures generic but surfaces safe network and server login errors", () => {
    const source = readFileSync(loginCardPath, "utf8");

    expect(source).toContain("import { getAdminErrorMessage }");
    expect(source).toContain("function resolveLoginErrorMessage");
    expect(source).toContain("if (status === 400 || status === 401)");
    expect(source).toContain("return getAdminErrorMessage(error, fallback)");
    expect(source).toContain("setError(resolveLoginErrorMessage(error, text.loginFailed))");
    expect(source).not.toContain("setError(text.loginFailed);");
  });

  it("prefetches the role-aware landing page for restored admin sessions", () => {
    const source = readFileSync(loginCardPath, "utf8");

    expect(source).toContain("if (!hasAdminPanelAccess(existingSession?.user.roles))");
    expect(source).toContain("getDefaultAdminPath(locale, existingSession?.user.roles)");
    expect(source).toContain(
      "router.prefetch(getDefaultAdminPath(locale, existingSession?.user.roles))"
    );
    expect(source).not.toContain("router.prefetch(`/${locale}/dashboard`)");
    expect(source).not.toContain(": `/${locale}/dashboard`");
  });
});
