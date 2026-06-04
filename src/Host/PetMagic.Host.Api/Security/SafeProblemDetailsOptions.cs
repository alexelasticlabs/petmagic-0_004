using System.Diagnostics;

using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

using PetMagic.Host.Api.Observability;

namespace PetMagic.Host.Api.Security;

public static class SafeProblemDetailsOptions
{
    public static void Configure(ProblemDetailsOptions options)
    {
        options.CustomizeProblemDetails = context =>
        {
            var httpContext = context.HttpContext;
            var environment = httpContext.RequestServices.GetService<IHostEnvironment>();
            var statusCode = context.ProblemDetails.Status ?? httpContext.Response.StatusCode;

            context.ProblemDetails.Extensions["traceId"] =
                Activity.Current?.TraceId.ToString() ?? httpContext.TraceIdentifier;
            context.ProblemDetails.Extensions["correlationId"] =
                httpContext.Items.TryGetValue(CorrelationId.HttpContextItemKey, out var correlationId)
                    ? correlationId
                    : "unknown";

            if (statusCode < StatusCodes.Status500InternalServerError)
            {
                return;
            }

            context.ProblemDetails.Title = "INTERNAL_SERVER_ERROR";
            context.ProblemDetails.Extensions["code"] = "INTERNAL_SERVER_ERROR";

            if (environment?.IsDevelopment() == true)
            {
                return;
            }

            context.ProblemDetails.Detail = "An unexpected error occurred.";
        };
    }
}
