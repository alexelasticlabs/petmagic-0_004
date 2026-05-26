import { type TemplateStatus, type TemplateType } from "@/lib/api-client";
import { type Dictionary, type Locale } from "@/lib/i18n";

type TemplateKindText = Pick<Dictionary, "templateKindVideoBadge" | "templateKindImageBadge">;
type TemplateAccessText = Pick<Dictionary, "premiumLabel" | "freeLabel">;

export function getTemplateTypeLabel(templateType: TemplateType, text: TemplateKindText) {
  return templateType === "Video" ? text.templateKindVideoBadge : text.templateKindImageBadge;
}

export function getTemplateAccessLabel(isPremium: boolean, text: TemplateAccessText) {
  return isPremium ? text.premiumLabel : text.freeLabel;
}

export function getTemplateStatusLabel(status: TemplateStatus, locale: Locale) {
  if (locale !== "ru") {
    return status;
  }

  return status === "Active" ? "Активен" : status === "Draft" ? "Черновик" : "Архив";
}

export function getCharacterOrientationLabel(value: string | undefined, text: TemplateKindText) {
  if (!value) {
    return "-";
  }

  return value === "Image"
    ? text.templateKindImageBadge
    : value === "Video"
      ? text.templateKindVideoBadge
      : value;
}
