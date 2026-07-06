using System.IO;

namespace PetMagic.Modules.Identity.Tests.Economy;

public sealed class EconomyPublicBillingEndpointHardeningTests
{
    [Fact]
    public void PublicBillingEndpoints_ShouldHandleServiceFailuresBeforeReadingResultValue()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Economy",
            "PetMagic.Modules.Economy.Api",
            "Endpoints",
            "EconomyEndpoints.Wallet.cs"));

        Assert.Contains("private static async Task<Results<Ok<IReadOnlyList<CurrencyPackResponse>>, ProblemHttpResult>> ListPacksAsync(", source);
        Assert.Contains("private static async Task<Results<Ok<WalletCheckoutConfigResponse>, ProblemHttpResult>> GetWalletCheckoutConfigAsync(", source);
        Assert.Contains("private static async Task<Results<Ok<IReadOnlyList<PremiumPlanResponse>>, ProblemHttpResult>> ListPremiumPlansAsync(", source);
        Assert.Contains("private static async Task<Results<Ok<PaywallConfigResponse>, ProblemHttpResult>> GetPaywallConfigAsync(", source);
        Assert.Contains("private static async Task<Results<Ok<BillingProductsResponse>, ProblemHttpResult>> GetBillingProductsAsync(", source);
        Assert.Contains("if (result.IsFailure)", source);
        Assert.Contains("return ToPublicEconomyProblem(result.Error.Code);", source);
        Assert.Contains("private static ProblemHttpResult ToPublicEconomyProblem(string errorCode)", source);
    }

    private static string FindRepositoryRoot()
    {
        var current = new DirectoryInfo(AppContext.BaseDirectory);

        while (current is not null)
        {
            if (File.Exists(Path.Combine(current.FullName, ".gitignore")))
            {
                return current.FullName;
            }

            current = current.Parent;
        }

        throw new InvalidOperationException("Could not locate repository root.");
    }
}
