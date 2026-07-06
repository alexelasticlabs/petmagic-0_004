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

    [Fact]
    public void PushNotificationContracts_ShouldNotAcceptCallerProvidedNotificationCopy()
    {
        var root = FindRepositoryRoot();
        var contractSource = File.ReadAllText(Path.Combine(
            root,
            "src",
            "Modules",
            "Economy",
            "PetMagic.Modules.Economy.Infrastructure",
            "IEconomyPushNotificationSender.cs"));
        var senderSource = File.ReadAllText(Path.Combine(
            root,
            "src",
            "Modules",
            "Economy",
            "PetMagic.Modules.Economy.Infrastructure",
            "FcmEconomyPushNotificationSender.cs"));

        var walletContract = SliceBetween(
            contractSource,
            "public sealed record WalletPushNotification(",
            ");",
            "WalletPushNotification");
        var premiumContract = SliceBetween(
            contractSource,
            "public sealed record PremiumPushNotification(",
            ");",
            "PremiumPushNotification");

        Assert.DoesNotContain("Title", walletContract, StringComparison.Ordinal);
        Assert.DoesNotContain("Body", walletContract, StringComparison.Ordinal);
        Assert.DoesNotContain("Title", premiumContract, StringComparison.Ordinal);
        Assert.DoesNotContain("Body", premiumContract, StringComparison.Ordinal);
        Assert.DoesNotContain("notification.Title", senderSource, StringComparison.Ordinal);
        Assert.DoesNotContain("notification.Body", senderSource, StringComparison.Ordinal);
        Assert.Contains("EconomyPushNotificationLocalizer.BuildWalletTitle(locale)", senderSource, StringComparison.Ordinal);
        Assert.Contains("EconomyPushNotificationLocalizer.BuildPremiumTitle(locale)", senderSource, StringComparison.Ordinal);
    }

    private static string SliceBetween(string source, string start, string end, string label)
    {
        var startIndex = source.IndexOf(start, StringComparison.Ordinal);
        Assert.True(startIndex >= 0, $"{label} start marker was not found.");

        var endIndex = source.IndexOf(end, startIndex, StringComparison.Ordinal);
        Assert.True(endIndex > startIndex, $"{label} end marker was not found.");

        return source[startIndex..endIndex];
    }

    private static string FindRepositoryRoot()
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null)
        {
            if (Directory.Exists(Path.Combine(directory.FullName, "src"))
                && Directory.Exists(Path.Combine(directory.FullName, "tests")))
            {
                return directory.FullName;
            }

            directory = directory.Parent;
        }

        throw new InvalidOperationException("Repository root could not be found.");
    }
}
