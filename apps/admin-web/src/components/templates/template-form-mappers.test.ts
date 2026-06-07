import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

import {
  TEMPLATE_TOKEN_COST_MAX_LENGTH,
  normalizeTemplateIntegerInput,
  parseNumber,
  parseOptionalDecimal,
} from "@/components/templates/template-form-mappers";

const basicFieldsPath = fileURLToPath(new URL("./template-basic-fields.tsx", import.meta.url));

describe("template form numeric hardening", () => {
  it("normalizes token cost to bounded digits only", () => {
    expect(normalizeTemplateIntegerInput("12e3.456789")).toBe("123456");
    expect(normalizeTemplateIntegerInput("abc")).toBe("");
    expect(TEMPLATE_TOKEN_COST_MAX_LENGTH).toBe(6);
  });

  it("rejects unsafe token costs instead of producing huge or non-finite values", () => {
    expect(parseNumber("250")).toBe(250);
    expect(parseNumber("1e6")).toBe(0);
    expect(parseNumber("1234567")).toBe(0);
    expect(parseNumber("999999999999999999999")).toBe(0);
    expect(parseNumber("")).toBe(0);
  });

  it("accepts only finite positive asset durations in a bounded range", () => {
    expect(parseOptionalDecimal("12.345")).toBe(12.345);
    expect(parseOptionalDecimal("12.3456")).toBeUndefined();
    expect(parseOptionalDecimal("1e999")).toBeUndefined();
    expect(parseOptionalDecimal("Infinity")).toBeUndefined();
    expect(parseOptionalDecimal("-1")).toBeUndefined();
    expect(parseOptionalDecimal("7200")).toBeUndefined();
  });

  it("keeps token cost input bounded in the editor UI", () => {
    const source = readFileSync(basicFieldsPath, "utf8");

    expect(source).toContain("normalizeTemplateIntegerInput(event.target.value)");
    expect(source).toContain("maxLength={TEMPLATE_TOKEN_COST_MAX_LENGTH}");
    expect(source).toContain('pattern="[0-9]*"');
  });
});
