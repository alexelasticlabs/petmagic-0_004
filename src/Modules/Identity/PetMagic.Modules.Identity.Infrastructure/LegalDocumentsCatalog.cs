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
                "Правила использования сервиса, аккаунта, контента и платных возможностей PetMagic.",
                [
                    new LegalDocumentSectionResponse("1. Общие условия использования", [
                        "Используя PetMagic, вы подтверждаете, что действуете законно и вправе принимать условия этого соглашения. Если вы не согласны с условиями, использование сервиса должно быть прекращено."
                    ]),
                    new LegalDocumentSectionResponse("2. Аккаунт и безопасность", [
                        "Вы обязаны указывать достоверные данные, хранить в тайне данные входа и не передавать доступ к аккаунту третьим лицам. Вы несете ответственность за действия, совершенные через ваш аккаунт."
                    ]),
                    new LegalDocumentSectionResponse("3. Контент пользователя", [
                        "Вы отвечаете за законность, корректность и права на загружаемый и создаваемый контент. Запрещено использовать сервис для незаконных, оскорбительных, мошеннических или нарушающих права третьих лиц материалов."
                    ]),
                    new LegalDocumentSectionResponse("4. Платные функции и изменения условий", [
                        "Часть функций может предоставляться за плату или с использованием внутренних цифровых единиц. Стоимость, лимиты и функциональность могут обновляться. При существенных изменениях условий мы вправе запросить повторное подтверждение актуальной версии документов."
                    ]),
                    new LegalDocumentSectionResponse("5. Ограничение доступа и ответственность", [
                        "Мы можем ограничить или прекратить доступ к сервису при нарушении правил, злоупотреблениях или угрозе безопасности платформы. PetMagic не гарантирует бесперебойную работу сервиса и несет ответственность в пределах, установленных применимым правом."
                    ])
                ]),
            new LegalDocumentResponse(
                LegalDocumentKinds.PrivacyPolicy,
                "Политика конфиденциальности PetMagic",
                CurrentVersion,
                PublishedAtUtc,
                "Информация о том, какие данные мы обрабатываем, зачем это делаем и как защищаем вашу информацию.",
                [
                    new LegalDocumentSectionResponse("1. Какие данные мы собираем", [
                        "Мы можем обрабатывать данные аккаунта (email, имя), настройки, сведения о согласиях, технические данные сеанса, а также данные, связанные с использованием функций сервиса: загруженные медиафайлы, события использования и обращения в поддержку."
                    ]),
                    new LegalDocumentSectionResponse("2. Цели обработки данных", [
                        "Данные используются для работы аккаунта и функций приложения, обеспечения безопасности, обработки запросов в поддержку, предотвращения злоупотреблений и выполнения требований закона. Маркетинговые сообщения отправляются только при отдельном согласии пользователя."
                    ]),
                    new LegalDocumentSectionResponse("3. Передача данных третьим лицам", [
                        "Мы не продаем персональные данные. Передача возможна только проверенным поставщикам инфраструктуры, аутентификации, платежей и коммуникаций в объеме, необходимом для работы сервиса и исполнения обязательств."
                    ]),
                    new LegalDocumentSectionResponse("4. Хранение и защита информации", [
                        "Мы применяем разумные технические и организационные меры для защиты данных от несанкционированного доступа, утраты или изменения. Данные хранятся не дольше, чем это необходимо для целей обработки или требований законодательства."
                    ]),
                    new LegalDocumentSectionResponse("5. Ваши права", [
                        "Вы можете запросить доступ к своим данным, их исправление или удаление в случаях, предусмотренных законом. Мы также фиксируем версии юридических документов и дату их принятия для подтверждения статуса согласия."
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
                "Rules for using the service, your account, content, and paid PetMagic features.",
                [
                    new LegalDocumentSectionResponse("1. General terms of use", [
                        "By using PetMagic, you confirm that you are legally able to accept these terms and that you will use the service lawfully. If you do not agree with these terms, you must stop using the service."
                    ]),
                    new LegalDocumentSectionResponse("2. Account and security", [
                        "You must provide accurate account information, keep your credentials secure, and not share account access with others. You are responsible for actions performed through your account."
                    ]),
                    new LegalDocumentSectionResponse("3. User content", [
                        "You are responsible for the legality of uploaded and generated content and for having the rights to use it. The service must not be used for unlawful, abusive, fraudulent, or rights-infringing materials."
                    ]),
                    new LegalDocumentSectionResponse("4. Paid features and updates", [
                        "Some features may require paid access or internal digital units. Pricing, limits, and functionality may change over time. Material updates may require you to accept the latest legal document version again."
                    ]),
                    new LegalDocumentSectionResponse("5. Access limits and liability", [
                        "We may limit or suspend access if these terms are violated, abuse is detected, or platform security is at risk. PetMagic is provided on an \"as available\" basis, with liability limited as permitted by applicable law."
                    ])
                ]),
            new LegalDocumentResponse(
                LegalDocumentKinds.PrivacyPolicy,
                "PetMagic Privacy Policy",
                CurrentVersion,
                PublishedAtUtc,
                "How we collect, use, share, and protect your personal information.",
                [
                    new LegalDocumentSectionResponse("1. What data we collect", [
                        "We may process account data (such as email and display name), preferences, consent records, technical session data, and feature-related data such as media uploads, usage events, and support messages."
                    ]),
                    new LegalDocumentSectionResponse("2. Why we process data", [
                        "We use data to operate your account, provide app functionality, maintain security, support users, prevent abuse, and comply with legal obligations. Marketing messages are sent only if you explicitly opt in."
                    ]),
                    new LegalDocumentSectionResponse("3. Data sharing", [
                        "We do not sell personal data. We share data only with trusted infrastructure, authentication, payment, and communication providers when necessary to operate the service and fulfill legal or contractual obligations."
                    ]),
                    new LegalDocumentSectionResponse("4. Storage and protection", [
                        "We apply reasonable technical and organizational safeguards to protect personal data from unauthorized access, loss, or alteration. Data is retained only as long as needed for processing purposes or as required by law."
                    ]),
                    new LegalDocumentSectionResponse("5. Your rights", [
                        "Where permitted by law, you may request access, correction, or deletion of your personal data. We also store accepted legal document versions and timestamps to verify your consent status."
                    ])
                ]));
    }
}
