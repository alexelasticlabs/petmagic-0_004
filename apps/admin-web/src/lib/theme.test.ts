import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { runInNewContext } from "node:vm";
import { describe, expect, test } from "vitest";

import { ADMIN_THEME_INIT_SCRIPT, nextAdminTheme, resolveAdminTheme } from "@/lib/theme";

const themeSourcePath = fileURLToPath(new URL("./theme.ts", import.meta.url));
const rootLayoutPath = fileURLToPath(new URL("../app/layout.tsx", import.meta.url));

function runThemeInit(options: {
  storedTheme?: string | null;
  prefersDark?: boolean;
  storageThrows?: boolean;
  matchMediaThrows?: boolean;
}) {
  const root = {
    dataset: {} as Record<string, string>,
    style: {} as Record<string, string>,
  };
  const fakeWindow = {
    localStorage: {
      getItem: () => {
        if (options.storageThrows) {
          throw new Error("Storage unavailable");
        }

        return options.storedTheme ?? null;
      },
    },
    matchMedia: () => {
      if (options.matchMediaThrows) {
        throw new Error("Media query unavailable");
      }

      return { matches: options.prefersDark ?? false };
    },
  };

  runInNewContext(ADMIN_THEME_INIT_SCRIPT, {
    document: { documentElement: root },
    window: fakeWindow,
  });

  return root;
}

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

describe("early theme initialization", () => {
  test("applies a persisted light theme before React hydration", () => {
    const root = runThemeInit({ storedTheme: "light", prefersDark: true });

    expect(root.dataset.theme).toBe("light");
    expect(root.style.colorScheme).toBe("light");
  });

  test("applies a light system preference before React hydration when storage is empty", () => {
    const root = runThemeInit({ storedTheme: null, prefersDark: false });

    expect(root.dataset.theme).toBe("light");
    expect(root.style.colorScheme).toBe("light");
  });

  test("falls back to the system preference when storage is unavailable", () => {
    const root = runThemeInit({ storageThrows: true, prefersDark: true });

    expect(root.dataset.theme).toBe("dark");
    expect(root.style.colorScheme).toBe("dark");
  });

  test("keeps the server fallback and CSP nonce wired to the head script", () => {
    const layoutSource = readFileSync(rootLayoutPath, "utf8");

    expect(layoutSource).toContain('import { headers } from "next/headers";');
    expect(layoutSource).toContain('const nonce = (await headers()).get("x-nonce");');
    expect(layoutSource).toContain('data-theme="dark"');
    expect(layoutSource).toContain('style={{ colorScheme: "dark" }}');
    expect(layoutSource).toContain("suppressHydrationWarning");
    expect(layoutSource).toContain("nonce={nonce ?? undefined}");
    expect(layoutSource).toContain("CSP nonce is regenerated per server response");
    expect(layoutSource).toContain(
      "nonce={nonce ?? undefined}\n          suppressHydrationWarning"
    );
    expect(layoutSource).toContain("dangerouslySetInnerHTML={{ __html: ADMIN_THEME_INIT_SCRIPT }}");
    expect(layoutSource).toContain("ADMIN_THEME_INIT_SCRIPT");
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
