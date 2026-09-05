import { describe, expect, it } from "vitest";

import type { AdminTemplate } from "@/lib/api-client";
import { getDictionary } from "@/lib/i18n";

import { buildTemplateEditorModel } from "./template-editor-model";
import {
  getTemplateActivationError,
  getTemplateEditorRequirements,
} from "./template-editor-readiness";
import { createFormFromTemplate, createInitialTemplateForm } from "./template-form-mappers";

const text = getDictionary("ru");
const details = { title: "Портрет", shortDescription: "Описание", category: "Портреты" };

describe("template publication readiness", () => {
  it("includes required metadata, rather than reporting a nameless template as ready", () => {
    const form = createInitialTemplateForm("Image");
    const missing = getTemplateEditorRequirements(text, form, "Image").filter(
      (item) => !item.ready
    );
    expect(missing.map((item) => item.targetId)).toEqual([
      "template-title",
      "template-description",
      "template-category",
      "template-preview",
    ]);
    expect(buildTemplateEditorModel(text, form, null, "Image").reviewReady).toBe(false);
  });

  it("permits a pending preview for save-time upload without marking it uploaded", () => {
    const form = { ...createInitialTemplateForm("Image"), ...details };
    expect(getTemplateActivationError(text, form, "Image")).toContain(text.previewAssetTitle);
    expect(getTemplateActivationError(text, form, "Image", { preview: true })).toBeNull();
    const model = buildTemplateEditorModel(text, form, null, "Image", { preview: true });
    expect(model.mediaReady).toBe(false);
    expect(model.checklist.find((item) => item.targetId === "template-preview")).toMatchObject({
      ready: false,
      pending: true,
    });
  });

  it("validates a new reference duration after upload, without reusing the old one", () => {
    const form = {
      ...createInitialTemplateForm("Video"),
      ...details,
      previewUrl: "preview",
      referenceUrl: "reference",
      referenceDurationSeconds: "15",
    };
    const saved = {
      referenceVideoDurationSeconds: 5,
      characterOrientation: "image",
    } as AdminTemplate;
    const model = buildTemplateEditorModel(text, form, saved, "Video");
    expect(model).toMatchObject({
      referenceDuration: 15,
      characterOrientation: "video",
      reviewReady: true,
    });
    expect(buildTemplateEditorModel(text, form, saved, "Video", { reference: true })).toMatchObject(
      { referenceDuration: undefined, characterOrientation: "", mediaReady: false }
    );
    form.referenceDurationSeconds = "";
    expect(getTemplateActivationError(text, form, "Video")).toContain(text.referenceDurationLabel);
    expect(getTemplateActivationError(text, form, "Video", { reference: true })).toBeNull();
  });

  it("allows empty prompts as the API does, but rejects unavailable models", () => {
    const form = {
      ...createInitialTemplateForm("Video"),
      ...details,
      previewUrl: "preview",
      referenceUrl: "reference",
      referenceDurationSeconds: "5",
      preprocessingPrompt: "",
      klingPrompt: "",
    };
    expect(getTemplateActivationError(text, form, "Video")).toBeNull();
    form.klingModel = "retired-model";
    expect(getTemplateActivationError(text, form, "Video")).toContain(text.klingModelLabel);
    expect(buildTemplateEditorModel(text, form, null, "Video").aiReady).toBe(false);
  });

  it("uses the same integer price rules as the submitted payload", () => {
    for (const tokenCost of ["0", "1.5", "abc", "1000000"]) {
      const form = {
        ...createInitialTemplateForm("Image"),
        ...details,
        previewUrl: "preview",
        tokenCost,
      };
      expect(getTemplateActivationError(text, form, "Image")).toContain(text.tokenCostLabel);
      expect(buildTemplateEditorModel(text, form, null, "Image").basicInfoReady).toBe(false);
    }
  });

  it("hydrates a legacy reference duration once so unchanged assets remain editable", () => {
    const template = {
      templateType: "Video",
      ...details,
      petPhotoRequirements: ["Full body"],
      tags: [],
      tokenCost: 60,
      referenceVideoDurationSeconds: 8,
      referenceMotionAsset: {
        url: "reference",
        fileName: "reference.mp4",
        contentType: "video/mp4",
      },
    } as unknown as AdminTemplate;
    expect(createFormFromTemplate(template).referenceDurationSeconds).toBe("8");
  });
});
