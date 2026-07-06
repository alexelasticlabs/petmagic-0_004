using System.Text.RegularExpressions;

using PetMagic.BuildingBlocks.Observability;

namespace PetMagic.Modules.Templates.Infrastructure;

internal static class AdminFailureMessageSanitizer
{
    private const int CodeMaxLength = 128;
    private const int MessageMaxLength = 240;

    private static readonly Regex ProviderDiagnosticIdPattern = new(
        @"\b(request[-_]?id|trace[-_]?id|correlation[-_]?id|job[-_]?id)\s*([:=])\s*[^\s,}\]]+",
        RegexOptions.IgnoreCase | RegexOptions.CultureInvariant | RegexOptions.Compiled);

    public static string? Sanitize(string? value)
    {
        var trimmed = value?.Trim();
        if (string.IsNullOrEmpty(trimmed))
        {
            return null;
        }

        var sanitized = SafeLogValues.SanitizeText(trimmed, maxLength: MessageMaxLength);
        sanitized = ProviderDiagnosticIdPattern.Replace(
            sanitized,
            match => $"{match.Groups[1].Value}{match.Groups[2].Value} ***");

        return sanitized.Length <= MessageMaxLength ? sanitized : sanitized[..MessageMaxLength];
    }

    public static string? SanitizeCode(string? value)
    {
        var trimmed = value?.Trim();
        return string.IsNullOrEmpty(trimmed)
            ? null
            : SafeLogValues.SanitizeText(trimmed, maxLength: CodeMaxLength);
    }
}
