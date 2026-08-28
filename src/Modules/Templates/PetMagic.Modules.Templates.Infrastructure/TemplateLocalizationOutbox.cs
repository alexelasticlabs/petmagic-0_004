using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Notifications;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

internal static class TemplateLocalizationOutbox
{
    internal const string Kind = "template_localization";

    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    internal static async Task EnqueueForTemplateAsync(
        TemplatesDbContext dbContext,
        TemplateItem template,
        TemplatesOptions options,
        CancellationToken cancellationToken,
        bool onlyMissingTranslations = false)
    {
        if (!HasCompleteSource(template))
        {
            return;
        }

        var payload = CreatePayload(template, options.SourceLocalizationLocale);
        var now = DateTime.UtcNow;

        foreach (var targetLocale in NormalizeTargetLocales(options.SupportedLocalizationLocales, payload.SourceLocale))
        {
            if (onlyMissingTranslations
                && TryReadTranslation(template.LocalizedTextsJson ?? string.Empty, targetLocale, out _))
            {
                continue;
            }

            var deduplicationKey = BuildDeduplicationKey(template.Id, payload.SourceFingerprint, targetLocale);
            if (dbContext.PushOutboxMessages.Local.Any(message => message.DeduplicationKey == deduplicationKey)
                || await dbContext.PushOutboxMessages.AsNoTracking().AnyAsync(
                    message => message.DeduplicationKey == deduplicationKey,
                    cancellationToken))
            {
                continue;
            }

            dbContext.PushOutboxMessages.Add(new PushOutboxMessage
            {
                Id = Guid.NewGuid(),
                DeduplicationKey = deduplicationKey,
                Kind = Kind,
                UserId = Guid.Empty,
                PayloadJson = JsonSerializer.Serialize(payload with { TargetLocale = targetLocale }, JsonOptions),
                Status = PushOutboxStatus.Queued,
                NextAttemptAtUtc = now,
                CreatedAtUtc = now,
                UpdatedAtUtc = now
            });
        }
    }

    internal static string CreateSourceFingerprint(TemplateItem template, string sourceLocale) =>
        CreatePayload(template, sourceLocale).SourceFingerprint;

    internal static bool HasCompleteSource(TemplateItem template) =>
        !string.IsNullOrWhiteSpace(template.Title)
        && !string.IsNullOrWhiteSpace(template.ShortDescription);

    internal static TemplateLocalizationPayload CreatePayload(TemplateItem template, string sourceLocale)
    {
        var source = new TemplateLocalizationPayload(
            template.Id,
            TargetLocale: string.Empty,
            SourceLocale: NormalizeLocale(sourceLocale) ?? "en",
            SourceFingerprint: string.Empty,
            Title: template.Title,
            ShortDescription: template.ShortDescription,
            PetPhotoRequirements: DeserializeRequirements(template.PetPhotoRequirements),
            ImagePrompt: template.ImagePrompt,
            PreprocessingPrompt: template.PreprocessingPrompt,
            KlingPrompt: template.KlingPrompt,
            MusicDescription: template.MusicDescription);

        var sourceJson = JsonSerializer.Serialize(source with { SourceFingerprint = string.Empty }, JsonOptions);
        return source with { SourceFingerprint = Convert.ToHexStringLower(SHA256.HashData(Encoding.UTF8.GetBytes(sourceJson))) };
    }

    internal static bool TryReadTranslation(
        string localizedTextsJson,
        string targetLocale,
        out TemplateLocalizationTranslator.TemplateLocalizedTexts translation)
    {
        translation = default!;
        try
        {
            var translations = JsonSerializer.Deserialize<Dictionary<string, TemplateLocalizationTranslator.TemplateLocalizedTexts>>(
                localizedTextsJson,
                JsonOptions);
            if (translations is null
                || !translations.TryGetValue(targetLocale, out var candidate)
                || candidate is null
                || string.IsNullOrWhiteSpace(candidate.Title)
                || string.IsNullOrWhiteSpace(candidate.ShortDescription))
            {
                return false;
            }

            translation = candidate;
            return true;
        }
        catch (JsonException)
        {
            return false;
        }
    }

    internal static string MergeTranslation(
        string? localizedTextsJson,
        string targetLocale,
        TemplateLocalizationTranslator.TemplateLocalizedTexts translation)
    {
        Dictionary<string, TemplateLocalizationTranslator.TemplateLocalizedTexts> translations;
        try
        {
            translations = string.IsNullOrWhiteSpace(localizedTextsJson)
                ? new Dictionary<string, TemplateLocalizationTranslator.TemplateLocalizedTexts>(StringComparer.OrdinalIgnoreCase)
                : JsonSerializer.Deserialize<Dictionary<string, TemplateLocalizationTranslator.TemplateLocalizedTexts>>(
                    localizedTextsJson,
                    JsonOptions)
                  ?? new Dictionary<string, TemplateLocalizationTranslator.TemplateLocalizedTexts>(StringComparer.OrdinalIgnoreCase);
        }
        catch (JsonException)
        {
            translations = new Dictionary<string, TemplateLocalizationTranslator.TemplateLocalizedTexts>(StringComparer.OrdinalIgnoreCase);
        }

        translations[targetLocale] = translation;
        return JsonSerializer.Serialize(translations, JsonOptions);
    }

    internal static bool IsTargetLocaleSupported(TemplateLocalizationPayload payload, TemplatesOptions options) =>
        NormalizeTargetLocales(options.SupportedLocalizationLocales, payload.SourceLocale)
            .Contains(payload.TargetLocale, StringComparer.OrdinalIgnoreCase);

    private static IEnumerable<string> NormalizeTargetLocales(IEnumerable<string> locales, string sourceLocale) =>
        locales.Select(NormalizeLocale)
            .Where(locale => !string.IsNullOrWhiteSpace(locale)
                             && !string.Equals(locale, sourceLocale, StringComparison.OrdinalIgnoreCase))
            .Cast<string>()
            .Distinct(StringComparer.OrdinalIgnoreCase);

    private static IReadOnlyList<string>? DeserializeRequirements(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return null;
        }

        return value
            .Split('\n', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Select(requirement => requirement.Trim())
            .Where(requirement => !string.IsNullOrWhiteSpace(requirement))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray();
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

    private static string BuildDeduplicationKey(Guid templateId, string sourceFingerprint, string targetLocale) =>
        $"template_localization:{templateId:D}:{sourceFingerprint}:{targetLocale}";

    internal sealed record TemplateLocalizationPayload(
        Guid TemplateId,
        string TargetLocale,
        string SourceLocale,
        string SourceFingerprint,
        string Title,
        string ShortDescription,
        IReadOnlyList<string>? PetPhotoRequirements,
        string? ImagePrompt,
        string? PreprocessingPrompt,
        string? KlingPrompt,
        string? MusicDescription);
}
