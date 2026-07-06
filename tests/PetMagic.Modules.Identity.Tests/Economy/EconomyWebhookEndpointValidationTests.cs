using System.Reflection;
using System.Text;

using FluentValidation;

using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.DependencyInjection;

using PetMagic.Modules.Economy.Api.Endpoints;
using PetMagic.Modules.Economy.Application.Contracts;
using PetMagic.Modules.Economy.Application.Validation;

namespace PetMagic.Modules.Identity.Tests.Economy;

public sealed class EconomyWebhookEndpointValidationTests
{
    private const int MaxWebhookPayloadLength = 256 * 1024;

    [Fact]
    public async Task GooglePlayWebhookEndpoint_ShouldReturnValidationProblem_WhenPubSubMessageIsMissing()
    {
        var method = typeof(EconomyEndpoints).GetMethod(
            "GooglePlayDeveloperNotificationAsync",
            BindingFlags.NonPublic | BindingFlags.Static);

        Assert.NotNull(method);

        var httpContext = new DefaultHttpContext();
        httpContext.Response.Body = new MemoryStream();
        httpContext.RequestServices = new ServiceCollection()
            .AddLogging()
            .AddProblemDetails()
            .BuildServiceProvider();

        var request = new EconomyEndpoints.GooglePlayDeveloperNotificationRequest(null!);
        var validator = new GooglePlayDeveloperNotificationCommandValidator();

        var task = (Task)method!.Invoke(
            null,
            [
                httpContext.Request,
                request,
                validator,
                null!,
                null!,
                CancellationToken.None,
            ])!;

        await task;

        var result = Assert.IsAssignableFrom<IResult>(
            task.GetType().GetProperty("Result")!.GetValue(task));

        await result.ExecuteAsync(httpContext);

        Assert.Equal(StatusCodes.Status400BadRequest, httpContext.Response.StatusCode);

        httpContext.Response.Body.Position = 0;
        var body = await new StreamReader(httpContext.Response.Body, Encoding.UTF8).ReadToEndAsync();
        Assert.Contains("MessageData", body, StringComparison.Ordinal);
    }

    [Fact]
    public async Task StripeWebhookEndpoint_ShouldRejectOversizedBodyBeforeValidationOrService()
    {
        var method = typeof(EconomyEndpoints).GetMethod(
            "StripeWebhookAsync",
            BindingFlags.NonPublic | BindingFlags.Static);
        var limitField = typeof(EconomyEndpoints).GetField(
            "MaxEconomyWebhookRequestBodyBytes",
            BindingFlags.NonPublic | BindingFlags.Static);

        Assert.NotNull(method);
        Assert.NotNull(limitField);

        var maxBytes = Assert.IsType<int>(limitField!.GetRawConstantValue());
        var httpContext = new DefaultHttpContext();
        httpContext.Response.Body = new MemoryStream();
        httpContext.RequestServices = new ServiceCollection()
            .AddLogging()
            .AddProblemDetails()
            .BuildServiceProvider();
        httpContext.Request.Body = new MemoryStream(new byte[maxBytes + 1]);

        var task = (Task)method!.Invoke(
            null,
            [
                httpContext.Request,
                null!,
                null!,
                CancellationToken.None,
            ])!;

        await task;

        var result = Assert.IsAssignableFrom<IResult>(
            task.GetType().GetProperty("Result")!.GetValue(task));

        await result.ExecuteAsync(httpContext);

        Assert.Equal(StatusCodes.Status413PayloadTooLarge, httpContext.Response.StatusCode);

        httpContext.Response.Body.Position = 0;
        var body = await new StreamReader(httpContext.Response.Body, Encoding.UTF8)
            .ReadToEndAsync();
        Assert.Contains("economy.invalid_webhook_payload", body, StringComparison.Ordinal);
        Assert.DoesNotContain("too large", body, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void WebhookCommandValidators_ShouldRejectOversizedPayloadFields()
    {
        var oversizedPayload = new string('a', MaxWebhookPayloadLength + 1);

        var stripeResult = new StripeWebhookCommandValidator().Validate(
            new StripeWebhookCommand(oversizedPayload, "t=123,v1=abc"));
        var appStoreResult = new AppStoreServerNotificationCommandValidator().Validate(
            new AppStoreServerNotificationCommand(oversizedPayload));
        var googlePlayResult = new GooglePlayDeveloperNotificationCommandValidator().Validate(
            new GooglePlayDeveloperNotificationCommand(oversizedPayload, "message-1"));
        var stripeSignatureResult = new StripeWebhookCommandValidator().Validate(
            new StripeWebhookCommand("{}", new string('s', 4097)));

        Assert.False(stripeResult.IsValid);
        Assert.Contains(
            stripeResult.Errors,
            error => error.PropertyName == nameof(StripeWebhookCommand.RawBody));
        Assert.False(appStoreResult.IsValid);
        Assert.Contains(
            appStoreResult.Errors,
            error => error.PropertyName == nameof(AppStoreServerNotificationCommand.SignedPayload));
        Assert.False(googlePlayResult.IsValid);
        Assert.Contains(
            googlePlayResult.Errors,
            error => error.PropertyName == nameof(GooglePlayDeveloperNotificationCommand.MessageData));
        Assert.False(stripeSignatureResult.IsValid);
        Assert.Contains(
            stripeSignatureResult.Errors,
            error => error.PropertyName == nameof(StripeWebhookCommand.StripeSignature));
    }
}
