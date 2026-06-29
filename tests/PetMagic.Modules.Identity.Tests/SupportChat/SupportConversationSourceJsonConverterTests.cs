using System.Text.Json;

using PetMagic.Modules.SupportChat.Domain.Enums;

namespace PetMagic.Modules.Identity.Tests.SupportChat;

public sealed class SupportConversationSourceJsonConverterTests
{
    [Theory]
    [InlineData("\"MobileChat\"", SupportConversationSource.MobileChat)]
    [InlineData("\"MobileAssistant\"", SupportConversationSource.MobileAssistant)]
    public void Deserialize_ShouldAcceptCanonicalNames(
        string json,
        SupportConversationSource expected)
    {
        var result = JsonSerializer.Deserialize<SupportConversationSource>(json);

        Assert.Equal(expected, result);
    }

    [Fact]
    public void Deserialize_ShouldRejectLegacyAlias()
    {
        Assert.Throws<JsonException>(() =>
            JsonSerializer.Deserialize<SupportConversationSource>("\"Direct\""));
    }

    [Fact]
    public void Serialize_ShouldEmitCanonicalName()
    {
        var json = JsonSerializer.Serialize(SupportConversationSource.MobileChat);

        Assert.Equal("\"MobileChat\"", json);
    }
}
