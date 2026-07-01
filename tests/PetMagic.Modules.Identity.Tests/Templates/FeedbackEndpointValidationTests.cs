using System.Reflection;
using System.Security.Claims;
using System.Text;

using FluentValidation;

using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.DependencyInjection;

using PetMagic.Modules.Templates.Api.Endpoints;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Application.Validation;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class FeedbackEndpointValidationTests
{
    [Fact]
    public async Task SubmitFeedbackEndpoint_ShouldReturnValidationProblem_WhenTypeIsUnknown()
    {
        var method = typeof(FeedbackEndpoints).GetMethod(
            "SubmitFeedbackAsync",
            BindingFlags.NonPublic | BindingFlags.Static);

        Assert.NotNull(method);

        var httpContext = new DefaultHttpContext();
        httpContext.Response.Body = new MemoryStream();
        httpContext.RequestServices = new ServiceCollection()
            .AddLogging()
            .AddProblemDetails()
            .BuildServiceProvider();
        httpContext.User = new ClaimsPrincipal(new ClaimsIdentity(
        [
            new Claim(ClaimTypes.NameIdentifier, Guid.NewGuid().ToString())
        ], "Test"));

        var request = Activator.CreateInstance(
            typeof(FeedbackEndpoints).Assembly.GetType(
                "PetMagic.Modules.Templates.Api.Endpoints.FeedbackEndpoints+SubmitFeedbackRequest",
                throwOnError: true)!,
            "Other",
            "quality",
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null);
        var validator = new SubmitFeedbackCommandValidator();

        var task = (Task)method!.Invoke(
            null,
            [
                httpContext,
                request!,
                validator,
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
        Assert.Contains("Type", body, StringComparison.Ordinal);
    }

    [Fact]
    public async Task RefundAdminFeedbackEndpoint_ShouldReturnValidationProblem_WhenAmountIsNonPositive()
    {
        var method = typeof(FeedbackEndpoints).GetMethod(
            "RefundAdminFeedbackAsync",
            BindingFlags.NonPublic | BindingFlags.Static);

        Assert.NotNull(method);

        var httpContext = new DefaultHttpContext();
        httpContext.Response.Body = new MemoryStream();
        httpContext.RequestServices = new ServiceCollection()
            .AddLogging()
            .AddProblemDetails()
            .BuildServiceProvider();
        httpContext.User = new ClaimsPrincipal(new ClaimsIdentity(
        [
            new Claim(ClaimTypes.NameIdentifier, Guid.NewGuid().ToString())
        ], "Test"));

        var request = Activator.CreateInstance(
            typeof(FeedbackEndpoints).Assembly.GetType(
                "PetMagic.Modules.Templates.Api.Endpoints.FeedbackEndpoints+RefundFeedbackCreditsRequest",
                throwOnError: true)!,
            0,
            "reason");
        var validator = new RefundFeedbackCreditsCommandValidator();

        var task = (Task)method!.Invoke(
            null,
            [
                httpContext,
                Guid.NewGuid(),
                request!,
                validator,
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
        Assert.Contains("Amount", body, StringComparison.Ordinal);
    }

    [Fact]
    public async Task UpdateAdminFeedbackEndpoint_ShouldReturnValidationProblem_WhenStatusIsInvalid()
    {
        var method = typeof(FeedbackEndpoints).GetMethod(
            "UpdateAdminFeedbackAsync",
            BindingFlags.NonPublic | BindingFlags.Static);

        Assert.NotNull(method);

        var httpContext = new DefaultHttpContext();
        httpContext.Response.Body = new MemoryStream();
        httpContext.RequestServices = new ServiceCollection()
            .AddLogging()
            .AddProblemDetails()
            .BuildServiceProvider();
        httpContext.User = new ClaimsPrincipal(new ClaimsIdentity(
        [
            new Claim(ClaimTypes.NameIdentifier, Guid.NewGuid().ToString())
        ], "Test"));

        var request = Activator.CreateInstance(
            typeof(FeedbackEndpoints).Assembly.GetType(
                "PetMagic.Modules.Templates.Api.Endpoints.FeedbackEndpoints+UpdateFeedbackAdminRequest",
                throwOnError: true)!,
            "not_open",
            null,
            null);
        var validator = new UpdateFeedbackAdminCommandValidator();

        var task = (Task)method!.Invoke(
            null,
            [
                httpContext,
                Guid.NewGuid(),
                request!,
                validator,
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
        Assert.Contains("Status", body, StringComparison.Ordinal);
    }
}
