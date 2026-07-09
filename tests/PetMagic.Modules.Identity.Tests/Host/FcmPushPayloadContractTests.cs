namespace PetMagic.Modules.Identity.Tests.Host;

public sealed class FcmPushPayloadContractTests
{
    [Theory]
    [InlineData("src/Modules/Templates/PetMagic.Modules.Templates.Infrastructure/FcmTemplateGenerationPushNotificationSender.cs")]
    [InlineData("src/Modules/SupportChat/PetMagic.Modules.SupportChat.Infrastructure/FcmSupportChatPushNotificationSender.cs")]
    [InlineData("src/Modules/Economy/PetMagic.Modules.Economy.Infrastructure/FcmEconomyPushNotificationSender.cs")]
    public void FcmSenders_ShouldUseSharedErrorClassifier(string relativePath)
    {
        var source = File.ReadAllText(ResolveRepositoryPath(relativePath));

        Assert.Contains("FirebaseMessagingErrorClassifier.ResolveErrorReason(", source, StringComparison.Ordinal);
        Assert.Contains("FirebaseMessagingErrorClassifier.ShouldDisableToken(", source, StringComparison.Ordinal);
        Assert.Contains("SafeHttpContentReader.ReadStringPrefixAsync(response.Content, cancellationToken)", source, StringComparison.Ordinal);
        Assert.Contains("HttpCompletionOption.ResponseHeadersRead", source, StringComparison.Ordinal);
        Assert.DoesNotContain("ReadAsStringAsync(cancellationToken)", source, StringComparison.Ordinal);
        Assert.DoesNotContain("responseBody.Contains(\"INVALID_ARGUMENT\"", source, StringComparison.Ordinal);
        Assert.DoesNotContain("body.Contains(\"INVALID_ARGUMENT\"", source, StringComparison.Ordinal);
    }

    [Theory]
    [InlineData("src/Modules/Templates/PetMagic.Modules.Templates.Infrastructure/FcmTemplateGenerationPushNotificationSender.cs")]
    [InlineData("src/Modules/SupportChat/PetMagic.Modules.SupportChat.Infrastructure/FcmSupportChatPushNotificationSender.cs")]
    [InlineData("src/Modules/Economy/PetMagic.Modules.Economy.Infrastructure/FcmEconomyPushNotificationSender.cs")]
    public void FcmSenders_ShouldHashStableIdentifiersBeforeLogging(string relativePath)
    {
        var source = File.ReadAllText(ResolveRepositoryPath(relativePath));

        Assert.Contains("TokenIdHash={TokenIdHash}", source, StringComparison.Ordinal);
        Assert.Contains("SafeLogValues.StableHash(token.Id.ToString(\"D\"))", source, StringComparison.Ordinal);
        Assert.DoesNotContain("TokenId={TokenId}", source, StringComparison.Ordinal);
        Assert.Contains("CorrelationIdHash={CorrelationIdHash}", source, StringComparison.Ordinal);
        Assert.Contains("SafeLogValues.StableHash(CorrelationContext.ResolveOrCreate())", source, StringComparison.Ordinal);
        Assert.DoesNotContain("CorrelationId={CorrelationId}", source, StringComparison.Ordinal);

        if (relativePath.Contains("Economy", StringComparison.Ordinal))
        {
            return;
        }

        Assert.Contains("EventIdHash={EventIdHash}", source, StringComparison.Ordinal);
        Assert.Contains("SafeLogValues.StableHash(eventId)", source, StringComparison.Ordinal);
        Assert.DoesNotContain("EventId={EventId}", source, StringComparison.Ordinal);
        Assert.DoesNotContain("MessageName={MessageName}", source, StringComparison.Ordinal);
        Assert.DoesNotContain("MessageNameHash={MessageNameHash}", source, StringComparison.Ordinal);
        Assert.DoesNotContain("TryReadFcmMessageName", source, StringComparison.Ordinal);
    }

    [Theory]
    [InlineData("src/Modules/Templates/PetMagic.Modules.Templates.Infrastructure/FcmTemplateGenerationPushNotificationSender.cs")]
    [InlineData("src/Modules/SupportChat/PetMagic.Modules.SupportChat.Infrastructure/FcmSupportChatPushNotificationSender.cs")]
    [InlineData("src/Modules/Economy/PetMagic.Modules.Economy.Infrastructure/FcmEconomyPushNotificationSender.cs")]
    public void FcmSenders_ShouldReadProviderBodyOnlyOnFailure(string relativePath)
    {
        var source = File.ReadAllText(ResolveRepositoryPath(relativePath));
        var successCheckIndex = source.IndexOf("if (response.IsSuccessStatusCode)", StringComparison.Ordinal);
        var readBodyIndex = source.IndexOf(
            "SafeHttpContentReader.ReadStringPrefixAsync(response.Content, cancellationToken)",
            StringComparison.Ordinal);

        Assert.True(successCheckIndex >= 0, "Success status check was not found.");
        Assert.True(readBodyIndex > successCheckIndex, "FCM response body should be read only after the success fast-path returns.");
    }

    [Theory]
    [InlineData("src/Modules/Templates/PetMagic.Modules.Templates.Infrastructure/FcmTemplateGenerationPushNotificationSender.cs")]
    [InlineData("src/Modules/SupportChat/PetMagic.Modules.SupportChat.Infrastructure/FcmSupportChatPushNotificationSender.cs")]
    [InlineData("src/Modules/Economy/PetMagic.Modules.Economy.Infrastructure/FcmEconomyPushNotificationSender.cs")]
    public void FcmSenders_ShouldUseNonDeprecatedGoogleCredentialJsonFactory(string relativePath)
    {
        var source = File.ReadAllText(ResolveRepositoryPath(relativePath));

        Assert.Contains("CredentialFactory.FromJson(json, credentialType: null)", source, StringComparison.Ordinal);
        Assert.DoesNotContain("GoogleCredential.FromJson(", source, StringComparison.Ordinal);
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

    [Fact]
    public void EconomyFcmSender_ShouldNotExposeRawUserIdInDedupePayload()
    {
        var source = File.ReadAllText(ResolveRepositoryPath(
            "src/Modules/Economy/PetMagic.Modules.Economy.Infrastructure/FcmEconomyPushNotificationSender.cs"));

        Assert.Contains("var userIdHash = SafeLogValues.StableHash(userId.ToString(\"D\"));", source, StringComparison.Ordinal);
        Assert.Contains("wallet:{notification.Status}:{userIdHash}", source, StringComparison.Ordinal);
        Assert.Contains("premium:{notification.Status}:{notification.Provider ?? \"unknown\"}:{notification.PlanCode ?? \"unknown\"}:{userIdHash}", source, StringComparison.Ordinal);
        Assert.DoesNotContain(":{userId:D}", source, StringComparison.Ordinal);
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
