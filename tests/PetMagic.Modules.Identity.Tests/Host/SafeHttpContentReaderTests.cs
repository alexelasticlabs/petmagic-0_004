using System.Text;

using PetMagic.BuildingBlocks.Observability;

namespace PetMagic.Modules.Identity.Tests.Host;

public sealed class SafeHttpContentReaderTests
{
    [Fact]
    public async Task ReadStringPrefixAsync_ShouldLimitReturnedBody()
    {
        using var content = new StringContent(new string('x', 32), Encoding.UTF8, "application/json");

        var value = await SafeHttpContentReader.ReadStringPrefixAsync(content, CancellationToken.None, maxChars: 7);

        Assert.Equal("xxxxxxx", value);
    }

    [Fact]
    public async Task ReadStringPrefixAsync_ShouldReturnEmpty_WhenLimitIsZero()
    {
        using var content = new StringContent("sensitive-provider-body", Encoding.UTF8, "application/json");

        var value = await SafeHttpContentReader.ReadStringPrefixAsync(content, CancellationToken.None, maxChars: 0);

        Assert.Equal(string.Empty, value);
    }

    [Fact]
    public async Task ReadStringPrefixAsync_ShouldSanitizeProviderSecrets()
    {
        const string rawBody =
            """
            {"client_secret":"pi_secret_raw","purchaseToken":"store-token-raw","userId":"user-raw","downloadUrl":"https://cdn.example.test/file.jpg?sig=raw"}
            """;
        using var content = new StringContent(rawBody, Encoding.UTF8, "application/json");

        var value = await SafeHttpContentReader.ReadStringPrefixAsync(content, CancellationToken.None);

        Assert.DoesNotContain("pi_secret_raw", value, StringComparison.Ordinal);
        Assert.DoesNotContain("store-token-raw", value, StringComparison.Ordinal);
        Assert.DoesNotContain("user-raw", value, StringComparison.Ordinal);
        Assert.DoesNotContain("sig=raw", value, StringComparison.Ordinal);
        Assert.Contains("\"client_secret\":\"***\"", value, StringComparison.Ordinal);
        Assert.Contains("\"purchaseToken\":\"***\"", value, StringComparison.Ordinal);
        Assert.Contains("\"userId\":\"***\"", value, StringComparison.Ordinal);
        Assert.Contains("\"downloadUrl\":\"https://cdn.example.test/***\"", value, StringComparison.Ordinal);
    }

    [Fact]
    public async Task ReadRawStringPrefixAsync_ShouldPreserveProviderJsonForParsing()
    {
        const string rawBody =
            """
            {"access_token":"google-access-token","status_url":"https://queue.fal.test/status/fal-request-1"}
            """;
        using var content = new StringContent(rawBody, Encoding.UTF8, "application/json");

        var value = await SafeHttpContentReader.ReadRawStringPrefixAsync(content, CancellationToken.None);

        Assert.Contains("\"access_token\":\"google-access-token\"", value, StringComparison.Ordinal);
        Assert.Contains("\"status_url\":\"https://queue.fal.test/status/fal-request-1\"", value, StringComparison.Ordinal);
    }
}
