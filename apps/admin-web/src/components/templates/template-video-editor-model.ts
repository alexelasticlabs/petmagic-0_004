import { parseNumber, parseOptionalDecimal } from "@/components/templates/template-form-mappers";
import { type TemplateFormState } from "@/components/templates/types";
import { type AdminTemplate, type TemplatePromoBadgeMode } from "@/lib/api-client";
import { type Dictionary } from "@/lib/i18n";

const FUNNY_PROMO_BADGE_KEYWORDS = ["funny", "meme", "viral", "dance", "lol", "cute"];

export type ChecklistItem = {
  label: string;
  detail: string;
  ready: boolean;
};

export type VideoEditorModel = {
  title: string;
  shortDescription: string;
  musicDescription: string;
  category: string;
  promoBadge?: Exclude<TemplatePromoBadgeMode, "Auto">;
  tokenCost: string;
  previewReady: boolean;
  referenceReady: boolean;
  referenceDuration?: number;
  characterOrientation: string;
  basicInfoReady: boolean;
  mediaReady: boolean;
  aiReady: boolean;
  reviewReady: boolean;
  checklist: ChecklistItem[];
};

export function buildVideoEditorModel(text: Dictionary, form: TemplateFormState, selectedTemplate: AdminTemplate | null): VideoEditorModel {
  const title = form.title.trim();
  const shortDescription = form.shortDescription.trim();
  const musicDescription = form.musicDescription.trim();
  const category = form.category.trim();
  const promoBadge = resolveEffectivePromoBadge(form, selectedTemplate);
  const tokenCost = normalizeIntegerString(form.tokenCost) || "0";
  const previewReady = Boolean(form.previewUrl.trim());
  const referenceReady = Boolean(form.referenceUrl.trim());
  const referenceDuration = selectedTemplate?.referenceVideoDurationSeconds ?? parseOptionalDecimal(form.referenceDurationSeconds);
  const characterOrientation = selectedTemplate?.characterOrientation ?? inferCharacterOrientation(referenceDuration);
  const preprocessingReady = Boolean(form.preprocessingModel.trim() && form.preprocessingPrompt.trim());
  const klingReady = Boolean(form.klingModel.trim() && form.klingPrompt.trim());
  const basicInfoReady = Boolean(title && shortDescription && category && parseNumber(tokenCost) > 0);
  const mediaReady = Boolean(previewReady && referenceReady && referenceDuration !== undefined && characterOrientation);
  const aiReady = Boolean(preprocessingReady && klingReady);
  const reviewReady = Boolean(basicInfoReady && mediaReady && aiReady);

  return {
    title,
    shortDescription,
    musicDescription,
    category,
    promoBadge,
    tokenCost,
    previewReady,
    referenceReady,
    referenceDuration,
    characterOrientation,
    basicInfoReady,
    mediaReady,
    aiReady,
    reviewReady,
    checklist: buildChecklist(text, {
      previewReady,
      referenceReady,
      referenceDuration,
      characterOrientation,
      preprocessingReady,
      klingReady,
    }),
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

function buildChecklist(
  text: Dictionary,
  signals: {
    previewReady: boolean;
    referenceReady: boolean;
    referenceDuration?: number;
    characterOrientation: string;
    preprocessingReady: boolean;
    klingReady: boolean;
  },
): ChecklistItem[] {
  return [
    {
      label: text.previewAssetTitle,
      detail: signals.previewReady ? text.editorReady : text.editorMissing,
      ready: signals.previewReady,
    },
    {
      label: text.referenceMotionTitle,
      detail: signals.referenceReady ? text.editorReady : text.editorMissing,
      ready: signals.referenceReady,
    },
    {
      label: text.referenceDurationLabel,
      detail: signals.referenceDuration === undefined ? text.editorMissing : formatDuration(signals.referenceDuration),
      ready: signals.referenceDuration !== undefined,
    },
    {
      label: text.characterOrientationLabel,
      detail: signals.characterOrientation || text.editorMissing,
      ready: Boolean(signals.characterOrientation),
    },
    {
      label: text.preprocessingModelLabel,
      detail: signals.preprocessingReady ? text.editorReady : text.editorMissing,
      ready: signals.preprocessingReady,
    },
    {
      label: text.klingModelLabel,
      detail: signals.klingReady ? text.editorReady : text.editorMissing,
      ready: signals.klingReady,
    },
  ];
}

function resolveEffectivePromoBadge(
  form: TemplateFormState,
  selectedTemplate: AdminTemplate | null,
): Exclude<TemplatePromoBadgeMode, "Auto"> | undefined {
  if (form.promoBadgeMode !== "Auto") {
    return form.promoBadgeMode as Exclude<TemplatePromoBadgeMode, "Auto">;
  }

  if (selectedTemplate) {
    const createdAt = new Date(selectedTemplate.createdAtUtc).getTime();
    const updatedAt = new Date(selectedTemplate.updatedAtUtc).getTime();
    const now = Date.now();

    if (createdAt >= now - 30 * 24 * 60 * 60 * 1000) {
      return "New";
    }

    if (selectedTemplate.status === "Active" && updatedAt >= now - 14 * 24 * 60 * 60 * 1000) {
      return "Trending";
    }
  }

  const searchText = [form.title, form.shortDescription, form.category, form.tags, form.musicDescription, form.klingPrompt]
    .join(" ")
    .toLowerCase();

  if (parseNumber(form.tokenCost) >= 60 || form.isPremium) {
    return "Popular";
  }

  if (FUNNY_PROMO_BADGE_KEYWORDS.some((keyword) => searchText.includes(keyword))) {
    return "Funny";
  }

  return "New";
}

function inferCharacterOrientation(duration?: number): string {
  if (duration === undefined) {
    return "";
  }

  return duration <= 10 ? "image" : "video";
}

function normalizeIntegerString(raw: string): string {
  return raw.replace(/\D+/g, "");
}
