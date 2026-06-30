using PetMagic.Modules.Economy.Infrastructure;

namespace PetMagic.Modules.Identity.Tests.Economy;

public sealed class EconomyPushNotificationLocalizerTests
{
    [Theory]
    [InlineData("ru-RU", "Баланс PawSpark обновлен", "Начислено +40 PawSpark.", "Проверьте последние операции в кошельке.")]
    [InlineData("de-DE", "PawSpark-Guthaben aktualisiert", "+40 PawSpark wurden gutgeschrieben.", "Öffnen Sie Ihr Wallet, um die letzte Operation zu sehen.")]
    [InlineData("pl-PL", "Saldo PawSpark zaktualizowano", "Dodano +40 PawSpark.", "Otwórz portfel, aby zobaczyć ostatnią operację.")]
    [InlineData("it-IT", "Saldo PawSpark aggiornato", "Aggiunti +40 PawSpark.", "Apri il portafoglio per vedere l'ultima operazione.")]
    [InlineData("fr-FR", "Solde PawSpark mis à jour", "+40 PawSpark ont été ajoutés.", "Ouvrez le portefeuille pour voir votre dernière opération.")]
    [InlineData("es-ES", "Saldo de PawSpark actualizado", "Se añadieron +40 PawSpark.", "Abre la billetera para ver tu última operación.")]
    [InlineData(null, "PawSpark balance updated", "Added +40 PawSpark.", "Open wallet to see your latest transaction.")]
    public void WalletCopy_ShouldBeLocalized(
        string? locale,
        string expectedTitle,
        string expectedPositiveBody,
        string expectedNeutralBody)
    {
        Assert.Equal(expectedTitle, EconomyPushNotificationLocalizer.BuildWalletTitle(locale));
        Assert.Equal(expectedPositiveBody, EconomyPushNotificationLocalizer.BuildWalletBody(locale, 40));
        Assert.Equal(expectedNeutralBody, EconomyPushNotificationLocalizer.BuildWalletBody(locale, 0));
    }

    [Theory]
    [InlineData("ru-RU", "Статус Premium обновлен", "Premium активирован. Возможности обновлены.")]
    [InlineData("de-DE", "Premium-Status aktualisiert", "Premium ist aktiv. Ihr Zugang wurde aktualisiert.")]
    [InlineData("pl-PL", "Status Premium zaktualizowano", "Premium jest aktywny. Twój dostęp został zaktualizowany.")]
    [InlineData("it-IT", "Stato Premium aggiornato", "Premium è attivo. Il tuo accesso è stato aggiornato.")]
    [InlineData("fr-FR", "Statut Premium mis à jour", "Premium est actif. Votre accès a été mis à jour.")]
    [InlineData("es-ES", "Estado Premium actualizado", "Premium está activo. Tu acceso se ha actualizado.")]
    [InlineData(null, "Premium status updated", "Premium is active. Your access has been updated.")]
    public void PremiumCopy_ShouldBeLocalizedForActiveStatus(
        string? locale,
        string expectedTitle,
        string expectedBody)
    {
        Assert.Equal(expectedTitle, EconomyPushNotificationLocalizer.BuildPremiumTitle(locale));
        Assert.Equal(expectedBody, EconomyPushNotificationLocalizer.BuildPremiumBody(locale, "active"));
    }
}
