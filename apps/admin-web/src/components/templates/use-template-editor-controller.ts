"use client";

import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";

import { useSyncToastToAdminNotifications } from "@/components/admin/admin-notifications";
import { ensureAdminSession } from "@/components/admin/admin-session";
import { buildTemplateEditorModel } from "@/components/templates/template-editor-model";
import {
  createFormFromTemplate,
  createInitialTemplateForm,
  parseOptionalDecimal,
  saveImageTemplateFromForm,
  saveVideoTemplateFromForm,
} from "@/components/templates/template-form-mappers";
import { type TemplateFormState } from "@/components/templates/types";
import { useAdminTemplateCategories } from "@/components/templates/use-admin-template-categories";
import { useAdminTemplateOptions } from "@/components/templates/use-admin-template-options";
import { getAdminErrorMessage } from "@/lib/admin-error-message";
import { adminQueryKeys } from "@/lib/admin-query-keys";
import {
  fetchAdminTemplate,
  uploadTemplateMedia,
  useAuthSession,
  type AdminTemplate,
  type TemplateAssetKind,
  type TemplateStatus,
  type TemplateType,
} from "@/lib/api-client";
import { clientLogger } from "@/lib/client-logger";
import { getDictionary, type Dictionary, type Locale } from "@/lib/i18n";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

type TemplateEditorControllerOptions = {
  initialTemplateId?: string;
  locale: Locale;
  templateType: TemplateType;
};

type ToastState = {
  type: "success" | "error";
  message: string;
};

type EditorVisibilityStatus = Extract<TemplateStatus, "Draft" | "Active">;

export function useTemplateEditorController({
  initialTemplateId,
  locale,
  templateType,
}: TemplateEditorControllerOptions) {
  const text = getDictionary(locale);
  const router = useRouter();
  const queryClient = useQueryClient();
  const session = useAuthSession();
  const canManageTemplates = session?.user.roles.includes("Admin") ?? false;
  const { categories } = useAdminTemplateCategories({
    enabled: Boolean(session),
    includeArchived: false,
  });
  const {
    hasError: hasTemplateOptionsError,
    isLoading: isTemplateOptionsLoading,
    refresh: refreshTemplateOptions,
    templates,
  } = useAdminTemplateOptions({ enabled: Boolean(session), templateType });
  const [selectedTemplate, setSelectedTemplate] = useState<AdminTemplate | null>(null);
  const [form, setForm] = useState<TemplateFormState>(() =>
    createInitialTemplateForm(templateType)
  );
  const [isInitializing, setIsInitializing] = useState(true);
  const [previewFile, setPreviewFile] = useState<File | null>(null);
  const [referenceFile, setReferenceFile] = useState<File | null>(null);
  const [uploadingKind, setUploadingKind] = useState<TemplateAssetKind | null>(null);
  const [toast, setToast] = useState<ToastState | null>(null);
  const [editorStatus, setEditorStatus] = useState<EditorVisibilityStatus>("Draft");
  const isVideo = templateType === "Video";
  const templateEditorActionsAdminOnly =
    locale === "ru"
      ? "Управление шаблонами доступно только Admin."
      : "Template management actions are available to Admin only.";

  useSyncToastToAdminNotifications(toast, {
    category: "templates",
    source: `template-editor:${templateType.toLowerCase()}`,
    title:
      locale === "ru"
        ? templateType === "Video"
          ? "Видео-шаблоны"
          : "Изображения-шаблоны"
        : templateType === "Video"
          ? "Video templates"
          : "Image templates",
    href: getTemplateCatalogPath(locale, templateType),
  });

  const saveTemplateMutation = useMutation<AdminTemplate, unknown, EditorVisibilityStatus>({
    mutationFn: (targetStatus) =>
      templateType === "Video"
        ? saveVideoTemplateFromForm(selectedTemplate?.templateId, form, targetStatus)
        : saveImageTemplateFromForm(selectedTemplate?.templateId, form, targetStatus),
    onSuccess: async (savedTemplate) => {
      setSelectedTemplate(savedTemplate);
      setForm(createFormFromTemplate(savedTemplate));
      setEditorStatus(resolveEditorVisibilityStatus(savedTemplate.status));

      await Promise.allSettled([
        refreshTemplateOptions(),
        queryClient.invalidateQueries({ queryKey: adminQueryKeys.templateCatalog(templateType) }),
        queryClient.invalidateQueries({ queryKey: adminQueryKeys.templateCategories(false) }),
        queryClient.invalidateQueries({ queryKey: adminQueryKeys.templateCategories(true) }),
      ]);
    },
  });

  const uploadTemplateMediaMutation = useMutation({
    mutationFn: ({
      assetKind,
      file,
      durationSeconds,
    }: {
      assetKind: TemplateAssetKind;
      file: File;
      durationSeconds?: number;
    }) => uploadTemplateMedia(file, assetKind, { durationSeconds }),
    onSuccess: (asset, { assetKind }) => {
      setForm((current) =>
        assetKind === "Preview"
          ? {
              ...current,
              previewUrl: asset.url,
              previewFileName: asset.fileName,
              previewContentType: asset.contentType,
              previewFileSizeBytes: asset.fileSizeBytes?.toString() ?? "",
              previewDurationSeconds: asset.durationSeconds?.toString() ?? "",
            }
          : {
              ...current,
              referenceUrl: asset.url,
              referenceFileName: asset.fileName,
              referenceContentType: asset.contentType,
              referenceFileSizeBytes: asset.fileSizeBytes?.toString() ?? "",
              referenceDurationSeconds: asset.durationSeconds?.toString() ?? "",
            }
      );

      if (assetKind === "Preview") {
        setPreviewFile(null);
      } else {
        setReferenceFile(null);
      }

      setToast({
        type: "success",
        message: text.templateFileUploaded,
      });
    },
    onError: () => {
      setToast({ type: "error", message: text.errorSavingTemplate });
    },
  });

  useEffect(() => {
    if (!toast) {
      return;
    }

    const timer = window.setTimeout(() => setToast(null), 2600);
    return () => window.clearTimeout(timer);
  }, [toast]);

  useEffect(() => {
    let isCancelled = false;
    const controller = new AbortController();

    async function initialize() {
      setIsInitializing(true);
      try {
        if (!ensureAdminSession(locale, router)) {
          return;
        }

        if (initialTemplateId) {
          const templateResponse = await fetchAdminTemplate(initialTemplateId, controller.signal);
          if (isCancelled) {
            return;
          }

          setSelectedTemplate(templateResponse);
          setForm(createFormFromTemplate(templateResponse));
          setEditorStatus(resolveEditorVisibilityStatus(templateResponse.status));
        }

        if (!isCancelled) {
          setIsInitializing(false);
        }
      } catch (error) {
        if (controller.signal.aborted || isCancelled) {
          return;
        }

        clientLogger.error("templates.editor_initialize_failed", {
          initialTemplateId,
          templateType,
          error,
        });
        if (!isCancelled) {
          setToast({ type: "error", message: text.errorLoadingTemplates });
        }
      } finally {
        if (!isCancelled) {
          setIsInitializing(false);
        }
      }
    }

    void initialize();

    return () => {
      isCancelled = true;
      controller.abort();
    };
  }, [initialTemplateId, locale, router, templateType, text.errorLoadingTemplates]);

  function resetForm() {
    setSelectedTemplate(null);
    setForm(createInitialTemplateForm(templateType));
    setEditorStatus("Draft");
    setPreviewFile(null);
    setReferenceFile(null);
  }

  function assertCanManageTemplateEditor(): boolean {
    if (canManageTemplates) {
      return true;
    }

    setToast({ type: "error", message: templateEditorActionsAdminOnly });
    return false;
  }

  async function handleSave(targetStatus: EditorVisibilityStatus) {
    if (!assertCanManageTemplateEditor()) {
      return;
    }

    if (saveTemplateMutation.isPending) {
      return;
    }

    const catalogPath = getTemplateCatalogPath(locale, templateType);

    try {
      const activationReadinessError = getActivationReadinessError(
        templateType,
        form,
        text,
        targetStatus
      );
      if (activationReadinessError) {
        setToast({ type: "error", message: activationReadinessError });
        return;
      }

      await saveTemplateMutation.mutateAsync(targetStatus);
      setToast({
        type: "success",
        message: targetStatus === "Active" ? text.templateActivated : text.templateSavedAsDraft,
      });

      router.push(catalogPath);
    } catch (error) {
      const message = getTemplateSaveErrorMessage(error, text, targetStatus);
      setToast({ type: "error", message });
    }
  }

  async function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    await handleSave(editorStatus);
  }

  async function handleUpload(assetKind: TemplateAssetKind) {
    if (!assertCanManageTemplateEditor()) {
      return;
    }

    if (uploadTemplateMediaMutation.isPending || uploadingKind !== null) {
      return;
    }

    const file = assetKind === "Preview" ? previewFile : referenceFile;
    if (!file) {
      return;
    }

    setUploadingKind(assetKind);
    try {
      const durationSeconds =
        assetKind === "Preview" && file.type.startsWith("video/")
          ? await readVideoDurationSeconds(file)
          : undefined;
      await uploadTemplateMediaMutation.mutateAsync({ assetKind, file, durationSeconds });
    } catch (error) {
      const message = resolveUploadErrorMessage(error, text.errorSavingTemplate);
      setToast({ type: "error", message });
      clientLogger.warn("templates.media_upload_failed", {
        assetKind,
        fileName: sanitizeSensitiveText(file.name, 120),
        contentType: file.type,
        error,
      });
    } finally {
      setUploadingKind(null);
    }
  }

  const mergedCategorySuggestions = getUniqueValues([
    ...categories.map((category) => category.name),
    ...templates.map((template) => template.category),
  ]);
  const isEditMode = selectedTemplate !== null;
  const catalogPath = getTemplateCatalogPath(locale, templateType);
  const editorModel = buildTemplateEditorModel(text, form, selectedTemplate, templateType);
  const catalogLabel = isVideo ? text.navVideoTemplates : text.navImageTemplates;
  const fallbackPreviewTitle = isVideo
    ? text.videoTemplateCreatePageTitle
    : text.imageTemplatesTitle;
  const previewTags = form.tags
    .split(",")
    .map((tag) => tag.trim())
    .filter(Boolean);
  const isLoading = isInitializing || isTemplateOptionsLoading;
  const isSaving = saveTemplateMutation.isPending;
  const activeToast =
    toast ??
    (hasTemplateOptionsError
      ? { type: "error" as const, message: text.errorLoadingTemplates }
      : null);

  return {
    activeToast,
    catalogLabel,
    catalogPath,
    editorModel,
    editorStatus,
    fallbackPreviewTitle,
    form,
    handleSave,
    handleSubmit,
    handleUpload,
    isEditMode,
    isLoading,
    isSaving,
    isVideo,
    mergedCategorySuggestions,
    previewFile,
    previewTags,
    referenceFile,
    resetForm,
    router,
    selectedTemplate,
    setEditorStatus,
    setForm,
    setPreviewFile,
    setReferenceFile,
    text,
    uploadingKind,
  };
}

function resolveUploadErrorMessage(error: unknown, fallback: string): string {
  return getAdminErrorMessage(error, fallback);
}

async function readVideoDurationSeconds(file: File): Promise<number | undefined> {
  const objectUrl = URL.createObjectURL(file);
  try {
    const duration = await new Promise<number | undefined>((resolve) => {
      const video = document.createElement("video");
      let settled = false;
      const timeoutId = window.setTimeout(() => {
        if (settled) {
          return;
        }

        settled = true;
        resolve(undefined);
      }, 5000);

      const finalize = (value: number | undefined) => {
        if (settled) {
          return;
        }

        settled = true;
        window.clearTimeout(timeoutId);
        resolve(value);
      };

      video.preload = "metadata";
      video.src = objectUrl;
      video.onloadedmetadata = () => {
        const value = Number.isFinite(video.duration) && video.duration > 0 ? video.duration : undefined;
        finalize(value);
      };
      video.onerror = () => finalize(undefined);
    });

    return duration;
  } finally {
    URL.revokeObjectURL(objectUrl);
  }
}

function getTemplateCatalogPath(locale: Locale, templateType: TemplateType) {
  const slug = templateType === "Video" ? "video" : "image";
  return `/${locale}/templates/${slug}`;
}

function getUniqueValues(values: string[]): string[] {
  return Array.from(new Set(values.map((value) => value.trim()).filter(Boolean))).sort(
    (left, right) => left.localeCompare(right)
  );
}

function resolveEditorVisibilityStatus(status?: TemplateStatus): EditorVisibilityStatus {
  return status === "Active" ? "Active" : "Draft";
}

function getTemplateSaveErrorMessage(
  error: unknown,
  text: Dictionary,
  targetStatus: EditorVisibilityStatus
): string {
  return getAdminErrorMessage(
    error,
    targetStatus === "Active" ? text.errorActivatingTemplate : text.errorSavingTemplate
  );
}

function getActivationReadinessError(
  templateType: TemplateType,
  form: TemplateFormState,
  text: Dictionary,
  targetStatus: EditorVisibilityStatus
): string | null {
  if (targetStatus !== "Active") {
    return null;
  }

  const missingLabels: string[] = [];

  if (!form.previewUrl.trim()) {
    missingLabels.push(text.previewAssetTitle);
  }

  if (!form.petPhotoRequirements.trim()) {
    missingLabels.push(text.petPhotoRequirementsLabel);
  }

  if (templateType === "Video") {
    if (!form.referenceUrl.trim()) {
      missingLabels.push(text.referenceMotionTitle);
    }

    if (parseOptionalDecimal(form.referenceDurationSeconds) === undefined) {
      missingLabels.push(text.referenceDurationLabel);
    }
  } else {
    if (!form.imageModel.trim()) {
      missingLabels.push(text.imageModelLabel);
    }

    if (!form.imagePrompt.trim()) {
      missingLabels.push(text.imagePromptLabel);
    }
  }

  if (missingLabels.length === 0) {
    return null;
  }

  return `${text.activationRequirementsMissing} ${missingLabels.join(", ")}.`;
}
