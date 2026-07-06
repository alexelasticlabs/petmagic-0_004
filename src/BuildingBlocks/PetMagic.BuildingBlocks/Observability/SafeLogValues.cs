using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;

namespace PetMagic.BuildingBlocks.Observability;

public static class SafeLogValues
{
    private const int StableHashLength = 16;
    private const int DefaultMaxSanitizedTextLength = 512;

    private static readonly Regex HeaderSecretPattern = new(
        @"\b(x[-_]?api[-_]?key|api[-_]?key|x[-_]?fal[-_]?key|fal[-_]?key|stripe[-_]?signature|x[-_]?goog[-_]?signature|x[-_]?webhook[-_]?signature|authorization|cookie|set[-_]?cookie)\s*[:=]\s*[^\s,}\]]+",
        RegexOptions.IgnoreCase | RegexOptions.CultureInvariant | RegexOptions.Compiled);

    private static readonly Regex KeyedSecretPattern = new(
        @"\b(access[-_]?token|refresh[-_]?token|id[-_]?token|[a-z0-9_-]*(?:token|secret)|jwt|api[-_]?key|credential|signature|password|receipt|purchase[-_]?token|verification[-_]?data|server[-_]?verification[-_]?data|local[-_]?verification[-_]?data|signed[-_]?payload|signed[-_]?renewal[-_]?info|signed[-_]?transaction[-_]?info|checkout[-_]?session[-_]?id|stripe[-_]?session[-_]?id|payment[-_]?intent[-_]?client[-_]?secret|payment[-_]?intent[-_]?id|setup[-_]?intent[-_]?id|customer[-_]?id|external[-_]?payment[-_]?id|external[-_]?subscription[-_]?id|client[-_]?secret)\s*[:=]\s*[^\s,}\]]+",
        RegexOptions.IgnoreCase | RegexOptions.CultureInvariant | RegexOptions.Compiled);

    private static readonly Regex JsonSecretPattern = new(
        """(["'])(access[-_]?token|refresh[-_]?token|id[-_]?token|[a-z0-9_-]*(?:token|secret)|jwt|api[-_]?key|credential|signature|password|receipt|purchase[-_]?token|verification[-_]?data|server[-_]?verification[-_]?data|local[-_]?verification[-_]?data|signed[-_]?payload|signed[-_]?renewal[-_]?info|signed[-_]?transaction[-_]?info|checkout[-_]?session[-_]?id|stripe[-_]?session[-_]?id|payment[-_]?intent[-_]?client[-_]?secret|payment[-_]?intent[-_]?id|setup[-_]?intent[-_]?id|customer[-_]?id|external[-_]?payment[-_]?id|external[-_]?subscription[-_]?id|client[-_]?secret)\1(\s*:\s*)(["'])(.*?)\4""",
        RegexOptions.IgnoreCase | RegexOptions.CultureInvariant | RegexOptions.Compiled);

    private static readonly Regex DomainIdentifierPattern = new(
        @"\b(?!request[-_]?id\b|correlation[-_]?id\b|trace[-_]?id\b)[a-z0-9_-]*(?:user[-_]?ids?|account[-_]?ids?|pet[-_]?ids?|generation(?:[-_]?result)?[-_]?ids?|template[-_]?ids?|assignment[-_]?ids?|conversation[-_]?ids?|message[-_]?ids?|ticket[-_]?ids?|attachment[-_]?ids?|purchase[-_]?ids?|subscription[-_]?ids?|feedback[-_]?ids?|report[-_]?ids?|moderation[-_]?ids?|order[-_]?ids?)\s*[:=]\s*[^\s,}\]]+",
        RegexOptions.IgnoreCase | RegexOptions.CultureInvariant | RegexOptions.Compiled);

    private static readonly Regex JsonDomainIdentifierPattern = new(
        """(["'])((?!request[-_]?id\1|correlation[-_]?id\1|trace[-_]?id\1)[a-z0-9_-]*(?:user[-_]?ids?|account[-_]?ids?|pet[-_]?ids?|generation(?:[-_]?result)?[-_]?ids?|template[-_]?ids?|assignment[-_]?ids?|conversation[-_]?ids?|message[-_]?ids?|ticket[-_]?ids?|attachment[-_]?ids?|purchase[-_]?ids?|subscription[-_]?ids?|feedback[-_]?ids?|report[-_]?ids?|moderation[-_]?ids?|order[-_]?ids?))\1(\s*:\s*)(["'])(.*?)\4""",
        RegexOptions.IgnoreCase | RegexOptions.CultureInvariant | RegexOptions.Compiled);

    private static readonly Regex PluralDomainIdentifierPattern = new(
        @"\b(?!request[-_]?ids\b|correlation[-_]?ids\b|trace[-_]?ids\b)[a-z0-9_-]*(?:user[-_]?ids|account[-_]?ids|pet[-_]?ids|generation(?:[-_]?result)?[-_]?ids|template[-_]?ids|assignment[-_]?ids|conversation[-_]?ids|message[-_]?ids|ticket[-_]?ids|attachment[-_]?ids|purchase[-_]?ids|subscription[-_]?ids|feedback[-_]?ids|report[-_]?ids|moderation[-_]?ids|order[-_]?ids)\s*[:=]\s*[^\s}\]]+",
        RegexOptions.IgnoreCase | RegexOptions.CultureInvariant | RegexOptions.Compiled);

    private static readonly Regex KeyedOpaqueUrlPattern = new(
        @"\b(attachment[-_]?urls?|file[-_]?urls?|media[-_]?urls?|image[-_]?urls?|video[-_]?urls?|avatar[-_]?urls?|thumbnail[-_]?urls?|preview[-_]?urls?|output[-_]?urls?|download[-_]?urls?|upload[-_]?urls?)\s*([:=])\s*(https?://[^\s,}\]]+)",
        RegexOptions.IgnoreCase | RegexOptions.CultureInvariant | RegexOptions.Compiled);

    private static readonly Regex JsonOpaqueUrlPattern = new(
        """(["'])(attachment[-_]?urls?|file[-_]?urls?|media[-_]?urls?|image[-_]?urls?|video[-_]?urls?|avatar[-_]?urls?|thumbnail[-_]?urls?|preview[-_]?urls?|output[-_]?urls?|download[-_]?urls?|upload[-_]?urls?)\1(\s*:\s*)(["'])(https?://.*?)\4""",
        RegexOptions.IgnoreCase | RegexOptions.CultureInvariant | RegexOptions.Compiled);

    private static readonly Regex KeyedSensitiveUrlPattern = new(
        @"\b([a-z0-9_-]*(?:urls?|uri)|callback|webhook|redirect)\s*([:=])\s*(['""]?)(https?://[^\s,}\]'""]+)\3",
        RegexOptions.IgnoreCase | RegexOptions.CultureInvariant | RegexOptions.Compiled);

    private static readonly Regex JsonSensitiveUrlPattern = new(
        """(["'])([a-z0-9_-]*(?:urls?|uri)|callback|webhook|redirect)\1(\s*:\s*)(["'])(https?://.*?)\4""",
        RegexOptions.IgnoreCase | RegexOptions.CultureInvariant | RegexOptions.Compiled);

    private static readonly Regex KeyedFileNamePattern = new(
        @"\b([a-z0-9_-]*file[-_]?names?)\s*[:=]\s*(?:""[^""]*""|'[^']*'|[^\s,}\]]+)",
        RegexOptions.IgnoreCase | RegexOptions.CultureInvariant | RegexOptions.Compiled);

    private static readonly Regex JsonFileNamePattern = new(
        """(["'])([a-z0-9_-]*file[-_]?names?)\1(\s*:\s*)(["'])(.*?)\4""",
        RegexOptions.IgnoreCase | RegexOptions.CultureInvariant | RegexOptions.Compiled);

    private static readonly Regex UrlWithSecretsPattern = new(
        @"https?://[^\s]+[?#][^\s]+",
        RegexOptions.IgnoreCase | RegexOptions.CultureInvariant | RegexOptions.Compiled);

    public static string StableHash(string? value)
    {
        var normalized = value?.Trim().Replace('\\', '/');
        if (string.IsNullOrWhiteSpace(normalized))
        {
            return "empty";
        }

        var hash = SHA256.HashData(Encoding.UTF8.GetBytes(normalized));
        return Convert.ToHexString(hash)[..StableHashLength].ToLowerInvariant();
    }

    public static string ExceptionType(Exception? exception)
    {
        return exception?.GetType().Name ?? "none";
    }

    public static string SanitizeText(string? value, int maxLength = DefaultMaxSanitizedTextLength)
    {
        if (string.IsNullOrWhiteSpace(value) || maxLength <= 0)
        {
            return string.Empty;
        }

        var sanitized = HeaderSecretPattern.Replace(value, match =>
        {
            var separator = match.Value.Contains(':') ? ':' : '=';
            var key = match.Value.Split([':', '='], 2, StringSplitOptions.TrimEntries)[0];
            return $"{key}{separator} ***";
        });
        sanitized = JsonSecretPattern.Replace(sanitized, match =>
        {
            var keyQuote = match.Groups[1].Value;
            var key = match.Groups[2].Value;
            var separator = match.Groups[3].Value;
            var valueQuote = match.Groups[4].Value;
            return $"{keyQuote}{key}{keyQuote}{separator}{valueQuote}***{valueQuote}";
        });
        sanitized = JsonDomainIdentifierPattern.Replace(sanitized, match =>
        {
            var keyQuote = match.Groups[1].Value;
            var key = match.Groups[2].Value;
            var separator = match.Groups[3].Value;
            var valueQuote = match.Groups[4].Value;
            return $"{keyQuote}{key}{keyQuote}{separator}{valueQuote}***{valueQuote}";
        });
        sanitized = JsonOpaqueUrlPattern.Replace(sanitized, match =>
        {
            var keyQuote = match.Groups[1].Value;
            var key = match.Groups[2].Value;
            var separator = match.Groups[3].Value;
            var valueQuote = match.Groups[4].Value;
            return $"{keyQuote}{key}{keyQuote}{separator}{valueQuote}{MaskUrl(match.Groups[5].Value)}{valueQuote}";
        });
        sanitized = JsonSensitiveUrlPattern.Replace(sanitized, match =>
        {
            var keyQuote = match.Groups[1].Value;
            var key = match.Groups[2].Value;
            var separator = match.Groups[3].Value;
            var valueQuote = match.Groups[4].Value;
            return $"{keyQuote}{key}{keyQuote}{separator}{valueQuote}{MaskUrl(match.Groups[5].Value)}{valueQuote}";
        });
        sanitized = JsonFileNamePattern.Replace(sanitized, match =>
        {
            var keyQuote = match.Groups[1].Value;
            var key = match.Groups[2].Value;
            var separator = match.Groups[3].Value;
            var valueQuote = match.Groups[4].Value;
            return $"{keyQuote}{key}{keyQuote}{separator}{valueQuote}***{valueQuote}";
        });
        sanitized = KeyedSecretPattern.Replace(sanitized, match =>
        {
            var separator = match.Value.Contains(':') ? ':' : '=';
            var key = match.Value.Split([':', '='], 2, StringSplitOptions.TrimEntries)[0];
            return $"{key}{separator} ***";
        });
        sanitized = PluralDomainIdentifierPattern.Replace(sanitized, match =>
        {
            var separator = match.Value.Contains(':') ? ':' : '=';
            var key = match.Value.Split([':', '='], 2, StringSplitOptions.TrimEntries)[0];
            return $"{key}{separator} ***";
        });
        sanitized = DomainIdentifierPattern.Replace(sanitized, match =>
        {
            var separator = match.Value.Contains(':') ? ':' : '=';
            var key = match.Value.Split([':', '='], 2, StringSplitOptions.TrimEntries)[0];
            return $"{key}{separator} ***";
        });
        sanitized = KeyedOpaqueUrlPattern.Replace(sanitized, match =>
        {
            return $"{match.Groups[1].Value}{match.Groups[2].Value} {MaskUrl(match.Groups[3].Value)}";
        });
        sanitized = KeyedSensitiveUrlPattern.Replace(sanitized, match =>
        {
            var valueQuote = match.Groups[3].Value;
            return $"{match.Groups[1].Value}{match.Groups[2].Value} {valueQuote}{MaskUrl(match.Groups[4].Value)}{valueQuote}";
        });
        sanitized = KeyedFileNamePattern.Replace(sanitized, match =>
        {
            var separator = match.Value.Contains(':') ? ':' : '=';
            var key = match.Value.Split([':', '='], 2, StringSplitOptions.TrimEntries)[0];
            return $"{key}{separator} ***";
        });
        sanitized = UrlWithSecretsPattern.Replace(sanitized, match =>
        {
            return MaskUrl(match.Value);
        });
        sanitized = Regex.Replace(sanitized, @"[\u0000-\u001F\u007F]+", " ");
        sanitized = Regex.Replace(sanitized, " {2,}", " ").Trim();

        return sanitized.Length > maxLength ? sanitized[..maxLength] : sanitized;
    }

    private static string MaskUrl(string value)
    {
        return Uri.TryCreate(value, UriKind.Absolute, out var uri)
            ? uri.GetLeftPart(UriPartial.Authority) + "/***"
            : "[redacted-url]";
    }
}
