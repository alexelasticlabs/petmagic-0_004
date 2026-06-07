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
    expect(source).toContain("maxLength={PROMO_CODE_MAX_LENGTH}");
    expect(source).toContain("maxLength={PROMO_DESCRIPTION_MAX_LENGTH}");
    expect(source).toContain("maxLength={PROMO_CAMPAIGN_FIELD_MAX_LENGTH}");
    expect(source).toContain("form.code.trim().length > PROMO_CODE_MAX_LENGTH");
    expect(source).not.toContain("form.code.trim().length > 48");
    expect(source).toContain('type="text"');
    expect(source).toContain('pattern="[0-9]*"');
    expect(source).toContain("normalizePromoIntegerInput(event.target.value)");
    expect(source).toContain("maxLength={PROMO_NUMERIC_FIELD_MAX_LENGTH}");
    expect(source).not.toContain('type="number"');
    expect(source).toContain("aria-invalid={isCodeInvalid}");
  });

  it("bounds free-text state updates before payload construction", () => {
    const source = readFileSync(drawerPath, "utf8");

    expect(source).toContain(
      "code: event.target.value.toUpperCase().slice(0, PROMO_CODE_MAX_LENGTH)"
    );
    expect(source).toContain(
      "description: event.target.value.slice(0, PROMO_DESCRIPTION_MAX_LENGTH)"
    );
    expect(source).toContain(
      "campaignName: event.target.value.slice(0, PROMO_CAMPAIGN_FIELD_MAX_LENGTH)"
    );
    expect(source).toContain(
      "campaignChannel: event.target.value.slice(\n                          0,\n                          PROMO_CAMPAIGN_FIELD_MAX_LENGTH\n                        )"
    );
    expect(source).not.toContain("description: event.target.value,\n");
    expect(source).not.toContain("campaignName: event.target.value,\n");
    expect(source).not.toContain("campaignChannel: event.target.value,\n");
  });
});
