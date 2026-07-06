import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, test } from "vitest";

import { nextAdminTheme, resolveAdminTheme } from "@/lib/theme";

const themeSourcePath = fileURLToPath(new URL("./theme.ts", import.meta.url));

describe("resolveAdminTheme", () => {
  test("returns stored dark theme", () => {
    expect(resolveAdminTheme("dark", false)).toBe("dark");
  });

  test("returns stored light theme", () => {
    expect(resolveAdminTheme("light", true)).toBe("light");
  });

  test("falls back to system preference when storage value is invalid", () => {
    expect(resolveAdminTheme("broken", true)).toBe("dark");
    expect(resolveAdminTheme("broken", false)).toBe("light");
  });

  test("falls back to system preference when storage is empty", () => {
    expect(resolveAdminTheme(null, true)).toBe("dark");
    expect(resolveAdminTheme(null, false)).toBe("light");
  });
});

describe("nextAdminTheme", () => {
  test("toggles theme value", () => {
    expect(nextAdminTheme("dark")).toBe("light");
    expect(nextAdminTheme("light")).toBe("dark");
  });
});

describe("theme storage diagnostics", () => {
  test("logs storage failures without raw Error objects", () => {
    const source = readFileSync(themeSourcePath, "utf8");

    expect(source).toContain('import { sanitizeSensitiveText } from "@/lib/sensitive-display";');
    expect(source).toContain("function getThemeStorageErrorDetails(error: unknown)");
    expect(source).toContain("function removeStoredAdminTheme(storageFailureEvent: string)");
    expect(source).toContain('errorName: error instanceof Error ? error.name : "UnknownError"');
    expect(source).toContain(
      'clientLogger.warn("theme.storage_read_failed", getThemeStorageErrorDetails(error));'
    );
    expect(source).toContain(
      'clientLogger.warn("theme.storage_write_failed", getThemeStorageErrorDetails(error));'
    );
    expect(source).not.toContain('clientLogger.warn("theme.storage_read_failed", { error });');
    expect(source).not.toContain('clientLogger.warn("theme.storage_write_failed", { error });');
  });

  test("cleans invalid persisted theme values through safe storage cleanup", () => {
    const source = readFileSync(themeSourcePath, "utf8");

    expect(source).toContain('removeStoredAdminTheme("theme.storage_invalid_cleanup_failed");');
    expect(source).toContain("window.localStorage.removeItem(ADMIN_THEME_STORAGE_KEY);");
    expect(source).toContain(
      "clientLogger.warn(storageFailureEvent, getThemeStorageErrorDetails(error));"
    );
    expect(source).not.toContain("return isAdminTheme(raw) ? raw : null;");
  });
});
