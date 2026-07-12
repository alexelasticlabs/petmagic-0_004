using Microsoft.Extensions.Configuration;

using PetMagic.Modules.Identity.Api.Endpoints;

namespace PetMagic.Modules.Identity.Tests.Identity;

public sealed class ExternalAuthMobileRedirectSchemeTests
{
    [Fact]
    public void TryNormalizeMobileRedirectUri_ShouldAcceptOnlyConfiguredStagingFlavor()
    {
        var configuration = CreateConfiguration("petmagic-staging");

        var accepted = AuthEndpoints.TryNormalizeMobileRedirectUri(
            "petmagic-staging://auth/external",
            configuration,
            out var normalized);
        var productionAccepted = AuthEndpoints.TryNormalizeMobileRedirectUri(
            "petmagic://auth/external",
            configuration,
            out _);

        Assert.True(accepted);
        Assert.Equal("petmagic-staging://auth/external", normalized);
        Assert.False(productionAccepted);
    }

    [Fact]
    public void TryNormalizeMobileRedirectUri_ShouldDefaultToProductionSchemeForLocalBackcompat()
    {
        var configuration = new ConfigurationBuilder().Build();

        Assert.True(AuthEndpoints.TryNormalizeMobileRedirectUri(
            "petmagic://auth/external",
            configuration,
            out var normalized));
        Assert.Equal("petmagic://auth/external", normalized);
        Assert.False(AuthEndpoints.TryNormalizeMobileRedirectUri(
            "petmagic-staging://auth/external",
            configuration,
            out _));
    }

    [Theory]
    [InlineData("petmagic://auth/external?next=https://attacker.example")]
    [InlineData("petmagic://auth:444/external")]
    [InlineData("petmagic://user@auth/external")]
    [InlineData("petmagic://auth/external#fragment")]
    public void TryNormalizeMobileRedirectUri_ShouldRejectNonCanonicalTargets(string redirectUri)
    {
        Assert.False(AuthEndpoints.TryNormalizeMobileRedirectUri(
            redirectUri,
            CreateConfiguration("petmagic"),
            out _));
    }

    private static IConfiguration CreateConfiguration(string scheme)
    {
        return new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                [AuthEndpoints.MobileRedirectSchemeConfigurationKey] = scheme
            })
            .Build();
    }
}
