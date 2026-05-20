using PetMagic.Modules.Identity.Application.Abstractions;
using PetMagic.Modules.Identity.Application.Contracts;

namespace PetMagic.Modules.Identity.Infrastructure;

internal sealed class LegalDocumentsCatalog : ILegalDocumentsCatalog
{
    private const string CurrentVersion = "2026-05-20";
    private static readonly DateTime PublishedAtUtc = new(2026, 5, 20, 0, 0, 0, DateTimeKind.Utc);

    public string CurrentTermsOfUseVersion => CurrentVersion;

    public string CurrentPrivacyPolicyVersion => CurrentVersion;

    public LegalDocumentsResponse GetCurrentDocuments(string? locale)
    {
        var isRussian = string.Equals(locale?.Trim(), "ru", StringComparison.OrdinalIgnoreCase)
            || string.Equals(locale?.Trim(), "ru-RU", StringComparison.OrdinalIgnoreCase);

        return isRussian ? BuildRussianDocuments() : BuildEnglishDocuments();
    }

    public bool MatchesCurrentVersions(string? termsOfUseVersion, string? privacyPolicyVersion)
    {
        return string.Equals(termsOfUseVersion, CurrentTermsOfUseVersion, StringComparison.Ordinal)
            && string.Equals(privacyPolicyVersion, CurrentPrivacyPolicyVersion, StringComparison.Ordinal);
    }

    private static LegalDocumentsResponse BuildRussianDocuments()
    {
        return new LegalDocumentsResponse(
            new LegalDocumentResponse(
                LegalDocumentKinds.TermsOfUse,
                "Пользовательское соглашение PetMagic",
                CurrentVersion,
                PublishedAtUtc,
                "Короткие правила использования аккаунта, контента и платных функций PetMagic.",
                [
                    new LegalDocumentSectionResponse("1. Использование сервиса", [
                        "PetMagic помогает создавать и обрабатывать контент о питомцах. Пользуясь приложением, вы подтверждаете, что можете заключать обязательные соглашения и соблюдаете эти правила."
                    ]),
                    new LegalDocumentSectionResponse("2. Аккаунт и безопасность", [
                        "Вы обязаны указывать актуальный email, защищать данные входа и не передавать аккаунт третьим лицам. Мы можем ограничить доступ при злоупотреблениях, нарушениях правил или угрозе безопасности платформы."
                    ]),
                    new LegalDocumentSectionResponse("3. Контент и ограничения", [
                        "Вы отвечаете за законность загружаемого и создаваемого контента. Нельзя использовать сервис для незаконных, оскорбительных, мошеннических или нарушающих чужие права материалов."
                    ]),
                    new LegalDocumentSectionResponse("4. Платные функции и обновления", [
                        "Некоторые функции могут требовать внутренние цифровые единицы или платный доступ. Стоимость и лимиты могут меняться, а при существенном обновлении условий мы можем запросить повторное принятие текущей версии документа."
                    ])
                ]),
            new LegalDocumentResponse(
                LegalDocumentKinds.PrivacyPolicy,
                "Политика конфиденциальности PetMagic",
                CurrentVersion,
                PublishedAtUtc,
                "Кратко о том, какие данные мы используем и как их защищаем.",
                [
                    new LegalDocumentSectionResponse("1. Какие данные нужны", [
                        "Мы обрабатываем данные аккаунта, настройки, сведения о согласиях и технические данные сеанса. При использовании функций сервиса также могут обрабатываться медиафайлы, события использования и обращения в поддержку."
                    ]),
                    new LegalDocumentSectionResponse("2. Зачем они используются", [
                        "Данные нужны для входа, работы приложения, генераций, поддержки, защиты от злоупотреблений и выполнения юридических обязанностей. Маркетинговые письма отправляются только при отдельном выборе пользователя."
                    ]),
                    new LegalDocumentSectionResponse("3. Передача и защита", [
                        "Мы не продаем персональные данные. Передача возможна только поставщикам инфраструктуры, аутентификации, платежей и коммуникаций, когда это необходимо для работы сервиса, при этом используются технические и организационные меры защиты."
                    ]),
                    new LegalDocumentSectionResponse("4. Ваши права", [
                        "Вы можете запросить доступ, исправление или удаление данных там, где это допускает закон. Мы также фиксируем версию документа и дату принятия, чтобы подтверждать актуальное состояние согласия."
                    ])
                ]));
    }

    private static LegalDocumentsResponse BuildEnglishDocuments()
    {
        return new LegalDocumentsResponse(
            new LegalDocumentResponse(
                LegalDocumentKinds.TermsOfUse,
                "PetMagic Terms of Use",
                CurrentVersion,
                PublishedAtUtc,
                "Short rules for account usage, user content, and paid PetMagic features.",
                [
                    new LegalDocumentSectionResponse("1. Using the service", [
                        "PetMagic helps create and process pet-related content. By using the app, you confirm that you can enter binding agreements and follow these rules."
                    ]),
                    new LegalDocumentSectionResponse("2. Account and security", [
                        "You must provide a valid email address, keep credentials secure, and not share account access. PetMagic may restrict access if rules are violated, abuse is detected, or platform security is at risk."
                    ]),
                    new LegalDocumentSectionResponse("3. Content and limits", [
                        "You are responsible for the lawfulness of uploaded or generated content. The service must not be used for unlawful, abusive, fraudulent, or rights-infringing materials."
                    ]),
                    new LegalDocumentSectionResponse("4. Paid features and updates", [
                        "Some features may require internal digital units or paid access. Pricing and limits may change over time, and a material update may require accepting the current document version again."
                    ])
                ]),
            new LegalDocumentResponse(
                LegalDocumentKinds.PrivacyPolicy,
                "PetMagic Privacy Policy",
                CurrentVersion,
                PublishedAtUtc,
                "A short overview of what data we use and how we protect it.",
                [
                    new LegalDocumentSectionResponse("1. What data we need", [
                        "We process account details, preferences, consent records, and technical session data. When you use app features, we may also process media uploads, usage events, and support messages."
                    ]),
                    new LegalDocumentSectionResponse("2. Why we use it", [
                        "Data is used for sign-in, app functionality, generations, support, abuse prevention, and legal compliance. Marketing communication is sent only when the user separately opts in."
                    ]),
                    new LegalDocumentSectionResponse("3. Sharing and protection", [
                        "We do not sell personal data. Sharing is limited to infrastructure, authentication, payment, and communication providers when required to run the service, and we apply technical and organizational safeguards."
                    ]),
                    new LegalDocumentSectionResponse("4. Your rights", [
                        "You may request access, correction, or deletion where allowed by law. We also store the accepted legal version and timestamp so the active consent state can be verified."
                    ])
                ]));
    }
}
