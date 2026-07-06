using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;

using PetMagic.BuildingBlocks.Observability;

namespace PetMagic.Modules.Templates.Infrastructure;

internal static class TemplateLocalizationTranslator
{
    public const string HttpClientName = "TemplateLocalizationTranslator";

    private static readonly Regex PlaceholderPattern = new(@"\{[^{}]+\}", RegexOptions.Compiled);
    private const string SourceLocale = "en";
    private const string NewlineToken = "___PM_NL___";
    private const string SegmentSeparator = "___PM_SEG_BREAK___";
    private const int TranslationResponseMaxChars = 64 * 1024;
    private static readonly Uri TranslationEndpoint = new("https://translate.googleapis.com/translate_a/single");
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
        HttpClient httpClient,
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

            var translatedTexts = await TranslateTemplateTextsAsync(
                locale,
                title,
                shortDescription,
                petPhotoRequirements,
                imagePrompt,
                preprocessingPrompt,
                klingPrompt,
                normalizedSourceLocale,
                httpClient,
                cancellationToken);
            if (translatedTexts is null)
            {
                continue;
            }

            payload[locale] = translatedTexts;
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
        HttpClient httpClient,
        CancellationToken cancellationToken)
    {
        if (values is null || values.Count == 0)
        {
            return null;
        }

        var translatedValues = new List<string>(values.Count);
        foreach (var value in values)
        {
            var translated = await TranslateOptionalAsync(targetLocale, value, sourceLocale, httpClient, cancellationToken);
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

    private static async Task<TemplateLocalizedTexts?> TranslateTemplateTextsAsync(
        string targetLocale,
        string title,
        string shortDescription,
        IReadOnlyList<string>? petPhotoRequirements,
        string? imagePrompt,
        string? preprocessingPrompt,
        string? klingPrompt,
        string sourceLocale,
        HttpClient httpClient,
        CancellationToken cancellationToken)
    {
        var batch = TranslationBatch.Create(
            title,
            shortDescription,
            petPhotoRequirements,
            imagePrompt,
            preprocessingPrompt,
            klingPrompt);

        var translatedParts = await TranslateBatchAsync(targetLocale, batch.Values, sourceLocale, httpClient, cancellationToken);
        if (translatedParts is not null)
        {
            return batch.ToLocalizedTexts(translatedParts);
        }

        var translatedTitle = await TranslateAsync(targetLocale, title, sourceLocale, httpClient, cancellationToken);
        var translatedShortDescription = await TranslateAsync(targetLocale, shortDescription, sourceLocale, httpClient, cancellationToken);
        var translatedPetPhotoRequirements = await TranslateListAsync(targetLocale, petPhotoRequirements, sourceLocale, httpClient, cancellationToken);
        var translatedImagePrompt = await TranslateOptionalAsync(targetLocale, imagePrompt, sourceLocale, httpClient, cancellationToken);
        var translatedPreprocessingPrompt = await TranslateOptionalAsync(targetLocale, preprocessingPrompt, sourceLocale, httpClient, cancellationToken);
        var translatedKlingPrompt = await TranslateOptionalAsync(targetLocale, klingPrompt, sourceLocale, httpClient, cancellationToken);

        if (string.IsNullOrWhiteSpace(translatedTitle) || string.IsNullOrWhiteSpace(translatedShortDescription))
        {
            return null;
        }

        return new TemplateLocalizedTexts(
            translatedTitle,
            translatedShortDescription,
            translatedPetPhotoRequirements,
            translatedImagePrompt,
            translatedPreprocessingPrompt,
            translatedKlingPrompt);
    }

    private static async Task<string?> TranslateOptionalAsync(
        string targetLocale,
        string? value,
        string sourceLocale,
        HttpClient httpClient,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return null;
        }

        return await TranslateAsync(targetLocale, value, sourceLocale, httpClient, cancellationToken);
    }

    private static async Task<string?> TranslateAsync(
        string targetLocale,
        string text,
        string sourceLocale,
        HttpClient httpClient,
        CancellationToken cancellationToken)
    {
        try
        {
            var protectedText = ProtectText(text);
            var responseBody = await SendTranslationRequestAsync(
                targetLocale,
                protectedText.Text,
                sourceLocale,
                httpClient,
                cancellationToken);
            if (responseBody is null)
            {
                return null;
            }

            using var document = JsonDocument.Parse(responseBody);

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

    private static async Task<string[]?> TranslateBatchAsync(
        string targetLocale,
        IReadOnlyList<string> values,
        string sourceLocale,
        HttpClient httpClient,
        CancellationToken cancellationToken)
    {
        if (values.Count == 0)
        {
            return [];
        }

        var protectedParts = values.Select(ProtectText).ToArray();
        var joinedText = string.Join(SegmentSeparator, protectedParts.Select(x => x.Text));
        var translatedText = await TranslateRawAsync(targetLocale, joinedText, sourceLocale, httpClient, cancellationToken);
        if (string.IsNullOrWhiteSpace(translatedText))
        {
            return null;
        }

        var translatedParts = translatedText.Split(SegmentSeparator, StringSplitOptions.None);
        if (translatedParts.Length != protectedParts.Length)
        {
            return null;
        }

        var restoredParts = new string[translatedParts.Length];
        for (var index = 0; index < translatedParts.Length; index++)
        {
            restoredParts[index] = RestoreText(translatedParts[index], protectedParts[index].Tokens);
        }

        return restoredParts;
    }

    private static async Task<string?> TranslateRawAsync(
        string targetLocale,
        string text,
        string sourceLocale,
        HttpClient httpClient,
        CancellationToken cancellationToken)
    {
        try
        {
            var responseBody = await SendTranslationRequestAsync(
                targetLocale,
                text,
                sourceLocale,
                httpClient,
                cancellationToken);
            if (responseBody is null)
            {
                return null;
            }

            using var document = JsonDocument.Parse(responseBody);

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

            return translatedText.Length == 0 ? null : translatedText.ToString();
        }
        catch
        {
            return null;
        }
    }

    private static async Task<string?> SendTranslationRequestAsync(
        string targetLocale,
        string text,
        string sourceLocale,
        HttpClient httpClient,
        CancellationToken cancellationToken)
    {
        using var request = new HttpRequestMessage(HttpMethod.Post, TranslationEndpoint)
        {
            Content = new FormUrlEncodedContent([
                new KeyValuePair<string, string>("client", "gtx"),
                new KeyValuePair<string, string>("sl", sourceLocale),
                new KeyValuePair<string, string>("tl", targetLocale),
                new KeyValuePair<string, string>("dt", "t"),
                new KeyValuePair<string, string>("q", text)
            ])
        };

        using var response = await httpClient.SendAsync(
            request,
            HttpCompletionOption.ResponseHeadersRead,
            cancellationToken);
        if (!response.IsSuccessStatusCode)
        {
            return null;
        }

        return await SafeHttpContentReader.ReadRawStringPrefixAsync(
            response.Content,
            cancellationToken,
            TranslationResponseMaxChars);
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

    private sealed record TranslationBatch(
        IReadOnlyList<string> Values,
        int RequirementsCount,
        int? ImagePromptIndex,
        int? PreprocessingPromptIndex,
        int? KlingPromptIndex)
    {
        public static TranslationBatch Create(
            string title,
            string shortDescription,
            IReadOnlyList<string>? petPhotoRequirements,
            string? imagePrompt,
            string? preprocessingPrompt,
            string? klingPrompt)
        {
            var values = new List<string> { title, shortDescription };
            var requirementsCount = petPhotoRequirements?.Count ?? 0;
            if (petPhotoRequirements is not null)
            {
                values.AddRange(petPhotoRequirements);
            }

            int? imagePromptIndex = null;
            if (!string.IsNullOrWhiteSpace(imagePrompt))
            {
                imagePromptIndex = values.Count;
                values.Add(imagePrompt);
            }

            int? preprocessingPromptIndex = null;
            if (!string.IsNullOrWhiteSpace(preprocessingPrompt))
            {
                preprocessingPromptIndex = values.Count;
                values.Add(preprocessingPrompt);
            }

            int? klingPromptIndex = null;
            if (!string.IsNullOrWhiteSpace(klingPrompt))
            {
                klingPromptIndex = values.Count;
                values.Add(klingPrompt);
            }

            return new TranslationBatch(values, requirementsCount, imagePromptIndex, preprocessingPromptIndex, klingPromptIndex);
        }

        public TemplateLocalizedTexts? ToLocalizedTexts(IReadOnlyList<string> translatedParts)
        {
            if (translatedParts.Count < 2
                || string.IsNullOrWhiteSpace(translatedParts[0])
                || string.IsNullOrWhiteSpace(translatedParts[1]))
            {
                return null;
            }

            IReadOnlyList<string>? translatedRequirements = null;
            if (RequirementsCount > 0)
            {
                translatedRequirements = new List<string>(RequirementsCount);
                for (var index = 0; index < RequirementsCount; index++)
                {
                    var translatedValue = translatedParts[2 + index];
                    ((List<string>)translatedRequirements).Add(
                        string.IsNullOrWhiteSpace(translatedValue)
                            ? Values[2 + index]
                            : translatedValue);
                }
            }

            return new TemplateLocalizedTexts(
                translatedParts[0],
                translatedParts[1],
                translatedRequirements,
                ReadOptional(translatedParts, ImagePromptIndex),
                ReadOptional(translatedParts, PreprocessingPromptIndex),
                ReadOptional(translatedParts, KlingPromptIndex));
        }

        private static string? ReadOptional(IReadOnlyList<string> values, int? index)
        {
            if (!index.HasValue)
            {
                return null;
            }

            var value = values[index.Value];
            return string.IsNullOrWhiteSpace(value) ? null : value;
        }
    }

    private sealed record ProtectedText(string Text, IReadOnlyDictionary<string, string> Tokens);
}
