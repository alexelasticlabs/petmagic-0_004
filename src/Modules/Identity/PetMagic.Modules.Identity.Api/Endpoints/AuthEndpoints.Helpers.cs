using System.Security.Claims;

using FluentValidation;

using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Routing;
using Microsoft.AspNetCore.WebUtilities;

using PetMagic.Modules.Identity.Application.Abstractions;
using PetMagic.Modules.Identity.Application.Contracts;

namespace PetMagic.Modules.Identity.Api.Endpoints;

public static partial class AuthEndpoints
{

    private static string? ResolveRefreshToken(HttpContext context, string? requestRefreshToken)
    {
        if (!string.IsNullOrWhiteSpace(requestRefreshToken))
        {
            return requestRefreshToken;
        }

        if (context.Request.Cookies.TryGetValue(RefreshTokenCookieName, out var refreshTokenFromCookie)
            && !string.IsNullOrWhiteSpace(refreshTokenFromCookie))
        {
            return refreshTokenFromCookie;
        }

        return null;
    }

    private static void WriteRefreshTokenCookie(HttpContext context, string refreshToken)
    {
        if (string.IsNullOrWhiteSpace(refreshToken))
        {
            return;
        }

        ApplySensitiveNoStoreHeaders(context);
        context.Response.Cookies.Append(RefreshTokenCookieName, refreshToken, BuildRefreshCookieOptions(context));
    }

    private static void DeleteRefreshTokenCookie(HttpContext context)
    {
        ApplySensitiveNoStoreHeaders(context);
        context.Response.Cookies.Delete(RefreshTokenCookieName, BuildRefreshCookieDeletionOptions(context));
    }

    private static void ApplySensitiveNoStoreHeaders(HttpContext context)
    {
        context.Response.Headers.CacheControl = "no-store, no-cache, max-age=0";
        context.Response.Headers.Pragma = "no-cache";
        context.Response.Headers.Expires = "0";
        context.Response.Headers.XContentTypeOptions = "nosniff";
    }

    private static CookieOptions BuildRefreshCookieOptions(HttpContext context)
    {
        var secureCookie = IsSecureConnection(context);

        return new CookieOptions
        {
            HttpOnly = true,
            Secure = secureCookie,
            SameSite = secureCookie ? SameSiteMode.None : SameSiteMode.Lax,
            IsEssential = true,
            Path = RefreshTokenCookiePath,
            Expires = DateTimeOffset.UtcNow.AddDays(RefreshTokenCookieLifetimeDays)
        };
    }

    private static CookieOptions BuildRefreshCookieDeletionOptions(HttpContext context)
    {
        var secureCookie = IsSecureConnection(context);

        return new CookieOptions
        {
            HttpOnly = true,
            Secure = secureCookie,
            SameSite = secureCookie ? SameSiteMode.None : SameSiteMode.Lax,
            IsEssential = true,
            Path = RefreshTokenCookiePath
        };
    }

    private static bool IsSecureConnection(HttpContext context)
    {
        return context.Request.IsHttps;
    }

    internal static bool TryGetUserId(HttpContext context, out Guid userId, out ProblemHttpResult? problem)
    {
        var subject = context.User.FindFirstValue("sub") ?? context.User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!Guid.TryParse(subject, out userId))
        {
            problem = IdentityClientProblems.InvalidSubject();
            return false;
        }

        problem = null;
        return true;
    }

}
