using PetMagic.Modules.SupportChat.Infrastructure;

namespace PetMagic.Modules.Identity.Tests.SupportChat;

public sealed class SupportChatPushNotificationLocalizerTests
{
    [Theory]
    [InlineData("ru-RU", "Поддержка PetMagic ответила", "Новое вложение в диалоге поддержки.", "Новый ответ в диалоге поддержки.")]
    [InlineData("de-DE", "Der PetMagic-Support hat geantwortet", "Neuer Anhang in Ihrem Support-Dialog.", "Neue Antwort in Ihrem Support-Dialog.")]
    [InlineData("pl-PL", "Pomoc PetMagic odpowiedziała", "Nowy załącznik w Twojej rozmowie ze wsparciem.", "Nowa odpowiedź w Twojej rozmowie ze wsparciem.")]
    [InlineData("it-IT", "Il supporto PetMagic ha risposto", "Nuovo allegato nella tua conversazione con il supporto.", "Nuova risposta nella tua conversazione con il supporto.")]
    [InlineData("fr-FR", "Le support PetMagic a répondu", "Nouvelle pièce jointe dans votre conversation avec le support.", "Nouvelle réponse dans votre conversation avec le support.")]
    [InlineData("es-ES", "El soporte de PetMagic respondió", "Nuevo archivo adjunto en tu conversación con soporte.", "Nueva respuesta en tu conversación con soporte.")]
    [InlineData(null, "PetMagic Support replied", "New attachment in your support conversation.", "New reply in your support conversation.")]
    public void Localizer_ShouldReturnExpectedLocalizedPushCopy(
        string? locale,
        string expectedTitle,
        string expectedAttachmentBody,
        string expectedReplyBody)
    {
        Assert.Equal(expectedTitle, SupportChatPushNotificationLocalizer.BuildTitle(locale));
        Assert.Equal(
            expectedAttachmentBody,
            SupportChatPushNotificationLocalizer.BuildFallbackBody(locale, hasAttachment: true));
        Assert.Equal(
            expectedReplyBody,
            SupportChatPushNotificationLocalizer.BuildFallbackBody(locale, hasAttachment: false));
    }
}
