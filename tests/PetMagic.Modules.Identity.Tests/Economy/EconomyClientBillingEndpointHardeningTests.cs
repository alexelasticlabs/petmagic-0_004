using System.IO;

namespace PetMagic.Modules.Identity.Tests.Economy;

public sealed class EconomyClientBillingEndpointHardeningTests
{
    [Fact]
    public void EconomyClientBillingEndpoints_ShouldUseSharedClientProblemMapping()
    {
        var source = ReadEconomyEndpointSource();

        Assert.Contains("private static ProblemHttpResult ToClientEconomyProblem(Error error)", source);
        Assert.Contains("\"economy.invalid_subject\" => StatusCodes.Status401Unauthorized", source);
        Assert.Contains("\"economy.invalid_amount\" => StatusCodes.Status400BadRequest", source);
        Assert.Contains("\"economy.weekly_cooldown\" => StatusCodes.Status409Conflict", source);
        Assert.Contains("\"economy.redeem_code_expired\" => StatusCodes.Status409Conflict", source);
        Assert.Contains("\"economy.redeem_code_reward_unsupported\" => StatusCodes.Status409Conflict", source);
        Assert.Contains("\"economy.referral_code_not_found\" => StatusCodes.Status404NotFound", source);
        Assert.Contains("\"economy.payment_method_ownership_conflict\" => StatusCodes.Status409Conflict", source);
        Assert.Contains("\"economy.subscription_ownership_conflict\" => StatusCodes.Status409Conflict", source);
        Assert.Contains("\"economy.push_token_invalid\" => StatusCodes.Status400BadRequest", source);
        Assert.Contains("\"economy.payment_gateway_failed\" => StatusCodes.Status503ServiceUnavailable", source);
        Assert.Contains("\"economy.premium_billing_unavailable\" => StatusCodes.Status503ServiceUnavailable", source);
        Assert.Contains("\"economy.payment_gateway_failed\"", source);
        Assert.Contains("private static ProblemHttpResult ToClientEconomyProblem(string errorCode)", source);
        Assert.Contains("return ToClientEconomyProblem(result.Error);", source);
        Assert.Contains("private static ProblemHttpResult ToPublicEconomyProblem(string errorCode)", source);
        Assert.Contains("return ToPublicEconomyProblem(result.Error.Code);", source);
        Assert.Contains("extensions: BuildClientEconomyProblemExtensions(errorCode)", source);
        Assert.Contains("return new Dictionary<string, object?> { [\"code\"] = errorCode };", source);
        Assert.DoesNotContain("GetClientEconomyProblemDetail", source, StringComparison.Ordinal);
        Assert.DoesNotContain("detail:", source, StringComparison.Ordinal);
        Assert.DoesNotContain("\"Authentication failed.\"", source, StringComparison.Ordinal);
        Assert.DoesNotContain("\"Billing product was not found.\"", source, StringComparison.Ordinal);
        Assert.DoesNotContain("\"Billing is temporarily unavailable.\"", source, StringComparison.Ordinal);
        Assert.DoesNotContain("Invalid access token subject.", source, StringComparison.Ordinal);
        Assert.DoesNotContain("Weekly reward is not available yet.", source, StringComparison.Ordinal);
        Assert.DoesNotContain("detail: result.Error.Message", source);
        Assert.DoesNotContain("detail: error.Message", source);
        Assert.DoesNotContain("detail: subjectError.Message", source);
        Assert.DoesNotContain("var statusCode = string.Equals(result.Error.Code, InsufficientBalanceCode", source);
        Assert.DoesNotContain("return TypedResults.Problem(title: \"economy.pack_not_found\"", source);
        Assert.DoesNotContain(
            "var statusCode = string.Equals(result.Error.Code, \"economy.premium_billing_unavailable\", StringComparison.Ordinal)\r\n                ? StatusCodes.Status404NotFound",
            source,
            StringComparison.Ordinal);
        Assert.DoesNotContain("/purchases/{orderId:guid}/confirm", source, StringComparison.Ordinal);
    }

    [Fact]
    public void EconomyErrors_ShouldUseProductionSafeClientFacingAvailabilityCopy()
    {
        var source = ReadEconomyInfrastructureSource("EconomyErrors.cs");

        Assert.Contains("Weekly reward is currently on cooldown.", source, StringComparison.Ordinal);
        Assert.DoesNotContain("Weekly reward is not available yet.", source, StringComparison.Ordinal);
    }

    [Fact]
    public void EconomyClientEndpoints_ShouldApplyPrivateCacheHeadersOnlyToAuthenticatedRoutes()
    {
        var source = ReadEconomyEndpointSource();

        Assert.Contains(".AddEndpointFilter(ApplyPrivateEconomyResponseHeadersAsync)", source, StringComparison.Ordinal);
        Assert.Contains("endpoint?.Metadata.GetMetadata<IAllowAnonymous>() is null", source, StringComparison.Ordinal);
        Assert.Contains("context.HttpContext.Response.Headers.CacheControl = \"no-store\";", source, StringComparison.Ordinal);
        Assert.Contains("context.HttpContext.Response.Headers.Pragma = \"no-cache\";", source, StringComparison.Ordinal);
        Assert.Contains("context.HttpContext.Response.Headers.XContentTypeOptions = \"nosniff\";", source, StringComparison.Ordinal);
        Assert.Contains("group.MapGet(\"/packs\", ListPacksAsync)", source, StringComparison.Ordinal);
        Assert.Contains("group.MapGet(\"/premium/plans\", ListPremiumPlansAsync)", source, StringComparison.Ordinal);
        Assert.Contains(".AllowAnonymous();", source, StringComparison.Ordinal);
    }

    [Fact]
    public void EconomyClientEndpoints_ShouldNotExposeDirectWalletSpendRoute()
    {
        var source = ReadEconomyEndpointSource();

        Assert.DoesNotContain("group.MapPost(\"/wallet/spend\", SpendAsync)", source, StringComparison.Ordinal);
        Assert.DoesNotContain("SpendRequest", source, StringComparison.Ordinal);
        Assert.DoesNotContain("IValidator<SpendBalanceCommand>", source, StringComparison.Ordinal);
    }

    private static string ReadEconomyEndpointSource()
    {
        var root = FindRepositoryRoot();
        var dir = Path.Combine(
            root,
            "src",
            "Modules",
            "Economy",
            "PetMagic.Modules.Economy.Api",
            "Endpoints");
        var files = Directory.GetFiles(dir, "EconomyEndpoints*.cs");
        return string.Join("\n", files.Select(File.ReadAllText));
    }

    private static string ReadEconomyInfrastructureSource(string fileName)
    {
        var root = FindRepositoryRoot();
        return File.ReadAllText(Path.Combine(
            root,
            "src",
            "Modules",
            "Economy",
            "PetMagic.Modules.Economy.Infrastructure",
            fileName));
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
