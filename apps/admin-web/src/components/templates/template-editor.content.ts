import { type Locale } from "@/lib/i18n";

const templateEditorRuntimeText = {
  ru: {
    actionsAdminOnly: "Управление шаблонами доступно только администратору.",
    templateTypeMismatch:
      "Этот шаблон имеет другой тип и не может быть открыт в выбранном редакторе.",
  },
  en: {
    actionsAdminOnly: "Template management actions are available to Admin only.",
    templateTypeMismatch:
      "This template has a different type and cannot be opened in the selected editor.",
  },
} as const;

export type TemplateEditorRuntimeText = {
  [K in keyof (typeof templateEditorRuntimeText)["en"]]: string;
};

export function getTemplateEditorRuntimeText(locale: Locale): TemplateEditorRuntimeText {
  return templateEditorRuntimeText[locale] as TemplateEditorRuntimeText;
}
