import {
  getTemplateTestPageText,
  type TemplateTestPageText,
} from "@/components/templates/template-test-page.content";
import type {
  ApiLikeError,
  BuildRunDetailsParams,
  DetailItem,
  TimelineItem,
} from "@/components/templates/template-test-page.types";
import { getAdminErrorMessage } from "@/lib/admin-error-message";
import type { AdminTemplate, AdminTemplateTestRun } from "@/lib/api-client";
import type { Dictionary, Locale } from "@/lib/i18n";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

export const MAX_TEMPLATE_TEST_IMAGE_BYTES = 8 * 1024 * 1024;

export function formatTemplateTestDisplayText(
  value: string | null | undefined,
  fallback = "-",
  maxLength = 160
) {
  const trimmed = value?.trim();
  return sanitizeSensitiveText(trimmed || fallback, maxLength);
}

export function getTemplateTestErrorDetails(error: unknown) {
  return {
    errorName: error instanceof Error ? error.name : "UnknownError",
    errorDigest:
      error && typeof error === "object" && "digest" in error
        ? sanitizeSensitiveText(String((error as { digest?: unknown }).digest ?? ""), 80)
        : undefined,
  };
}

export function isTemplateTestRunInFlight(run: AdminTemplateTestRun | null | undefined): boolean {
  return run?.status === "Queued" || run?.status === "Processing" || run?.status === "Retrying";
}

export function getStartTestErrorMessage(
  error: unknown,
  text: Dictionary,
  isVideoTemplate: boolean
): string {
  const apiError = error as ApiLikeError | null;
  if (!apiError) {
    return text.templateTestStartFailed;
  }

  if (Array.isArray(apiError.validationErrors) && apiError.validationErrors.length > 0) {
    return getAdminErrorMessage(
      { validationErrors: apiError.validationErrors },
      text.templateTestStartFailed
    );
  }

  if (apiError.code === "templates.invalid_status") {
    return text.templateTestInvalidStatus;
  }

  if (
    apiError.code === "templates.image_model_required" ||
    apiError.code === "templates.invalid_image_model"
  ) {
    return text.templateTestImageModelRequired;
  }

  if (isVideoTemplate && apiError.code === "templates.reference_motion_required") {
    return text.templateTestReferenceMotionRequired;
  }

  if (isVideoTemplate && apiError.code === "templates.invalid_preprocessing_model") {
    return text.templateTestPreprocessingModelRequired;
  }

  if (isVideoTemplate && apiError.code === "templates.invalid_kling_model") {
    return text.templateTestKlingModelRequired;
  }

  if (isVideoTemplate && apiError.code === "templates.character_orientation_required") {
    return text.templateTestCharacterOrientationRequired;
  }

  return getAdminErrorMessage(error, text.templateTestStartFailed);
}

export function buildRunDetails({
  run,
  locale,
  pageText,
  isVideoTemplate,
  statusText,
  petMagicBillingLabel,
  internalBillingText,
  falProviderCostLabel,
  providerCostText,
}: BuildRunDetailsParams): DetailItem[] {
  const common: DetailItem[] = [
    { label: pageText.attempt, value: run ? String(run.attemptCount) : "-" },
    { label: pageText.status, value: statusText },
    { label: petMagicBillingLabel, value: internalBillingText },
    { label: falProviderCostLabel, value: providerCostText },
    {
      label: pageText.created,
      value: run ? formatDateTime(run.createdAtUtc, locale, true) : "-",
    },
    { label: pageText.started, value: formatDateTime(run?.startedAtUtc, locale, true) },
  ];

  if (!isVideoTemplate) {
    return [
      ...common,
      {
        label: pageText.imageGenerationCompleted,
        value: formatDateTime(run?.preprocessingCompletedAtUtc, locale, true),
      },
      {
        label: pageText.falImageRequest,
        value: formatTemplateTestDisplayText(run?.preprocessingProviderRequestId, "-", 120),
      },
      {
        label: pageText.falImageInferenceDetail,
        value: formatSeconds(run?.preprocessingInferenceTimeSeconds, pageText),
      },
      {
        label: pageText.mediaImport,
        value: formatDateTime(run?.mediaImportCompletedAtUtc, locale, true),
      },
      {
        label: pageText.failureCode,
        value: formatTemplateTestDisplayText(run?.failureCode, "-", 120),
      },
    ];
  }

  return [
    ...common,
    {
      label: pageText.preprocessingCompleted,
      value: formatDateTime(run?.preprocessingCompletedAtUtc, locale, true),
    },
    {
      label: pageText.falPreprocessRequest,
      value: formatTemplateTestDisplayText(run?.preprocessingProviderRequestId, "-", 120),
    },
    {
      label: pageText.falPreprocessInference,
      value: formatSeconds(run?.preprocessingInferenceTimeSeconds, pageText),
    },
    {
      label: pageText.motionCompleted,
      value: formatDateTime(run?.motionGenerationCompletedAtUtc, locale, true),
    },
    {
      label: pageText.falMotionRequest,
      value: formatTemplateTestDisplayText(run?.motionProviderRequestId, "-", 120),
    },
    {
      label: pageText.falMotionInferenceDetail,
      value: formatSeconds(run?.motionInferenceTimeSeconds, pageText),
    },
    {
      label: pageText.finalVideoDuration,
      value: formatSeconds(run?.outputVideoDurationSeconds, pageText),
    },
    {
      label: pageText.mediaImport,
      value: formatDateTime(run?.mediaImportCompletedAtUtc, locale, true),
    },
    {
      label: pageText.failureCode,
      value: formatTemplateTestDisplayText(run?.failureCode, "-", 120),
    },
  ];
}

export function formatReferenceDuration(value: number | undefined, text: TemplateTestPageText) {
  if (!value) {
    return text.noReference;
  }

  const rounded = Math.max(0, Math.round(value));
  const minutes = Math.floor(rounded / 60)
    .toString()
    .padStart(2, "0");
  const seconds = (rounded % 60).toString().padStart(2, "0");
  return rounded >= 60 ? `${minutes}:${seconds}` : `${rounded} ${text.secondsSuffix}`;
}

export function formatGenerationDuration(
  run: AdminTemplateTestRun | null,
  text: TemplateTestPageText
) {
  if (!run?.startedAtUtc || !run.completedAtUtc) {
    return text.inProgress;
  }

  const started = new Date(run.startedAtUtc).getTime();
  const completed = new Date(run.completedAtUtc).getTime();
  if (Number.isNaN(started) || Number.isNaN(completed) || completed < started) {
    return "-";
  }

  const seconds = Math.round((completed - started) / 1000);
  return formatReferenceDuration(seconds, text);
}

export function formatTokenCost(value: number) {
  return `${value} PawSpark`;
}

export function formatSeconds(value: number | undefined | null, text: TemplateTestPageText) {
  if (typeof value !== "number" || Number.isNaN(value) || value <= 0) {
    return "-";
  }

  const formatted = new Intl.NumberFormat(text.intlLocale, {
    minimumFractionDigits: value % 1 === 0 ? 0 : 1,
    maximumFractionDigits: 2,
  }).format(value);

  return `${formatted} ${text.secondsSuffix}`;
}

export function formatUsd(value: number, intlLocale: string) {
  return new Intl.NumberFormat(intlLocale, {
    style: "currency",
    currency: "USD",
    minimumFractionDigits: 2,
    maximumFractionDigits: 4,
  }).format(value);
}

export function formatProviderCost(run: AdminTemplateTestRun | null, text: TemplateTestPageText) {
  if (typeof run?.motionProviderCostUsd === "number" && !Number.isNaN(run.motionProviderCostUsd)) {
    return formatUsd(run.motionProviderCostUsd, text.intlLocale);
  }

  return run ? text.providerPendingAfterCompletion : text.providerPendingAfterGeneration;
}

export function formatProviderInference(
  run: AdminTemplateTestRun | null,
  text: TemplateTestPageText,
  isVideoTemplate: boolean
) {
  const value = isVideoTemplate
    ? run?.motionInferenceTimeSeconds
    : run?.preprocessingInferenceTimeSeconds;
  if (typeof value === "number" && !Number.isNaN(value)) {
    return formatSeconds(value, text);
  }

  return run ? text.providerPendingAfterCompletion : text.providerPendingAfterGeneration;
}

export function formatDateTime(value: string | undefined | null, locale: Locale, withDate = false) {
  if (!value) {
    return "-";
  }

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return "-";
  }

  const intlLocale = getTemplateTestPageText(locale).intlLocale;
  return new Intl.DateTimeFormat(
    intlLocale,
    withDate
      ? {
          day: "2-digit",
          month: "short",
          hour: "2-digit",
          minute: "2-digit",
        }
      : {
          hour: "2-digit",
          minute: "2-digit",
          second: "2-digit",
        }
  ).format(date);
}

export function formatBytes(value: number) {
  if (value < 1024 * 1024) {
    return `${Math.max(1, Math.round(value / 1024))} KB`;
  }

  return `${(value / 1024 / 1024).toFixed(1)} MB`;
}

export function buildGeneratedDownloadName(
  templateTitle: string,
  generationId: string,
  extension: ".mp4" | ".png"
) {
  const safeTitle = sanitizeSensitiveText(templateTitle, 96)
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9а-яё]+/gi, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 48);
  const safeGenerationId = sanitizeSensitiveText(generationId, 64)
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9-]+/gi, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 48);

  return `${safeTitle || "template-test"}-${safeGenerationId || "run"}${extension}`;
}

export function formatTemplateStatus(
  status: AdminTemplate["status"],
  locale: Locale,
  text = getTemplateTestPageText(locale)
) {
  const localizedStatuses: Partial<Record<AdminTemplate["status"], string>> = {
    Active: text.templateStatusActive,
    Draft: text.templateStatusDraft,
    Archived: text.templateStatusArchived,
  };

  return localizedStatuses[status] ?? formatTemplateTestDisplayText(status, "-", 48);
}

export function buildTimeline(
  run: AdminTemplateTestRun | null,
  locale: Locale,
  text: TemplateTestPageText,
  isVideoTemplate: boolean
): TimelineItem[] {
  if (!run) {
    return [];
  }

  const items: TimelineItem[] = [
    {
      label: text.timelineTestQueued,
      at: formatDateTime(run.createdAtUtc, locale),
      description: text.timelineTestQueuedDescription,
      done: true,
    },
  ];

  if (run.sourceImageAsset) {
    items.push({
      label: text.timelinePhotoUploaded,
      at: formatDateTime(run.createdAtUtc, locale),
      description: text.timelinePhotoUploadedDescription,
      done: true,
    });
  }

  if (run.startedAtUtc) {
    items.push({
      label: isVideoTemplate
        ? text.timelinePreprocessingStarted
        : text.timelineImageGenerationStarted,
      at: formatDateTime(run.startedAtUtc, locale),
      description: `${text.modelLabel}: ${formatTemplateTestDisplayText(
        run.usedPreprocessingModel,
        "-",
        80
      )}`,
      done: Boolean(run.preprocessingCompletedAtUtc),
    });
  }

  if (run.preprocessingCompletedAtUtc) {
    items.push({
      label: isVideoTemplate
        ? text.timelinePreprocessingCompleted
        : text.timelineImageReceivedFromProvider,
      at: formatDateTime(run.preprocessingCompletedAtUtc, locale),
      description: isVideoTemplate
        ? text.timelineNormalizedImageReady
        : text.timelineGeneratedImageReady,
      done: true,
    });
  }

  if (isVideoTemplate && (run.preprocessingCompletedAtUtc || run.motionGenerationCompletedAtUtc)) {
    items.push({
      label: text.timelineMotionGeneration,
      at: formatDateTime(run.preprocessingCompletedAtUtc ?? run.startedAtUtc, locale),
      description: `${text.modelLabel}: ${formatTemplateTestDisplayText(
        run.usedKlingModel,
        "-",
        80
      )}`,
      done: Boolean(run.motionGenerationCompletedAtUtc),
    });
  }

  if (isVideoTemplate && run.motionGenerationCompletedAtUtc) {
    items.push({
      label: text.timelineVideoReceivedFromProvider,
      at: formatDateTime(run.motionGenerationCompletedAtUtc, locale),
      description: text.timelineIntermediateVideoReady,
      done: Boolean(
        run.mediaImportCompletedAtUtc || (run.completedAtUtc && run.status === "Completed")
      ),
    });
  }

  if (run.mediaImportCompletedAtUtc) {
    items.push({
      label: text.timelineMediaStorageImport,
      at: formatDateTime(run.mediaImportCompletedAtUtc, locale),
      description: isVideoTemplate ? text.timelineFinalVideoSaved : text.timelineFinalImageSaved,
      done: run.status === "Completed",
    });
  }

  if (run.completedAtUtc && run.status === "Completed") {
    items.push({
      label: text.timelineCompletedSuccess,
      at: formatDateTime(run.completedAtUtc, locale),
      description: text.timelineCompletedSuccessDescription,
      done: true,
    });
  }

  if (run.completedAtUtc && run.status === "Failed") {
    items.push({
      label: text.timelineFailed,
      at: formatDateTime(run.completedAtUtc, locale),
      description: formatTemplateTestDisplayText(run.failureCode, text.timelineFailedFallback, 120),
      done: false,
    });
  }

  return items;
}
