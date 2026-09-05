import { describe, expect, it } from "vitest";

import { getDictionary } from "@/lib/i18n";

import { getTemplateEditorErrorMessage } from "./template-editor-error-message";

describe("template editor media errors", () => {
  for (const locale of ["ru", "en"] as const) {
    const text = getDictionary(locale);
    it(`explains media validation and retry errors in ${locale}`, () => {
      expect(
        getTemplateEditorErrorMessage(
          { validationErrors: ["templates.preview_duration_invalid"] },
          text,
          "fallback"
        )
      ).toBe(text.editorPreviewDurationError);
      expect(
        getTemplateEditorErrorMessage(
          { code: "templates.media_metadata_invalid" },
          text,
          "fallback"
        )
      ).toBe(text.editorMediaReadError);
      expect(
        getTemplateEditorErrorMessage({ code: "templates.media_storage_failed" }, text, "fallback")
      ).toBe(text.editorMediaRetryError);
    });
  }

  it("keeps unknown technical details out of user feedback", () => {
    expect(
      getTemplateEditorErrorMessage(
        { code: "templates.unknown", validationErrors: ["templates.secret_internal_detail"] },
        getDictionary("ru"),
        "fallback"
      )
    ).toBe("fallback");
    expect(getTemplateEditorErrorMessage(null, getDictionary("en"), "fallback")).toBe("fallback");
  });
});
