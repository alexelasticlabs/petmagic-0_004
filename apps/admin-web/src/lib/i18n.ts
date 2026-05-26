import { enDictionary } from "./i18n.en";
import { ruDictionary } from "./i18n.ru";
import { locales, type Dictionary, type Locale } from "./i18n.types";

export { defaultLocale, locales } from "./i18n.types";
export type { Dictionary, Locale } from "./i18n.types";

const dictionaries: Record<Locale, Dictionary> = {
  ru: ruDictionary,
  en: enDictionary,
};

export function isLocale(value: string): value is Locale {
  return locales.includes(value as Locale);
}

export function getDictionary(locale: Locale): Dictionary {
  return dictionaries[locale];
}
