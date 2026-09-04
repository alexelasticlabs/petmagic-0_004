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
    [InlineData("ru-RU", "PetMagic не смог создать результат", "Откройте Галерею, чтобы посмотреть статус и дальнейшие действия.")]
    [InlineData("de-DE", "PetMagic konnte kein Ergebnis erstellen", "Öffnen Sie die Galerie, um den Status und die nächsten Schritte zu sehen.")]
    [InlineData("pl-PL", "PetMagic nie mógł utworzyć wyniku", "Otwórz Galerię, aby sprawdzić status i dalsze kroki.")]
    [InlineData("it-IT", "PetMagic non è riuscito a creare il risultato", "Apri la Galleria per vedere lo stato e i passaggi successivi.")]
    [InlineData("fr-FR", "PetMagic n'a pas pu créer le résultat", "Ouvrez la Galerie pour voir le statut et les prochaines étapes.")]
    [InlineData("es-ES", "PetMagic no pudo crear el resultado", "Abre la Galería para ver el estado y los pasos siguientes.")]
    [InlineData(null, "PetMagic could not create the result", "Open Gallery to view the status and next steps.")]
    public void FailureCopy_ShouldBeLocalized(
        string? locale,
        string expectedTitle,
        string expectedBody)
    {
        Assert.Equal(expectedTitle, TemplateGenerationPushNotificationLocalizer.BuildTitle(locale, isFailed: true));
        Assert.Equal(expectedBody, TemplateGenerationPushNotificationLocalizer.BuildBody(locale, isFailed: true));
    }

    [Theory]
    [InlineData("ru-RU", "image", "Ваша картинка готова", "Откройте Галерею, чтобы посмотреть картинку.")]
    [InlineData("ru-RU", "video", "Ваше видео готово", "Откройте Галерею, чтобы посмотреть видео.")]
    [InlineData("de-DE", "image", "Ihr Bild ist fertig", "Öffnen Sie die Galerie, um das Bild anzusehen.")]
    [InlineData("de-DE", "video", "Ihr Video ist fertig", "Öffnen Sie die Galerie, um das Video anzusehen.")]
    [InlineData("pl-PL", "image", "Twój obraz jest gotowy", "Otwórz Galerię, aby zobaczyć obraz.")]
    [InlineData("pl-PL", "video", "Twój film jest gotowy", "Otwórz Galerię, aby zobaczyć film.")]
    [InlineData("it-IT", "image", "La tua immagine è pronta", "Apri la Galleria per vedere l'immagine.")]
    [InlineData("it-IT", "video", "Il tuo video è pronto", "Apri la Galleria per vedere il video.")]
    [InlineData("fr-FR", "image", "Votre image est prête", "Ouvrez la Galerie pour voir l'image.")]
    [InlineData("fr-FR", "video", "Votre vidéo est prête", "Ouvrez la Galerie pour voir la vidéo.")]
    [InlineData("es-ES", "image", "Tu imagen está lista", "Abre la Galería para ver la imagen.")]
    [InlineData("es-ES", "video", "Tu vídeo está listo", "Abre la Galería para ver el vídeo.")]
    [InlineData(null, "image", "Your image is ready", "Open Gallery to view your image.")]
    [InlineData(null, "video", "Your video is ready", "Open Gallery to view your video.")]
    public void SuccessCopy_ShouldNameCompletedMedia(
        string? locale,
        string mediaType,
        string expectedTitle,
        string expectedBody)
    {
        Assert.Equal(
            expectedTitle,
            TemplateGenerationPushNotificationLocalizer.BuildTitle(
                locale,
                isFailed: false,
                mediaType: mediaType));
        Assert.Equal(
            expectedBody,
            TemplateGenerationPushNotificationLocalizer.BuildBody(
                locale,
                isFailed: false,
                mediaType: mediaType));
    }

    [Theory]
    [InlineData("ru-RU", "Готовы новые результаты PetMagic: 3", "Откройте Галерею, чтобы посмотреть все результаты.")]
    [InlineData("de-DE", "3 neue PetMagic-Ergebnisse sind fertig", "Öffnen Sie die Galerie, um alle Ergebnisse anzusehen.")]
    [InlineData("pl-PL", "Nowe wyniki PetMagic są gotowe: 3", "Otwórz Galerię, aby zobaczyć wszystkie wyniki.")]
    [InlineData("it-IT", "3 nuovi risultati PetMagic sono pronti", "Apri la Galleria per vedere tutti i risultati.")]
    [InlineData("fr-FR", "3 nouveaux résultats PetMagic sont prêts", "Ouvrez la Galerie pour voir tous les résultats.")]
    [InlineData("es-ES", "3 resultados nuevos de PetMagic están listos", "Abre la Galería para ver todos los resultados.")]
    [InlineData(null, "3 new PetMagic results are ready", "Open Gallery to view all results.")]
    public void MultipleUnreadResults_ShouldUseSelfContainedAggregateCopy(
        string? locale,
        string expectedTitle,
        string expectedBody)
    {
        Assert.Equal(
            expectedTitle,
            TemplateGenerationPushNotificationLocalizer.BuildTitle(
                locale,
                isFailed: false,
                mediaType: "video",
                unreadCompletedCount: 3));
        Assert.Equal(
            expectedBody,
            TemplateGenerationPushNotificationLocalizer.BuildBody(
                locale,
                isFailed: false,
                mediaType: "video",
                unreadCompletedCount: 3));
    }

    [Fact]
    public void FailureCopy_ShouldNotClaimThatRefundCompleted()
    {
        var body = TemplateGenerationPushNotificationLocalizer.BuildBody(
            "ru-RU",
            isFailed: true,
            mediaType: "video");

        Assert.DoesNotContain("вернул", body, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("refund", body, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void FailureCopy_ShouldTakePriorityOverUnreadCompletedAggregate()
    {
        Assert.Equal(
            "PetMagic не смог создать результат",
            TemplateGenerationPushNotificationLocalizer.BuildTitle(
                "ru-RU",
                isFailed: true,
                mediaType: "video",
                unreadCompletedCount: 3));
        Assert.Equal(
            "Откройте Галерею, чтобы посмотреть статус и дальнейшие действия.",
            TemplateGenerationPushNotificationLocalizer.BuildBody(
                "ru-RU",
                isFailed: true,
                mediaType: "video",
                unreadCompletedCount: 3));
    }
}
