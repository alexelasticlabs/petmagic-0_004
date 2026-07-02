"use client";

import { useRouter } from "next/navigation";
import { useCallback, useEffect, useMemo, useState, type FormEvent } from "react";

import { ensureAdminSession } from "@/components/admin/admin-session";
import { getTemplatesDailyFeaturedPageText } from "@/components/templates/templates-daily-featured-page.content";
import {
  SEARCH_DEBOUNCE_MS,
  TEMPLATE_OPTIONS_TAKE,
  dateRangesOverlap,
  emptyForm,
  formFromAssignment,
  getPreviewUrl,
  hasInvalidDateRange,
  optionFromAssignment,
  optionFromTemplate,
  parseExcludeRecentDays,
  safeActionContext,
  safeDisplayText,
  safeErrorDetails,
  toPayload,
  todayIso,
  useDebouncedValue,
} from "@/components/templates/templates-daily-featured-page.helpers";
import type {
  AssignmentFormState,
  AutoPickState,
  TemplateAccessFilter,
  TemplateOption,
  TemplatesDailyFeaturedPageProps,
} from "@/components/templates/templates-daily-featured-page.types";
import { getAdminErrorMessage } from "@/lib/admin-error-message";
import {
  autoPickTemplateOfTheDay,
  createTemplateOfTheDay,
  deleteTemplateOfTheDay,
  fetchAdminTemplates,
  fetchCurrentTemplateOfTheDay,
  fetchTemplateOfTheDaySchedule,
  fetchTemplateOfTheDaySettings,
  updateTemplateOfTheDay,
  updateTemplateOfTheDaySettings,
  useAuthSession,
  type AdminTemplateListItem,
  type AdminTemplateOfTheDay,
  type AdminTemplateOfTheDaySettings,
  type TemplateType,
} from "@/lib/api-client";
import { clientLogger } from "@/lib/client-logger";
import { sanitizeSensitiveText } from "@/lib/sensitive-display";

export function useTemplatesDailyFeaturedController({ locale }: TemplatesDailyFeaturedPageProps) {
  const text = useMemo(() => getTemplatesDailyFeaturedPageText(locale), [locale]);
  const router = useRouter();
  const session = useAuthSession();
  const canManageTemplates = session?.user.roles.includes("Admin") ?? false;
  const [schedule, setSchedule] = useState<AdminTemplateOfTheDay[]>([]);
  const [current, setCurrent] = useState<AdminTemplateOfTheDay | null>(null);
  const [settings, setSettings] = useState<AdminTemplateOfTheDaySettings | null>(null);
  const [templates, setTemplates] = useState<AdminTemplateListItem[]>([]);
  const [search, setSearch] = useState("");
  const [templateTypeFilter, setTemplateTypeFilter] = useState<"" | TemplateType>("");
  const [templateAccessFilter, setTemplateAccessFilter] = useState<TemplateAccessFilter>("");
  const debouncedSearch = useDebouncedValue(search.trim(), SEARCH_DEBOUNCE_MS);
  const [form, setForm] = useState<AssignmentFormState>(() => emptyForm());
  const [selectedTemplateOptionSnapshot, setSelectedTemplateOptionSnapshot] =
    useState<TemplateOption | null>(null);
  const [autoPick, setAutoPick] = useState<AutoPickState>({
    date: todayIso(),
    autoModeEnabled: true,
    allowedTypes: "both",
    excludeRecentDays: "7",
  });
  const [isScheduleLoading, setIsScheduleLoading] = useState(true);
  const [isTemplateOptionsLoading, setIsTemplateOptionsLoading] = useState(true);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [templateOptionsError, setTemplateOptionsError] = useState<string | null>(null);
  const [assignmentPendingDelete, setAssignmentPendingDelete] =
    useState<AdminTemplateOfTheDay | null>(null);

  const selectedTemplate = templates.find((template) => template.templateId === form.templateId);
  const selectedAssignment = schedule.find((assignment) => assignment.id === form.id);
  const selectedTemplateSnapshot = useMemo(() => {
    if (!form.templateId) {
      return null;
    }

    if (selectedTemplate) {
      return optionFromTemplate(selectedTemplate);
    }

    if (selectedAssignment?.templateId === form.templateId) {
      return optionFromAssignment(selectedAssignment);
    }

    if (selectedTemplateOptionSnapshot?.templateId === form.templateId) {
      return selectedTemplateOptionSnapshot;
    }

    return null;
  }, [form.templateId, selectedAssignment, selectedTemplate, selectedTemplateOptionSnapshot]);
  const templateOptions = useMemo(() => {
    const options = templates.map(optionFromTemplate);
    if (
      selectedTemplateSnapshot &&
      selectedTemplateSnapshot.templateId === form.templateId &&
      !options.some((template) => template.templateId === selectedTemplateSnapshot.templateId)
    ) {
      return [selectedTemplateSnapshot, ...options];
    }

    return options;
  }, [form.templateId, selectedTemplateSnapshot, templates]);
  const previewTitle = safeDisplayText(
    form.titleOverride.trim() || selectedTemplateSnapshot?.title || "",
    120
  );
  const previewSubtitle = safeDisplayText(
    form.subtitleOverride.trim() || selectedTemplateSnapshot?.shortDescription || "",
    220
  );
  const previewBadge = safeDisplayText(form.badgeTextOverride.trim() || text.heroBadge, 64);
  const previewType = selectedTemplateSnapshot?.templateType ?? ("Image" as TemplateType);
  const previewMediaUrl = getPreviewUrl(selectedTemplateSnapshot);
  const isLoading = isScheduleLoading || isTemplateOptionsLoading;
  const isActionLocked = isSubmitting || isLoading;
  const isAutoPickSettingsDirty =
    settings === null ||
    autoPick.autoModeEnabled !== settings.autoModeEnabled ||
    autoPick.allowedTypes !== settings.allowedTypes ||
    parseExcludeRecentDays(autoPick.excludeRecentDays) !== settings.excludeRecentDays;
  const scheduleAssignmentIds = useMemo(
    () => new Set(schedule.map((assignment) => assignment.id)),
    [schedule]
  );
  const dateOccupiedWarning = schedule.some(
    (assignment) =>
      assignment.isActive &&
      assignment.isManual &&
      assignment.id !== form.id &&
      dateRangesOverlap(form.startDate, form.endDate, assignment)
  );
  const invalidDateRangeWarning = hasInvalidDateRange(form.startDate, form.endDate);
  const isAutoPickDateMissing = autoPick.date.trim().length === 0;

  const loadTemplateOptions = useCallback(
    async (query: string, signal?: AbortSignal) => {
      if (signal?.aborted) {
        return;
      }

      if (!canManageTemplates) {
        setTemplates([]);
        setTemplateOptionsError(null);
        setIsTemplateOptionsLoading(false);
        return;
      }

      setIsTemplateOptionsLoading(true);
      setTemplates([]);
      setTemplateOptionsError(null);
      try {
        const templateResponse = await fetchAdminTemplates(
          {
            status: "Active",
            type: templateTypeFilter || undefined,
            search: query || undefined,
            access: templateAccessFilter || undefined,
            take: TEMPLATE_OPTIONS_TAKE,
          },
          signal
        );
        setTemplates(templateResponse.items);
        setTemplateOptionsError(null);
      } catch (loadError) {
        if (signal?.aborted) return;
        clientLogger.warn(
          "templates.daily_featured_template_options_failed",
          safeErrorDetails(loadError)
        );
        setTemplates([]);
        setTemplateOptionsError(getAdminErrorMessage(loadError, text.loadError));
      } finally {
        if (!signal?.aborted) {
          setIsTemplateOptionsLoading(false);
        }
      }
    },
    [canManageTemplates, templateAccessFilter, templateTypeFilter, text.loadError]
  );

  const loadScheduleData = useCallback(
    async (signal?: AbortSignal) => {
      if (signal?.aborted) {
        return;
      }

      if (!canManageTemplates) {
        setIsScheduleLoading(false);
        return;
      }

      setIsScheduleLoading(true);
      setError(null);
      try {
        const [scheduleResponse, currentResponse, settingsResponse] = await Promise.allSettled([
          fetchTemplateOfTheDaySchedule(signal),
          fetchCurrentTemplateOfTheDay(undefined, signal),
          fetchTemplateOfTheDaySettings(signal),
        ]);

        if (signal?.aborted) return;

        let loadFailure: unknown = null;

        if (scheduleResponse.status === "fulfilled") {
          setSchedule(scheduleResponse.value.items);
        } else {
          loadFailure ??= scheduleResponse.reason;
        }

        if (currentResponse.status === "fulfilled") {
          setCurrent(currentResponse.value);
        } else {
          loadFailure ??= currentResponse.reason;
        }

        if (settingsResponse.status === "fulfilled") {
          setSettings(settingsResponse.value);
          setAutoPick((state) => ({
            ...state,
            autoModeEnabled: settingsResponse.value.autoModeEnabled,
            allowedTypes: settingsResponse.value.allowedTypes,
            excludeRecentDays: String(settingsResponse.value.excludeRecentDays),
          }));
        } else {
          loadFailure ??= settingsResponse.reason;
        }

        if (loadFailure) {
          clientLogger.warn("templates.daily_featured_load_failed", safeErrorDetails(loadFailure));
          setError(getAdminErrorMessage(loadFailure, text.loadError));
        }
      } catch (loadError) {
        if (signal?.aborted) return;
        clientLogger.warn("templates.daily_featured_load_failed", safeErrorDetails(loadError));
        setError(getAdminErrorMessage(loadError, text.loadError));
      } finally {
        if (!signal?.aborted) {
          setIsScheduleLoading(false);
        }
      }
    },
    [canManageTemplates, text.loadError]
  );

  const refreshPageData = useCallback(async () => {
    if (!canManageTemplates) {
      return;
    }

    await Promise.allSettled([loadScheduleData(), loadTemplateOptions(debouncedSearch)]);
  }, [canManageTemplates, debouncedSearch, loadScheduleData, loadTemplateOptions]);

  useEffect(() => {
    ensureAdminSession(locale, router, { requiredRole: "Admin" });
  }, [locale, router, session]);

  useEffect(() => {
    if (!canManageTemplates) {
      return;
    }

    const controller = new AbortController();
    queueMicrotask(() => void loadScheduleData(controller.signal));
    return () => controller.abort();
  }, [canManageTemplates, loadScheduleData]);

  useEffect(() => {
    if (!canManageTemplates) {
      return;
    }

    const controller = new AbortController();
    queueMicrotask(() => void loadTemplateOptions(debouncedSearch, controller.signal));
    return () => controller.abort();
  }, [canManageTemplates, debouncedSearch, loadTemplateOptions]);

  useEffect(() => {
    if (isScheduleLoading || isActionLocked) {
      return;
    }

    const shouldResetPendingDelete =
      assignmentPendingDelete && !scheduleAssignmentIds.has(assignmentPendingDelete.id);
    const shouldResetForm = form.id && !scheduleAssignmentIds.has(form.id);

    if (!shouldResetPendingDelete && !shouldResetForm) {
      return;
    }

    let isActive = true;
    queueMicrotask(() => {
      if (!isActive) {
        return;
      }

      if (shouldResetPendingDelete) {
        setAssignmentPendingDelete(null);
      }

      if (shouldResetForm) {
        setSelectedTemplateOptionSnapshot(null);
        setForm(emptyForm(form.startDate));
      }
    });

    return () => {
      isActive = false;
    };
  }, [
    assignmentPendingDelete,
    form.id,
    form.startDate,
    isActionLocked,
    isScheduleLoading,
    scheduleAssignmentIds,
  ]);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!canManageTemplates || !form.templateId || isActionLocked || invalidDateRangeWarning)
      return;

    setIsSubmitting(true);
    setError(null);
    try {
      const payload = toPayload(form);
      if (form.id) {
        await updateTemplateOfTheDay(form.id, payload);
      } else {
        await createTemplateOfTheDay(payload);
      }
      setSelectedTemplateOptionSnapshot(null);
      setForm(emptyForm(form.startDate));
      await loadScheduleData();
    } catch (saveError) {
      clientLogger.warn("templates.daily_featured_save_failed", {
        ...safeActionContext({
          assignmentId: form.id,
          templateId: form.templateId,
          templateTitle: selectedTemplateSnapshot?.title,
        }),
        ...safeErrorDetails(saveError),
      });
      setError(getAdminErrorMessage(saveError, text.saveError));
    } finally {
      setIsSubmitting(false);
    }
  }

  async function handleDelete(assignment: AdminTemplateOfTheDay) {
    if (!canManageTemplates || isActionLocked) {
      return false;
    }

    setIsSubmitting(true);
    setError(null);
    try {
      await deleteTemplateOfTheDay(assignment.id);
      if (form.id === assignment.id) {
        setSelectedTemplateOptionSnapshot(null);
        setForm(emptyForm(form.startDate));
      }
      await loadScheduleData();
      return true;
    } catch (deleteError) {
      clientLogger.warn("templates.daily_featured_delete_failed", {
        ...safeActionContext({
          assignmentId: assignment.id,
          templateId: assignment.templateId,
          templateTitle: assignment.templateTitle,
        }),
        ...safeErrorDetails(deleteError),
      });
      setError(getAdminErrorMessage(deleteError, text.saveError));
      return false;
    } finally {
      setIsSubmitting(false);
    }
  }

  async function handleAutoPick() {
    if (!canManageTemplates || isActionLocked || isAutoPickDateMissing) return;

    setIsSubmitting(true);
    setError(null);
    try {
      await autoPickTemplateOfTheDay({
        date: autoPick.date,
        allowedTypes: autoPick.allowedTypes,
        excludeRecentDays: parseExcludeRecentDays(autoPick.excludeRecentDays),
      });
      await loadScheduleData();
    } catch (autoPickError) {
      clientLogger.warn("templates.daily_featured_auto_pick_failed", {
        autoPickDate: sanitizeSensitiveText(autoPick.date, 20),
        allowedTypes: autoPick.allowedTypes,
        excludeRecentDays: parseExcludeRecentDays(autoPick.excludeRecentDays),
        ...safeErrorDetails(autoPickError),
      });
      setError(getAdminErrorMessage(autoPickError, text.saveError));
    } finally {
      setIsSubmitting(false);
    }
  }

  async function handleSaveSettings() {
    if (!canManageTemplates || isActionLocked || !isAutoPickSettingsDirty) return;

    setIsSubmitting(true);
    setError(null);
    try {
      const saved = await updateTemplateOfTheDaySettings({
        autoModeEnabled: autoPick.autoModeEnabled,
        allowedTypes: autoPick.allowedTypes,
        excludeRecentDays: parseExcludeRecentDays(autoPick.excludeRecentDays),
      });
      setSettings(saved);
      setAutoPick((state) => ({
        ...state,
        autoModeEnabled: saved.autoModeEnabled,
        allowedTypes: saved.allowedTypes,
        excludeRecentDays: String(saved.excludeRecentDays),
      }));
    } catch (settingsError) {
      clientLogger.warn("templates.daily_featured_settings_save_failed", {
        autoModeEnabled: autoPick.autoModeEnabled,
        allowedTypes: autoPick.allowedTypes,
        excludeRecentDays: parseExcludeRecentDays(autoPick.excludeRecentDays),
        ...safeErrorDetails(settingsError),
      });
      setError(getAdminErrorMessage(settingsError, text.saveError));
    } finally {
      setIsSubmitting(false);
    }
  }

  const handleFormChange = useCallback((patch: Partial<AssignmentFormState>) => {
    setForm((state) => ({ ...state, ...patch }));
  }, []);

  const handleTemplateSelectionChange = useCallback(
    (nextTemplateId: string) => {
      setSelectedTemplateOptionSnapshot(
        templateOptions.find((template) => template.templateId === nextTemplateId) ?? null
      );
      setForm((state) => ({ ...state, templateId: nextTemplateId }));
    },
    [templateOptions]
  );

  const handleResetForm = useCallback(() => {
    setSelectedTemplateOptionSnapshot(null);
    setForm(emptyForm(form.startDate));
  }, [form.startDate]);

  const handleEditAssignment = useCallback((assignment: AdminTemplateOfTheDay) => {
    setSelectedTemplateOptionSnapshot(optionFromAssignment(assignment));
    setForm(formFromAssignment(assignment));
  }, []);

  return {
    assignmentPendingDelete,
    autoPick,
    canManageTemplates,
    current,
    dateOccupiedWarning,
    debouncedSearch,
    error,
    form,
    handleAutoPick,
    handleDelete,
    handleEditAssignment,
    handleFormChange,
    handleResetForm,
    handleSaveSettings,
    handleSubmit,
    handleTemplateSelectionChange,
    invalidDateRangeWarning,
    isActionLocked,
    isAutoPickDateMissing,
    isAutoPickSettingsDirty,
    isScheduleLoading,
    isTemplateOptionsLoading,
    loadTemplateOptions,
    previewBadge,
    previewMediaUrl,
    previewSubtitle,
    previewTitle,
    previewType,
    refreshPageData,
    schedule,
    search,
    selectedTemplateSnapshot,
    setAssignmentPendingDelete,
    setAutoPick,
    setSearch,
    setTemplateAccessFilter,
    setTemplateTypeFilter,
    settings,
    templateAccessFilter,
    templateOptions,
    templateOptionsError,
    templateTypeFilter,
    text,
    templates,
  };
}
