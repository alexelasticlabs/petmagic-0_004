using Microsoft.Extensions.Options;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Infrastructure;
using PetMagic.Modules.Economy.Infrastructure.Options;
using PetMagic.Modules.Economy.Infrastructure.Payments;

namespace PetMagic.Modules.Identity.Tests.Economy;

public sealed class StoreWebhookSecurityValidatorTests
{
    [Fact]
    public void ValidateAppStoreSignedPayload_ShouldFail_ForMalformedPayload()
    {
        var validator = CreateValidator();

        var result = validator.ValidateAppStoreSignedPayload("invalid-payload");

        Assert.True(result.IsFailure);
        Assert.Equal(EconomyErrors.InvalidStoreWebhookSignature.Code, result.Error.Code);
    }

    [Fact]
    public async Task ValidateGooglePlayPushAsync_ShouldFail_WhenAuthorizationHeaderMissing()
    {
        var validator = CreateValidator(audience: "https://petmagic.app/webhooks/google-play");

        var result = await validator.ValidateGooglePlayPushAsync(null, CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(EconomyErrors.InvalidStoreWebhookSignature.Code, result.Error.Code);
    }

    [Fact]
    public async Task ValidateGooglePlayPushAsync_ShouldFail_WhenExpectedEmailDoesNotMatch()
    {
        var validator = CreateValidator(
            audience: "https://petmagic.app/webhooks/google-play",
            expectedEmail: "pubsub@petmagic.app",
            googleTokenVerifier: new FakeGoogleStoreWebhookTokenVerifier(
                Result.Success(new GoogleStoreWebhookTokenPayload(
                    "https://accounts.google.com",
                    "wrong@petmagic.app",
                    true,
                    "subject-1"))));

        var result = await validator.ValidateGooglePlayPushAsync("Bearer token-1", CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(EconomyErrors.InvalidStoreWebhookSignature.Code, result.Error.Code);
    }

    [Fact]
    public async Task ValidateGooglePlayPushAsync_ShouldSucceed_WhenTokenMatchesAudienceAndEmail()
    {
        var validator = CreateValidator(
            audience: "https://petmagic.app/webhooks/google-play",
            expectedEmail: "pubsub@petmagic.app",
            googleTokenVerifier: new FakeGoogleStoreWebhookTokenVerifier(
                Result.Success(new GoogleStoreWebhookTokenPayload(
                    "https://accounts.google.com",
                    "pubsub@petmagic.app",
                    true,
                    "subject-1"))));

        var result = await validator.ValidateGooglePlayPushAsync("Bearer token-1", CancellationToken.None);

        Assert.True(result.IsSuccess);
    }

    private static StoreWebhookSecurityValidator CreateValidator(
        string audience = "",
        string expectedEmail = "",
        IGoogleStoreWebhookTokenVerifier? googleTokenVerifier = null)
    {
        return new StoreWebhookSecurityValidator(
            Options.Create(new EconomyOptions
            {
                AppStoreBundleId = "com.petmagic.app",
                GooglePlayPubSubAudience = audience,
                GooglePlayPubSubExpectedEmail = expectedEmail,
            }),
            googleTokenVerifier ?? new FakeGoogleStoreWebhookTokenVerifier(
                Result.Success(new GoogleStoreWebhookTokenPayload(
                    "https://accounts.google.com",
                    "pubsub@petmagic.app",
                    true,
                    "subject-1"))));
    }

    private sealed class FakeGoogleStoreWebhookTokenVerifier(Result<GoogleStoreWebhookTokenPayload> result)
        : IGoogleStoreWebhookTokenVerifier
    {
        public Task<Result<GoogleStoreWebhookTokenPayload>> ValidateAsync(string idToken, string audience, CancellationToken cancellationToken)
        {
            return Task.FromResult(result);
        }
    }
}