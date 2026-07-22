import catalogJson from "../../../shared/legal/legal-documents.v2026-07-09.json";

export const supportedLocales = ["en", "ru"] as const;
export type SupportedLocale = (typeof supportedLocales)[number];
export type DocumentRoute = "privacy" | "terms" | "support" | "account-deletion";

export type LegalDocument = {
  title: string;
  summary: string;
  sections: Array<{ title: string; paragraphs: string[] }>;
};

type CatalogLocale = {
  termsOfUse: LegalDocument;
  privacyPolicy: LegalDocument;
};

type LegalCatalog = {
  version: string;
  publishedAtUtc: string;
  defaultLocale: string;
  requiredLocales: string[];
  locales: Record<string, CatalogLocale>;
};

export const legalCatalog = catalogJson as LegalCatalog;

export function isSupportedLocale(value: string): value is SupportedLocale {
  return supportedLocales.includes(value as SupportedLocale);
}

export function resolveCatalogLocale(locale: SupportedLocale): {
  content: CatalogLocale;
  isFallback: boolean;
} {
  const localized = legalCatalog.locales[locale];
  if (localized) return { content: localized, isFallback: false };
  return {
    content: legalCatalog.locales[legalCatalog.defaultLocale],
    isFallback: true,
  };
}

export function parseRoute(slug: string[]): {
  locale: SupportedLocale;
  route: DocumentRoute;
} | null {
  if (slug.length === 1 && isDocumentRoute(slug[0])) {
    return { locale: "en", route: slug[0] };
  }
  if (slug.length === 2 && isSupportedLocale(slug[0]) && isDocumentRoute(slug[1])) {
    return { locale: slug[0], route: slug[1] };
  }
  return null;
}

function isDocumentRoute(value: string): value is DocumentRoute {
  return ["privacy", "terms", "support", "account-deletion"].includes(value);
}
