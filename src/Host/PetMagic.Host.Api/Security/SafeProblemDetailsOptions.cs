using System.Diagnostics;

using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;

using PetMagic.Host.Api.Observability;

namespace PetMagic.Host.Api.Security;

public static class SafeProblemDetailsOptions
{
    public static void Configure(ProblemDetailsOptions options)
    {
        options.CustomizeProblemDetails = context =>
        {
            var httpContext = context.HttpContext;
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

            if (IsSafeClientVisibleServerProblem(context.ProblemDetails))
            {
                return;
            }

            context.ProblemDetails.Title = "INTERNAL_SERVER_ERROR";
            context.ProblemDetails.Extensions["code"] = "INTERNAL_SERVER_ERROR";
            context.ProblemDetails.Detail = null;
        };
    }

    private static bool IsSafeClientVisibleServerProblem(ProblemDetails problemDetails)
    {
        var code = problemDetails.Extensions.TryGetValue("code", out var extensionCode)
            ? extensionCode?.ToString()
            : problemDetails.Title;

        return code is "GENERATION_QUEUE_OVERLOADED" or "GENERATION_WAIT_TOO_LONG";
    }
}
