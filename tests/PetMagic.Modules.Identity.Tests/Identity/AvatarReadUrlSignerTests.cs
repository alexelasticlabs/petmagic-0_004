using Microsoft.AspNetCore.WebUtilities;

using PetMagic.Modules.Identity.Infrastructure;
using PetMagic.Modules.Identity.Infrastructure.Options;

namespace PetMagic.Modules.Identity.Tests.Identity;

public sealed class AvatarReadUrlSignerTests
{
    private static readonly AvatarStorageOptions StorageOptions = new()
    {
        PublicBaseUrl = "https://api.petmagic.app/media"
    };

    private static readonly AvatarReadUrlSigningOptions SigningOptions = new()
    {
        SigningKey = new string('s', 64),
        ReadUrlTtlMinutes = 30
    };

    [Fact]
    public void CreateReadUrl_ShouldAppendSignatureForManagedAvatars()
    {
        var signer = CreateSigner();

        var signedUrl = signer.CreateReadUrl("https://api.petmagic.app/media/user-avatars/2026/06/test.jpg");
        var uri = new Uri(signedUrl);
        var query = QueryHelpers.ParseQuery(uri.Query);

        Assert.Equal("/media/user-avatars/2026/06/test.jpg", uri.AbsolutePath);
        Assert.True(query.ContainsKey("pmexp"));
        Assert.True(query.ContainsKey("pmsig"));
    }

    [Fact]
    public void CreateReadUrl_ShouldStripLegacyQueryAndFragmentFromManagedAvatars()
    {
        var signer = CreateSigner();

        var signedUrl = signer.CreateReadUrl(
            "https://api.petmagic.app/media/user-avatars/2026/06/test.jpg?token=raw&signature=legacy#profile");
        var uri = new Uri(signedUrl);
        var query = QueryHelpers.ParseQuery(uri.Query);

        Assert.Equal("/media/user-avatars/2026/06/test.jpg", uri.AbsolutePath);
        Assert.True(query.ContainsKey("pmexp"));
        Assert.True(query.ContainsKey("pmsig"));
        Assert.False(query.ContainsKey("token"));
        Assert.False(query.ContainsKey("signature"));
        Assert.Equal(string.Empty, uri.Fragment);
    }

    [Fact]
    public void IsAuthorizedRequest_ShouldAcceptCanonicalAvatarPath_WhenProxyPrefixIsStripped()
    {
        var signer = CreateSigner();
        var signedUrl = signer.CreateReadUrl("https://api.petmagic.app/media/user-avatars/2026/06/test.jpg");
        var uri = new Uri(signedUrl);
        var query = QueryHelpers.ParseQuery(uri.Query).ToDictionary(
            pair => pair.Key,
            pair => (string?)pair.Value.ToString(),
            StringComparer.OrdinalIgnoreCase);

        Assert.True(signer.IsAuthorizedRequest("/user-avatars/2026/06/test.jpg", query));
        Assert.True(signer.IsAuthorizedRequest("/media/user-avatars/2026/06/test.jpg", query));
    }

    [Fact]
    public void CreateReadUrl_ShouldHideManagedAvatarUrl_WhenSigningKeyMissing()
    {
        var signer = new AvatarReadUrlSigner(
            StorageOptions,
            new AvatarReadUrlSigningOptions
            {
                SigningKey = string.Empty,
                ReadUrlTtlMinutes = SigningOptions.ReadUrlTtlMinutes
            });

        var signedUrl = signer.CreateReadUrl("https://api.petmagic.app/media/user-avatars/2026/06/test.jpg");

        Assert.Equal(string.Empty, signedUrl);
    }

    [Fact]
    public void CreateReadUrl_ShouldHideManagedAvatarUrl_WhenPublicBaseUrlDoesNotMatch()
    {
        var signer = new AvatarReadUrlSigner(
            new AvatarStorageOptions
            {
                PublicBaseUrl = "https://media.petmagic.app/media"
            },
            SigningOptions);

        var signedUrl = signer.CreateReadUrl("https://api.petmagic.app/media/user-avatars/2026/06/test.jpg");

        Assert.Equal(string.Empty, signedUrl);
    }

    [Theory]
    [InlineData("https://api.petmagic.app/media/user-avatars/2026/../private.jpg")]
    [InlineData("https://api.petmagic.app/media/user-avatars/2026/%2e%2e/private.jpg")]
    [InlineData("https://api.petmagic.app/media/user-avatars/2026%2f..%2fprivate.jpg")]
    [InlineData("https://api.petmagic.app/media/user-avatars/2026%5c..%5cprivate.jpg")]
    [InlineData("https://api.petmagic.app/media/user-avatars/2026/%zz/private.jpg")]
    public void CreateReadUrl_ShouldHideTraversalLikeManagedAvatarUrl(string fileUrl)
    {
        var signer = CreateSigner();

        var signedUrl = signer.CreateReadUrl(fileUrl);

        Assert.Equal(string.Empty, signedUrl);
    }

    [Fact]
    public void IsAuthorizedRequest_ShouldRejectExpiredOrTamperedAvatarUrls()
    {
        var signer = CreateSigner();
        var signedUrl = signer.CreateReadUrl("https://api.petmagic.app/media/user-avatars/2026/06/test.jpg");
        var uri = new Uri(signedUrl);
        var query = QueryHelpers.ParseQuery(uri.Query);

        var expired = new Dictionary<string, string?>
        {
            ["pmexp"] = "1",
            ["pmsig"] = query["pmsig"].ToString()
        };
        var tampered = new Dictionary<string, string?>
        {
            ["pmexp"] = query["pmexp"].ToString(),
            ["pmsig"] = "BAD"
        };

        Assert.False(signer.IsAuthorizedRequest("/user-avatars/2026/06/test.jpg", expired));
        Assert.False(signer.IsAuthorizedRequest("/user-avatars/2026/06/test.jpg", tampered));
    }

    [Fact]
    public void IsAuthorizedRequest_ShouldRejectManagedSegmentOutsideConfiguredBasePath()
    {
        var signer = CreateSigner();
        var signedUrl = signer.CreateReadUrl("https://api.petmagic.app/media/user-avatars/2026/06/test.jpg");
        var uri = new Uri(signedUrl);
        var query = QueryHelpers.ParseQuery(uri.Query).ToDictionary(
            pair => pair.Key,
            pair => (string?)pair.Value.ToString(),
            StringComparer.OrdinalIgnoreCase);

        Assert.False(signer.IsAuthorizedRequest("/other/user-avatars/2026/06/test.jpg", query));
    }

    [Theory]
    [InlineData("/user-avatars/2026/../private.jpg")]
    [InlineData("/media/user-avatars/2026/%2e%2e/private.jpg")]
    [InlineData("/user-avatars/2026%2f..%2fprivate.jpg")]
    [InlineData("/user-avatars/2026%5c..%5cprivate.jpg")]
    [InlineData("/user-avatars/2026/%zz/private.jpg")]
    public void IsAuthorizedRequest_ShouldRejectTraversalLikeManagedAvatarPath(string requestPath)
    {
        var signer = CreateSigner();
        var signedUrl = signer.CreateReadUrl("https://api.petmagic.app/media/user-avatars/2026/06/test.jpg");
        var uri = new Uri(signedUrl);
        var query = QueryHelpers.ParseQuery(uri.Query).ToDictionary(
            pair => pair.Key,
            pair => (string?)pair.Value.ToString(),
            StringComparer.OrdinalIgnoreCase);

        Assert.False(signer.IsAuthorizedRequest(requestPath, query));
    }

    private static AvatarReadUrlSigner CreateSigner() => new(StorageOptions, SigningOptions);
}
