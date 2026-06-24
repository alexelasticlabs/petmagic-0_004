using System.Security.Claims;
using System.Text.Json;

using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Logging;

using PetMagic.Modules.Identity.Application.Abstractions;
using PetMagic.Modules.Identity.Infrastructure.Entities;

namespace PetMagic.Host.Api.Security;

public sealed class LegalAcceptanceEnforcementMiddleware(
    RequestDelegate next,
    ILogger<LegalAcceptanceEnforcementMiddleware> logger,
    IMemoryCache cache)
{
    private static readonly PathString[] AllowedPaths =
    [
        new PathString("/api/legal/current"),
        new PathString("/api/legal/accept"),
        new PathString("/api/auth/register"),
        new PathString("/api/auth/login"),
        new PathString("/api/auth/email-confirmation/request"),
        new PathString("/api/auth/email-confirmation/confirm"),
        new PathString("/api/auth/resend-email-verification-code"),
        new PathString("/api/auth/verify-email-code"),
        new PathString("/api/auth/password-reset/request"),
        new PathString("/api/auth/password-reset/confirm"),
        new PathString("/api/auth/request-password-reset"),
        new PathString("/api/auth/verify-password-reset-code"),
        new PathString("/api/auth/reset-password"),
        new PathString("/api/auth/refresh"),
        new PathString("/api/auth/logout"),
        new PathString("/api/auth/me")
    ];

    private const string LegalAcceptanceRequiredCode = "auth.legal_acceptance_required";
    private const string LegalAcceptanceRequiredMessage = "Current legal documents must be accepted before using this endpoint.";
    private static readonly TimeSpan CacheDuration = TimeSpan.FromMinutes(5);

    public async Task InvokeAsync(HttpContext context, UserManager<AppUser> userManager, ILegalDocumentsCatalog legalDocumentsCatalog)
    {
        if (HttpMethods.IsOptions(context.Request.Method)
            || context.User.Identity?.IsAuthenticated != true
            || context.GetEndpoint()?.Metadata.GetMetadata<IAllowAnonymous>() is not null
            || IsAllowedPath(context.Request.Path))
        {
            await next(context);
            return;
        }

        var subject = context.User.FindFirstValue("sub") ?? context.User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!Guid.TryParse(subject, out var userId))
        {
            await next(context);
            return;
        }

        var cacheKey = $"legal_acceptance:{userId}";
        if (!cache.TryGetValue(cacheKey, out bool requiresAcceptance))
        {
            var user = await userManager.Users
                .AsNoTracking()
                .FirstOrDefaultAsync(x => x.Id == userId, context.RequestAborted);

            requiresAcceptance = user is not null && RequiresAcceptance(user, legalDocumentsCatalog);
            cache.Set(cacheKey, requiresAcceptance, CacheDuration);
        }

        if (!requiresAcceptance)
        {
            await next(context);
            return;
        }

        var correlationId = context.Request.Headers.TryGetValue("X-Correlation-ID", out var correlationHeader)
            ? correlationHeader.ToString()
            : "unknown";
        var requestId = context.Request.Headers.TryGetValue("X-Request-ID", out var requestHeader)
            ? requestHeader.ToString()
            : context.TraceIdentifier;

        logger.LogWarning(
            "Legal acceptance required blocked {Method} {Path} with {StatusCode}. ProblemCode={ProblemCode} CorrelationId={CorrelationId} RequestId={RequestId}",
            context.Request.Method,
            context.Request.Path.Value ?? string.Empty,
            StatusCodes.Status403Forbidden,
            LegalAcceptanceRequiredCode,
            string.IsNullOrWhiteSpace(correlationId) ? "unknown" : correlationId,
            string.IsNullOrWhiteSpace(requestId) ? context.TraceIdentifier : requestId);

        context.Response.StatusCode = StatusCodes.Status403Forbidden;
        context.Response.ContentType = "application/problem+json";
        var payload = JsonSerializer.Serialize(new
        {
            title = LegalAcceptanceRequiredCode,
            detail = LegalAcceptanceRequiredMessage,
            status = StatusCodes.Status403Forbidden
        });
        await context.Response.WriteAsync(payload, context.RequestAborted);
    }

    private static bool IsAllowedPath(PathString path)
    {
        for (var i = 0; i < AllowedPaths.Length; i++)
        {
            if (path.Equals(AllowedPaths[i], StringComparison.OrdinalIgnoreCase))
            {
                return true;
            }
        }

        return false;
    }

    private static bool RequiresAcceptance(AppUser user, ILegalDocumentsCatalog legalDocumentsCatalog)
    {
        var currentTermsVersion = legalDocumentsCatalog.CurrentTermsOfUseVersion;
        var currentPrivacyVersion = legalDocumentsCatalog.CurrentPrivacyPolicyVersion;

        return !user.TermsOfUseAccepted
            || !user.PrivacyPolicyAccepted
            || !string.Equals(user.TermsOfUseAcceptedVersion, currentTermsVersion, StringComparison.Ordinal)
            || !string.Equals(user.PrivacyPolicyAcceptedVersion, currentPrivacyVersion, StringComparison.Ordinal);
    }
}
