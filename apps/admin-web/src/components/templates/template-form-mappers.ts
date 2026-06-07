import { type TemplateFormState } from "@/components/templates/types";
import {
  createImageTemplate,
  createVideoTemplate,
  updateImageTemplate,
  updateVideoTemplate,
  type AdminTemplate,
  type ImageTemplatePayload,
  type TemplateAssetInput,
  type TemplatePromoBadgeMode,
  type TemplateStatus,
  type TemplateType,
  type VideoTemplatePayload,
} from "@/lib/api-client";

export const DEFAULT_IMAGE_PROMPT =
  "Keep the same pet, same face, same fur, same colors, same eyes, same breed, and the same overall identity. Apply the template style and scene to the uploaded pet photo without replacing the pet with a different animal.";
export const DEFAULT_PREPROCESSING_PROMPT =
  "Keep the same pet, same face, same fur, same colors, same background, same lighting and camera angle. Adjust the pet into an upright pose standing on its two hind legs like a human, with the front paws naturally positioned like arms. Make the full body clearly visible and suitable for motion transfer. Do not change the pet’s identity, breed, facial features, background, or image style.";
export const DEFAULT_KLING_PROMPT =
  "A cute pet performing a funny viral dance, smooth animation, high quality.";

export const IMAGE_MODELS = [
  "openai/gpt-image-2/edit",
  "fal-ai/nano-banana-pro/edit",
  "fal-ai/flux-2-pro/edit",
  "fal-ai/gpt-image-1.5/edit",
  "fal-ai/bytedance/seedream/v5/lite/edit",
  "fal-ai/nano-banana-2/edit",
] as const;

export const PREPROCESSING_MODELS = [
  "openai/gpt-image-2/edit",
  "fal-ai/nano-banana-pro/edit",
  "fal-ai/flux-2-pro/edit",
  "fal-ai/gpt-image-1.5/edit",
  "fal-ai/bytedance/seedream/v5/lite/edit",
  "fal-ai/nano-banana-2/edit",
] as const;

export const KLING_MODELS = [
  "fal-ai/kling-video/v3/pro/motion-control",
  "fal-ai/kling-video/v3/standard/motion-control",
] as const;

export const TEMPLATE_TOKEN_COST_MAX_LENGTH = 6;
export const TEMPLATE_TITLE_MAX_LENGTH = 60;
export const TEMPLATE_SHORT_DESCRIPTION_MAX_LENGTH = 120;
export const TEMPLATE_REQUIREMENT_MAX_LENGTH = 180;
export const TEMPLATE_CATEGORY_MAX_LENGTH = 64;
export const TEMPLATE_TAG_MAX_LENGTH = 48;
export const TEMPLATE_TAG_MAX_COUNT = 12;
export const TEMPLATE_MODEL_MAX_LENGTH = 160;
export const TEMPLATE_PROMPT_MAX_LENGTH = 4000;
export const TEMPLATE_MUSIC_DESCRIPTION_MAX_LENGTH = 240;
export const TEMPLATE_ASSET_METADATA_MAX_LENGTH = 240;
const TEMPLATE_ASSET_DURATION_MAX_SECONDS = 60 * 60;

export function createInitialTemplateForm(templateType: TemplateType): TemplateFormState {
  return {
    title: "",
    shortDescription: "",
    petPhotoRequirements:
      templateType === "Video"
        ? "Full body visible\nPet facing camera\nNo cropped head or legs"
        : "One pet in the photo\nClear face\nGood lighting",
    category: "",
    promoBadgeMode: "Auto",
    tags: "",
    isPremium: false,
    tokenCost: templateType === "Video" ? "60" : "20",
    previewUrl: "",
    previewUrlSource: "none",
    previewFileName: "",
    previewContentType: templateType === "Video" ? "video/mp4" : "image/jpeg",
    previewFileSizeBytes: "",
    previewDurationSeconds: "",
    musicDescription: "",
    referenceUrl: "",
    referenceUrlSource: "none",
    referenceFileName: "",
    referenceContentType: "video/mp4",
    referenceFileSizeBytes: "",
    referenceDurationSeconds: "",
    imageModel: IMAGE_MODELS[0],
    imagePrompt: DEFAULT_IMAGE_PROMPT,
    preprocessingModel: PREPROCESSING_MODELS[0],
    preprocessingPrompt: DEFAULT_PREPROCESSING_PROMPT,
    klingModel: KLING_MODELS[0],
    klingPrompt: DEFAULT_KLING_PROMPT,
    keepOriginalSound: true,
  };
}

export function createFormFromTemplate(template: AdminTemplate): TemplateFormState {
  return {
    title: template.title,
    shortDescription: template.shortDescription,
    petPhotoRequirements: template.petPhotoRequirements?.join("\n") ?? "",
    category: template.category,
    promoBadgeMode: template.promoBadgeMode,
    tags: template.tags.join(", "),
    isPremium: template.isPremium,
    tokenCost: template.tokenCost.toString(),
    previewUrl: template.previewAsset?.url ?? "",
    previewUrlSource: template.previewAsset?.url ? "persisted" : "none",
    previewFileName: template.previewAsset?.fileName ?? "",
    previewContentType:
      template.previewAsset?.contentType ??
      (template.templateType === "Video" ? "video/mp4" : "image/jpeg"),
    previewFileSizeBytes: template.previewAsset?.fileSizeBytes?.toString() ?? "",
    previewDurationSeconds: template.previewAsset?.durationSeconds?.toString() ?? "",
    musicDescription: template.musicDescription ?? "",
    referenceUrl: template.referenceMotionAsset?.url ?? "",
    referenceUrlSource: template.referenceMotionAsset?.url ? "persisted" : "none",
    referenceFileName: template.referenceMotionAsset?.fileName ?? "",
    referenceContentType: template.referenceMotionAsset?.contentType ?? "video/mp4",
    referenceFileSizeBytes: template.referenceMotionAsset?.fileSizeBytes?.toString() ?? "",
    referenceDurationSeconds: template.referenceMotionAsset?.durationSeconds?.toString() ?? "",
    imageModel: template.imageModel ?? IMAGE_MODELS[0],
    imagePrompt: template.imagePrompt ?? DEFAULT_IMAGE_PROMPT,
    preprocessingModel: template.preprocessingModel ?? PREPROCESSING_MODELS[0],
    preprocessingPrompt: template.preprocessingPrompt ?? DEFAULT_PREPROCESSING_PROMPT,
    klingModel: template.klingModel ?? KLING_MODELS[0],
    klingPrompt: template.klingPrompt ?? DEFAULT_KLING_PROMPT,
    keepOriginalSound: template.keepOriginalSound ?? true,
  };
}

export async function saveImageTemplateFromForm(
  templateId: string | undefined,
  form: TemplateFormState,
  status: TemplateStatus
): Promise<AdminTemplate> {
  const payload: ImageTemplatePayload = {
    title: normalizeTemplateText(form.title, TEMPLATE_TITLE_MAX_LENGTH),
    shortDescription: normalizeTemplateText(
      form.shortDescription,
      TEMPLATE_SHORT_DESCRIPTION_MAX_LENGTH
    ),
    petPhotoRequirements: normalizeRequirements(form.petPhotoRequirements),
    category: normalizeTemplateText(form.category, TEMPLATE_CATEGORY_MAX_LENGTH),
    status,
    promoBadgeMode: form.promoBadgeMode as TemplatePromoBadgeMode,
    tags: normalizeTags(form.tags),
    isPremium: form.isPremium,
    tokenCost: parseNumber(form.tokenCost),
    previewAsset: buildUploadedAsset(
      form.previewUrlSource,
      form.previewUrl,
      form.previewFileName,
      form.previewContentType,
      form.previewFileSizeBytes,
      form.previewDurationSeconds
    ),
    imageModel: normalizeTemplateText(form.imageModel, TEMPLATE_MODEL_MAX_LENGTH),
    imagePrompt: normalizeTemplateText(form.imagePrompt, TEMPLATE_PROMPT_MAX_LENGTH),
  };

  return templateId ? updateImageTemplate(templateId, payload) : createImageTemplate(payload);
}

export async function saveVideoTemplateFromForm(
  templateId: string | undefined,
  form: TemplateFormState,
  status: TemplateStatus
): Promise<AdminTemplate> {
  const payload: VideoTemplatePayload = {
    title: normalizeTemplateText(form.title, TEMPLATE_TITLE_MAX_LENGTH),
    shortDescription: normalizeTemplateText(
      form.shortDescription,
      TEMPLATE_SHORT_DESCRIPTION_MAX_LENGTH
    ),
    petPhotoRequirements: normalizeRequirements(form.petPhotoRequirements),
    category: normalizeTemplateText(form.category, TEMPLATE_CATEGORY_MAX_LENGTH),
    status,
    promoBadgeMode: form.promoBadgeMode as TemplatePromoBadgeMode,
    tags: normalizeTags(form.tags),
    isPremium: form.isPremium,
    tokenCost: parseNumber(form.tokenCost),
    musicDescription: normalizeTemplateText(
      form.musicDescription,
      TEMPLATE_MUSIC_DESCRIPTION_MAX_LENGTH
    ),
    previewAsset: buildUploadedAsset(
      form.previewUrlSource,
      form.previewUrl,
      form.previewFileName,
      form.previewContentType,
      form.previewFileSizeBytes,
      form.previewDurationSeconds
    ),
    referenceMotionAsset: buildUploadedAsset(
      form.referenceUrlSource,
      form.referenceUrl,
      form.referenceFileName,
      form.referenceContentType,
      form.referenceFileSizeBytes,
      form.referenceDurationSeconds
    ),
    preprocessingModel: normalizeTemplateText(form.preprocessingModel, TEMPLATE_MODEL_MAX_LENGTH),
    preprocessingPrompt: normalizeTemplateText(form.preprocessingPrompt, TEMPLATE_PROMPT_MAX_LENGTH),
    klingModel: normalizeTemplateText(form.klingModel, TEMPLATE_MODEL_MAX_LENGTH),
    klingPrompt: normalizeTemplateText(form.klingPrompt, TEMPLATE_PROMPT_MAX_LENGTH),
    keepOriginalSound: form.keepOriginalSound,
  };

  return templateId ? updateVideoTemplate(templateId, payload) : createVideoTemplate(payload);
}

export function parseNumber(raw: string): number {
  const normalized = raw.trim();
  if (!new RegExp(`^\\d{1,${TEMPLATE_TOKEN_COST_MAX_LENGTH}}$`).test(normalized)) {
    return 0;
  }

  const value = Number.parseInt(normalized, 10);
  return Number.isSafeInteger(value) ? value : 0;
}

export function parseOptionalDecimal(raw?: string): number | undefined {
  const normalized = raw?.trim();
  if (!normalized || !/^\d+(?:\.\d{1,3})?$/.test(normalized)) {
    return undefined;
  }

  const value = Number.parseFloat(normalized);
  return Number.isFinite(value) && value > 0 && value <= TEMPLATE_ASSET_DURATION_MAX_SECONDS
    ? value
    : undefined;
}

function buildUploadedAsset(
  source: TemplateFormState["previewUrlSource"] | TemplateFormState["referenceUrlSource"],
  url: string,
  fileName: string,
  contentType: string,
  fileSizeBytes: string,
  durationSeconds?: string
): TemplateAssetInput | undefined {
  if (source !== "uploaded") {
    return undefined;
  }

  if (!url.trim()) {
    return undefined;
  }

  const size = parseOptionalNumber(fileSizeBytes);
  const duration = parseOptionalDecimal(durationSeconds);

  return {
    url: url.trim(),
    fileName:
      normalizeTemplateText(fileName, TEMPLATE_ASSET_METADATA_MAX_LENGTH) || inferFileName(url),
    contentType:
      normalizeTemplateText(contentType, TEMPLATE_ASSET_METADATA_MAX_LENGTH) ||
      inferContentType(url),
    fileSizeBytes: size,
    durationSeconds: duration,
  };
}

function normalizeTags(raw: string): string[] {
  return raw
    .split(",")
    .map((tag) => normalizeTemplateText(tag, TEMPLATE_TAG_MAX_LENGTH))
    .filter(Boolean)
    .slice(0, TEMPLATE_TAG_MAX_COUNT);
}

function normalizeRequirements(raw: string): string[] {
  return raw
    .split(/\r?\n/)
    .map((item) => normalizeTemplateText(item, TEMPLATE_REQUIREMENT_MAX_LENGTH))
    .filter(Boolean)
    .slice(0, 6);
}

export function normalizeTemplateText(raw: string, maxLength: number): string {
  return raw.replace(/\s+/g, " ").trim().slice(0, maxLength);
}

function parseOptionalNumber(raw: string): number | undefined {
  const normalized = normalizeIntegerString(raw);
  const value = Number.parseInt(normalized, 10);
  return normalized && Number.isSafeInteger(value) ? value : undefined;
}

export function normalizeTemplateIntegerInput(raw: string): string {
  return raw.replace(/\D+/g, "").slice(0, TEMPLATE_TOKEN_COST_MAX_LENGTH);
}

export function normalizeTemplateTextInput(raw: string, maxLength: number): string {
  return raw.slice(0, maxLength);
}

function normalizeIntegerString(raw: string): string {
  return normalizeTemplateIntegerInput(raw);
}

function inferFileName(url: string): string {
  const parts = url.split("/");
  return parts.at(-1) || "asset";
}

function inferContentType(url: string): string {
  const lower = url.toLowerCase();

  if (lower.endsWith(".mp4")) {
    return "video/mp4";
  }

  if (lower.endsWith(".webm")) {
    return "video/webm";
  }

  if (lower.endsWith(".png")) {
    return "image/png";
  }

  return "image/jpeg";
}
