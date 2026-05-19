"use client";

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
import { getDictionary, type Dictionary, type Locale } from "@/lib/i18n";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";

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

export function useTemplateEditorController({ initialTemplateId, locale, templateType }: TemplateEditorControllerOptions) {
  const text = getDictionary(locale);
  const router = useRouter();
  const queryClient = useQueryClient();
  const session = useAuthSession();
  const { categories } = useAdminTemplateCategories({ enabled: Boolean(session), includeArchived: false });
  const {
    hasError: hasTemplateOptionsError,
    isLoading: isTemplateOptionsLoading,
    refresh: refreshTemplateOptions,
    templates,
  } = useAdminTemplateOptions({ enabled: Boolean(session), templateType });
  const [selectedTemplate, setSelectedTemplate] = useState<AdminTemplate | null>(null);
  const [form, setForm] = useState<TemplateFormState>(() => createInitialTemplateForm(templateType));
  const [isInitializing, setIsInitializing] = useState(true);
  const [previewFile, setPreviewFile] = useState<File | null>(null);
  const [referenceFile, setReferenceFile] = useState<File | null>(null);
  const [uploadingKind, setUploadingKind] = useState<TemplateAssetKind | null>(null);
  const [toast, setToast] = useState<ToastState | null>(null);
  const [editorStatus, setEditorStatus] = useState<EditorVisibilityStatus>("Draft");
  const isVideo = templateType === "Video";

  const saveTemplateMutation = useMutation<AdminTemplate, unknown, EditorVisibilityStatus>({
    mutationFn: (targetStatus) => (
      templateType === "Video"
        ? saveVideoTemplateFromForm(selectedTemplate?.templateId, form, targetStatus)
        : saveImageTemplateFromForm(selectedTemplate?.templateId, form, targetStatus)
    ),
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
    mutationFn: ({ assetKind, file }: { assetKind: TemplateAssetKind; file: File }) => uploadTemplateMedia(file, assetKind),
    onSuccess: (asset, { assetKind }) => {
      setForm((current) => assetKind === "Preview"
        ? {
          ...current,
          previewUrl: asset.url,
          previewFileName: asset.fileName,
          previewContentType: asset.contentType,
          previewFileSizeBytes: asset.fileSizeBytes?.toString() ?? "",
        }
        : {
          ...current,
          referenceUrl: asset.url,
          referenceFileName: asset.fileName,
          referenceContentType: asset.contentType,
          referenceFileSizeBytes: asset.fileSizeBytes?.toString() ?? "",
          referenceDurationSeconds: asset.durationSeconds?.toString() ?? "",
        });

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

    async function initialize() {
      setIsInitializing(true);
      try {
        if (!ensureAdminSession(locale, router)) {
          return;
        }

        if (initialTemplateId) {
          const templateResponse = await fetchAdminTemplate(initialTemplateId);
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
      } catch {
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
    };
  }, [initialTemplateId, locale, router, text.errorLoadingTemplates]);

  function resetForm() {
    setSelectedTemplate(null);
    setForm(createInitialTemplateForm(templateType));
    setEditorStatus("Draft");
    setPreviewFile(null);
    setReferenceFile(null);
  }

  async function handleSave(targetStatus: EditorVisibilityStatus) {
    const catalogPath = getTemplateCatalogPath(locale, templateType);

    try {
      const activationReadinessError = getActivationReadinessError(templateType, form, text, targetStatus);
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
    const file = assetKind === "Preview" ? previewFile : referenceFile;
    if (!file) {
      return;
    }

    setUploadingKind(assetKind);
    try {
      await uploadTemplateMediaMutation.mutateAsync({ assetKind, file });
    } finally {
      setUploadingKind(null);
    }
  }

  const mergedCategorySuggestions = getUniqueValues([...categories.map((category) => category.name), ...templates.map((template) => template.category)]);
  const isEditMode = selectedTemplate !== null;
  const catalogPath = getTemplateCatalogPath(locale, templateType);
  const editorModel = buildTemplateEditorModel(text, form, selectedTemplate, templateType);
  const catalogLabel = isVideo ? text.navVideoTemplates : text.navImageTemplates;
  const fallbackPreviewTitle = isVideo ? text.videoTemplateCreatePageTitle : text.imageTemplatesTitle;
  const previewTags = form.tags.split(",").map((tag) => tag.trim()).filter(Boolean);
  const isLoading = isInitializing || isTemplateOptionsLoading;
  const isSaving = saveTemplateMutation.isPending;
  const activeToast = toast ?? (hasTemplateOptionsError ? { type: "error" as const, message: text.errorLoadingTemplates } : null);

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

function getTemplateCatalogPath(locale: Locale, templateType: TemplateType) {
  const slug = templateType === "Video" ? "video" : "image";
  return `/${locale}/templates/${slug}`;
}

function getUniqueValues(values: string[]): string[] {
  return Array.from(new Set(values.map((value) => value.trim()).filter(Boolean))).sort((left, right) => left.localeCompare(right));
}

function resolveEditorVisibilityStatus(status?: TemplateStatus): EditorVisibilityStatus {
  return status === "Active" ? "Active" : "Draft";
}

function getTemplateSaveErrorMessage(error: unknown, text: Dictionary, targetStatus: EditorVisibilityStatus): string {
  if (error && typeof error === "object" && "validationErrors" in error) {
    const validationErrors = (error as { validationErrors?: string[] }).validationErrors ?? [];
    if (validationErrors.length > 0) {
      return validationErrors.join(" ");
    }
  }

  if (error instanceof Error && error.message && !/^API request failed with status \d+$/i.test(error.message)) {
    return error.message;
  }

  return targetStatus === "Active" ? text.errorActivatingTemplate : text.errorSavingTemplate;
}

function getActivationReadinessError(
  templateType: TemplateType,
  form: TemplateFormState,
  text: Dictionary,
  targetStatus: EditorVisibilityStatus,
): string | null {
  if (targetStatus !== "Active") {
    return null;
  }

  const missingLabels: string[] = [];

  if (!form.previewUrl.trim()) {
    missingLabels.push(text.previewAssetTitle);
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
