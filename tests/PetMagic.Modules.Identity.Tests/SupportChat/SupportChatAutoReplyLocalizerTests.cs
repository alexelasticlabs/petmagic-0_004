using PetMagic.Modules.SupportChat.Infrastructure;

namespace PetMagic.Modules.Identity.Tests.SupportChat;

public sealed class SupportChatAutoReplyLocalizerTests
{
    [Theory]
    [InlineData("ru-RU", "Спасибо, мы получили ваше сообщение. Поддержка ответит в этом чате.")]
    [InlineData("de-DE", "Nachricht erhalten. Der Support antwortet in diesem Chat.")]
    [InlineData("pl-PL", "Wiadomość otrzymana. Wsparcie odpowie w tym czacie.")]
    [InlineData("it-IT", "Messaggio ricevuto. Il supporto risponderà in questa chat.")]
    [InlineData("fr-FR", "Message reçu. Le support répondra dans ce chat.")]
    [InlineData("es-ES", "Mensaje recibido. Soporte responderá en este chat.")]
    [InlineData(null, "Message received. Support will reply in this chat.")]
    public void BuildFirstReplyAcknowledgement_ShouldReturnLocalizedCopy(
        string? locale,
        string expected)
    {
        var result = SupportChatAutoReplyLocalizer.BuildFirstReplyAcknowledgement(locale);

        Assert.Equal(expected, result);
    }
}
