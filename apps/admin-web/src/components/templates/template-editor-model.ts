import { parseNumber, parseOptionalDecimal } from "@/components/templates/template-form-mappers";
import { resolveAutoPromoBadge } from "@/components/templates/template-promo-badge-rules";
import { type TemplateFormState } from "@/components/templates/types";
import {
  type AdminTemplate,
  type TemplatePromoBadgeMode,
  type TemplateType,
} from "@/lib/api-client";
import { type Dictionary } from "@/lib/i18n";

import {
  getTemplateEditorRequirements,
  type PendingTemplateMedia,
  type TemplateEditorRequirement,
} from "./template-editor-readiness";

export type ChecklistItem = TemplateEditorRequirement & {
  detail: string;
  ready: boolean;
};

export type VideoEditorModel = {
  title: string;
  shortDescription: string;
  petPhotoRequirements: string[];
  musicDescription: string;
  category: string;
  promoBadge?: Exclude<TemplatePromoBadgeMode, "Auto">;
  tokenCost: string;
  previewReady: boolean;
  petPhotoRequirementsReady: boolean;
  referenceReady: boolean;
  referenceDuration?: number;
  characterOrientation: string;
  basicInfoReady: boolean;
  mediaReady: boolean;
  aiReady: boolean;
  reviewReady: boolean;
  checklist: ChecklistItem[];
};

export type ImageEditorModel = Omit<
  VideoEditorModel,
  "referenceReady" | "referenceDuration" | "characterOrientation" | "musicDescription"
> & {
  imageModelReady: boolean;
  imagePromptReady: boolean;
};

export type TemplateEditorModel = VideoEditorModel | ImageEditorModel;

export function buildTemplateEditorModel(
  text: Dictionary,
  form: TemplateFormState,
  selectedTemplate: AdminTemplate | null,
  templateType: TemplateType,
  pending: PendingTemplateMedia = {}
): TemplateEditorModel {
  const checklist = getTemplateEditorRequirements(text, form, templateType, pending).map(
    (item) => ({
      ...item,
      detail: item.pending
        ? text.editorFilePending
        : item.ready
          ? text.editorReady
          : text.editorMissing,
    })
  );
  const sectionReady = (sectionId: string) =>
    checklist.filter((item) => item.sectionId === sectionId).every((item) => item.ready);
  const common = {
    title: form.title.trim(),
    shortDescription: form.shortDescription.trim(),
    petPhotoRequirements: normalizeRequirements(form.petPhotoRequirements),
    petPhotoRequirementsReady: Boolean(form.petPhotoRequirements.trim()),
    category: form.category.trim(),
    promoBadge: resolveEffectivePromoBadge(form, selectedTemplate),
    tokenCost: parseNumber(form.tokenCost).toString(),
    previewReady: Boolean(form.previewUrl.trim()) && !pending.preview,
    checklist,
    basicInfoReady: sectionReady("template-basics"),
    mediaReady: sectionReady("template-media"),
    aiReady: sectionReady("template-ai"),
    reviewReady: checklist.every((item) => item.ready),
  };
  if (templateType === "Video") {
    const referenceDuration = pending.reference
      ? undefined
      : parseOptionalDecimal(form.referenceDurationSeconds);
    return {
      ...common,
      musicDescription: form.musicDescription.trim(),
      referenceReady: Boolean(form.referenceUrl.trim()) && !pending.reference,
      referenceDuration,
      characterOrientation: inferCharacterOrientation(referenceDuration),
    };
  }
  return {
    ...common,
    imageModelReady: common.aiReady,
    imagePromptReady: Boolean(form.imagePrompt.trim()),
  };
}

export function formatDuration(seconds?: number): string {
  if (seconds === undefined) {
    return "--:--";
  }

  const totalSeconds = Math.max(0, Math.round(seconds));
  const minutes = Math.floor(totalSeconds / 60);
  const remainderSeconds = totalSeconds % 60;
  return `${minutes.toString().padStart(2, "0")}:${remainderSeconds.toString().padStart(2, "0")}`;
}

export function formatPromoBadge(value: Exclude<TemplatePromoBadgeMode, "Auto">): string {
  return value.toUpperCase();
}

function resolveEffectivePromoBadge(
  form: TemplateFormState,
  selectedTemplate: AdminTemplate | null
): Exclude<TemplatePromoBadgeMode, "Auto"> | undefined {
  if (form.promoBadgeMode !== "Auto") {
    return form.promoBadgeMode as Exclude<TemplatePromoBadgeMode, "Auto">;
  }

  return resolveAutoPromoBadge({
    createdAtUtc: selectedTemplate?.createdAtUtc,
    publishedAtUtc: selectedTemplate?.publishedAtUtc,
    updatedAtUtc: selectedTemplate?.updatedAtUtc,
    status: selectedTemplate?.status,
    isPremium: form.isPremium,
    tokenCost: parseNumber(form.tokenCost),
    searchFragments: [
      form.title,
      form.shortDescription,
      form.category,
      form.tags,
      form.musicDescription,
      form.klingPrompt,
      form.imagePrompt,
    ],
  });
}

function inferCharacterOrientation(duration?: number): string {
  if (duration === undefined) {
    return "";
  }

  return duration <= 10 ? "image" : "video";
}

function normalizeRequirements(raw: string): string[] {
  return raw
    .split(/\r?\n/)
    .map((item) => item.trim())
    .filter(Boolean)
    .slice(0, 6);
}
