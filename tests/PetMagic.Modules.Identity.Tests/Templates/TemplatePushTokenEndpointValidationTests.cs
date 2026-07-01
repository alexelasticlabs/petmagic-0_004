using System.Reflection;
using System.Security.Claims;
using System.Text;

using FluentValidation;

using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.DependencyInjection;

using PetMagic.Modules.Templates.Api.Endpoints;
using PetMagic.Modules.Templates.Application.Validation;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class TemplatePushTokenEndpointValidationTests
{
    [Fact]
    public async Task RegisterPushTokenEndpoint_ShouldReturnValidationProblem_WhenTokenIsBlank()
    {
        var method = typeof(TemplateGenerationEndpoints).GetMethod(
            "RegisterPushTokenAsync",
            BindingFlags.NonPublic | BindingFlags.Static);

        Assert.NotNull(method);

        var httpContext = CreateHttpContext();
        var request = Activator.CreateInstance(
            typeof(TemplateGenerationEndpoints).Assembly.GetType(
                "PetMagic.Modules.Templates.Api.Endpoints.TemplateGenerationEndpoints+RegisterPushTokenRequest",
                throwOnError: true)!,
            " ",
            "android",
            "device-1",
            "1.0.0",
            "en-US");
        var validator = new RegisterTemplatePushTokenCommandValidator();

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
        Assert.Contains("Token", body, StringComparison.Ordinal);
    }

    [Fact]
    public async Task RegisterPushTokenEndpoint_ShouldReturnValidationProblem_WhenTokenIsTooShort()
    {
        var method = typeof(TemplateGenerationEndpoints).GetMethod(
            "RegisterPushTokenAsync",
            BindingFlags.NonPublic | BindingFlags.Static);

        Assert.NotNull(method);

        var httpContext = CreateHttpContext();
        var request = Activator.CreateInstance(
            typeof(TemplateGenerationEndpoints).Assembly.GetType(
                "PetMagic.Modules.Templates.Api.Endpoints.TemplateGenerationEndpoints+RegisterPushTokenRequest",
                throwOnError: true)!,
            "short-token",
            "android",
            "device-1",
            "1.0.0",
            "en-US");
        var validator = new RegisterTemplatePushTokenCommandValidator();

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
        Assert.Contains("Token", body, StringComparison.Ordinal);
    }

    [Fact]
    public async Task UnregisterPushTokenEndpoint_ShouldReturnValidationProblem_WhenTokenIsTooLong()
    {
        var method = typeof(TemplateGenerationEndpoints).GetMethod(
            "UnregisterPushTokenAsync",
            BindingFlags.NonPublic | BindingFlags.Static);

        Assert.NotNull(method);

        var httpContext = CreateHttpContext();
        var request = Activator.CreateInstance(
            typeof(TemplateGenerationEndpoints).Assembly.GetType(
                "PetMagic.Modules.Templates.Api.Endpoints.TemplateGenerationEndpoints+UnregisterPushTokenRequest",
                throwOnError: true)!,
            new string('x', 4097));
        var validator = new UnregisterTemplatePushTokenCommandValidator();

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
        Assert.Contains("Token", body, StringComparison.Ordinal);
    }

    [Fact]
    public async Task UnregisterPushTokenEndpoint_ShouldReturnValidationProblem_WhenTokenIsTooShort()
    {
        var method = typeof(TemplateGenerationEndpoints).GetMethod(
            "UnregisterPushTokenAsync",
            BindingFlags.NonPublic | BindingFlags.Static);

        Assert.NotNull(method);

        var httpContext = CreateHttpContext();
        var request = Activator.CreateInstance(
            typeof(TemplateGenerationEndpoints).Assembly.GetType(
                "PetMagic.Modules.Templates.Api.Endpoints.TemplateGenerationEndpoints+UnregisterPushTokenRequest",
                throwOnError: true)!,
            "short-token");
        var validator = new UnregisterTemplatePushTokenCommandValidator();

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
        Assert.Contains("Token", body, StringComparison.Ordinal);
    }

    private static DefaultHttpContext CreateHttpContext()
    {
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
        return httpContext;
    }
}
