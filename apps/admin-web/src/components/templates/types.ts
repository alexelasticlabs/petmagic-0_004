import type { Dispatch, SetStateAction } from "react";

export type TemplateFormState = {
  title: string;
  shortDescription: string;
  petPhotoRequirements: string;
  category: string;
  promoBadgeMode: string;
  tags: string;
  isPremium: boolean;
  tokenCost: string;
  supportsGenerationResultInput: boolean;
  requiredInputMediaType: "Image" | "Video";
  recommendedAfterImageGeneration: boolean;
  previewUrl: string;
  previewUrlSource: "none" | "persisted" | "uploaded";
  previewFileName: string;
  previewContentType: string;
  previewFileSizeBytes: string;
  previewDurationSeconds: string;
  musicDescription: string;
  referenceUrl: string;
  referenceUrlSource: "none" | "persisted" | "uploaded";
  referenceFileName: string;
  referenceContentType: string;
  referenceFileSizeBytes: string;
  referenceDurationSeconds: string;
  imageModel: string;
  imagePrompt: string;
  preprocessingModel: string;
  preprocessingPrompt: string;
  klingModel: string;
  klingPrompt: string;
  keepOriginalSound: boolean;
};

export type SetTemplateFormState = Dispatch<SetStateAction<TemplateFormState>>;
