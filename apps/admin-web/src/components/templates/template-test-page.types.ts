import type { TemplateTestPageText } from "@/components/templates/template-test-page.content";
import type { AdminTemplate, AdminTemplateTestRun } from "@/lib/api-client";
import type { Dictionary, Locale } from "@/lib/i18n";

export type TemplateTestPageProps = {
  locale: Locale;
  templateId: string;
};

export type TimelineItem = {
  label: string;
  at: string;
  description: string;
  done: boolean;
};

export type ArtifactItem = {
  key: string;
  title: string;
  accent: "source" | "preprocess" | "result";
  imageUrl?: string;
  videoUrl?: string;
  placeholderEyebrow: string;
  placeholderTitle: string;
  placeholderText: string;
  openLabel: string;
  downloadLabel: string;
  downloadName?: string;
};

export type ApiLikeError = {
  message?: string;
  detail?: string;
  code?: string;
  status?: number;
  validationErrors?: string[];
};

export type DetailItem = {
  label: string;
  value: string;
  multiline?: boolean;
};

export type BuildRunDetailsParams = {
  run: AdminTemplateTestRun | null;
  locale: Locale;
  pageText: TemplateTestPageText;
  isVideoTemplate: boolean;
  statusText: string;
  petMagicBillingLabel: string;
  internalBillingText: string;
  falProviderCostLabel: string;
  providerCostText: string;
};

export type MediaPreviewCardProps = {
  title: string;
  accent: "source" | "preprocess" | "result";
  imageUrl?: string;
  videoUrl?: string;
  placeholderEyebrow: string;
  placeholderTitle: string;
  placeholderText: string;
  openLabel: string;
  downloadLabel: string;
  downloadName?: string;
  canManageTemplates: boolean;
};

export type SourceUploadCardProps = {
  text: TemplateTestPageText;
  imageUrl?: string;
  fileName: string;
  fileMeta: string;
  isDragActive: boolean;
  isDisabled: boolean;
  onDragActiveChange: (value: boolean) => void;
  onFileSelected: (file: File | null) => void;
  onReset?: () => void;
};

export type GetStartTestErrorMessage = (
  error: unknown,
  text: Dictionary,
  isVideoTemplate: boolean
) => string;

export type FormatTemplateStatus = (
  status: AdminTemplate["status"],
  locale: Locale,
  text?: TemplateTestPageText
) => string;
