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
        Assert.Contains("\"economy.weekly_cooldown\" => StatusCodes.Status409Conflict", source);
        Assert.Contains("\"economy.redeem_code_expired\" => StatusCodes.Status409Conflict", source);
        Assert.Contains("\"economy.referral_code_not_found\" => StatusCodes.Status404NotFound", source);
        Assert.Contains("\"economy.push_token_invalid\" => StatusCodes.Status400BadRequest", source);
        Assert.Contains("\"economy.payment_gateway_failed\" => StatusCodes.Status503ServiceUnavailable", source);
        Assert.Contains("\"economy.premium_billing_unavailable\" => StatusCodes.Status503ServiceUnavailable", source);
        Assert.Contains("\"economy.payment_gateway_failed\"", source);
        Assert.Contains("\"Authentication failed.\"", source);
        Assert.Contains("\"Billing is temporarily unavailable.\"", source);
        Assert.Contains("private static ProblemHttpResult ToClientEconomyProblem(string errorCode)", source);
        Assert.Contains("return ToClientEconomyProblem(result.Error);", source);
        Assert.Contains("return ToClientEconomyProblem(packsResult.Error);", source);
        Assert.Contains("return ToClientEconomyProblem(\"economy.pack_not_found\");", source);
        Assert.Contains("detail: GetClientEconomyProblemDetail(errorCode)", source);
        Assert.DoesNotContain("Invalid access token subject.", source, StringComparison.Ordinal);
        Assert.DoesNotContain("detail: result.Error.Message", source);
        Assert.DoesNotContain("detail: error.Message", source);
        Assert.DoesNotContain("detail: subjectError.Message", source);
        Assert.DoesNotContain("var statusCode = string.Equals(result.Error.Code, InsufficientBalanceCode", source);
        Assert.DoesNotContain("return TypedResults.Problem(title: \"economy.pack_not_found\"", source);
        Assert.DoesNotContain(
            "var statusCode = string.Equals(result.Error.Code, \"economy.premium_billing_unavailable\", StringComparison.Ordinal)\r\n                ? StatusCodes.Status404NotFound",
            source,
            StringComparison.Ordinal);
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
