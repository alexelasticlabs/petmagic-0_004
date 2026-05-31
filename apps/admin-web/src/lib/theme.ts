import { clientLogger } from "@/lib/client-logger";

export type AdminTheme = "dark" | "light";

export const ADMIN_THEME_STORAGE_KEY = "petmagic_admin_theme";

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

export function readStoredAdminTheme(): AdminTheme | null {
  if (typeof window === "undefined") {
    return null;
  }

  try {
    const raw = window.localStorage.getItem(ADMIN_THEME_STORAGE_KEY);
    return isAdminTheme(raw) ? raw : null;
  } catch (error) {
    clientLogger.warn("theme.storage_read_failed", { error });
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
    clientLogger.warn("theme.storage_write_failed", { error });
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
