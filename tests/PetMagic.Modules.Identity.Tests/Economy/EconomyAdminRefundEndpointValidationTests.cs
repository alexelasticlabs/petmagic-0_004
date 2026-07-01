using System.Reflection;
using System.Text;

using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.DependencyInjection;

using PetMagic.Modules.Economy.Api.Endpoints;
using PetMagic.Modules.Economy.Application.Validation;

namespace PetMagic.Modules.Identity.Tests.Economy;

public sealed class EconomyAdminRefundEndpointValidationTests
{
    [Fact]
    public async Task RefundPurchaseEndpoint_ShouldReturnValidationProblem_WhenReasonIsTooLong()
    {
        var method = typeof(AdminEconomyEndpoints).GetMethod(
            "RefundPurchaseAsync",
            BindingFlags.NonPublic | BindingFlags.Static);

        Assert.NotNull(method);

        var httpContext = new DefaultHttpContext();
        httpContext.Response.Body = new MemoryStream();
        httpContext.RequestServices = new ServiceCollection()
            .AddLogging()
            .AddProblemDetails()
            .BuildServiceProvider();

        var request = new AdminEconomyEndpoints.AdminRefundPurchaseRequest(new string('r', 241));
        var validator = new AdminRefundPurchaseCommandValidator();

        var task = (Task)method!.Invoke(
            null,
            [
                Guid.NewGuid(),
                request,
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
        Assert.Contains("Reason", body, StringComparison.Ordinal);
    }
}
