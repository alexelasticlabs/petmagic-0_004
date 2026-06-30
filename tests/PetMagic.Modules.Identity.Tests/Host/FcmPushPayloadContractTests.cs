namespace PetMagic.Modules.Identity.Tests.Host;

public sealed class FcmPushPayloadContractTests
{
    [Theory]
    [InlineData("src/Modules/Templates/PetMagic.Modules.Templates.Infrastructure/FcmTemplateGenerationPushNotificationSender.cs")]
    [InlineData("src/Modules/SupportChat/PetMagic.Modules.SupportChat.Infrastructure/FcmSupportChatPushNotificationSender.cs")]
    [InlineData("src/Modules/Economy/PetMagic.Modules.Economy.Infrastructure/FcmEconomyPushNotificationSender.cs")]
    public void FcmSenders_ShouldUseNonDeprecatedGoogleCredentialJsonFactory(string relativePath)
    {
        var source = File.ReadAllText(ResolveRepositoryPath(relativePath));

        Assert.Contains("GoogleCredential.FromJson(json)", source, StringComparison.Ordinal);
        Assert.DoesNotContain("FromJsonParameters(", source, StringComparison.Ordinal);
        Assert.DoesNotContain("#pragma warning disable CS0618", source, StringComparison.Ordinal);
    }

    [Theory]
    [InlineData("src/Modules/Templates/PetMagic.Modules.Templates.Infrastructure/FcmTemplateGenerationPushNotificationSender.cs", "$\"/generations/{generation.GenerationId}\"")]
    [InlineData("src/Modules/SupportChat/PetMagic.Modules.SupportChat.Infrastructure/FcmSupportChatPushNotificationSender.cs", "\"/profile/support\"")]
    [InlineData("src/Modules/Economy/PetMagic.Modules.Economy.Infrastructure/FcmEconomyPushNotificationSender.cs", "\"/profile")]
    public void FcmSenders_ShouldIncludeNotificationRoutingAndDedupePayload(
        string relativePath,
        string expectedRoute)
    {
        var source = File.ReadAllText(ResolveRepositoryPath(relativePath));

        Assert.Contains("[\"type\"]", source);
        Assert.Contains("[\"route\"]", source);
        Assert.Contains(expectedRoute, source);
        Assert.Contains("[\"dedupe_key\"]", source);
        Assert.Contains("new FcmAndroidConfig(\"high\", new FcmAndroidNotification(\"petmagic_updates\"))", source);
        Assert.Contains("[property: JsonPropertyName(\"channel_id\")]", source);
        Assert.Contains("new FcmApnsConfig(new FcmApnsPayload(new FcmAps(\"default\"", source);
    }

    private static string ResolveRepositoryPath(string relativePath)
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null)
        {
            var candidate = Path.Combine(directory.FullName, relativePath);
            if (File.Exists(candidate))
            {
                return candidate;
            }

            directory = directory.Parent;
        }

        throw new FileNotFoundException($"Could not resolve repository file '{relativePath}'.");
    }
}
