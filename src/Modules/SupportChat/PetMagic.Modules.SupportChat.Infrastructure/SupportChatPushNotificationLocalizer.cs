namespace PetMagic.Modules.SupportChat.Infrastructure;

internal static class SupportChatPushNotificationLocalizer
{
    public static string BuildTitle(string? locale)
    {
        return NormalizeLanguage(locale) switch
        {
            "ru" => "Поддержка PetMagic ответила",
            "de" => "Der PetMagic-Support hat geantwortet",
            "pl" => "Pomoc PetMagic odpowiedziała",
            "it" => "Il supporto PetMagic ha risposto",
            "fr" => "Le support PetMagic a répondu",
            "es" => "El soporte de PetMagic respondió",
            _ => "PetMagic Support replied",
        };
    }

    public static string BuildFallbackBody(string? locale, bool hasAttachment)
    {
        return NormalizeLanguage(locale) switch
        {
            "ru" => hasAttachment
                ? "Новое вложение в диалоге поддержки."
                : "Новый ответ в диалоге поддержки.",
            "de" => hasAttachment
                ? "Neuer Anhang in Ihrem Support-Dialog."
                : "Neue Antwort in Ihrem Support-Dialog.",
            "pl" => hasAttachment
                ? "Nowy załącznik w Twojej rozmowie ze wsparciem."
                : "Nowa odpowiedź w Twojej rozmowie ze wsparciem.",
            "it" => hasAttachment
                ? "Nuovo allegato nella tua conversazione con il supporto."
                : "Nuova risposta nella tua conversazione con il supporto.",
            "fr" => hasAttachment
                ? "Nouvelle pièce jointe dans votre conversation avec le support."
                : "Nouvelle réponse dans votre conversation avec le support.",
            "es" => hasAttachment
                ? "Nuevo archivo adjunto en tu conversación con soporte."
                : "Nueva respuesta en tu conversación con soporte.",
            _ => hasAttachment
                ? "New attachment in your support conversation."
                : "New reply in your support conversation.",
        };
    }

    private static string NormalizeLanguage(string? locale)
    {
        if (string.IsNullOrWhiteSpace(locale))
        {
            return "en";
        }

        var normalized = locale.Trim().Replace('_', '-').ToLowerInvariant();
        var separatorIndex = normalized.IndexOf('-');
        return separatorIndex >= 0 ? normalized[..separatorIndex] : normalized;
    }
}
