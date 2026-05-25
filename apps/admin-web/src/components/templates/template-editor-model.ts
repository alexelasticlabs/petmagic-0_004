import { parseNumber, parseOptionalDecimal } from "@/components/templates/template-form-mappers";
import { resolveAutoPromoBadge } from "@/components/templates/template-promo-badge-rules";
import { type TemplateFormState } from "@/components/templates/types";
import {
  type AdminTemplate,
  type TemplatePromoBadgeMode,
  type TemplateType,
} from "@/lib/api-client";
import { type Dictionary } from "@/lib/i18n";

export type ChecklistItem = {
  label: string;
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
  templateType: TemplateType
): TemplateEditorModel {
  return templateType === "Video"
    ? buildVideoEditorModel(text, form, selectedTemplate)
    : buildImageEditorModel(text, form, selectedTemplate);
}

export function buildVideoEditorModel(
  text: Dictionary,
  form: TemplateFormState,
  selectedTemplate: AdminTemplate | null
): VideoEditorModel {
  const title = form.title.trim();
  const shortDescription = form.shortDescription.trim();
  const petPhotoRequirements = normalizeRequirements(form.petPhotoRequirements);
  const musicDescription = form.musicDescription.trim();
  const category = form.category.trim();
  const promoBadge = resolveEffectivePromoBadge(form, selectedTemplate);
  const tokenCost = normalizeIntegerString(form.tokenCost) || "0";
  const previewReady = Boolean(form.previewUrl.trim());
  const referenceReady = Boolean(form.referenceUrl.trim());
  const referenceDuration =
    selectedTemplate?.referenceVideoDurationSeconds ??
    parseOptionalDecimal(form.referenceDurationSeconds);
  const characterOrientation =
    selectedTemplate?.characterOrientation ?? inferCharacterOrientation(referenceDuration);
  const petPhotoRequirementsReady = petPhotoRequirements.length > 0;
  const preprocessingReady = Boolean(
    form.preprocessingModel.trim() && form.preprocessingPrompt.trim()
  );
  const klingReady = Boolean(form.klingModel.trim() && form.klingPrompt.trim());
  const basicInfoReady = Boolean(
    title && shortDescription && category && parseNumber(tokenCost) > 0 && petPhotoRequirementsReady
  );
  const mediaReady = Boolean(
    previewReady && referenceReady && referenceDuration !== undefined && characterOrientation
  );
  const aiReady = Boolean(preprocessingReady && klingReady);
  const reviewReady = Boolean(basicInfoReady && mediaReady && aiReady);

  return {
    title,
    shortDescription,
    petPhotoRequirements,
    musicDescription,
    category,
    promoBadge,
    tokenCost,
    previewReady,
    petPhotoRequirementsReady,
    referenceReady,
    referenceDuration,
    characterOrientation,
    basicInfoReady,
    mediaReady,
    aiReady,
    reviewReady,
    checklist: buildChecklist(text, {
      previewReady,
      petPhotoRequirementsReady,
      referenceReady,
      referenceDuration,
      characterOrientation,
      preprocessingReady,
      klingReady,
    }),
  };
}

export function buildImageEditorModel(
  text: Dictionary,
  form: TemplateFormState,
  selectedTemplate: AdminTemplate | null
): ImageEditorModel {
  const title = form.title.trim();
  const shortDescription = form.shortDescription.trim();
  const petPhotoRequirements = normalizeRequirements(form.petPhotoRequirements);
  const category = form.category.trim();
  const promoBadge = resolveEffectivePromoBadge(form, selectedTemplate);
  const tokenCost = normalizeIntegerString(form.tokenCost) || "0";
  const previewReady = Boolean(form.previewUrl.trim());
  const petPhotoRequirementsReady = petPhotoRequirements.length > 0;
  const imageModelReady = Boolean(form.imageModel.trim());
  const imagePromptReady = Boolean(form.imagePrompt.trim());
  const basicInfoReady = Boolean(
    title && shortDescription && category && parseNumber(tokenCost) > 0 && petPhotoRequirementsReady
  );
  const mediaReady = previewReady;
  const aiReady = Boolean(imageModelReady && imagePromptReady);
  const reviewReady = Boolean(basicInfoReady && mediaReady && aiReady);

  return {
    title,
    shortDescription,
    petPhotoRequirements,
    category,
    promoBadge,
    tokenCost,
    previewReady,
    petPhotoRequirementsReady,
    imageModelReady,
    imagePromptReady,
    basicInfoReady,
    mediaReady,
    aiReady,
    reviewReady,
    checklist: buildImageChecklist(text, {
      previewReady,
      petPhotoRequirementsReady,
      imageModelReady,
      imagePromptReady,
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
    petPhotoRequirementsReady: boolean;
    referenceReady: boolean;
    referenceDuration?: number;
    characterOrientation: string;
    preprocessingReady: boolean;
    klingReady: boolean;
  }
): ChecklistItem[] {
  return [
    {
      label: text.petPhotoRequirementsLabel,
      detail: signals.petPhotoRequirementsReady ? text.editorReady : text.editorMissing,
      ready: signals.petPhotoRequirementsReady,
    },
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
      detail:
        signals.referenceDuration === undefined
          ? text.editorMissing
          : formatDuration(signals.referenceDuration),
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

function buildImageChecklist(
  text: Dictionary,
  signals: {
    previewReady: boolean;
    petPhotoRequirementsReady: boolean;
    imageModelReady: boolean;
    imagePromptReady: boolean;
  }
): ChecklistItem[] {
  return [
    {
      label: text.petPhotoRequirementsLabel,
      detail: signals.petPhotoRequirementsReady ? text.editorReady : text.editorMissing,
      ready: signals.petPhotoRequirementsReady,
    },
    {
      label: text.previewAssetTitle,
      detail: signals.previewReady ? text.editorReady : text.editorMissing,
      ready: signals.previewReady,
    },
    {
      label: text.imageModelLabel,
      detail: signals.imageModelReady ? text.editorReady : text.editorMissing,
      ready: signals.imageModelReady,
    },
    {
      label: text.imagePromptLabel,
      detail: signals.imagePromptReady ? text.editorReady : text.editorMissing,
      ready: signals.imagePromptReady,
    },
  ];
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

function normalizeIntegerString(raw: string): string {
  return raw.replace(/\D+/g, "");
}

function normalizeRequirements(raw: string): string[] {
  return raw
    .split(/\r?\n/)
    .map((item) => item.trim())
    .filter(Boolean)
    .slice(0, 6);
}
