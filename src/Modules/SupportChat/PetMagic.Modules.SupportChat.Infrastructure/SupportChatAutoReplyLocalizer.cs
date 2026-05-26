namespace PetMagic.Modules.SupportChat.Infrastructure;

internal static class SupportChatAutoReplyLocalizer
{
    public static string BuildFirstReplyAcknowledgement(string? locale)
    {
        return NormalizeLanguage(locale) switch
        {
            "ru" => "Сообщение получено. Команда поддержки уже получила ваш запрос и ответит в ближайшее время.",
            "de" => "Nachricht erhalten. Unser Support-Team hat Ihre Anfrage bereits erhalten und wird bald antworten.",
            "pl" => "Wiadomosc otrzymana. Nasz zespol wsparcia otrzymal Twoje zgloszenie i odpowie w najblizszym czasie.",
            "it" => "Messaggio ricevuto. Il nostro team di supporto ha gia ricevuto la tua richiesta e rispondera al piu presto.",
            "fr" => "Message recu. Notre equipe de support a bien recu votre demande et vous repondra bientot.",
            "es" => "Mensaje recibido. Nuestro equipo de soporte ya recibio tu solicitud y respondera pronto.",
            _ => "Message received. Our support team has your request and will reply soon.",
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
