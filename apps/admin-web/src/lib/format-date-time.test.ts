import { describe, expect, it } from "vitest";

import { formatDateTime } from "./format-date-time";

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
});
