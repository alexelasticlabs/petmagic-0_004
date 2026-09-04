namespace PetMagic.Modules.Templates.Infrastructure;

internal static class TemplateGenerationPushNotificationLocalizer
{
    public static string BuildTitle(
        string? locale,
        bool isFailed,
        string? mediaType = null,
        int unreadCompletedCount = 1)
    {
        var language = NormalizeLanguage(locale);
        if (isFailed)
        {
            return language switch
            {
                "ru" => "PetMagic не смог создать результат",
                "de" => "PetMagic konnte kein Ergebnis erstellen",
                "pl" => "PetMagic nie mógł utworzyć wyniku",
                "it" => "PetMagic non è riuscito a creare il risultato",
                "fr" => "PetMagic n'a pas pu créer le résultat",
                "es" => "PetMagic no pudo crear el resultado",
                _ => "PetMagic could not create the result",
            };
        }

        if (unreadCompletedCount > 1)
        {
            return BuildAggregateTitle(language, unreadCompletedCount);
        }

        return (language, NormalizeMediaType(mediaType)) switch
        {
            ("ru", "image") => "Ваша картинка готова",
            ("ru", "video") => "Ваше видео готово",
            ("de", "image") => "Ihr Bild ist fertig",
            ("de", "video") => "Ihr Video ist fertig",
            ("pl", "image") => "Twój obraz jest gotowy",
            ("pl", "video") => "Twój film jest gotowy",
            ("it", "image") => "La tua immagine è pronta",
            ("it", "video") => "Il tuo video è pronto",
            ("fr", "image") => "Votre image est prête",
            ("fr", "video") => "Votre vidéo est prête",
            ("es", "image") => "Tu imagen está lista",
            ("es", "video") => "Tu vídeo está listo",
            (_, "image") => "Your image is ready",
            (_, "video") => "Your video is ready",
            ("ru", _) => "Ваш PetMagic результат готов",
            ("de", _) => "Ihr PetMagic-Ergebnis ist fertig",
            ("pl", _) => "Twój wynik PetMagic jest gotowy",
            ("it", _) => "Il tuo risultato PetMagic è pronto",
            ("fr", _) => "Votre résultat PetMagic est prêt",
            ("es", _) => "Tu resultado de PetMagic está listo",
            _ => "Your PetMagic result is ready",
        };
    }

    public static string BuildBody(
        string? locale,
        bool isFailed,
        string? mediaType = null,
        int unreadCompletedCount = 1)
    {
        var language = NormalizeLanguage(locale);
        if (isFailed)
        {
            return language switch
            {
                "ru" => "Откройте Галерею, чтобы посмотреть статус и дальнейшие действия.",
                "de" => "Öffnen Sie die Galerie, um den Status und die nächsten Schritte zu sehen.",
                "pl" => "Otwórz Galerię, aby sprawdzić status i dalsze kroki.",
                "it" => "Apri la Galleria per vedere lo stato e i passaggi successivi.",
                "fr" => "Ouvrez la Galerie pour voir le statut et les prochaines étapes.",
                "es" => "Abre la Galería para ver el estado y los pasos siguientes.",
                _ => "Open Gallery to view the status and next steps.",
            };
        }

        if (unreadCompletedCount > 1)
        {
            return BuildAggregateBody(language);
        }

        return (language, NormalizeMediaType(mediaType)) switch
        {
            ("ru", "image") => "Откройте Галерею, чтобы посмотреть картинку.",
            ("ru", "video") => "Откройте Галерею, чтобы посмотреть видео.",
            ("de", "image") => "Öffnen Sie die Galerie, um das Bild anzusehen.",
            ("de", "video") => "Öffnen Sie die Galerie, um das Video anzusehen.",
            ("pl", "image") => "Otwórz Galerię, aby zobaczyć obraz.",
            ("pl", "video") => "Otwórz Galerię, aby zobaczyć film.",
            ("it", "image") => "Apri la Galleria per vedere l'immagine.",
            ("it", "video") => "Apri la Galleria per vedere il video.",
            ("fr", "image") => "Ouvrez la Galerie pour voir l'image.",
            ("fr", "video") => "Ouvrez la Galerie pour voir la vidéo.",
            ("es", "image") => "Abre la Galería para ver la imagen.",
            ("es", "video") => "Abre la Galería para ver el vídeo.",
            (_, "image") => "Open Gallery to view your image.",
            (_, "video") => "Open Gallery to view your video.",
            ("ru", _) => "Откройте Галерею, чтобы посмотреть результат.",
            ("de", _) => "Öffnen Sie die Galerie, um das Ergebnis anzusehen.",
            ("pl", _) => "Otwórz Galerię, aby zobaczyć wynik.",
            ("it", _) => "Apri la Galleria per vedere il risultato.",
            ("fr", _) => "Ouvrez la Galerie pour voir le résultat.",
            ("es", _) => "Abre la Galería para ver el resultado.",
            _ => "Open Gallery to view the result.",
        };
    }

    private static string BuildAggregateTitle(string language, int unreadCompletedCount)
    {
        return language switch
        {
            "ru" => $"Готовы новые результаты PetMagic: {unreadCompletedCount}",
            "de" => $"{unreadCompletedCount} neue PetMagic-Ergebnisse sind fertig",
            "pl" => $"Nowe wyniki PetMagic są gotowe: {unreadCompletedCount}",
            "it" => $"{unreadCompletedCount} nuovi risultati PetMagic sono pronti",
            "fr" => $"{unreadCompletedCount} nouveaux résultats PetMagic sont prêts",
            "es" => $"{unreadCompletedCount} resultados nuevos de PetMagic están listos",
            _ => $"{unreadCompletedCount} new PetMagic results are ready",
        };
    }

    private static string BuildAggregateBody(string language)
    {
        return language switch
        {
            "ru" => "Откройте Галерею, чтобы посмотреть все результаты.",
            "de" => "Öffnen Sie die Galerie, um alle Ergebnisse anzusehen.",
            "pl" => "Otwórz Galerię, aby zobaczyć wszystkie wyniki.",
            "it" => "Apri la Galleria per vedere tutti i risultati.",
            "fr" => "Ouvrez la Galerie pour voir tous les résultats.",
            "es" => "Abre la Galería para ver todos los resultados.",
            _ => "Open Gallery to view all results.",
        };
    }

    private static string? NormalizeMediaType(string? mediaType)
    {
        var normalized = mediaType?.Trim().ToLowerInvariant();
        return normalized is "image" or "video" ? normalized : null;
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
