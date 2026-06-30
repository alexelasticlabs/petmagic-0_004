namespace PetMagic.Modules.Economy.Infrastructure;

internal static class EconomyPushNotificationLocalizer
{
    public static string BuildWalletTitle(string? locale)
    {
        return NormalizeLanguage(locale) switch
        {
            "ru" => "Баланс PawSpark обновлен",
            "de" => "PawSpark-Guthaben aktualisiert",
            "pl" => "Saldo PawSpark zaktualizowano",
            "it" => "Saldo PawSpark aggiornato",
            "fr" => "Solde PawSpark mis à jour",
            "es" => "Saldo de PawSpark actualizado",
            _ => "PawSpark balance updated",
        };
    }

    public static string BuildWalletBody(string? locale, int? sparkDelta)
    {
        if (sparkDelta.HasValue && sparkDelta.Value > 0)
        {
            return NormalizeLanguage(locale) switch
            {
                "ru" => $"Начислено +{sparkDelta.Value} PawSpark.",
                "de" => $"+{sparkDelta.Value} PawSpark wurden gutgeschrieben.",
                "pl" => $"Dodano +{sparkDelta.Value} PawSpark.",
                "it" => $"Aggiunti +{sparkDelta.Value} PawSpark.",
                "fr" => $"+{sparkDelta.Value} PawSpark ont été ajoutés.",
                "es" => $"Se añadieron +{sparkDelta.Value} PawSpark.",
                _ => $"Added +{sparkDelta.Value} PawSpark.",
            };
        }

        return NormalizeLanguage(locale) switch
        {
            "ru" => "Проверьте последние операции в кошельке.",
            "de" => "Öffnen Sie Ihr Wallet, um die letzte Operation zu sehen.",
            "pl" => "Otwórz portfel, aby zobaczyć ostatnią operację.",
            "it" => "Apri il portafoglio per vedere l'ultima operazione.",
            "fr" => "Ouvrez le portefeuille pour voir votre dernière opération.",
            "es" => "Abre la billetera para ver tu última operación.",
            _ => "Open wallet to see your latest transaction.",
        };
    }

    public static string BuildPremiumTitle(string? locale)
    {
        return NormalizeLanguage(locale) switch
        {
            "ru" => "Статус Premium обновлен",
            "de" => "Premium-Status aktualisiert",
            "pl" => "Status Premium zaktualizowano",
            "it" => "Stato Premium aggiornato",
            "fr" => "Statut Premium mis à jour",
            "es" => "Estado Premium actualizado",
            _ => "Premium status updated",
        };
    }

    public static string BuildPremiumBody(string? locale, string status)
    {
        return status.ToLowerInvariant() switch
        {
            "active" => NormalizeLanguage(locale) switch
            {
                "ru" => "Premium активирован. Возможности обновлены.",
                "de" => "Premium ist aktiv. Ihr Zugang wurde aktualisiert.",
                "pl" => "Premium jest aktywny. Twój dostęp został zaktualizowany.",
                "it" => "Premium è attivo. Il tuo accesso è stato aggiornato.",
                "fr" => "Premium est actif. Votre accès a été mis à jour.",
                "es" => "Premium está activo. Tu acceso se ha actualizado.",
                _ => "Premium is active. Your access has been updated.",
            },
            "inactive" => NormalizeLanguage(locale) switch
            {
                "ru" => "Premium сейчас не активен. Проверить статус можно в профиле.",
                "de" => "Premium ist derzeit nicht aktiv. Den Status finden Sie im Profil.",
                "pl" => "Premium nie jest teraz aktywny. Status sprawdzisz w profilu.",
                "it" => "Premium non è attivo in questo momento. Puoi controllare lo stato nel profilo.",
                "fr" => "Premium n'est pas actif pour le moment. Vous pouvez vérifier son statut dans le profil.",
                "es" => "Premium no está activo en este momento. Puedes revisar el estado en el perfil.",
                _ => "Premium is not active right now. You can review status in Profile.",
            },
            "expired" => NormalizeLanguage(locale) switch
            {
                "ru" => "Срок Premium завершился.",
                "de" => "Das Premium-Abonnement ist abgelaufen.",
                "pl" => "Subskrypcja Premium wygasła.",
                "it" => "L'abbonamento Premium è scaduto.",
                "fr" => "L'abonnement Premium a expiré.",
                "es" => "La suscripción Premium ha expirado.",
                _ => "Premium subscription has expired.",
            },
            "failed" or "error" => NormalizeLanguage(locale) switch
            {
                "ru" => "Не удалось обновить Premium. Попробуйте снова.",
                "de" => "Premium konnte nicht aktualisiert werden. Bitte versuchen Sie es erneut.",
                "pl" => "Nie udało się zaktualizować Premium. Spróbuj ponownie.",
                "it" => "Aggiornamento Premium non riuscito. Riprova.",
                "fr" => "La mise à jour Premium a échoué. Veuillez réessayer.",
                "es" => "La actualización de Premium falló. Inténtalo de nuevo.",
                _ => "Premium update failed. Please try again.",
            },
            _ => NormalizeLanguage(locale) switch
            {
                "ru" => "Статус Premium обновлен.",
                "de" => "Der Premium-Status wurde aktualisiert.",
                "pl" => "Status Premium został zaktualizowany.",
                "it" => "Lo stato Premium è stato aggiornato.",
                "fr" => "Le statut Premium a été mis à jour.",
                "es" => "El estado Premium se ha actualizado.",
                _ => "Premium status has been updated.",
            }
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
