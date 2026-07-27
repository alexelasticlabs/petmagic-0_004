"use client";

import { useRouter } from "next/navigation";
import { useCallback, useEffect, useMemo, useRef, useState, type FormEvent } from "react";

import { ensureAdminSession } from "@/components/admin/admin-session";
import { getTemplatesDailyFeaturedPageText } from "@/components/templates/templates-daily-featured-page.content";
import {
  SEARCH_DEBOUNCE_MS,
  SCHEDULE_PAGE_SIZE,
  TEMPLATE_OPTIONS_TAKE,
  dateRangesOverlap,
  emptyForm,
  getBusinessDateOrClientToday,
  formFromAssignment,
  getPreviewUrl,
  hasInvalidDateRange,
  isExcludeRecentDaysValid,
  isPriorityValid,
  optionFromAssignment,
  optionFromTemplate,
  parseExcludeRecentDays,
  safeActionContext,
  safeDisplayText,
  safeErrorDetails,
  toPayload,
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
  type AdminTemplateOfTheDaySchedule,
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
  const [schedulePage, setSchedulePage] = useState(0);
  const [schedulePageData, setSchedulePageData] = useState<AdminTemplateOfTheDaySchedule | null>(
    null
  );
  const schedule = useMemo(() => schedulePageData?.items ?? [], [schedulePageData]);
  const scheduleTotalCount = schedulePageData?.totalCount ?? 0;
  const schedulePageSize = schedulePageData?.take ?? SCHEDULE_PAGE_SIZE;
  const scheduleHasMore = schedulePageData?.hasMore ?? false;
  const [current, setCurrent] = useState<AdminTemplateOfTheDay | null>(null);
  const [settings, setSettings] = useState<AdminTemplateOfTheDaySettings | null>(null);
  const [templates, setTemplates] = useState<AdminTemplateListItem[]>([]);
  const [search, setSearch] = useState("");
  const [templateTypeFilter, setTemplateTypeFilter] = useState<"" | TemplateType>("");
  const [templateAccessFilter, setTemplateAccessFilter] = useState<TemplateAccessFilter>("");
  const debouncedSearch = useDebouncedValue(search.trim(), SEARCH_DEBOUNCE_MS);
  const [form, setForm] = useState<AssignmentFormState>(() => emptyForm(""));
  const [selectedTemplateOptionSnapshot, setSelectedTemplateOptionSnapshot] =
    useState<TemplateOption | null>(null);
  const [autoPick, setAutoPick] = useState<AutoPickState>({
    date: "",
    autoModeEnabled: true,
    allowedTypes: "both",
    excludeRecentDays: "7",
  });
  const [isScheduleLoading, setIsScheduleLoading] = useState(true);
  const [isTemplateOptionsLoading, setIsTemplateOptionsLoading] = useState(true);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [settingsLoadError, setSettingsLoadError] = useState<string | null>(null);
  const [templateOptionsError, setTemplateOptionsError] = useState<string | null>(null);
  const [assignmentPendingDelete, setAssignmentPendingDelete] =
    useState<AdminTemplateOfTheDay | null>(null);
  const [isAutoPickConfirmationOpen, setIsAutoPickConfirmationOpen] = useState(false);
  const settingsSnapshotRef = useRef<AdminTemplateOfTheDaySettings | null>(null);

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
  const isSettingsReady = settings !== null && settingsLoadError === null;
  const isExcludeRecentDaysInvalid = !isExcludeRecentDaysValid(autoPick.excludeRecentDays);
  const isPriorityInvalid = !isPriorityValid(form.priority);
  const isStartDateMissing = form.startDate.trim().length === 0;
  const isActionLocked = isSubmitting || isScheduleLoading;
  const isAutoPickSettingsDirty =
    settings !== null &&
    (autoPick.autoModeEnabled !== settings.autoModeEnabled ||
      autoPick.allowedTypes !== settings.allowedTypes ||
      parseExcludeRecentDays(autoPick.excludeRecentDays) !== settings.excludeRecentDays);
  const isAutoPickRunAvailable =
    isSettingsReady &&
    settings?.autoModeEnabled === true &&
    !isAutoPickSettingsDirty &&
    !isExcludeRecentDaysInvalid;
  const scheduleAssignmentIds = useMemo(
    () => new Set(schedule.map((assignment) => assignment.id)),
    [schedule]
  );
  const dateOccupiedWarning = schedule.some(
    (assignment) =>
      form.isManual &&
      form.isActive &&
      !isStartDateMissing &&
      assignment.isActive &&
      assignment.isManual &&
      assignment.id !== form.id &&
      dateRangesOverlap(form.startDate, form.endDate, assignment)
  );
  const invalidDateRangeWarning =
    !isStartDateMissing && hasInvalidDateRange(form.startDate, form.endDate);
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
        setSchedulePage(0);
        setSchedulePageData(null);
        settingsSnapshotRef.current = null;
        setSettings(null);
        setSettingsLoadError(null);
        setIsScheduleLoading(false);
        return;
      }

      setIsScheduleLoading(true);
      setError(null);
      try {
        const [scheduleResponse, currentResponse, settingsResponse] = await Promise.allSettled([
          fetchTemplateOfTheDaySchedule(
            {
              skip: schedulePage * SCHEDULE_PAGE_SIZE,
              take: SCHEDULE_PAGE_SIZE,
            },
            signal
          ),
          fetchCurrentTemplateOfTheDay(undefined, signal),
          fetchTemplateOfTheDaySettings(signal),
        ]);

        if (signal?.aborted) return;

        let loadFailure: unknown = null;

        if (scheduleResponse.status === "fulfilled") {
          const lastSchedulePage = Math.max(
            0,
            Math.ceil(
              scheduleResponse.value.totalCount / Math.max(scheduleResponse.value.take, 1)
            ) - 1
          );
          if (schedulePage > lastSchedulePage) {
            setSchedulePage(lastSchedulePage);
          } else {
            setSchedulePageData(scheduleResponse.value);
          }
        } else {
          loadFailure ??= scheduleResponse.reason;
        }

        if (currentResponse.status === "fulfilled") {
          setCurrent(currentResponse.value);
        } else {
          loadFailure ??= currentResponse.reason;
        }

        if (settingsResponse.status === "fulfilled") {
          const previousSettings = settingsSnapshotRef.current;
          const businessDate = getBusinessDateOrClientToday(settingsResponse.value.businessDate);
          settingsSnapshotRef.current = settingsResponse.value;
          setSettings(settingsResponse.value);
          setSettingsLoadError(null);
          setAutoPick((state) => {
            const hasUnsavedSettings =
              previousSettings !== null &&
              (state.autoModeEnabled !== previousSettings.autoModeEnabled ||
                state.allowedTypes !== previousSettings.allowedTypes ||
                parseExcludeRecentDays(state.excludeRecentDays) !==
                  previousSettings.excludeRecentDays);

            return {
              ...state,
              date: state.date || businessDate,
              ...(hasUnsavedSettings
                ? {}
                : {
                    autoModeEnabled: settingsResponse.value.autoModeEnabled,
                    allowedTypes: settingsResponse.value.allowedTypes,
                    excludeRecentDays: String(settingsResponse.value.excludeRecentDays),
                  }),
            };
          });
          setForm((state) => (state.startDate ? state : emptyForm(businessDate)));
        } else {
          setSettingsLoadError(getAdminErrorMessage(settingsResponse.reason, text.loadError));
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
    [canManageTemplates, schedulePage, text.loadError]
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
    if (
      !canManageTemplates ||
      !form.templateId ||
      isActionLocked ||
      isStartDateMissing ||
      invalidDateRangeWarning ||
      dateOccupiedWarning ||
      isPriorityInvalid
    )
      return;

    setIsSubmitting(true);
    setError(null);
    setNotice(null);
    try {
      const payload = toPayload(form);
      const isEditing = Boolean(form.id);
      const savedAssignment = form.id
        ? await updateTemplateOfTheDay(form.id, payload)
        : await createTemplateOfTheDay(payload);
      setNotice(
        isEditing
          ? text.assignmentUpdated(safeDisplayText(savedAssignment.templateTitle, 120))
          : text.assignmentCreated(safeDisplayText(savedAssignment.templateTitle, 120))
      );
      setSelectedTemplateOptionSnapshot(null);
      setForm(emptyForm(form.startDate));
      if (!isEditing && schedulePage > 0) {
        setSchedulePage(0);
      } else {
        await loadScheduleData();
      }
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
    setNotice(null);
    try {
      await deleteTemplateOfTheDay(assignment.id);
      if (form.id === assignment.id) {
        setSelectedTemplateOptionSnapshot(null);
        setForm(emptyForm(form.startDate));
      }
      await loadScheduleData();
      setNotice(text.assignmentDeleted(safeDisplayText(assignment.templateTitle, 120)));
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
    if (
      !canManageTemplates ||
      isActionLocked ||
      isAutoPickDateMissing ||
      isExcludeRecentDaysInvalid ||
      !isAutoPickRunAvailable
    ) {
      return false;
    }

    setIsSubmitting(true);
    setError(null);
    setNotice(null);
    try {
      const assignment = await autoPickTemplateOfTheDay({
        date: autoPick.date,
        allowedTypes: autoPick.allowedTypes,
        excludeRecentDays: parseExcludeRecentDays(autoPick.excludeRecentDays),
      });
      await loadScheduleData();
      setNotice(text.autoPickSucceeded(safeDisplayText(assignment.templateTitle, 120)));
      return true;
    } catch (autoPickError) {
      clientLogger.warn("templates.daily_featured_auto_pick_failed", {
        autoPickDate: sanitizeSensitiveText(autoPick.date, 20),
        allowedTypes: autoPick.allowedTypes,
        excludeRecentDays: parseExcludeRecentDays(autoPick.excludeRecentDays),
        ...safeErrorDetails(autoPickError),
      });
      setError(getAdminErrorMessage(autoPickError, text.saveError));
      return false;
    } finally {
      setIsSubmitting(false);
    }
  }

  async function handleSaveSettings() {
    if (
      !canManageTemplates ||
      isActionLocked ||
      !isSettingsReady ||
      !isAutoPickSettingsDirty ||
      isExcludeRecentDaysInvalid
    )
      return;

    setIsSubmitting(true);
    setError(null);
    setNotice(null);
    try {
      const saved = await updateTemplateOfTheDaySettings({
        autoModeEnabled: autoPick.autoModeEnabled,
        allowedTypes: autoPick.allowedTypes,
        excludeRecentDays: parseExcludeRecentDays(autoPick.excludeRecentDays),
      });
      settingsSnapshotRef.current = saved;
      setSettings(saved);
      setSettingsLoadError(null);
      setAutoPick((state) => ({
        ...state,
        autoModeEnabled: saved.autoModeEnabled,
        allowedTypes: saved.allowedTypes,
        excludeRecentDays: String(saved.excludeRecentDays),
      }));
      setNotice(text.settingsSaved);
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
    setNotice(null);
  }, []);

  const requestSchedulePage = useCallback(
    (nextPage: number) => {
      if (
        isScheduleLoading ||
        nextPage < 0 ||
        nextPage === schedulePage ||
        (nextPage > schedulePage && !scheduleHasMore)
      ) {
        return;
      }

      setSchedulePage(nextPage);
    },
    [isScheduleLoading, scheduleHasMore, schedulePage]
  );

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
    isAutoPickConfirmationOpen,
    isAutoPickDateMissing,
    isAutoPickRunAvailable,
    isAutoPickSettingsDirty,
    isExcludeRecentDaysInvalid,
    isPriorityInvalid,
    isScheduleLoading,
    isScheduleNavigationLocked: Boolean(form.id || assignmentPendingDelete),
    isSettingsReady,
    isStartDateMissing,
    isTemplateOptionsLoading,
    loadTemplateOptions,
    previewBadge,
    previewMediaUrl,
    previewSubtitle,
    previewTitle,
    previewType,
    notice,
    refreshPageData,
    requestSchedulePage,
    schedule,
    scheduleHasMore,
    schedulePage,
    schedulePageSize,
    scheduleTotalCount,
    search,
    selectedTemplateSnapshot,
    setAssignmentPendingDelete,
    setAutoPick,
    setIsAutoPickConfirmationOpen,
    setSearch,
    setTemplateAccessFilter,
    setTemplateTypeFilter,
    settings,
    settingsLoadError,
    templateAccessFilter,
    templateOptions,
    templateOptionsError,
    templateTypeFilter,
    text,
    templates,
  };
}
