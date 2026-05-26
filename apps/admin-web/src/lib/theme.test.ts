import { describe, expect, test } from "vitest";

import { nextAdminTheme, resolveAdminTheme } from "@/lib/theme";

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
