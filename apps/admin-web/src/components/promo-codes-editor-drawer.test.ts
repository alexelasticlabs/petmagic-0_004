import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const drawerPath = fileURLToPath(new URL("./promo-codes-editor-drawer.tsx", import.meta.url));

describe("promo codes editor drawer production form", () => {
  it("uses localized copy instead of hardcoded Russian placeholders", () => {
    const source = readFileSync(drawerPath, "utf8");

    expect(source).toContain("text.promoCodesDescriptionPlaceholder");
    expect(source).toContain("text.promoCodesCampaignNamePlaceholder");
    expect(source).toContain("text.promoCodesCampaignChannelPlaceholder");
    expect(source).toContain("text.promoCodesFormSummaryLabel");
    expect(source).not.toContain("Например:");
    expect(source).not.toContain("Сводка параметров промокода");
    expect(source).not.toContain("/ чел");
  });

  it("keeps submit guarded by client validation and mutation state", () => {
    const source = readFileSync(drawerPath, "utf8");

    expect(source).toContain("const isSubmitDisabled =");
    expect(source).toContain("isMutating || isCodeInvalid || hasInvalidNumber || hasInvalidDateWindow");
    expect(source).toContain("disabled={isSubmitDisabled}");
    expect(source).toContain("minLength={4}");
    expect(source).toContain("maxLength={48}");
    expect(source).toContain("maxLength={160}");
    expect(source).toContain('type="text"');
    expect(source).toContain('pattern="[0-9]*"');
    expect(source).toContain("normalizePromoIntegerInput(event.target.value)");
    expect(source).toContain("maxLength={PROMO_NUMERIC_FIELD_MAX_LENGTH}");
    expect(source).not.toContain('type="number"');
    expect(source).toContain("aria-invalid={isCodeInvalid}");
  });
});
