import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

import {
  TEMPLATE_CATEGORY_MAX_LENGTH,
  TEMPLATE_MUSIC_DESCRIPTION_MAX_LENGTH,
  TEMPLATE_MODEL_MAX_LENGTH,
  TEMPLATE_PROMPT_MAX_LENGTH,
  TEMPLATE_REQUIREMENT_MAX_LENGTH,
  TEMPLATE_SHORT_DESCRIPTION_MAX_LENGTH,
  TEMPLATE_TAG_MAX_COUNT,
  TEMPLATE_TAG_MAX_LENGTH,
  TEMPLATE_TITLE_MAX_LENGTH,
  TEMPLATE_TOKEN_COST_MAX_LENGTH,
  createFormFromTemplate,
  createInitialTemplateForm,
  normalizeTemplateText,
  normalizeTemplateTextInput,
  normalizeTemplateIntegerInput,
  parseNumber,
  parseOptionalDecimal,
} from "@/components/templates/template-form-mappers";
import type { AdminTemplate } from "@/lib/api-client";

const basicFieldsPath = fileURLToPath(new URL("./template-basic-fields.tsx", import.meta.url));
const editorSectionsPath = fileURLToPath(
  new URL("./template-editor-sections.tsx", import.meta.url)
);
const editorControllerPath = fileURLToPath(
  new URL("./use-template-editor-controller.ts", import.meta.url)
);
const formMappersPath = fileURLToPath(new URL("./template-form-mappers.ts", import.meta.url));
const editorStylesPath = fileURLToPath(new URL("./template-editor.module.css", import.meta.url));

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

  it("normalizes template text before building API payloads", () => {
    expect(normalizeTemplateText("  Hello\n\n  world  ", 20)).toBe("Hello world");
    expect(normalizeTemplateText("x".repeat(80), 12)).toBe("x".repeat(12));
    expect(normalizeTemplateTextInput(`  ${"x".repeat(80)}  `, 12)).toBe(`  ${"x".repeat(10)}`);

    const source = readFileSync(formMappersPath, "utf8");

    expect(TEMPLATE_TITLE_MAX_LENGTH).toBe(60);
    expect(TEMPLATE_SHORT_DESCRIPTION_MAX_LENGTH).toBe(120);
    expect(TEMPLATE_CATEGORY_MAX_LENGTH).toBe(64);
    expect(TEMPLATE_TAG_MAX_LENGTH).toBe(32);
    expect(TEMPLATE_TAG_MAX_COUNT).toBe(12);
    expect(TEMPLATE_MODEL_MAX_LENGTH).toBe(128);
    expect(TEMPLATE_PROMPT_MAX_LENGTH).toBe(1000);
    expect(source).toContain("title: normalizeTemplateText(form.title, TEMPLATE_TITLE_MAX_LENGTH)");
    expect(source).toContain("TEMPLATE_SHORT_DESCRIPTION_MAX_LENGTH");
    expect(source).toContain(
      "category: normalizeTemplateText(form.category, TEMPLATE_CATEGORY_MAX_LENGTH)"
    );
    expect(source).toContain(
      "imageModel: normalizeTemplateText(form.imageModel, TEMPLATE_MODEL_MAX_LENGTH)"
    );
    expect(source).toContain(
      "imagePrompt: normalizeTemplateText(form.imagePrompt, TEMPLATE_PROMPT_MAX_LENGTH)"
    );
    expect(source).toContain("preprocessingPrompt: normalizeTemplateText(");
    expect(source).toContain("form.preprocessingPrompt");
    expect(source).toContain(
      "klingPrompt: normalizeTemplateText(form.klingPrompt, TEMPLATE_PROMPT_MAX_LENGTH)"
    );
    expect(source).toContain("normalizeTemplateText(tag, TEMPLATE_TAG_MAX_LENGTH)");
    expect(source).toContain(".slice(0, TEMPLATE_TAG_MAX_COUNT)");
    expect(source).toContain("normalizeTemplateText(fileName, TEMPLATE_ASSET_METADATA_MAX_LENGTH)");
    expect(source).toContain(
      "normalizeTemplateText(contentType, TEMPLATE_ASSET_CONTENT_TYPE_MAX_LENGTH)"
    );
    expect(source).toContain(
      "normalizeTemplateText(inferFileName(url), TEMPLATE_ASSET_METADATA_MAX_LENGTH)"
    );
    expect(source).toContain("value > 0 ? value : undefined");
    expect(source).not.toContain("title: form.title");
    expect(source).not.toContain("imagePrompt: form.imagePrompt");
    expect(source).not.toContain(".map((tag) => tag.trim())");
  });

  it("bounds template editor text state before payload construction", () => {
    const basicFieldsSource = readFileSync(basicFieldsPath, "utf8");
    const editorSectionsSource = readFileSync(editorSectionsPath, "utf8");

    expect(TEMPLATE_REQUIREMENT_MAX_LENGTH).toBe(160);
    expect(TEMPLATE_MUSIC_DESCRIPTION_MAX_LENGTH).toBe(240);
    expect(basicFieldsSource).toContain("maxLength={TEMPLATE_TITLE_MAX_LENGTH}");
    expect(basicFieldsSource).toContain("maxLength={TEMPLATE_SHORT_DESCRIPTION_MAX_LENGTH}");
    expect(basicFieldsSource).toContain("maxLength={PET_PHOTO_REQUIREMENTS_INPUT_MAX_LENGTH}");
    expect(basicFieldsSource).toContain("maxLength={TAGS_INPUT_MAX_LENGTH}");
    expect(basicFieldsSource).toContain("maxLength={TEMPLATE_MUSIC_DESCRIPTION_MAX_LENGTH}");
    expect(basicFieldsSource).toContain("import { sanitizeSensitiveText }");
    expect(basicFieldsSource).toContain("const TEMPLATE_CATEGORY_SELECT_LABEL_MAX_LENGTH = 80;");
    expect(basicFieldsSource).toContain(
      "label: sanitizeSensitiveText(category, TEMPLATE_CATEGORY_SELECT_LABEL_MAX_LENGTH)"
    );
    expect(basicFieldsSource).toContain(
      "title: normalizeTemplateTextInput(event.target.value, TEMPLATE_TITLE_MAX_LENGTH)"
    );
    expect(basicFieldsSource).toContain("shortDescription: normalizeTemplateTextInput(");
    expect(basicFieldsSource).toContain("petPhotoRequirements: normalizeTemplateTextInput(");
    expect(basicFieldsSource).toContain(
      "tags: normalizeTemplateTextInput(event.target.value, TAGS_INPUT_MAX_LENGTH)"
    );
    expect(basicFieldsSource).toContain("musicDescription: normalizeTemplateTextInput(");
    expect(editorSectionsSource).toContain("normalizeTemplateTextInput(");
    expect(editorSectionsSource).toContain("preprocessingPrompt: normalizeTemplateTextInput(");
    expect(editorSectionsSource).toContain(
      "klingPrompt: normalizeTemplateTextInput(event.target.value, promptMaxLength)"
    );
    expect(editorSectionsSource).toContain(
      "imagePrompt: normalizeTemplateTextInput(event.target.value, promptMaxLength)"
    );
    expect(basicFieldsSource).not.toContain("title: event.target.value");
    expect(basicFieldsSource).not.toContain("shortDescription: event.target.value");
    expect(basicFieldsSource).not.toContain("petPhotoRequirements: event.target.value");
    expect(basicFieldsSource).not.toContain("tags: event.target.value");
    expect(basicFieldsSource).not.toContain("musicDescription: event.target.value");
    expect(basicFieldsSource).not.toContain("label: category");
    expect(editorSectionsSource).not.toContain("preprocessingPrompt: event.target.value");
    expect(editorSectionsSource).not.toContain("klingPrompt: event.target.value");
    expect(editorSectionsSource).not.toContain("imagePrompt: event.target.value");
  });

  it("keeps generation result editor controls localized", () => {
    const basicFieldsSource = readFileSync(basicFieldsPath, "utf8");

    expect(basicFieldsSource).toContain("text.editorGenerationResultInputTitle");
    expect(basicFieldsSource).toContain("text.editorGenerationResultSupported");
    expect(basicFieldsSource).toContain("text.editorGenerationResultUnsupported");
    expect(basicFieldsSource).toContain("text.editorGenerationResultInputHint");
    expect(basicFieldsSource).toContain("text.editorRequiredInputMediaTypeLabel");
    expect(basicFieldsSource).toContain("text.editorInputMediaTypeImageLabel");
    expect(basicFieldsSource).toContain("text.editorInputMediaTypeImageHint");
    expect(basicFieldsSource).toContain("text.editorInputMediaTypeVideoLabel");
    expect(basicFieldsSource).toContain("text.editorInputMediaTypeVideoHint");
    expect(basicFieldsSource).toContain('role="group"');
    expect(basicFieldsSource).toContain("aria-label={text.accessLabel}");
    expect(basicFieldsSource).toContain("aria-label={text.editorGenerationResultInputTitle}");
    expect(basicFieldsSource).toContain("aria-pressed={!form.isPremium}");
    expect(basicFieldsSource).toContain("aria-pressed={form.isPremium}");
    expect(basicFieldsSource).toContain("aria-pressed={form.supportsGenerationResultInput}");
    expect(basicFieldsSource).not.toContain("aria-pressed={form.recommendedAfterImageGeneration}");
    expect(basicFieldsSource).not.toContain("text.editorGenerationResultRecommended");
    expect(basicFieldsSource).not.toContain("text.editorGenerationResultNotRecommended");
    expect(basicFieldsSource).not.toContain("text.editorGenerationResultRecommendedHint");
    expect(basicFieldsSource).not.toContain(">Generation result input<");
    expect(basicFieldsSource).not.toContain(">Supported<");
    expect(basicFieldsSource).not.toContain(">Not supported<");
    expect(basicFieldsSource).not.toContain(
      "Allows completed generation results to start this template."
    );
    expect(basicFieldsSource).not.toContain(">Recommended<");
    expect(basicFieldsSource).not.toContain(">Not recommended<");
    expect(basicFieldsSource).not.toContain("Prioritizes this template after image generation.");
    expect(basicFieldsSource).not.toContain(">Required input media type<");
    expect(basicFieldsSource).not.toContain('ariaLabel="Required input media type"');
    expect(basicFieldsSource).not.toContain('label: "Image"');
    expect(basicFieldsSource).not.toContain('label: "Video"');
    expect(basicFieldsSource).not.toContain('description: "Completed image result"');
    expect(basicFieldsSource).not.toContain(
      'description: "Reserved for future video-result input"'
    );
  });

  it("makes the selected template access tier visually and keyboard-accessibly distinct", () => {
    const basicFieldsSource = readFileSync(basicFieldsPath, "utf8");
    const stylesSource = readFileSync(editorStylesPath, "utf8");

    expect(basicFieldsSource).toContain("aria-pressed={!form.isPremium}");
    expect(basicFieldsSource).toContain("aria-pressed={form.isPremium}");
    expect(stylesSource).toContain(".accessOption::after");
    expect(stylesSource).toContain(".accessOptionActive::before");
    expect(stylesSource).toContain(".accessOption:focus-visible");
    expect(stylesSource).toContain(".accessOptionActivePremium::after");
  });

  it("keeps template editor promo badge options localized", () => {
    const basicFieldsSource = readFileSync(basicFieldsPath, "utf8");

    expect(basicFieldsSource).toContain("text.promoBadgeAutoLabel");
    expect(basicFieldsSource).toContain("text.promoBadgeAutoHint");
    expect(basicFieldsSource).toContain("text.promoBadgeAutoBadge");
    expect(basicFieldsSource).toContain("text.promoBadgeNewLabel");
    expect(basicFieldsSource).toContain("text.promoBadgeNewBadge");
    expect(basicFieldsSource).toContain("text.promoBadgeTrendingLabel");
    expect(basicFieldsSource).toContain("text.promoBadgeTrendingBadge");
    expect(basicFieldsSource).toContain("text.promoBadgePopularLabel");
    expect(basicFieldsSource).toContain("text.promoBadgePopularBadge");
    expect(basicFieldsSource).toContain("text.promoBadgeFunnyLabel");
    expect(basicFieldsSource).toContain("text.promoBadgeFunnyBadge");
    expect(basicFieldsSource).not.toContain('label: "NEW"');
    expect(basicFieldsSource).not.toContain('label: "TRENDING"');
    expect(basicFieldsSource).not.toContain('label: "POPULAR"');
    expect(basicFieldsSource).not.toContain('label: "FUNNY"');
    expect(basicFieldsSource).not.toContain('badge: "Fresh"');
    expect(basicFieldsSource).not.toContain('badge: "Hot"');
    expect(basicFieldsSource).not.toContain('badge: "Core"');
    expect(basicFieldsSource).not.toContain('badge: "Mood"');
  });

  it("keeps template editor model card captions localized", () => {
    const editorSectionsSource = readFileSync(editorSectionsPath, "utf8");

    expect(editorSectionsSource).toContain("text.preprocessingModelEyebrow");
    expect(editorSectionsSource).toContain("text.klingModelEyebrow");
    expect(editorSectionsSource).toContain("text.imageModelEyebrow");
    expect(editorSectionsSource).toContain("text.motionModelPremiumDescription");
    expect(editorSectionsSource).toContain("text.motionModelFastDescription");
    expect(editorSectionsSource).toContain("text.imageModelRecommendedDescription");
    expect(editorSectionsSource).toContain("text.imageModelPremiumDescription");
    expect(editorSectionsSource).toContain("text.imageModelFastDescription");
    expect(editorSectionsSource).toContain("text.modelBadgeRecommended");
    expect(editorSectionsSource).toContain("text.modelBadgePremium");
    expect(editorSectionsSource).toContain("text.modelBadgeFast");
    expect(editorSectionsSource).not.toContain(">Input shaping<");
    expect(editorSectionsSource).not.toContain(">Motion pass<");
    expect(editorSectionsSource).not.toContain(">Image pass<");
    expect(editorSectionsSource).not.toContain("Motion control for highest-fidelity generation.");
    expect(editorSectionsSource).not.toContain("Motion control tuned for quicker iteration.");
    expect(editorSectionsSource).not.toContain(
      "Image edit pass for balanced fidelity and consistency."
    );
    expect(editorSectionsSource).not.toContain(
      "Image edit pass focused on premium detail retention."
    );
    expect(editorSectionsSource).not.toContain("Image edit pass optimized for faster turnaround.");
    expect(editorSectionsSource).not.toContain('badge: "Recommended"');
    expect(editorSectionsSource).not.toContain('badge: "Premium"');
    expect(editorSectionsSource).not.toContain('badge: "Fast"');
  });

  it("keeps template editor action logs sanitized", () => {
    const controllerSource = readFileSync(editorControllerPath, "utf8");

    expect(controllerSource).toContain("function getTemplateEditorErrorDetails(error: unknown)");
    expect(controllerSource).toContain(
      'errorName: error instanceof Error ? error.name : "UnknownError"'
    );
    expect(controllerSource).toContain("sanitizeSensitiveText(initialTemplateId, 80)");
    expect(controllerSource).toContain("fileSizeBytes: file.size");
    expect(controllerSource).toContain("contentType: sanitizeSensitiveText(file.type, 80)");
    expect(controllerSource).toContain("...getTemplateEditorErrorDetails(error)");
    expect(controllerSource).not.toContain(
      "initialTemplateId,\n          templateType,\n          error"
    );
    expect(controllerSource).not.toContain("fileName:");
    expect(controllerSource).not.toContain("contentType: file.type,\n        error");
  });

  it("keeps active publication blocked in the editor until required media is present", () => {
    const controllerSource = readFileSync(editorControllerPath, "utf8");

    expect(controllerSource).toContain("function getActivationReadinessError(");
    expect(controllerSource).toContain('if (targetStatus !== "Active")');
    expect(controllerSource).toContain(
      "const activationReadinessError = getActivationReadinessError("
    );
    expect(controllerSource).toContain(
      'if (activationReadinessError) {\n        setToast({ type: "error", message: activationReadinessError });\n        return;\n      }'
    );
    expect(
      controllerSource.indexOf("const activationReadinessError = getActivationReadinessError(")
    ).toBeLessThan(controllerSource.indexOf("await saveTemplateMutation.mutateAsync"));
    expect(controllerSource).toContain("missingLabels.push(text.previewAssetTitle)");
    expect(controllerSource).toContain("missingLabels.push(text.petPhotoRequirementsLabel)");
    expect(controllerSource).toContain("missingLabels.push(text.referenceMotionTitle)");
    expect(controllerSource).toContain("missingLabels.push(text.referenceDurationLabel)");
    expect(controllerSource).toContain("missingLabels.push(text.imageModelLabel)");
    expect(controllerSource).toContain("missingLabels.push(text.imagePromptLabel)");
    expect(controllerSource).toContain(
      'return `${text.activationRequirementsMissing} ${missingLabels.join(", ")}.`;'
    );
  });
});

describe("template media asset payload hardening", () => {
  it("tracks persisted template media separately from freshly uploaded media", () => {
    const initialImageForm = createInitialTemplateForm("Image");
    const formFromTemplate = createFormFromTemplate(createTemplate());

    expect(initialImageForm.previewUrlSource).toBe("none");
    expect(initialImageForm.referenceUrlSource).toBe("none");
    expect(initialImageForm.isQaOnly).toBe(false);
    expect(formFromTemplate.isQaOnly).toBe(false);
    expect(formFromTemplate.previewUrl).toContain("X-Amz-Signature=preview-secret");
    expect(formFromTemplate.referenceUrl).toContain("X-Amz-Signature=reference-secret");
    expect(formFromTemplate.previewUrlSource).toBe("persisted");
    expect(formFromTemplate.referenceUrlSource).toBe("persisted");
  });

  it("keeps persisted template media out of save payload asset objects", () => {
    const source = readFileSync(formMappersPath, "utf8");

    expect(source).toContain("function buildTemplateAsset(");
    expect(source).toContain('if (source === "none" || source === "persisted") {');
    expect(source).toContain("return undefined;");
    expect(source).toContain(
      'const keepPreviewAsset = Boolean(templateId && form.previewUrlSource === "persisted");'
    );
    expect(source).toContain('templateId && form.referenceUrlSource === "persisted"');
    expect(source).toContain("...(keepPreviewAsset ? { keepPreviewAsset } : {})");
    expect(source).toContain("...(keepReferenceMotionAsset ? { keepReferenceMotionAsset } : {})");
    expect(source).toContain("const previewAsset = buildTemplateAsset(");
    expect(source).toContain("previewAsset,");
    expect(source).toContain("thumbnailAsset: previewAsset");
    expect(source).toContain("feedLoopLowAsset: previewAsset");
    expect(source).toContain("detailPreviewAsset: previewAsset");
    expect(source).toContain("referenceMotionAsset: buildTemplateAsset(");
    expect(source).toContain("url: url.trim()");
    expect(source).toContain("isQaOnly: form.isQaOnly");
  });
});

function createTemplate(): AdminTemplate {
  return {
    templateId: "template-1",
    templateType: "Video",
    title: "Template",
    shortDescription: "Description",
    petPhotoRequirements: ["One pet"],
    category: "Pets",
    status: "Draft",
    promoBadgeMode: "Auto",
    isPremium: false,
    isQaOnly: false,
    tokenCost: 60,
    supportsGenerationResultInput: true,
    requiredInputMediaType: "Image",
    recommendedAfterImageGeneration: false,
    tags: [],
    previewAsset: {
      url: "https://cdn.example.com/preview.jpg?X-Amz-Signature=preview-secret",
      fileName: "preview.jpg",
      contentType: "image/jpeg",
      fileSizeBytes: 100,
    },
    referenceMotionAsset: {
      url: "https://cdn.example.com/reference.mp4?X-Amz-Signature=reference-secret",
      fileName: "reference.mp4",
      contentType: "video/mp4",
      fileSizeBytes: 1000,
      durationSeconds: 3,
    },
    musicDescription: "",
    imageModel: "openai/gpt-image-2/edit",
    imagePrompt: "Prompt",
    preprocessingModel: "openai/gpt-image-2/edit",
    preprocessingPrompt: "Prompt",
    klingModel: "fal-ai/kling-video/v3/pro/motion-control",
    klingPrompt: "Prompt",
    keepOriginalSound: true,
    createdAtUtc: "2026-06-07T00:00:00Z",
    updatedAtUtc: "2026-06-07T00:00:00Z",
  };
}
