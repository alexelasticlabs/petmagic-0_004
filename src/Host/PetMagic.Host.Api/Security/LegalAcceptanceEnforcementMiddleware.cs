using System.Security.Claims;
using System.Text.Json;

using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

using PetMagic.Modules.Identity.Application.Abstractions;
using PetMagic.Modules.Identity.Infrastructure.Entities;

namespace PetMagic.Host.Api.Security;

public sealed class LegalAcceptanceEnforcementMiddleware(RequestDelegate next)
{
    private static readonly PathString[] AllowedPaths =
    [
        new PathString("/api/legal/current"),
        new PathString("/api/legal/accept"),
        new PathString("/api/auth/refresh"),
        new PathString("/api/auth/logout"),
        new PathString("/api/auth/me")
    ];

    private const string LegalAcceptanceRequiredCode = "auth.legal_acceptance_required";
    private const string LegalAcceptanceRequiredMessage = "Current legal documents must be accepted before using this endpoint.";

    public async Task InvokeAsync(HttpContext context, UserManager<AppUser> userManager, ILegalDocumentsCatalog legalDocumentsCatalog)
    {
        if (HttpMethods.IsOptions(context.Request.Method)
            || context.User.Identity?.IsAuthenticated != true
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

        var user = await userManager.Users
            .AsNoTracking()
            .FirstOrDefaultAsync(x => x.Id == userId, context.RequestAborted);

        if (user is null || !RequiresAcceptance(user, legalDocumentsCatalog))
        {
            await next(context);
            return;
        }

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
