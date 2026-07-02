using Microsoft.AspNetCore.WebUtilities;

using PetMagic.Modules.SupportChat.Infrastructure;

namespace PetMagic.Modules.Identity.Tests.SupportChat;

public sealed class SupportAttachmentReadUrlSignerTests
{
    private static readonly SupportAttachmentStorageOptions StorageOptions = new()
    {
        PublicBaseUrl = "https://api.petmagic.app/support-media"
    };

    private static readonly SupportAttachmentReadUrlSigningOptions SigningOptions = new()
    {
        SigningKey = new string('s', 64),
        ReadUrlTtlMinutes = 30
    };

    [Fact]
    public void CreateReadUrl_ShouldAppendSignatureForManagedSupportAttachments()
    {
        var signer = CreateSigner();

        var signedUrl = signer.CreateReadUrl("https://api.petmagic.app/support-media/support-attachments/2026/06/test.png");
        var uri = new Uri(signedUrl);
        var query = QueryHelpers.ParseQuery(uri.Query);

        Assert.Equal("/support-media/support-attachments/2026/06/test.png", uri.AbsolutePath);
        Assert.True(query.ContainsKey("pmexp"));
        Assert.True(query.ContainsKey("pmsig"));
    }

    [Fact]
    public void CreateReadUrl_ShouldLeaveNonManagedUrlsUnchanged()
    {
        var signer = CreateSigner();
        const string externalUrl = "https://cdn.example.com/file.png";

        var signedUrl = signer.CreateReadUrl(externalUrl);

        Assert.Equal(externalUrl, signedUrl);
    }

    [Fact]
    public void CreateReadUrl_ShouldHideManagedUrl_WhenSigningKeyMissing()
    {
        var signer = new SupportAttachmentReadUrlSigner(
            StorageOptions,
            new SupportAttachmentReadUrlSigningOptions
            {
                SigningKey = string.Empty,
                ReadUrlTtlMinutes = SigningOptions.ReadUrlTtlMinutes
            });

        var signedUrl = signer.CreateReadUrl("https://api.petmagic.app/support-media/support-attachments/2026/06/test.png");

        Assert.Equal(string.Empty, signedUrl);
    }

    [Fact]
    public void CreateReadUrl_ShouldHideManagedUrl_WhenPublicBaseUrlDoesNotMatch()
    {
        var signer = new SupportAttachmentReadUrlSigner(
            new SupportAttachmentStorageOptions
            {
                PublicBaseUrl = "https://media.petmagic.app/support-media"
            },
            SigningOptions);

        var signedUrl = signer.CreateReadUrl("https://api.petmagic.app/support-media/support-attachments/2026/06/test.png");

        Assert.Equal(string.Empty, signedUrl);
    }

    [Fact]
    public void IsAuthorizedRequest_ShouldAcceptSignedManagedPath()
    {
        var signer = CreateSigner();
        var signedUrl = signer.CreateReadUrl("https://api.petmagic.app/support-media/support-attachments/2026/06/test.png");
        var uri = new Uri(signedUrl);
        var query = QueryHelpers.ParseQuery(uri.Query).ToDictionary(
            pair => pair.Key,
            pair => (string?)pair.Value.ToString(),
            StringComparer.OrdinalIgnoreCase);

        Assert.True(signer.IsAuthorizedRequest("/support-attachments/2026/06/test.png", query));
        Assert.True(signer.IsAuthorizedRequest(uri.AbsolutePath, query));
    }

    [Fact]
    public void IsAuthorizedRequest_ShouldRejectExpiredOrTamperedRequests()
    {
        var signer = CreateSigner();
        var signedUrl = signer.CreateReadUrl("https://api.petmagic.app/support-media/support-attachments/2026/06/test.png");
        var uri = new Uri(signedUrl);
        var query = QueryHelpers.ParseQuery(uri.Query);

        var expired = new Dictionary<string, string?>
        {
            ["pmexp"] = "1",
            ["pmsig"] = query["pmsig"].ToString(),
        };
        var tampered = new Dictionary<string, string?>
        {
            ["pmexp"] = query["pmexp"].ToString(),
            ["pmsig"] = "BAD",
        };

        Assert.False(signer.IsAuthorizedRequest(uri.AbsolutePath, expired));
        Assert.False(signer.IsAuthorizedRequest(uri.AbsolutePath, tampered));
    }

    private static SupportAttachmentReadUrlSigner CreateSigner() => new(StorageOptions, SigningOptions);
}
