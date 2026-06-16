import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const loginCardPath = fileURLToPath(new URL("./login-card.tsx", import.meta.url));
const loginCardStylesPath = fileURLToPath(new URL("./login-card.module.css", import.meta.url));

describe("login card logging", () => {
  it("does not send raw login email to client telemetry", () => {
    const source = readFileSync(loginCardPath, "utf8");

    expect(source).not.toContain("email: normalizedEmail");
    expect(source).toContain("maskedEmail: maskEmail(normalizedEmail)");
    expect(source).toContain('import { maskEmail, sanitizeSensitiveText }');
    expect(source).toContain("function getLoginClientErrorDetails(error: unknown)");
    expect(source).toContain('errorName: error instanceof Error ? error.name : "UnknownError"');
    expect(source).toContain('"digest" in error');
    expect(source).toContain(
      'sanitizeSensitiveText(String((error as { digest?: unknown }).digest ?? ""), 80)'
    );
    expect(source).toContain("...getLoginClientErrorDetails(error)");
    expect(source).not.toContain("sanitizeSensitiveText(error.message, 160)");
    expect(source).not.toContain(
      'clientLogger.warn("auth.legal_acceptance_with_session_versions_failed", {\n        locale,\n        error,'
    );
    expect(source).not.toContain(
      'clientLogger.warn("auth.login_failed", {\n        locale,\n        maskedEmail: maskEmail(normalizedEmail),\n        error,'
    );
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

  it("submits the exact password value while normalizing only email", () => {
    const source = readFileSync(loginCardPath, "utf8");

    expect(source).toContain("const normalizedEmail = email.trim();");
    expect(source).toContain("const submittedPassword = password;");
    expect(source).toContain("const isPasswordValid = submittedPassword.length >= 1;");
    expect(source).toContain("const session = await login(normalizedEmail, submittedPassword);");
    expect(source).not.toContain("const normalizedPassword = password.trim();");
    expect(source).not.toContain("login(normalizedEmail, normalizedPassword)");
  });

  it("keeps login copy centralized and locks mutable fields while submitting", () => {
    const source = readFileSync(loginCardPath, "utf8");
    const stylesSource = readFileSync(loginCardStylesPath, "utf8");

    expect(source).toContain("const authText = {");
    expect(source).toContain("emailPlaceholder: isRu ? \"Введите email\" : \"Enter email\"");
    expect(source).toContain("passwordPlaceholder: isRu ? \"Введите пароль\" : \"Enter password\"");
    expect(source).toContain("setError(authText.validationError);");
    expect(source).toContain("setError(authText.noAccess);");
    expect(source).toContain("aria-busy={isSubmitting}");
    expect(source).toContain("placeholder={authText.emailPlaceholder}");
    expect(source).toContain("placeholder={authText.passwordPlaceholder}");
    expect(source).toContain("disabled={isSubmitting}");
    expect(source).toContain(
      "aria-label={showPassword ? authText.hidePassword : authText.showPassword}"
    );
    expect(source).toContain("{authText.contactText}");
    expect(source).toContain("{authText.contactLinkText}");
    expect(source).toContain("{authText.orText}");
    expect(source).not.toContain('placeholder={isRu ? "Введите email" : "Enter email"}');
    expect(source).not.toContain('placeholder={isRu ? "Введите пароль" : "Enter password"}');
    expect(stylesSource).toContain(".input:disabled {");
    expect(stylesSource).toContain(".eyeButton:disabled {");
    expect(stylesSource).toContain("cursor: not-allowed;");
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

  it("keeps compact auth typography from using decorative letter spacing", () => {
    const source = readFileSync(loginCardStylesPath, "utf8");
    const nonZeroLetterSpacingRules = [...source.matchAll(/letter-spacing:\s*([^;]+);/g)]
      .map((match) => match[1].trim())
      .filter((value) => value !== "0");

    expect(nonZeroLetterSpacingRules).toEqual([]);
    expect(source).toContain("letter-spacing: 0;");
  });
});
