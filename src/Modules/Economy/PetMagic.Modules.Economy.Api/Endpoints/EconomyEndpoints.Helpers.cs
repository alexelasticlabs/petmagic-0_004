using System.Security.Claims;
using System.Text;

using FluentValidation;

using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Routing;

using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Economy.Application.Contracts;

namespace PetMagic.Modules.Economy.Api.Endpoints;

public static partial class EconomyEndpoints
{

    private static (Guid? UserId, bool IsPremium, PetMagic.BuildingBlocks.Results.Error? Error) TryGetSubject(HttpContext context)
    {
        var subject = context.User.FindFirstValue("sub") ?? context.User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!Guid.TryParse(subject, out var userId))
        {
            return (null, false, new PetMagic.BuildingBlocks.Results.Error(InvalidSubjectCode, InvalidSubjectMessage));
        }

        var premiumRaw = context.User.FindFirstValue("premium");
        var isPremium = string.Equals(premiumRaw, "true", StringComparison.OrdinalIgnoreCase);
        return (userId, isPremium, null);
    }

    private static CurrencyPackResponse? ResolveCurrencyPack(
        string tokenPackId,
        IReadOnlyList<CurrencyPackResponse> packs)
    {
        var normalized = tokenPackId.Trim();
        if (Guid.TryParse(normalized, out var packId))
        {
            return packs.FirstOrDefault(x => x.PackId == packId);
        }

        var code = normalized.ToLowerInvariant();
        var pack = packs.FirstOrDefault(x => string.Equals(x.Code, code, StringComparison.OrdinalIgnoreCase));
        if (pack is not null)
        {
            return pack;
        }

        if (code.StartsWith("pack_", StringComparison.Ordinal))
        {
            code = code[5..];
        }

        return int.TryParse(code, out var totalSpark)
            ? packs.FirstOrDefault(x => x.TotalSpark == totalSpark || x.GrantedSpark == totalSpark)
            : null;
    }

    private static string ResolveCheckoutPlatform(HttpContext context, string? requestPlatform)
    {
        var normalizedFromBody = NormalizePlatformToken(requestPlatform);
        if (context.Request.Headers.TryGetValue("X-PetMagic-Platform", out var headerPlatform))
        {
            var normalizedFromHeader = NormalizePlatformToken(headerPlatform.ToString());
            if (!string.Equals(normalizedFromHeader, "web", StringComparison.Ordinal))
            {
                return normalizedFromHeader;
            }
        }

        if (!string.Equals(normalizedFromBody, "web", StringComparison.Ordinal))
        {
            return normalizedFromBody;
        }

        if (context.Request.Headers.TryGetValue("User-Agent", out var userAgentValues))
        {
            var userAgent = userAgentValues.ToString();
            if (userAgent.Contains("Android", StringComparison.OrdinalIgnoreCase))
            {
                return "android";
            }

            if (userAgent.Contains("iPhone", StringComparison.OrdinalIgnoreCase)
                || userAgent.Contains("iPad", StringComparison.OrdinalIgnoreCase)
                || userAgent.Contains("iOS", StringComparison.OrdinalIgnoreCase))
            {
                return "ios";
            }
        }

        return normalizedFromBody;
    }

    private static string NormalizePlatformToken(string? rawPlatform)
    {
        if (string.IsNullOrWhiteSpace(rawPlatform))
        {
            return "web";
        }

        var normalized = rawPlatform.Trim().ToLowerInvariant();
        if (normalized.Contains("android", StringComparison.Ordinal))
        {
            return "android";
        }

        if (normalized.Contains("ios", StringComparison.Ordinal)
            || normalized.Contains("iphone", StringComparison.Ordinal)
            || normalized.Contains("ipad", StringComparison.Ordinal))
        {
            return "ios";
        }

        return normalized switch
        {
            "iphone" => "ios",
            "ipad" => "ios",
            "mobile" => "web",
            _ => normalized
        };
    }

}
