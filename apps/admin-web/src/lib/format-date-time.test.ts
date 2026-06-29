import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

import { formatDateTime } from "./format-date-time";

const formatDateTimePath = fileURLToPath(new URL("./format-date-time.ts", import.meta.url));

describe("format-date-time", () => {
  it("returns fallback for empty values", () => {
    expect(formatDateTime(null, "ru")).toBe("—");
    expect(formatDateTime(undefined, "en")).toBe("—");
    expect(formatDateTime("", "ru")).toBe("—");
  });

  it("returns fallback for invalid date values", () => {
    expect(formatDateTime("not-a-date", "ru")).toBe("—");
  });

  it("formats valid date values", () => {
    const ruValue = formatDateTime("2026-05-22T12:34:56Z", "ru");
    const enValue = formatDateTime("2026-05-22T12:34:56Z", "en");

    expect(ruValue).not.toBe("—");
    expect(enValue).not.toBe("—");
    expect(ruValue.length).toBeGreaterThan(0);
    expect(enValue.length).toBeGreaterThan(0);
  });

  it("keeps Intl locale selection centralized instead of inline locale branching", () => {
    const source = readFileSync(formatDateTimePath, "utf8");

    expect(source).toContain("const dateTimeIntlLocales: Record<Locale, string> = {");
    expect(source).toContain("new Intl.DateTimeFormat(dateTimeIntlLocales[locale], {");
    expect(source).not.toContain('locale === "ru" ? "ru-RU" : "en-US"');
  });
});
