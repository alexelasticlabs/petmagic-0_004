import { type Locale } from "@/lib/i18n";

const templateEditorRuntimeText = {
  ru: {
    actionsAdminOnly: "Управление шаблонами доступно только администратору.",
  },
  en: {
    actionsAdminOnly: "Template management actions are available to Admin only.",
  },
} as const;

export type TemplateEditorRuntimeText = {
  [K in keyof (typeof templateEditorRuntimeText)["en"]]: string;
};

export function getTemplateEditorRuntimeText(locale: Locale): TemplateEditorRuntimeText {
  return templateEditorRuntimeText[locale] as TemplateEditorRuntimeText;
}
