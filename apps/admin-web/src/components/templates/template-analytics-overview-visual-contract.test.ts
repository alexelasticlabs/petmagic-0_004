import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const overviewPath = fileURLToPath(
  new URL("./template-analytics-overview-sections.tsx", import.meta.url)
);

describe("template analytics overview visual contract", () => {
  it("keeps chart and status ring colors on semantic theme tokens", () => {
    const source = readFileSync(overviewPath, "utf8");

    expect(source).toContain('stopColor="var(--success)" stopOpacity="0.36"');
    expect(source).toContain('stopColor="var(--success)" stopOpacity="0.02"');
    expect(source).toContain('color: "var(--success)"');
    expect(source).toContain('color: "var(--danger)"');
    expect(source).toContain('color: "var(--info)"');
    expect(source).toContain('color: "var(--warning)"');
    expect(source).toContain("conic-gradient(var(--surface-3) 0 100%)");
    expect(source).not.toContain("rgba(74, 222, 128");
    expect(source).not.toContain("#22c55e");
    expect(source).not.toContain("#f87171");
    expect(source).not.toContain("#7dd3fc");
    expect(source).not.toContain("#fcd34d");
    expect(source).not.toContain("conic-gradient(#1f3651 0 100%)");
  });
});
