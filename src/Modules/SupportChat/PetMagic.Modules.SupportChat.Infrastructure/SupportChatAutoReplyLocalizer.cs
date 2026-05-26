namespace PetMagic.Modules.SupportChat.Infrastructure;

internal static class SupportChatAutoReplyLocalizer
{
    public static string BuildFirstReplyAcknowledgement(string? locale)
    {
        return NormalizeLanguage(locale) switch
        {
            "ru" => "Сообщение доставлено. Я отвечу на русском, потому что у вас русский интерфейс. Команда PetMagic уже получила ваш запрос.",
            "de" => "Nachricht zugestellt. Ich antworte auf Deutsch, weil Ihre App-Oberflache auf Deutsch eingestellt ist. Das PetMagic-Team hat Ihre Anfrage bereits erhalten.",
            "pl" => "Wiadomosc dostarczona. Odpowiem po polsku, bo interfejs aplikacji jest ustawiony na ten jezyk. Zespol PetMagic juz otrzymal Twoje zgloszenie.",
            "it" => "Messaggio consegnato. Rispondero in italiano, perche l'interfaccia dell'app e impostata in questa lingua. Il team PetMagic ha gia ricevuto la tua richiesta.",
            "fr" => "Message livre. Je repondrai en francais, car l'interface de l'application utilise cette langue. L'equipe PetMagic a deja recu votre demande.",
            "es" => "Mensaje entregado. Respondere en espanol porque la interfaz de la aplicacion usa ese idioma. El equipo de PetMagic ya recibio tu solicitud.",
            _ => "Message delivered. I will reply in English because your app interface is using English. The PetMagic team has already received your request.",
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
