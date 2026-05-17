import type { Dispatch, SetStateAction } from "react";

export type TemplateFormState = {
  title: string;
  shortDescription: string;
  category: string;
  promoBadgeMode: string;
  tags: string;
  isPremium: boolean;
  tokenCost: string;
  previewUrl: string;
  previewFileName: string;
  previewContentType: string;
  previewFileSizeBytes: string;
  musicDescription: string;
  referenceUrl: string;
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
