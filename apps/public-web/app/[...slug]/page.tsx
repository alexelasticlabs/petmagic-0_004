import type { Metadata } from "next";
import { notFound } from "next/navigation";
import {
  legalCatalog,
  parseRoute,
  resolveCatalogLocale,
  type DocumentRoute,
  type LegalDocument,
  type SupportedLocale,
} from "../legal-catalog";
import { LegalShell } from "../site-components";

type PageProps = { params: Promise<{ slug: string[] }> };

const routeTitles: Record<DocumentRoute, string> = {
  privacy: "Privacy Policy",
  terms: "Terms of Use",
  support: "Support",
  "account-deletion": "Account deletion",
};

export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const route = parseRoute((await params).slug);
  if (!route) return {};
  return {
    title: routeTitles[route.route],
    alternates: {
      canonical:
        route.locale === "en"
          ? `/${route.route}`
          : `/${route.locale}/${route.route}`,
    },
  };
}

export default async function InformationPage({ params }: PageProps) {
  const route = parseRoute((await params).slug);
  if (!route) notFound();
  const localized = resolveCatalogLocale(route.locale);

  return (
    <LegalShell locale={route.locale} currentRoute={route.route}>
      {localized.isFallback && (
        <aside className="translation-notice" role="status">
          The approved {route.locale.toUpperCase()} legal translation is not published yet. English is shown.
        </aside>
      )}
      {route.route === "privacy" && (
        <LegalDocumentPage
          document={localized.content.privacyPolicy}
          locale={localized.isFallback ? "en" : route.locale}
        />
      )}
      {route.route === "terms" && (
        <LegalDocumentPage
          document={localized.content.termsOfUse}
          locale={localized.isFallback ? "en" : route.locale}
        />
      )}
      {route.route === "support" && <SupportPage locale={route.locale} />}
      {route.route === "account-deletion" && <AccountDeletionPage locale={route.locale} />}
    </LegalShell>
  );
}

function LegalDocumentPage({
  document,
  locale,
}: {
  document: LegalDocument;
  locale: SupportedLocale;
}) {
  return (
    <article className="document" lang={locale}>
      <header className="document-header">
        <p className="eyebrow">Version {legalCatalog.version}</p>
        <h1>{document.title}</h1>
        <p>{document.summary}</p>
        <time dateTime={legalCatalog.publishedAtUtc}>Published July 9, 2026</time>
      </header>
      <div className="document-sections">
        {document.sections.map((section) => (
          <section key={section.title}>
            <h2>{section.title}</h2>
            {section.paragraphs.map((paragraph) => <p key={paragraph}>{paragraph}</p>)}
          </section>
        ))}
      </div>
    </article>
  );
}

function SupportPage({ locale }: { locale: SupportedLocale }) {
  const russian = locale === "ru";
  return (
    <article className="document compact-document" lang={russian ? "ru" : "en"}>
      <header className="document-header">
        <p className="eyebrow">PetMagic care</p>
        <h1>{russian ? "Поддержка" : "Support"}</h1>
        <p>{russian ? "Поможем с аккаунтом, генерацией и оплатой." : "Help with your account, generations, and payments."}</p>
      </header>
      <div className="support-panel">
        <h2>{russian ? "Связаться с нами в приложении" : "Contact us in the app"}</h2>
        <p>{russian ? "Откройте Профиль → Поддержка и создайте обращение. Для платежного вопроса укажите магазин, дату и номер заказа — не отправляйте пароль, токен или полные данные карты." : "Open Profile → Support and start a request. For billing questions, include the store, date, and order number—never send a password, token, or full card details."}</p>
      </div>
    </article>
  );
}

function AccountDeletionPage({ locale }: { locale: SupportedLocale }) {
  const russian = locale === "ru";
  return (
    <article className="document compact-document" lang={russian ? "ru" : "en"}>
      <header className="document-header">
        <p className="eyebrow">Account control</p>
        <h1>{russian ? "Удаление аккаунта" : "Delete your account"}</h1>
        <p>{russian ? "Удаление необратимо и выполняется из авторизованного профиля." : "Deletion is irreversible and starts from your authenticated profile."}</p>
      </header>
      <ol className="steps">
        <li>{russian ? "Войдите в PetMagic." : "Sign in to PetMagic."}</li>
        <li>{russian ? "Откройте Профиль → Настройки." : "Open Profile → Settings."}</li>
        <li>{russian ? "Выберите «Удалить аккаунт» и подтвердите действие." : "Choose Delete account and confirm."}</li>
      </ol>
      <p className="safety-note">{russian ? "Если вы не можете войти, создайте обращение в разделе Поддержка с устройства, где аккаунт использовался ранее." : "If you cannot sign in, open Support from a device where you previously used the account."}</p>
    </article>
  );
}
