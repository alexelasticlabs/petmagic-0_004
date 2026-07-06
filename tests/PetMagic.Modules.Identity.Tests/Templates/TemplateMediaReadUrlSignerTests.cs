using Microsoft.AspNetCore.WebUtilities;

using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class TemplateMediaReadUrlSignerTests
{
    private static readonly TemplatesOptions Options = new()
    {
        PublicBaseUrl = "https://api.petmagic.app/media",
        LocalMediaRootPath = "unused",
        DefaultImagePrompt = "Create a themed pet portrait.",
        DefaultPreprocessingPrompt = "Keep the same pet.",
        DefaultKlingPrompt = "Funny dance.",
        AllowedImageModels = ["openai/gpt-image-2/edit"],
        AllowedPreprocessingModels = ["openai/gpt-image-2/edit"],
        AllowedKlingModels = ["fal-ai/kling-video/v3/pro/motion-control"],
        SupportedLocalizationLocales = ["ru", "de", "es", "fr", "it", "pl"],
        SeedSampleTemplates = false
    };

    private static readonly TemplateMediaReadUrlSigningOptions SigningOptions = new()
    {
        SigningKey = new string('s', 64)
    };

    [Fact]
    public void CreateReadUrl_ShouldAppendSignatureForManagedTemplatesMedia()
    {
        var signer = CreateSigner();

        var signedUrl = signer.CreateReadUrl(
            "https://api.petmagic.app/media/templates-media/2026/06/result.png",
            TimeSpan.FromMinutes(5));
        var uri = new Uri(signedUrl);
        var query = QueryHelpers.ParseQuery(uri.Query);

        Assert.Equal("/media/templates-media/2026/06/result.png", uri.AbsolutePath);
        Assert.True(query.ContainsKey("pmexp"));
        Assert.True(query.ContainsKey("pmsig"));
    }

    [Fact]
    public void CreateReadUrl_ShouldStripLegacyQueryAndFragment()
    {
        var signer = CreateSigner();

        var signedUrl = signer.CreateReadUrl(
            "https://api.petmagic.app/media/templates-media/2026/06/result.png?token=raw&signature=legacy#viewer",
            TimeSpan.FromMinutes(5));
        var uri = new Uri(signedUrl);
        var query = QueryHelpers.ParseQuery(uri.Query);

        Assert.Equal("/media/templates-media/2026/06/result.png", uri.AbsolutePath);
        Assert.True(query.ContainsKey("pmexp"));
        Assert.True(query.ContainsKey("pmsig"));
        Assert.False(query.ContainsKey("token"));
        Assert.False(query.ContainsKey("signature"));
        Assert.Equal(string.Empty, uri.Fragment);
    }

    [Fact]
    public void IsAuthorizedRequest_ShouldAcceptSignedManagedPath()
    {
        var signer = CreateSigner();
        var signedUrl = signer.CreateReadUrl(
            "https://api.petmagic.app/media/templates-media/2026/06/result.png",
            TimeSpan.FromMinutes(5));
        var uri = new Uri(signedUrl);
        var query = QueryHelpers.ParseQuery(uri.Query).ToDictionary(
            pair => pair.Key,
            pair => (string?)pair.Value.ToString(),
            StringComparer.OrdinalIgnoreCase);

        Assert.True(signer.IsAuthorizedRequest("/templates-media/2026/06/result.png", query));
        Assert.True(signer.IsAuthorizedRequest(uri.AbsolutePath, query));
    }

    [Theory]
    [InlineData("https://api.petmagic.app/media/templates-media/2026/../private.png")]
    [InlineData("https://api.petmagic.app/media/templates-media/2026/%2e%2e/private.png")]
    [InlineData("https://api.petmagic.app/media/templates-media/2026%2f..%2fprivate.png")]
    [InlineData("https://api.petmagic.app/media/templates-media/2026%5c..%5cprivate.png")]
    [InlineData("https://api.petmagic.app/media/templates-media/2026/%zz/private.png")]
    [InlineData("https://tracker.example.com/templates-media/2026/06/result.png")]
    public void CreateReadUrl_ShouldRejectUnsafeOrExternalUrls(string mediaUrl)
    {
        var signer = CreateSigner();

        var signedUrl = signer.CreateReadUrl(mediaUrl, TimeSpan.FromMinutes(5));

        Assert.Equal(string.Empty, signedUrl);
    }

    [Theory]
    [InlineData("/templates-media/2026%2f..%2fprivate.png")]
    [InlineData("/templates-media/2026%5c..%5cprivate.png")]
    [InlineData("/templates-media/2026/%zz/private.png")]
    public void IsAuthorizedRequest_ShouldRejectEncodedPathSeparators(string requestPath)
    {
        var signer = CreateSigner();
        var signedUrl = signer.CreateReadUrl(
            "https://api.petmagic.app/media/templates-media/2026/06/result.png",
            TimeSpan.FromMinutes(5));
        var uri = new Uri(signedUrl);
        var query = QueryHelpers.ParseQuery(uri.Query).ToDictionary(
            pair => pair.Key,
            pair => (string?)pair.Value.ToString(),
            StringComparer.OrdinalIgnoreCase);

        Assert.False(signer.IsAuthorizedRequest(requestPath, query));
    }

    private static TemplateMediaReadUrlSigner CreateSigner() => new(Options, SigningOptions);
}
