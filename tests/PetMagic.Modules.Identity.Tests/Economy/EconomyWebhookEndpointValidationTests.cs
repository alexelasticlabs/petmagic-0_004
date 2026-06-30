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
}
