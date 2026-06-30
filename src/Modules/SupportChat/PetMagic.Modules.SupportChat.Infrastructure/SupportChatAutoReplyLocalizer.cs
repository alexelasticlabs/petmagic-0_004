namespace PetMagic.Modules.SupportChat.Infrastructure;

internal static class SupportChatAutoReplyLocalizer
{
    public static string BuildFirstReplyAcknowledgement(string? locale)
    {
        return NormalizeLanguage(locale) switch
        {
            "ru" => "Спасибо, мы получили ваше сообщение. Поддержка ответит в этом чате.",
            "de" => "Nachricht erhalten. Der Support antwortet in diesem Chat.",
            "pl" => "Wiadomość otrzymana. Wsparcie odpowie w tym czacie.",
            "it" => "Messaggio ricevuto. Il supporto risponderà in questa chat.",
            "fr" => "Message reçu. Le support répondra dans ce chat.",
            "es" => "Mensaje recibido. Soporte responderá en este chat.",
            _ => "Message received. Support will reply in this chat.",
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
