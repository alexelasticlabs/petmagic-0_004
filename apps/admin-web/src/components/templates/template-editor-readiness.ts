import type { TemplateType } from "@/lib/api-client";
import type { Dictionary } from "@/lib/i18n";

import {
  IMAGE_MODELS,
  KLING_MODELS,
  PREPROCESSING_MODELS,
  parseNumber,
  parseOptionalDecimal,
} from "./template-form-mappers";

import type { TemplateFormState } from "./types";

export type EditorSectionId = "template-basics" | "template-media" | "template-ai";
export type TemplateEditorRequirement = {
  label: string;
  targetId: string;
  sectionId: EditorSectionId;
  ready: boolean;
  pending: boolean;
};
export type PendingTemplateMedia = { preview?: boolean; reference?: boolean };

// Shared by section summaries, the publication checklist and submit validation.
// A selected file can be uploaded on save; it is never presented as uploaded.
export function getTemplateEditorRequirements(
  text: Dictionary,
  form: TemplateFormState,
  templateType: TemplateType,
  pending: PendingTemplateMedia = {}
): TemplateEditorRequirement[] {
  const item = (
    label: string,
    targetId: string,
    sectionId: EditorSectionId,
    ready: boolean,
    isPending = false
  ) => ({ label, targetId, sectionId, ready: ready && !isPending, pending: isPending });
  const requirements = [
    item(text.titleLabel, "template-title", "template-basics", Boolean(form.title.trim())),
    item(
      text.shortDescriptionLabel,
      "template-description",
      "template-basics",
      Boolean(form.shortDescription.trim())
    ),
    item(text.categoryLabel, "template-category", "template-basics", Boolean(form.category.trim())),
    item(
      text.tokenCostLabel,
      "template-token-cost",
      "template-basics",
      parseNumber(form.tokenCost) > 0
    ),
    item(
      text.petPhotoRequirementsLabel,
      "template-photo-requirements",
      "template-basics",
      Boolean(form.petPhotoRequirements.trim())
    ),
    item(
      text.previewAssetTitle,
      "template-preview",
      "template-media",
      Boolean(form.previewUrl.trim()),
      pending.preview
    ),
  ];
  if (templateType === "Video") {
    requirements.push(
      item(
        text.referenceMotionTitle,
        "template-reference",
        "template-media",
        Boolean(form.referenceUrl.trim()),
        pending.reference
      ),
      item(
        text.referenceDurationLabel,
        "template-reference",
        "template-media",
        parseOptionalDecimal(form.referenceDurationSeconds) !== undefined,
        pending.reference
      ),
      item(
        text.preprocessingModelLabel,
        "template-preprocessing-model",
        "template-ai",
        (PREPROCESSING_MODELS as readonly string[]).includes(form.preprocessingModel)
      ),
      item(
        text.klingModelLabel,
        "template-motion-model",
        "template-ai",
        (KLING_MODELS as readonly string[]).includes(form.klingModel)
      )
    );
  } else {
    requirements.push(
      item(
        text.imageModelLabel,
        "template-image-model",
        "template-ai",
        (IMAGE_MODELS as readonly string[]).includes(form.imageModel)
      )
    );
  }
  return requirements;
}

export function getTemplateActivationError(
  text: Dictionary,
  form: TemplateFormState,
  templateType: TemplateType,
  pending: PendingTemplateMedia = {}
): string | null {
  const missing = getTemplateEditorRequirements(text, form, templateType, pending).filter(
    (item) => !item.ready && !item.pending
  );
  return missing.length
    ? `${text.activationRequirementsMissing} ${missing.map((item) => item.label).join(", ")}.`
    : null;
}

export function focusTemplateEditorField(targetId: string) {
  const target = document.getElementById(targetId);
  if (!target) return;
  target.closest("details")?.setAttribute("open", "");
  target.scrollIntoView({ block: "center" });
  const control = target.matches("input, textarea, button, [tabindex]")
    ? target
    : target.querySelector<HTMLElement>(
        'input:not([type="file"]), textarea, button, [role="button"]'
      );
  (control as HTMLElement | null)?.focus({ preventScroll: true });
}
