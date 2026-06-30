using PetMagic.Modules.Templates.Infrastructure;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class TemplateGenerationPushNotificationLocalizerTests
{
    [Theory]
    [InlineData("ru-RU", "Ваш PetMagic результат готов", "Откройте Галерею, чтобы посмотреть результат.")]
    [InlineData("de-DE", "Ihr PetMagic-Ergebnis ist fertig", "Öffnen Sie die Galerie, um das Ergebnis anzusehen.")]
    [InlineData("pl-PL", "Twój wynik PetMagic jest gotowy", "Otwórz Galerię, aby zobaczyć wynik.")]
    [InlineData("it-IT", "Il tuo risultato PetMagic è pronto", "Apri la Galleria per vedere il risultato.")]
    [InlineData("fr-FR", "Votre résultat PetMagic est prêt", "Ouvrez la Galerie pour voir le résultat.")]
    [InlineData("es-ES", "Tu resultado de PetMagic está listo", "Abre la Galería para ver el resultado.")]
    [InlineData(null, "Your PetMagic result is ready", "Open Gallery to view the result.")]
    public void SuccessCopy_ShouldBeLocalized(
        string? locale,
        string expectedTitle,
        string expectedBody)
    {
        Assert.Equal(expectedTitle, TemplateGenerationPushNotificationLocalizer.BuildTitle(locale, isFailed: false));
        Assert.Equal(expectedBody, TemplateGenerationPushNotificationLocalizer.BuildBody(locale, isFailed: false));
    }

    [Theory]
    [InlineData("ru-RU", "PetMagic не смог создать результат", "Мы сохранили статус генерации и вернули токены, если списание прошло.")]
    [InlineData("de-DE", "PetMagic konnte kein Ergebnis erstellen", "Wir haben den Generierungsstatus gespeichert und Tokens zurückerstattet, falls sie abgebucht wurden.")]
    [InlineData("pl-PL", "PetMagic nie mógł utworzyć wyniku", "Zapisaliśmy status generacji i zwróciliśmy tokeny, jeśli zostały pobrane.")]
    [InlineData("it-IT", "PetMagic non è riuscito a creare il risultato", "Abbiamo salvato lo stato della generazione e restituito i token, se erano stati addebitati.")]
    [InlineData("fr-FR", "PetMagic n'a pas pu créer le résultat", "Nous avons enregistré le statut de génération et remboursé les tokens s'ils avaient été débités.")]
    [InlineData("es-ES", "PetMagic no pudo crear el resultado", "Guardamos el estado de la generación y devolvimos los tokens si se habían descontado.")]
    [InlineData(null, "PetMagic could not create the result", "We saved the generation status and refunded tokens if they were charged.")]
    public void FailureCopy_ShouldBeLocalized(
        string? locale,
        string expectedTitle,
        string expectedBody)
    {
        Assert.Equal(expectedTitle, TemplateGenerationPushNotificationLocalizer.BuildTitle(locale, isFailed: true));
        Assert.Equal(expectedBody, TemplateGenerationPushNotificationLocalizer.BuildBody(locale, isFailed: true));
    }
}
