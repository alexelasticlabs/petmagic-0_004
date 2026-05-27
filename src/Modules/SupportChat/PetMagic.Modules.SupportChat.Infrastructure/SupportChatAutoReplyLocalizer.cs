namespace PetMagic.Modules.SupportChat.Infrastructure;

internal static class SupportChatAutoReplyLocalizer
{
    public static string BuildFirstReplyAcknowledgement(string? locale)
    {
        return NormalizeLanguage(locale) switch
        {
            "ru" => "Спасибо, мы получили ваше сообщение. Поддержка ответит в этом чате.",
            "de" => "Nachricht erhalten. Der Support antwortet in diesem Chat.",
            "pl" => "Wiadomosc otrzymana. Wsparcie odpowie w tym czacie.",
            "it" => "Messaggio ricevuto. Il supporto rispondera in questa chat.",
            "fr" => "Message recu. Le support repondra dans ce chat.",
            "es" => "Mensaje recibido. Soporte respondera en este chat.",
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
