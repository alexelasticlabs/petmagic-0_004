namespace PetMagic.Modules.Templates.Infrastructure;

internal static class TemplateGenerationPushNotificationLocalizer
{
    public static string BuildTitle(string? locale, bool isFailed)
    {
        return NormalizeLanguage(locale) switch
        {
            "ru" => isFailed
                ? "PetMagic не смог создать результат"
                : "Ваш PetMagic результат готов",
            "de" => isFailed
                ? "PetMagic konnte kein Ergebnis erstellen"
                : "Ihr PetMagic-Ergebnis ist fertig",
            "pl" => isFailed
                ? "PetMagic nie mógł utworzyć wyniku"
                : "Twój wynik PetMagic jest gotowy",
            "it" => isFailed
                ? "PetMagic non è riuscito a creare il risultato"
                : "Il tuo risultato PetMagic è pronto",
            "fr" => isFailed
                ? "PetMagic n'a pas pu créer le résultat"
                : "Votre résultat PetMagic est prêt",
            "es" => isFailed
                ? "PetMagic no pudo crear el resultado"
                : "Tu resultado de PetMagic está listo",
            _ => isFailed
                ? "PetMagic could not create the result"
                : "Your PetMagic result is ready",
        };
    }

    public static string BuildBody(string? locale, bool isFailed)
    {
        return NormalizeLanguage(locale) switch
        {
            "ru" => isFailed
                ? "Мы сохранили статус генерации и вернули токены, если списание прошло."
                : "Откройте Галерею, чтобы посмотреть результат.",
            "de" => isFailed
                ? "Wir haben den Generierungsstatus gespeichert und Tokens zurückerstattet, falls sie abgebucht wurden."
                : "Öffnen Sie die Galerie, um das Ergebnis anzusehen.",
            "pl" => isFailed
                ? "Zapisaliśmy status generacji i zwróciliśmy tokeny, jeśli zostały pobrane."
                : "Otwórz Galerię, aby zobaczyć wynik.",
            "it" => isFailed
                ? "Abbiamo salvato lo stato della generazione e restituito i token, se erano stati addebitati."
                : "Apri la Galleria per vedere il risultato.",
            "fr" => isFailed
                ? "Nous avons enregistré le statut de génération et remboursé les tokens s'ils avaient été débités."
                : "Ouvrez la Galerie pour voir le résultat.",
            "es" => isFailed
                ? "Guardamos el estado de la generación y devolvimos los tokens si se habían descontado."
                : "Abre la Galería para ver el resultado.",
            _ => isFailed
                ? "We saved the generation status and refunded tokens if they were charged."
                : "Open Gallery to view the result.",
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
