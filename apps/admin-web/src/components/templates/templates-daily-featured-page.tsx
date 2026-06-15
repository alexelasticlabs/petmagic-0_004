"use client";

import { useRouter } from "next/navigation";
import { useCallback, useEffect, useMemo, useState, type FormEvent } from "react";

import {
  CalendarIcon,
  PencilIcon,
  RefreshIcon,
  TemplatesIcon,
} from "@/components/admin/admin-icons";
import {
  AdminBadge,
  AdminCard,
  AdminIconTile,
  AdminPage,
  AdminPageGrid,
  AdminPageHero,
  AdminSelectField,
  AdminStateCard,
  adminTableStyles,
} from "@/components/admin/admin-primitives";
import { ensureAdminSession } from "@/components/admin/admin-session";
import { ConfirmationDialog } from "@/components/admin/confirmation-dialog";
import styles from "@/components/templates/templates-daily-featured-page.module.css";
import { Button } from "@/components/ui/button";
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
  type TemplateOfTheDayPayload,
  type TemplateType,
} from "@/lib/api-client";
import { clientLogger } from "@/lib/client-logger";
import { type Locale } from "@/lib/i18n";


type TemplatesDailyFeaturedPageProps = {
  locale: Locale;
};

type AssignmentFormState = {
  id: string | null;
  templateId: string;
  startDate: string;
  endDate: string;
  priority: string;
  isActive: boolean;
  titleOverride: string;
  subtitleOverride: string;
  badgeTextOverride: string;
};

type AutoPickState = {
  date: string;
  autoModeEnabled: boolean;
  allowedTypes: "both" | "image" | "video";
  excludeRecentDays: string;
};

type TemplateAccessFilter = "" | "premium" | "free";

type DailyFeaturedCopy = ReturnType<typeof copy>;

type TemplateOption = Pick<
  AdminTemplateListItem,
  "templateId" | "templateType" | "title" | "shortDescription" | "category" | "isPremium" | "previewAsset"
>;

const SEARCH_LIMIT = 80;
const SEARCH_DEBOUNCE_MS = 300;
const TEMPLATE_OPTIONS_TAKE = 30;

function useDebouncedValue(value: string, delayMs: number) {
  const [debouncedValue, setDebouncedValue] = useState(value);

  useEffect(() => {
    const timeout = window.setTimeout(() => setDebouncedValue(value), delayMs);
    return () => window.clearTimeout(timeout);
  }, [delayMs, value]);

  return debouncedValue;
}

function todayIso() {
  return new Date().toISOString().slice(0, 10);
}

function emptyForm(date = todayIso()): AssignmentFormState {
  return {
    id: null,
    templateId: "",
    startDate: date,
    endDate: "",
    priority: "0",
    isActive: true,
    titleOverride: "",
    subtitleOverride: "",
    badgeTextOverride: "",
  };
}

function parseExcludeRecentDays(value: string) {
  const parsed = Number.parseInt(value, 10);
  if (!Number.isFinite(parsed)) {
    return 7;
  }

  return Math.min(Math.max(parsed, 0), 365);
}

function toPayload(form: AssignmentFormState): TemplateOfTheDayPayload {
  return {
    templateId: form.templateId,
    startDate: form.startDate,
    endDate: form.endDate.trim() || null,
    isActive: form.isActive,
    isManual: true,
    priority: Number.parseInt(form.priority || "0", 10) || 0,
    titleOverride: form.titleOverride.trim() || null,
    subtitleOverride: form.subtitleOverride.trim() || null,
    badgeTextOverride: form.badgeTextOverride.trim() || null,
  };
}

function formFromAssignment(assignment: AdminTemplateOfTheDay): AssignmentFormState {
  return {
    id: assignment.id,
    templateId: assignment.templateId,
    startDate: assignment.startDate,
    endDate: assignment.endDate ?? "",
    priority: String(assignment.priority),
    isActive: assignment.isActive,
    titleOverride: assignment.titleOverride ?? "",
    subtitleOverride: assignment.subtitleOverride ?? "",
    badgeTextOverride: assignment.badgeTextOverride ?? "",
  };
}

function isVideoTemplate(type: TemplateType | string) {
  return type === "Video";
}

function getPreviewUrl(template?: AdminTemplateListItem | AdminTemplateOfTheDay | null) {
  return template?.previewAsset?.url?.trim() || null;
}

function optionFromTemplate(template: AdminTemplateListItem): TemplateOption {
  return {
    templateId: template.templateId,
    templateType: template.templateType,
    title: template.title,
    shortDescription: template.shortDescription,
    category: template.category,
    isPremium: template.isPremium,
    previewAsset: template.previewAsset,
  };
}

function optionFromAssignment(assignment: AdminTemplateOfTheDay): TemplateOption {
  return {
    templateId: assignment.templateId,
    templateType: assignment.templateType,
    title: assignment.templateTitle,
    shortDescription: assignment.subtitleOverride ?? "",
    category: assignment.category,
    isPremium: assignment.isPremium,
    previewAsset: assignment.previewAsset ?? undefined,
  };
}

function statusTone(assignment: AdminTemplateOfTheDay) {
  if (!assignment.isActive) return "neutral" as const;
  if (assignment.isManual) return "success" as const;
  return "info" as const;
}

function formatDateRange(assignment: AdminTemplateOfTheDay) {
  return assignment.endDate
    ? `${assignment.startDate} - ${assignment.endDate}`
    : assignment.startDate;
}

function dateRangesOverlap(startDate: string, endDate: string, assignment: AdminTemplateOfTheDay) {
  const requestedStart = startDate || todayIso();
  const requestedEnd = endDate.trim() || "9999-12-31";
  const assignmentEnd = assignment.endDate ?? "9999-12-31";
  return assignment.startDate <= requestedEnd && assignmentEnd >= requestedStart;
}

function hasInvalidDateRange(startDate: string, endDate: string) {
  return endDate.trim().length > 0 && endDate.trim() < (startDate || todayIso());
}

function copy(locale: Locale) {
  const isRu = locale === "ru";
  return {
    eyebrow: isRu ? "Шаблоны" : "Templates",
    title: isRu ? "Шаблон дня" : "Daily Featured",
    description: isRu
      ? "Планируйте витрину Template of the Day: ручные назначения, предпросмотр и автоматический выбор."
      : "Schedule Template of the Day with manual assignments, preview, and automatic fallback picks.",
    heroBadge: isRu ? "Витрина дня" : "Template of the Day",
    refresh: isRu ? "Обновить" : "Refresh",
    retry: isRu ? "Повторить" : "Retry",
    current: isRu ? "Текущий выбор" : "Current pick",
    schedule: isRu ? "Расписание" : "Schedule",
    assignments: isRu ? "назначений" : "assignments",
    form: isRu ? "Назначение" : "Assignment",
    formDescription: isRu
      ? "Выберите активный шаблон, период показа и текст для карточки в мобильной витрине."
      : "Choose an active template, display window, and mobile storefront copy.",
    formAdminOnly: isRu
      ? "Для изменений нужна роль Admin."
      : "Admin role required to make changes.",
    templateSearch: isRu ? "Поиск шаблона" : "Template search",
    templateSearchPlaceholder: isRu ? "Название, категория или тег" : "Title, category, or tag",
    templateTypeFilter: isRu ? "Тип шаблона" : "Template type",
    templateAccessFilter: isRu ? "Тариф" : "Access",
    allTemplateTypes: isRu ? "Все типы" : "All types",
    allAccessLevels: isRu ? "Все тарифы" : "All access levels",
    activeTemplatesOnly: isRu ? "Статус: Active" : "Status: Active",
    template: isRu ? "Шаблон" : "Template",
    selectTemplate: isRu ? "Выберите шаблон" : "Select template",
    startDate: isRu ? "Дата начала" : "Start date",
    endDate: isRu ? "Дата окончания" : "End date",
    priority: isRu ? "Приоритет" : "Priority",
    active: isRu ? "Активно" : "Active",
    inactive: isRu ? "Отключено" : "Disabled",
    titleOverride: isRu ? "Заголовок для витрины" : "Storefront title",
    subtitleOverride: isRu ? "Описание для витрины" : "Storefront subtitle",
    badgeOverride: isRu ? "Текст бейджа" : "Badge text",
    save: isRu ? "Сохранить" : "Save",
    create: isRu ? "Создать" : "Create",
    reset: isRu ? "Очистить" : "Reset",
    edit: isRu ? "Изменить" : "Edit",
    delete: isRu ? "Удалить" : "Delete",
    cancel: isRu ? "Отмена" : "Cancel",
    deleteConfirmTitle: isRu ? "Удалить назначение?" : "Delete assignment?",
    deleteConfirmDescription: (templateTitle: string) =>
      isRu
        ? `Удалить назначение "${templateTitle}" из расписания? Текущий мобильный показ обновится после сохранения.`
        : `Delete "${templateTitle}" from the schedule? The current mobile storefront pick will update after the change is saved.`,
    preview: isRu ? "Предпросмотр" : "Preview",
    previewEmptyTitle: isRu ? "Выберите шаблон" : "Select a template",
    previewEmptySubtitle: isRu
      ? "Здесь появится карточка витрины до сохранения назначения."
      : "The storefront card preview appears here before saving.",
    noCurrent: isRu ? "На сегодня назначение не найдено." : "No assignment is active today.",
    noSchedule: isRu ? "Расписание пока пустое." : "No scheduled assignments yet.",
    dateOccupiedWarning: isRu
      ? "На выбранные даты уже есть активное ручное назначение. v1 поддерживает одно manual-назначение на дату."
      : "The selected dates already have an active manual assignment. v1 supports one manual assignment per date.",
    invalidDateRangeWarning: isRu
      ? "Дата окончания не может быть раньше даты начала."
      : "End date cannot be earlier than start date.",
    autoPickDateRequired: isRu
      ? "Выберите дату для ручного автовыбора."
      : "Select a date before running auto-pick.",
    noTemplates: isRu
      ? "Активные шаблоны по этому запросу не найдены."
      : "No active templates match this search.",
    loading: isRu ? "Загружаем витрину дня." : "Loading daily featured.",
    loadingTemplates: isRu ? "Ищем активные шаблоны." : "Searching active templates.",
    loadError: isRu ? "Не удалось загрузить витрину дня." : "Failed to load daily featured.",
    saveError: isRu ? "Не удалось сохранить назначение." : "Failed to save assignment.",
    autoPick: isRu ? "Автовыбор" : "Auto-pick",
    autoPickDescription: isRu
      ? "Управляет fallback-выбором и daily job. Ручной запуск ниже создаёт подбор на выбранную дату."
      : "Controls fallback picks and the daily job. The run action below creates a pick for a selected date.",
    autoMode: isRu ? "Auto mode" : "Auto mode",
    autoModeEnabled: isRu ? "Включен" : "Enabled",
    autoModeDisabled: isRu ? "Отключен" : "Disabled",
    autoModeStatus: isRu ? "Статус auto mode" : "Auto mode status",
    autoModeSave: isRu ? "Сохранить настройки" : "Save settings",
    autoPickRun: isRu ? "Запустить автовыбор" : "Run auto-pick",
    allowedTypes: isRu ? "Типы" : "Allowed types",
    allowedBoth: isRu ? "Изображения и видео" : "Images and videos",
    excludeRecent: isRu ? "Исключить последние дни" : "Exclude recent days",
    manual: isRu ? "Ручной" : "Manual",
    auto: isRu ? "Авто" : "Auto",
    premium: isRu ? "Premium" : "Premium",
    free: isRu ? "Free" : "Free",
    image: isRu ? "Изображение" : "Image",
    video: isRu ? "Видео" : "Video",
    date: isRu ? "Период" : "Date",
    mode: isRu ? "Режим" : "Mode",
    status: isRu ? "Статус" : "Status",
    actions: isRu ? "Действия" : "Actions",
    titleLabel: isRu ? "Заголовок" : "Title",
    subtitleLabel: isRu ? "Описание" : "Subtitle",
    badgeLabel: isRu ? "Бейдж" : "Badge",
  };
}

export function TemplatesDailyFeaturedPage({ locale }: TemplatesDailyFeaturedPageProps) {
  const text = useMemo(() => copy(locale), [locale]);
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

    return null;
  }, [form.templateId, selectedAssignment, selectedTemplate]);
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
  const previewTitle =
    form.titleOverride.trim() || selectedTemplate?.title || selectedAssignment?.templateTitle || "";
  const previewSubtitle =
    form.subtitleOverride.trim() ||
    selectedTemplate?.shortDescription ||
    selectedAssignment?.subtitleOverride ||
    "";
  const previewBadge = form.badgeTextOverride.trim() || text.heroBadge;
  const previewType =
    selectedTemplate?.templateType ?? selectedAssignment?.templateType ?? ("Image" as TemplateType);
  const previewMediaUrl = getPreviewUrl(selectedTemplate ?? selectedAssignment);
  const isLoading = isScheduleLoading || isTemplateOptionsLoading;
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
      if (!canManageTemplates) {
        setTemplates([]);
        setTemplateOptionsError(null);
        setIsTemplateOptionsLoading(false);
        return;
      }

      setIsTemplateOptionsLoading(true);
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
        clientLogger.warn("templates.daily_featured_template_options_failed", { error: loadError });
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
          clientLogger.warn("templates.daily_featured_load_failed", { error: loadFailure });
          setError(getAdminErrorMessage(loadFailure, text.loadError));
        }
      } catch (loadError) {
        if (signal?.aborted) return;
        clientLogger.warn("templates.daily_featured_load_failed", { error: loadError });
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

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!canManageTemplates || !form.templateId || isSubmitting || invalidDateRangeWarning) return;

    setIsSubmitting(true);
    setError(null);
    try {
      const payload = toPayload(form);
      if (form.id) {
        await updateTemplateOfTheDay(form.id, payload);
      } else {
        await createTemplateOfTheDay(payload);
      }
      setForm(emptyForm(form.startDate));
      await loadScheduleData();
    } catch (saveError) {
      setError(getAdminErrorMessage(saveError, text.saveError));
    } finally {
      setIsSubmitting(false);
    }
  }

  async function handleDelete(assignment: AdminTemplateOfTheDay) {
    if (!canManageTemplates || isSubmitting) {
      return false;
    }

    setIsSubmitting(true);
    setError(null);
    try {
      await deleteTemplateOfTheDay(assignment.id);
      if (form.id === assignment.id) {
        setForm(emptyForm(form.startDate));
      }
      await loadScheduleData();
      return true;
    } catch (deleteError) {
      setError(getAdminErrorMessage(deleteError, text.saveError));
      return false;
    } finally {
      setIsSubmitting(false);
    }
  }

  async function handleAutoPick() {
    if (!canManageTemplates || isSubmitting || isAutoPickDateMissing) return;

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
      setError(getAdminErrorMessage(autoPickError, text.saveError));
    } finally {
      setIsSubmitting(false);
    }
  }

  async function handleSaveSettings() {
    if (!canManageTemplates || isSubmitting) return;

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
      setError(getAdminErrorMessage(settingsError, text.saveError));
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <AdminPage className={styles.page}>
      <AdminPageHero
        eyebrow={text.eyebrow}
        title={text.title}
        description={text.description}
        badge={<AdminBadge tone="info">{text.heroBadge}</AdminBadge>}
        actions={
          <Button
            variant="secondary"
            onClick={() => void refreshPageData()}
            disabled={!canManageTemplates || isLoading}
          >
            <RefreshIcon className={styles.buttonIcon} />
            {text.refresh}
          </Button>
        }
        metaItems={[
          `${text.schedule}: ${schedule.length} ${text.assignments}`,
          current ? `${text.current}: ${current.templateTitle}` : text.noCurrent,
          settings?.autoModeEnabled ? text.autoModeEnabled : text.autoModeDisabled,
        ]}
      />

      {error ? (
        <AdminStateCard
          tone="warning"
          title={error}
          action={
            <Button
              variant="secondary"
              onClick={() => void refreshPageData()}
              disabled={!canManageTemplates || isLoading}
            >
              {text.retry}
            </Button>
          }
        />
      ) : null}
      {isScheduleLoading ? <AdminStateCard title={text.loading} /> : null}

      <AdminPageGrid columns="two" className={styles.topGrid}>
        <AdminCard title={text.current}>
          {current ? (
            <AssignmentSummary assignment={current} text={text} />
          ) : (
            <AdminStateCard description={text.noCurrent} />
          )}
        </AdminCard>

        <AdminCard title={text.autoPick} description={text.autoPickDescription}>
          <div className={styles.assignmentSummary}>
            <strong>{text.autoModeStatus}</strong>
            <span>{autoPick.autoModeEnabled ? text.autoModeEnabled : text.autoModeDisabled}</span>
          </div>
          <label className={styles.checkboxField}>
            <input
              type="checkbox"
              checked={autoPick.autoModeEnabled}
              disabled={!canManageTemplates || isSubmitting}
              onChange={(event) =>
                setAutoPick((value) => ({
                  ...value,
                  autoModeEnabled: event.target.checked,
                }))
              }
            />
            <span>{text.autoMode}</span>
          </label>
          <div className={styles.compactGrid}>
            <AdminSelectField
              label={text.allowedTypes}
              value={autoPick.allowedTypes}
              disabled={!canManageTemplates || isSubmitting}
              onChange={(value) =>
                setAutoPick((state) => ({
                  ...state,
                  allowedTypes: value as AutoPickState["allowedTypes"],
                }))
              }
              options={[
                { value: "both", label: text.allowedBoth },
                { value: "image", label: text.image },
                { value: "video", label: text.video },
              ]}
            />
            <label className={styles.field}>
              <span>{text.excludeRecent}</span>
              <input
                className={styles.control}
                type="number"
                min={0}
                max={365}
                value={autoPick.excludeRecentDays}
                disabled={!canManageTemplates || isSubmitting}
                onChange={(event) =>
                  setAutoPick((value) => ({ ...value, excludeRecentDays: event.target.value }))
                }
              />
            </label>
          </div>
          <div className={styles.actionRow}>
            <Button
              variant="secondary"
              onClick={() => void handleSaveSettings()}
              disabled={!canManageTemplates || isSubmitting}
            >
              {text.autoModeSave}
            </Button>
          </div>
          <div className={styles.compactGrid}>
            <label className={styles.field}>
              <span>{text.startDate}</span>
              <input
                className={styles.control}
                type="date"
                required
                value={autoPick.date}
                disabled={!canManageTemplates || isSubmitting}
                onChange={(event) =>
                  setAutoPick((value) => ({ ...value, date: event.target.value }))
                }
              />
            </label>
          </div>
          {isAutoPickDateMissing ? (
            <AdminStateCard tone="warning" description={text.autoPickDateRequired} />
          ) : null}
          <div className={styles.actionRow}>
            <Button
              variant="primary"
              onClick={() => void handleAutoPick()}
              disabled={!canManageTemplates || isSubmitting || isAutoPickDateMissing}
            >
              <CalendarIcon className={styles.buttonIcon} />
              {text.autoPickRun}
            </Button>
          </div>
        </AdminCard>
      </AdminPageGrid>

      <AdminPageGrid columns="two" className={styles.editorGrid}>
        <AdminCard
          title={text.form}
          description={canManageTemplates ? text.formDescription : text.formAdminOnly}
        >
          <form onSubmit={handleSubmit} className={styles.form}>
            <label className={styles.field}>
              <span>{text.templateSearch}</span>
              <input
                className={styles.control}
                value={search}
                maxLength={SEARCH_LIMIT}
                placeholder={text.templateSearchPlaceholder}
                onChange={(event) => setSearch(event.target.value.slice(0, SEARCH_LIMIT))}
              />
            </label>
            <div className={styles.compactGrid}>
              <AdminSelectField
                label={text.templateTypeFilter}
                value={templateTypeFilter}
                disabled={isTemplateOptionsLoading}
                onChange={(value) => setTemplateTypeFilter(value as "" | TemplateType)}
                options={[
                  { value: "", label: text.allTemplateTypes },
                  { value: "Image", label: text.image },
                  { value: "Video", label: text.video },
                ]}
              />
              <AdminSelectField
                label={text.templateAccessFilter}
                value={templateAccessFilter}
                disabled={isTemplateOptionsLoading}
                onChange={(value) => setTemplateAccessFilter(value as TemplateAccessFilter)}
                options={[
                  { value: "", label: text.allAccessLevels },
                  { value: "free", label: text.free },
                  { value: "premium", label: text.premium },
                ]}
              />
              <div className={styles.inlineStatus}>{text.activeTemplatesOnly}</div>
            </div>
            <label className={styles.field}>
              <span>{text.template}</span>
              <select
                className={styles.control}
                value={form.templateId}
                disabled={!canManageTemplates || isSubmitting || isTemplateOptionsLoading}
                onChange={(event) =>
                  setForm((state) => ({ ...state, templateId: event.target.value }))
                }
              >
                <option value="">
                  {isTemplateOptionsLoading ? text.loadingTemplates : text.selectTemplate}
                </option>
                {templateOptions.map((template) => (
                  <option key={template.templateId} value={template.templateId}>
                    {template.title} · {template.templateType} · {template.category} ·{" "}
                    {template.isPremium ? text.premium : text.free}
                  </option>
                ))}
              </select>
            </label>
            {templateOptionsError ? (
              <AdminStateCard
                tone="warning"
                description={templateOptionsError}
                action={
                  <Button
                    type="button"
                    variant="secondary"
                    disabled={!canManageTemplates || isTemplateOptionsLoading}
                    onClick={() => void loadTemplateOptions(debouncedSearch)}
                  >
                    {text.retry}
                  </Button>
                }
              />
            ) : null}
            {!isTemplateOptionsLoading && templates.length === 0 ? (
              <AdminStateCard tone="info" description={text.noTemplates} />
            ) : null}
            {dateOccupiedWarning ? (
              <AdminStateCard tone="warning" description={text.dateOccupiedWarning} />
            ) : null}
            {invalidDateRangeWarning ? (
              <AdminStateCard tone="danger" description={text.invalidDateRangeWarning} />
            ) : null}
            <div className={styles.compactGrid}>
              <label className={styles.field}>
                <span>{text.startDate}</span>
                <input
                  className={styles.control}
                  type="date"
                  required
                  value={form.startDate}
                  disabled={!canManageTemplates || isSubmitting}
                  onChange={(event) =>
                    setForm((state) => ({ ...state, startDate: event.target.value }))
                  }
                />
              </label>
              <label className={styles.field}>
                <span>{text.endDate}</span>
                <input
                  className={styles.control}
                  type="date"
                  value={form.endDate}
                  disabled={!canManageTemplates || isSubmitting}
                  onChange={(event) =>
                    setForm((state) => ({ ...state, endDate: event.target.value }))
                  }
                />
              </label>
              <label className={styles.field}>
                <span>{text.priority}</span>
                <input
                  className={styles.control}
                  type="number"
                  value={form.priority}
                  disabled={!canManageTemplates || isSubmitting}
                  onChange={(event) =>
                    setForm((state) => ({ ...state, priority: event.target.value }))
                  }
                />
              </label>
              <label className={styles.checkboxField}>
                <input
                  type="checkbox"
                  checked={form.isActive}
                  disabled={!canManageTemplates || isSubmitting}
                  onChange={(event) =>
                    setForm((state) => ({ ...state, isActive: event.target.checked }))
                  }
                />
                <span>{text.active}</span>
              </label>
            </div>
            <label className={styles.field}>
              <span>{text.titleOverride}</span>
              <input
                className={styles.control}
                value={form.titleOverride}
                maxLength={120}
                disabled={!canManageTemplates || isSubmitting}
                onChange={(event) =>
                  setForm((state) => ({
                    ...state,
                    titleOverride: event.target.value.slice(0, 120),
                  }))
                }
              />
            </label>
            <label className={styles.field}>
              <span>{text.subtitleOverride}</span>
              <textarea
                className={`${styles.control} ${styles.textarea}`}
                value={form.subtitleOverride}
                maxLength={240}
                disabled={!canManageTemplates || isSubmitting}
                onChange={(event) =>
                  setForm((state) => ({
                    ...state,
                    subtitleOverride: event.target.value.slice(0, 240),
                  }))
                }
              />
            </label>
            <label className={styles.field}>
              <span>{text.badgeOverride}</span>
              <input
                className={styles.control}
                value={form.badgeTextOverride}
                maxLength={64}
                disabled={!canManageTemplates || isSubmitting}
                onChange={(event) =>
                  setForm((state) => ({
                    ...state,
                    badgeTextOverride: event.target.value.slice(0, 64),
                  }))
                }
              />
            </label>
            <div className={styles.actionRow}>
              <Button
                type="submit"
                variant="primary"
                disabled={
                  !canManageTemplates || isSubmitting || !form.templateId || invalidDateRangeWarning
                }
              >
                <PencilIcon className={styles.buttonIcon} />
                {form.id ? text.save : text.create}
              </Button>
              <Button
                variant="secondary"
                onClick={() => setForm(emptyForm(form.startDate))}
                disabled={isSubmitting}
              >
                {text.reset}
              </Button>
            </div>
          </form>
        </AdminCard>

        <AdminCard title={text.preview}>
          <div className={styles.previewCard}>
            {previewMediaUrl ? (
              isVideoTemplate(previewType) ? (
                <video
                  src={previewMediaUrl}
                  muted
                  playsInline
                  controls
                  className={styles.previewMedia}
                />
              ) : (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={previewMediaUrl} alt={previewTitle} className={styles.previewMedia} />
              )
            ) : (
              <div className={styles.previewEmpty}>
                <AdminIconTile icon={<TemplatesIcon />} tone="info" />
              </div>
            )}
            <div className={styles.previewOverlay}>
              <span className={styles.previewBadge}>
                <AdminBadge tone="success">{previewBadge}</AdminBadge>
              </span>
              <h3>{previewTitle || text.previewEmptyTitle}</h3>
              <p>{previewSubtitle || text.previewEmptySubtitle}</p>
            </div>
          </div>
        </AdminCard>
      </AdminPageGrid>

      <AdminCard title={text.schedule}>
        {schedule.length === 0 ? (
          <AdminStateCard description={text.noSchedule} />
        ) : (
          <div className={adminTableStyles.tableWrap}>
            <table className={`${adminTableStyles.table} ${styles.scheduleTable}`}>
              <thead>
                <tr>
                  <th>{text.template}</th>
                  <th>{text.date}</th>
                  <th>{text.mode}</th>
                  <th>{text.status}</th>
                  <th>{text.priority}</th>
                  <th>{text.actions}</th>
                </tr>
              </thead>
              <tbody>
                {schedule.map((assignment) => (
                  <tr key={assignment.id}>
                    <td>
                      <strong className={styles.templateTitle}>{assignment.templateTitle}</strong>
                      <span className={styles.templateMeta}>
                        {assignment.templateType} · {assignment.category} ·{" "}
                        {assignment.isPremium ? text.premium : text.free}
                      </span>
                    </td>
                    <td>{formatDateRange(assignment)}</td>
                    <td>
                      <AdminBadge tone={statusTone(assignment)}>
                        {assignment.isManual ? text.manual : text.auto}
                      </AdminBadge>
                    </td>
                    <td>{assignment.isActive ? text.active : text.inactive}</td>
                    <td>{assignment.priority}</td>
                    <td>
                      <div className={styles.tableActions}>
                        <Button
                          size="sm"
                          variant="secondary"
                          onClick={() => setForm(formFromAssignment(assignment))}
                        >
                          {text.edit}
                        </Button>
                        <Button
                          size="sm"
                          variant="danger"
                          disabled={!canManageTemplates || isSubmitting}
                          onClick={() => setAssignmentPendingDelete(assignment)}
                        >
                          {text.delete}
                        </Button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </AdminCard>

      <ConfirmationDialog
        open={assignmentPendingDelete !== null}
        title={text.deleteConfirmTitle}
        description={
          assignmentPendingDelete
            ? text.deleteConfirmDescription(assignmentPendingDelete.templateTitle)
            : ""
        }
        confirmLabel={text.delete}
        cancelLabel={text.cancel}
        isSubmitting={Boolean(assignmentPendingDelete && isSubmitting)}
        onCancel={() => {
          if (!isSubmitting) {
            setAssignmentPendingDelete(null);
          }
        }}
        onConfirm={() => {
          if (!assignmentPendingDelete) {
            return;
          }

          void handleDelete(assignmentPendingDelete).then((succeeded) => {
            if (succeeded) {
              setAssignmentPendingDelete(null);
            }
          });
        }}
      />
    </AdminPage>
  );
}

function AssignmentSummary({
  assignment,
  text,
}: {
  assignment: AdminTemplateOfTheDay;
  text: DailyFeaturedCopy;
}) {
  return (
    <div className={styles.assignmentSummary}>
      <strong>{assignment.templateTitle}</strong>
      <span>
        {formatDateRange(assignment)} · {assignment.templateType} · {assignment.category}
      </span>
      <span>
        <AdminBadge tone={statusTone(assignment)}>
          {assignment.isManual ? text.manual : text.auto}
        </AdminBadge>{" "}
        {assignment.isPremium ? text.premium : text.free}
      </span>
      {assignment.titleOverride ? (
        <span>
          {text.titleLabel}: {assignment.titleOverride}
        </span>
      ) : null}
      {assignment.subtitleOverride ? (
        <span>
          {text.subtitleLabel}: {assignment.subtitleOverride}
        </span>
      ) : null}
      {assignment.badgeTextOverride ? (
        <span>
          {text.badgeLabel}: {assignment.badgeTextOverride}
        </span>
      ) : null}
    </div>
  );
}
