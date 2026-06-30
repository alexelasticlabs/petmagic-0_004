import type { FormEvent } from "react";

import type { TemplatesDailyFeaturedPageText } from "@/components/templates/templates-daily-featured-page.content";
import type { AdminTemplateListItem, AdminTemplateOfTheDay, TemplateType } from "@/lib/api-client";
import type { Locale } from "@/lib/i18n";

export type TemplatesDailyFeaturedPageProps = {
  locale: Locale;
};

export type AssignmentFormState = {
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

export type AutoPickState = {
  date: string;
  autoModeEnabled: boolean;
  allowedTypes: "both" | "image" | "video";
  excludeRecentDays: string;
};

export type TemplateAccessFilter = "" | "premium" | "free";

export type TemplateOption = Pick<
  AdminTemplateListItem,
  | "templateId"
  | "templateType"
  | "title"
  | "shortDescription"
  | "category"
  | "isPremium"
  | "previewAsset"
>;

export type CurrentAssignmentCardProps = {
  current: AdminTemplateOfTheDay | null;
  text: TemplatesDailyFeaturedPageText;
};

export type AutoPickSettingsCardProps = {
  text: TemplatesDailyFeaturedPageText;
  autoPick: AutoPickState;
  canManageTemplates: boolean;
  isActionLocked: boolean;
  isAutoPickSettingsDirty: boolean;
  isAutoPickDateMissing: boolean;
  onAutoModeEnabledChange: (value: boolean) => void;
  onAllowedTypesChange: (value: AutoPickState["allowedTypes"]) => void;
  onExcludeRecentDaysChange: (value: string) => void;
  onDateChange: (value: string) => void;
  onSaveSettings: () => void;
  onRunAutoPick: () => void;
};

export type TemplateAssignmentEditorCardProps = {
  text: TemplatesDailyFeaturedPageText;
  canManageTemplates: boolean;
  isActionLocked: boolean;
  search: string;
  templateTypeFilter: "" | TemplateType;
  templateAccessFilter: TemplateAccessFilter;
  form: AssignmentFormState;
  templateOptions: TemplateOption[];
  isTemplateOptionsLoading: boolean;
  hasTemplateOptions: boolean;
  templateOptionsError: string | null;
  dateOccupiedWarning: boolean;
  invalidDateRangeWarning: boolean;
  onSearchChange: (value: string) => void;
  onTemplateTypeFilterChange: (value: "" | TemplateType) => void;
  onTemplateAccessFilterChange: (value: TemplateAccessFilter) => void;
  onTemplateChange: (templateId: string) => void;
  onRetryTemplateOptions: () => void;
  onFormChange: (patch: Partial<AssignmentFormState>) => void;
  onReset: () => void;
  onSubmit: (event: FormEvent<HTMLFormElement>) => void;
};

export type FeaturedPreviewCardProps = {
  text: TemplatesDailyFeaturedPageText;
  selectedTemplateSnapshot: TemplateOption | null;
  previewTitle: string;
  previewSubtitle: string;
  previewBadge: string;
  previewType: TemplateType;
  previewMediaUrl: string | null;
};

export type TemplateScheduleCardProps = {
  text: TemplatesDailyFeaturedPageText;
  schedule: AdminTemplateOfTheDay[];
  canManageTemplates: boolean;
  isActionLocked: boolean;
  onEditAssignment: (assignment: AdminTemplateOfTheDay) => void;
  onRequestDeleteAssignment: (assignment: AdminTemplateOfTheDay) => void;
};
