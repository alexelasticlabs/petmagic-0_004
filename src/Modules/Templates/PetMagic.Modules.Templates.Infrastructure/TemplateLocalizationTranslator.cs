using System.Globalization;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace PetMagic.Modules.Templates.Infrastructure;

internal static class TemplateLocalizationTranslator
{
    private static readonly Regex PlaceholderPattern = new(@"\{[^{}]+\}", RegexOptions.Compiled);
    private const string SourceLocale = "en";
    private const string NewlineToken = "___PM_NL___";
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    public static async Task<string?> GenerateAsync(
        string title,
        string shortDescription,
        IReadOnlyList<string>? petPhotoRequirements,
        string? imagePrompt,
        string? preprocessingPrompt,
        string? klingPrompt,
        IEnumerable<string> targetLocales,
        string? sourceLocale,
        CancellationToken cancellationToken)
    {
        var normalizedSourceLocale = NormalizeLocale(sourceLocale) ?? SourceLocale;
        var payload = new Dictionary<string, TemplateLocalizedTexts>(StringComparer.OrdinalIgnoreCase);

        foreach (var locale in targetLocales.Select(NormalizeLocale).Where(locale => !string.IsNullOrWhiteSpace(locale)).Distinct(StringComparer.OrdinalIgnoreCase).Cast<string>())
        {
            if (string.Equals(locale, normalizedSourceLocale, StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }

            var translatedTitle = await TranslateAsync(locale, title, normalizedSourceLocale, cancellationToken);
            var translatedShortDescription = await TranslateAsync(locale, shortDescription, normalizedSourceLocale, cancellationToken);
            var translatedPetPhotoRequirements = await TranslateListAsync(locale, petPhotoRequirements, normalizedSourceLocale, cancellationToken);
            var translatedImagePrompt = await TranslateOptionalAsync(locale, imagePrompt, normalizedSourceLocale, cancellationToken);
            var translatedPreprocessingPrompt = await TranslateOptionalAsync(locale, preprocessingPrompt, normalizedSourceLocale, cancellationToken);
            var translatedKlingPrompt = await TranslateOptionalAsync(locale, klingPrompt, normalizedSourceLocale, cancellationToken);

            if (string.IsNullOrWhiteSpace(translatedTitle) || string.IsNullOrWhiteSpace(translatedShortDescription))
            {
                continue;
            }

            payload[locale] = new TemplateLocalizedTexts(
                translatedTitle,
                translatedShortDescription,
                translatedPetPhotoRequirements,
                translatedImagePrompt,
                translatedPreprocessingPrompt,
                translatedKlingPrompt);
        }

        return payload.Count == 0 ? null : JsonSerializer.Serialize(payload, JsonOptions);
    }

    public static TemplateLocalizedTexts Resolve(
        string title,
        string shortDescription,
        string? localizedTextsJson,
        string? locale,
        string? imagePrompt = null,
        string? preprocessingPrompt = null,
        string? klingPrompt = null)
    {
        var fallback = new TemplateLocalizedTexts(
            title,
            shortDescription,
            null,
            imagePrompt,
            preprocessingPrompt,
            klingPrompt);

        var normalizedLocale = NormalizeLocale(locale);
        if (string.IsNullOrWhiteSpace(normalizedLocale) || string.Equals(normalizedLocale, SourceLocale, StringComparison.OrdinalIgnoreCase))
        {
            return fallback;
        }

        if (string.IsNullOrWhiteSpace(localizedTextsJson))
        {
            return fallback;
        }

        try
        {
            var localizedMap = JsonSerializer.Deserialize<Dictionary<string, TemplateLocalizedTexts>>(localizedTextsJson, JsonOptions);
            if (localizedMap is null || !localizedMap.TryGetValue(normalizedLocale, out var localizedTexts))
            {
                return fallback;
            }

            return new TemplateLocalizedTexts(
                string.IsNullOrWhiteSpace(localizedTexts.Title) ? title : localizedTexts.Title,
                string.IsNullOrWhiteSpace(localizedTexts.ShortDescription) ? shortDescription : localizedTexts.ShortDescription,
                localizedTexts.PetPhotoRequirements,
                localizedTexts.ImagePrompt ?? imagePrompt,
                localizedTexts.PreprocessingPrompt ?? preprocessingPrompt,
                localizedTexts.KlingPrompt ?? klingPrompt);
        }
        catch (JsonException)
        {
            return fallback;
        }
    }

    private static async Task<IReadOnlyList<string>?> TranslateListAsync(
        string targetLocale,
        IReadOnlyList<string>? values,
        string sourceLocale,
        CancellationToken cancellationToken)
    {
        if (values is null || values.Count == 0)
        {
            return null;
        }

        var translatedValues = new List<string>(values.Count);
        foreach (var value in values)
        {
            var translated = await TranslateOptionalAsync(targetLocale, value, sourceLocale, cancellationToken);
            if (string.IsNullOrWhiteSpace(translated))
            {
                translatedValues.Add(value);
            }
            else
            {
                translatedValues.Add(translated);
            }
        }

        return translatedValues;
    }

    private static async Task<string?> TranslateOptionalAsync(
        string targetLocale,
        string? value,
        string sourceLocale,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return null;
        }

        return await TranslateAsync(targetLocale, value, sourceLocale, cancellationToken);
    }

    private static async Task<string?> TranslateAsync(string targetLocale, string text, string sourceLocale, CancellationToken cancellationToken)
    {
        var protectedText = ProtectText(text);
        var query = string.Create(
            CultureInfo.InvariantCulture,
            $"client=gtx&sl={sourceLocale}&tl={targetLocale}&dt=t&q={Uri.EscapeDataString(protectedText.Text)}");
        var requestUri = new Uri($"https://translate.googleapis.com/translate_a/single?{query}");

        try
        {
            using var httpClient = new HttpClient();
            using var response = await httpClient.GetAsync(requestUri, cancellationToken);
            if (!response.IsSuccessStatusCode)
            {
                return null;
            }

            await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken);
            using var document = await JsonDocument.ParseAsync(stream, cancellationToken: cancellationToken);

            if (document.RootElement.ValueKind != JsonValueKind.Array || document.RootElement.GetArrayLength() == 0)
            {
                return null;
            }

            var translatedText = new StringBuilder();
            foreach (var part in document.RootElement[0].EnumerateArray())
            {
                if (part.ValueKind != JsonValueKind.Array || part.GetArrayLength() == 0)
                {
                    continue;
                }

                var translatedPart = part[0].GetString();
                if (!string.IsNullOrWhiteSpace(translatedPart))
                {
                    translatedText.Append(translatedPart);
                }
            }

            if (translatedText.Length == 0)
            {
                return null;
            }

            return RestoreText(translatedText.ToString(), protectedText.Tokens);
        }
        catch
        {
            return null;
        }
    }

    private static ProtectedText ProtectText(string text)
    {
        var tokens = new Dictionary<string, string>();
        var index = 0;
        var protectedText = PlaceholderPattern.Replace(text, match =>
        {
            var token = $"___PM_PH_{index++}___";
            tokens[token] = match.Value;
            return token;
        });

        protectedText = protectedText.Replace("\n", NewlineToken, StringComparison.Ordinal);
        return new ProtectedText(protectedText, tokens);
    }

    private static string RestoreText(string text, IReadOnlyDictionary<string, string> tokens)
    {
        var restored = text.Replace(NewlineToken, "\n", StringComparison.Ordinal);
        foreach (var token in tokens)
        {
            restored = restored.Replace(token.Key, token.Value, StringComparison.Ordinal);
        }

        return restored;
    }

    private static string? NormalizeLocale(string? locale)
    {
        if (string.IsNullOrWhiteSpace(locale))
        {
            return null;
        }

        var normalized = locale.Trim().ToLowerInvariant();
        var separatorIndex = normalized.IndexOf('-');
        if (separatorIndex > 0)
        {
            normalized = normalized[..separatorIndex];
        }

        return normalized.Length == 2 ? normalized : null;
    }

    public sealed record TemplateLocalizedTexts(
        string Title,
        string ShortDescription,
        IReadOnlyList<string>? PetPhotoRequirements,
        string? ImagePrompt,
        string? PreprocessingPrompt,
        string? KlingPrompt);

    private sealed record ProtectedText(string Text, IReadOnlyDictionary<string, string> Tokens);
}
