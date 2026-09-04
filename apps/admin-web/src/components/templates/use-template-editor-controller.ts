"use client";

import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";

import { useSyncToastToAdminNotifications } from "@/components/admin/admin-notifications";
import { ensureAdminSession } from "@/components/admin/admin-session";
import { buildTemplateEditorModel } from "@/components/templates/template-editor-model";
import { getTemplateEditorRuntimeText } from "@/components/templates/template-editor.content";
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
  type TemplateAsset,
  type TemplateAssetKind,
  type TemplateMediaUploadResponse,
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

function isTemplateRouteTypeCompatible(
  initialTemplateId: string | undefined,
  selectedTemplate: AdminTemplate | null,
  templateType: TemplateType
): boolean {
  return !initialTemplateId || selectedTemplate?.templateType === templateType;
}

function getTemplateEditorErrorDetails(error: unknown) {
  return {
    errorName: error instanceof Error ? error.name : "UnknownError",
    errorDigest:
      error && typeof error === "object" && "digest" in error
        ? sanitizeSensitiveText(String((error as { digest?: unknown }).digest ?? ""), 80)
        : undefined,
  };
}

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
    enabled: canManageTemplates,
    includeArchived: false,
  });
  const {
    hasError: hasTemplateOptionsError,
    isLoading: isTemplateOptionsLoading,
    refresh: refreshTemplateOptions,
    templates,
  } = useAdminTemplateOptions({ enabled: canManageTemplates, templateType });
  const [selectedTemplate, setSelectedTemplate] = useState<AdminTemplate | null>(null);
  const [form, setForm] = useState<TemplateFormState>(() =>
    createInitialTemplateForm(templateType)
  );
  const [isInitializing, setIsInitializing] = useState(true);
  const [initializationError, setInitializationError] = useState<string | null>(null);
  const [initializationRetryKey, setInitializationRetryKey] = useState(0);
  const [previewFile, setPreviewFile] = useState<File | null>(null);
  const [referenceFile, setReferenceFile] = useState<File | null>(null);
  const [uploadingKind, setUploadingKind] = useState<TemplateAssetKind | null>(null);
  const [toast, setToast] = useState<ToastState | null>(null);
  const [editorStatus, setEditorStatus] = useState<EditorVisibilityStatus>("Draft");
  const isVideo = templateType === "Video";
  const runtimeText = getTemplateEditorRuntimeText(locale);
  const templateEditorActionsAdminOnly = runtimeText.actionsAdminOnly;
  const templateEditorTypeMismatch = runtimeText.templateTypeMismatch;
  const notificationTitle = isVideo ? text.videoTemplatesTitle : text.imageTemplatesTitle;

  useSyncToastToAdminNotifications(toast, {
    category: "templates",
    source: `template-editor:${templateType.toLowerCase()}`,
    title: notificationTitle,
    href: getTemplateCatalogPath(locale, templateType),
  });

  const saveTemplateMutation = useMutation<
    AdminTemplate,
    unknown,
    { targetStatus: EditorVisibilityStatus; form: TemplateFormState }
  >({
    mutationFn: ({ targetStatus, form: templateForm }) => {
      if (!isTemplateRouteTypeCompatible(initialTemplateId, selectedTemplate, templateType)) {
        throw new Error(templateEditorTypeMismatch);
      }

      return templateType === "Video"
        ? saveVideoTemplateFromForm(selectedTemplate?.templateId, templateForm, targetStatus)
        : saveImageTemplateFromForm(selectedTemplate?.templateId, templateForm, targetStatus);
    },
    onSuccess: (savedTemplate) => {
      setSelectedTemplate(savedTemplate);
      setForm(createFormFromTemplate(savedTemplate));
      setEditorStatus(resolveEditorVisibilityStatus(savedTemplate.status));

      void Promise.allSettled([
        refreshTemplateOptions(),
        queryClient.invalidateQueries({ queryKey: adminQueryKeys.templateCatalogRoot }),
        queryClient.invalidateQueries({ queryKey: adminQueryKeys.templateCategories(false) }),
        queryClient.invalidateQueries({ queryKey: adminQueryKeys.templateCategories(true) }),
      ]);
    },
  });

  const uploadTemplateMediaMutation = useMutation({
    mutationFn: ({ assetKind, file }: { assetKind: TemplateAssetKind; file: File }) =>
      uploadTemplateMedia(file, assetKind),
    onSuccess: (asset, { assetKind }) => {
      setForm((current) => applyUploadedAssetToForm(current, assetKind, asset));

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
      setInitializationError(null);
      try {
        if (!ensureAdminSession(locale, router, { requiredRole: "Admin" })) {
          return;
        }

        if (initialTemplateId) {
          const templateResponse = await fetchAdminTemplate(initialTemplateId, controller.signal);
          if (isCancelled) {
            return;
          }

          if (templateResponse.templateType !== templateType) {
            clientLogger.warn("templates.editor_template_type_mismatch", {
              initialTemplateId: sanitizeSensitiveText(initialTemplateId, 80),
              routeTemplateType: templateType,
              responseTemplateType: templateResponse.templateType,
            });
            setSelectedTemplate(null);
            setForm(createInitialTemplateForm(templateType));
            setEditorStatus("Draft");
            setPreviewFile(null);
            setReferenceFile(null);
            setInitializationError(templateEditorTypeMismatch);
            setToast({ type: "error", message: templateEditorTypeMismatch });
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
          initialTemplateId: initialTemplateId
            ? sanitizeSensitiveText(initialTemplateId, 80)
            : undefined,
          templateType,
          ...getTemplateEditorErrorDetails(error),
        });
        if (!isCancelled) {
          const message = getAdminErrorMessage(error, text.errorLoadingTemplates);
          setInitializationError(message);
          setToast({ type: "error", message });
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
  }, [
    canManageTemplates,
    initialTemplateId,
    initializationRetryKey,
    locale,
    router,
    templateType,
    templateEditorTypeMismatch,
    text.errorLoadingTemplates,
  ]);

  function resetForm() {
    if (selectedTemplate) {
      setForm(createFormFromTemplate(selectedTemplate));
      setEditorStatus(resolveEditorVisibilityStatus(selectedTemplate.status));
    } else {
      setForm(createInitialTemplateForm(templateType));
      setEditorStatus("Draft");
    }

    setPreviewFile(null);
    setReferenceFile(null);
  }

  function retryInitialization() {
    setInitializationRetryKey((current) => current + 1);
  }

  function assertCanManageTemplateEditor(): boolean {
    if (canManageTemplates) {
      return true;
    }

    setToast({ type: "error", message: templateEditorActionsAdminOnly });
    return false;
  }

  function assertTemplateMatchesEditorRoute(): boolean {
    if (isTemplateRouteTypeCompatible(initialTemplateId, selectedTemplate, templateType)) {
      return true;
    }

    setToast({ type: "error", message: templateEditorTypeMismatch });
    return false;
  }

  async function handleSave(targetStatus: EditorVisibilityStatus) {
    if (!assertCanManageTemplateEditor()) {
      return;
    }

    if (!assertTemplateMatchesEditorRoute()) {
      return;
    }

    if (
      saveTemplateMutation.isPending ||
      uploadTemplateMediaMutation.isPending ||
      uploadingKind !== null
    ) {
      return;
    }

    const catalogPath = getTemplateCatalogPath(locale, templateType);
    const draftReadinessError = getDraftReadinessError(form, text);
    if (draftReadinessError) {
      setToast({ type: "error", message: draftReadinessError });
      return;
    }

    try {
      let formToSave = form;
      if (previewFile) {
        formToSave = await uploadSelectedMediaForSave("Preview", previewFile, formToSave);
      }

      if (isVideo && referenceFile) {
        formToSave = await uploadSelectedMediaForSave("ReferenceMotion", referenceFile, formToSave);
      }

      const activationReadinessError = getActivationReadinessError(
        templateType,
        formToSave,
        text,
        targetStatus
      );
      if (activationReadinessError) {
        setToast({ type: "error", message: activationReadinessError });
        return;
      }

      await saveTemplateMutation.mutateAsync({ targetStatus, form: formToSave });
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

  async function uploadSelectedMediaForSave(
    assetKind: TemplateAssetKind,
    file: File,
    currentForm: TemplateFormState
  ): Promise<TemplateFormState> {
    setUploadingKind(assetKind);
    try {
      const asset = await uploadTemplateMedia(file, assetKind);
      const nextForm = applyUploadedAssetToForm(currentForm, assetKind, asset);
      setForm(nextForm);

      if (assetKind === "Preview") {
        setPreviewFile(null);
      } else {
        setReferenceFile(null);
      }

      return nextForm;
    } catch (error) {
      clientLogger.warn("templates.media_upload_failed", {
        assetKind,
        fileSizeBytes: file.size,
        contentType: sanitizeSensitiveText(file.type, 80),
        ...getTemplateEditorErrorDetails(error),
      });
      throw error;
    } finally {
      setUploadingKind(null);
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
      await uploadTemplateMediaMutation.mutateAsync({ assetKind, file });
    } catch (error) {
      const message = resolveUploadErrorMessage(error, text.errorSavingTemplate);
      setToast({ type: "error", message });
      clientLogger.warn("templates.media_upload_failed", {
        assetKind,
        fileSizeBytes: file.size,
        contentType: sanitizeSensitiveText(file.type, 80),
        ...getTemplateEditorErrorDetails(error),
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
  const draftReadinessError = getDraftReadinessError(form, text);
  const activationReadinessError = getActivationReadinessError(templateType, form, text, "Active");
  const saveReadinessHint =
    editorStatus === "Active" ? activationReadinessError : draftReadinessError;
  const isSaveReady = saveReadinessHint === null;
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
    initializationError,
    isEditMode,
    isSaveReady,
    isLoading,
    isSaving,
    isVideo,
    mergedCategorySuggestions,
    previewFile,
    previewTags,
    referenceFile,
    resetForm,
    retryInitialization,
    router,
    saveReadinessHint,
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

function applyUploadedAssetToForm(
  form: TemplateFormState,
  assetKind: TemplateAssetKind,
  asset: TemplateMediaUploadResponse
): TemplateFormState {
  return assetKind === "Preview"
    ? {
        ...form,
        previewUrl: asset.url,
        previewUrlSource: "uploaded",
        previewFileName: asset.fileName,
        previewContentType: asset.contentType,
        previewFileSizeBytes: asset.fileSizeBytes?.toString() ?? "",
        previewDurationSeconds: asset.durationSeconds?.toString() ?? "",
        thumbnailAsset: cloneTemplateAsset(asset.thumbnailAsset),
        animatedPreviewAsset: cloneTemplateAsset(asset.animatedPreviewAsset),
        feedLoopLowAsset: cloneTemplateAsset(asset.feedLoopLowAsset),
        feedLoopMediumAsset: cloneTemplateAsset(asset.feedLoopMediumAsset),
        detailPreviewAsset: cloneTemplateAsset(asset.detailPreviewAsset),
      }
    : {
        ...form,
        referenceUrl: asset.url,
        referenceUrlSource: "uploaded",
        referenceFileName: asset.fileName,
        referenceContentType: asset.contentType,
        referenceFileSizeBytes: asset.fileSizeBytes?.toString() ?? "",
        referenceDurationSeconds: asset.durationSeconds?.toString() ?? "",
      };
}

function cloneTemplateAsset(asset: TemplateAsset | null | undefined): TemplateAsset | null {
  return asset ? { ...asset } : null;
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

function getDraftReadinessError(form: TemplateFormState, text: Dictionary): string | null {
  return form.title.trim() ? null : text.templateDraftTitleRequired;
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

  if (!form.title.trim()) {
    missingLabels.push(text.titleLabel);
  }

  if (!form.shortDescription.trim()) {
    missingLabels.push(text.shortDescriptionLabel);
  }

  if (!form.category.trim()) {
    missingLabels.push(text.categoryLabel);
  }

  if ((parseOptionalDecimal(form.tokenCost) ?? 0) <= 0) {
    missingLabels.push(text.tokenCostLabel);
  }

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

    if (!form.preprocessingModel.trim()) {
      missingLabels.push(text.preprocessingModelLabel);
    }

    if (!form.preprocessingPrompt.trim()) {
      missingLabels.push(text.preprocessingPromptLabel);
    }

    if (!form.klingModel.trim()) {
      missingLabels.push(text.klingModelLabel);
    }

    if (!form.klingPrompt.trim()) {
      missingLabels.push(text.klingPromptLabel);
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
