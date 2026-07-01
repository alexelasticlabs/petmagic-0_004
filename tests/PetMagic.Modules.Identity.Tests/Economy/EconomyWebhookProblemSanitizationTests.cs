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
    [InlineData("economy.invalid_stripe_signature", StatusCodes.Status401Unauthorized, "Webhook signature validation failed.")]
    [InlineData("economy.invalid_webhook_payload", StatusCodes.Status400BadRequest, "Webhook payload is invalid.")]
    [InlineData("economy.store_verification_unavailable", StatusCodes.Status503ServiceUnavailable, "Webhook verification is temporarily unavailable.")]
    [InlineData("economy.premium_billing_unavailable", StatusCodes.Status400BadRequest, "Webhook request could not be processed.")]
    public async Task ToWebhookProblem_ShouldHideInternalErrorDetails(
        string errorCode,
        int statusCode,
        string expectedDetail)
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

        Assert.Contains(expectedDetail, body, StringComparison.Ordinal);
        Assert.DoesNotContain(rawDetail, body, StringComparison.Ordinal);
        Assert.DoesNotContain("secret_token", body, StringComparison.Ordinal);
    }
}
