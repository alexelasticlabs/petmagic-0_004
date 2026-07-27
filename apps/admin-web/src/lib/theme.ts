import { clientLogger } from "@/lib/client-logger";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

export type AdminTheme = "dark" | "light";

export const ADMIN_THEME_STORAGE_KEY = "petmagic_admin_theme";
const ADMIN_THEME_CHANGE_EVENT = "petmagic:admin-theme-change";

/**
 * Runs in the document head before React hydrates. It intentionally uses only
 * browser primitives so the initial color scheme matches a persisted choice
 * without making the server render depend on client storage.
 */
export const ADMIN_THEME_INIT_SCRIPT = `(() => {
  const root = document.documentElement;
  let theme;

  try {
    const storedTheme = window.localStorage.getItem("${ADMIN_THEME_STORAGE_KEY}");
    if (storedTheme === "dark" || storedTheme === "light") {
      theme = storedTheme;
    }
  } catch {
    // Storage can be disabled by browser privacy settings. System preference remains usable.
  }

  if (!theme) {
    try {
      theme = window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
    } catch {
      theme = "dark";
    }
  }

  root.dataset.theme = theme;
  root.style.colorScheme = theme;
})();`;

export function isAdminTheme(value: string | null): value is AdminTheme {
  return value === "dark" || value === "light";
}

export function resolveAdminTheme(storedTheme: string | null, prefersDark: boolean): AdminTheme {
  if (isAdminTheme(storedTheme)) {
    return storedTheme;
  }

  return prefersDark ? "dark" : "light";
}

export function nextAdminTheme(current: AdminTheme): AdminTheme {
  return current === "dark" ? "light" : "dark";
}

function getThemeStorageErrorDetails(error: unknown) {
  return {
    errorName: error instanceof Error ? error.name : "UnknownError",
    errorDigest:
      error && typeof error === "object" && "digest" in error
        ? sanitizeSensitiveText(String((error as { digest?: unknown }).digest ?? ""), 80)
        : undefined,
  };
}

function removeStoredAdminTheme(storageFailureEvent: string): void {
  if (typeof window === "undefined") {
    return;
  }

  try {
    window.localStorage.removeItem(ADMIN_THEME_STORAGE_KEY);
  } catch (error) {
    clientLogger.warn(storageFailureEvent, getThemeStorageErrorDetails(error));
  }
}

export function readStoredAdminTheme(): AdminTheme | null {
  if (typeof window === "undefined") {
    return null;
  }

  try {
    const raw = window.localStorage.getItem(ADMIN_THEME_STORAGE_KEY);
    if (isAdminTheme(raw)) {
      return raw;
    }

    if (raw !== null) {
      removeStoredAdminTheme("theme.storage_invalid_cleanup_failed");
    }

    return null;
  } catch (error) {
    clientLogger.warn("theme.storage_read_failed", getThemeStorageErrorDetails(error));
    return null;
  }
}

export function storeAdminTheme(theme: AdminTheme): void {
  if (typeof window === "undefined") {
    return;
  }

  try {
    window.localStorage.setItem(ADMIN_THEME_STORAGE_KEY, theme);
  } catch (error) {
    clientLogger.warn("theme.storage_write_failed", getThemeStorageErrorDetails(error));
  }
}

export function applyAdminTheme(theme: AdminTheme): void {
  if (typeof document === "undefined") {
    return;
  }

  const root = document.documentElement;
  root.dataset.theme = theme;
  root.style.colorScheme = theme;
}

export function getAppliedAdminTheme(): AdminTheme {
  if (typeof document === "undefined") {
    return "dark";
  }

  const appliedTheme = document.documentElement.dataset.theme ?? null;
  if (isAdminTheme(appliedTheme)) {
    return appliedTheme;
  }

  let prefersDark = true;
  try {
    prefersDark = window.matchMedia("(prefers-color-scheme: dark)").matches;
  } catch {
    // Keep the server fallback when the media query API is unavailable.
  }

  return resolveAdminTheme(readStoredAdminTheme(), prefersDark);
}

export function subscribeToAdminTheme(onThemeChange: () => void): () => void {
  if (typeof window === "undefined") {
    return () => {};
  }

  window.addEventListener(ADMIN_THEME_CHANGE_EVENT, onThemeChange);
  return () => window.removeEventListener(ADMIN_THEME_CHANGE_EVENT, onThemeChange);
}

export function publishAdminThemeChange(): void {
  if (typeof window === "undefined") {
    return;
  }

  window.dispatchEvent(new Event(ADMIN_THEME_CHANGE_EVENT));
}
