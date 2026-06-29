import { type Locale } from "@/lib/i18n";

const dateTimeIntlLocales: Record<Locale, string> = {
  ru: "ru-RU",
  en: "en-US",
};

export function formatDateTime(value: string | null | undefined, locale: Locale): string {
  if (!value) {
    return "—";
  }

  const parsedDate = new Date(value);
  if (Number.isNaN(parsedDate.getTime())) {
    return "—";
  }

  return new Intl.DateTimeFormat(dateTimeIntlLocales[locale], {
    dateStyle: "medium",
    timeStyle: "short",
  }).format(parsedDate);
}
