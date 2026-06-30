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

    private static AvatarReadUrlSigner CreateSigner() => new(StorageOptions, SigningOptions);
}
