using System.Reflection;
using System.Text;

using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.Extensions.DependencyInjection;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Api.Endpoints;

namespace PetMagic.Modules.Identity.Tests.Economy;

public sealed class EconomyWebhookProblemSanitizationTests
{
    [Theory]
    [InlineData("economy.invalid_stripe_signature", StatusCodes.Status401Unauthorized)]
    [InlineData("economy.invalid_webhook_payload", StatusCodes.Status400BadRequest)]
    [InlineData("economy.store_verification_unavailable", StatusCodes.Status503ServiceUnavailable)]
    [InlineData("economy.premium_billing_unavailable", StatusCodes.Status400BadRequest)]
    public async Task ToWebhookProblem_ShouldReturnStableCodeWithoutUserFacingDetail(
        string errorCode,
        int statusCode)
    {
        var method = typeof(EconomyEndpoints).GetMethod(
            "ToWebhookProblem",
            BindingFlags.NonPublic | BindingFlags.Static);

        Assert.NotNull(method);

        const string rawDetail = "stage=premium.identity secret_token=abc123";
        var result = Assert.IsType<ProblemHttpResult>(
            method!.Invoke(null, [new Error(errorCode, rawDetail), statusCode]));

        var httpContext = new DefaultHttpContext();
        httpContext.Response.Body = new MemoryStream();
        httpContext.RequestServices = new ServiceCollection()
            .AddLogging()
            .AddProblemDetails()
            .BuildServiceProvider();

        await result.ExecuteAsync(httpContext);

        Assert.Equal(statusCode, httpContext.Response.StatusCode);

        httpContext.Response.Body.Position = 0;
        var body = await new StreamReader(httpContext.Response.Body, Encoding.UTF8)
            .ReadToEndAsync();

        Assert.Contains(errorCode, body, StringComparison.Ordinal);
        Assert.Contains("\"code\"", body, StringComparison.Ordinal);
        Assert.DoesNotContain("\"detail\"", body, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain(rawDetail, body, StringComparison.Ordinal);
        Assert.DoesNotContain("secret_token", body, StringComparison.Ordinal);
        Assert.DoesNotContain("Webhook signature validation failed.", body, StringComparison.Ordinal);
        Assert.DoesNotContain("Webhook payload is invalid.", body, StringComparison.Ordinal);
        Assert.DoesNotContain("Webhook verification is temporarily unavailable.", body, StringComparison.Ordinal);
        Assert.DoesNotContain("Webhook request could not be processed.", body, StringComparison.Ordinal);
    }
}
